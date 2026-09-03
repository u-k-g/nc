alias psa = ^ps aux
alias rm = rm --verbose
alias mv = mv --verbose
alias cp = cp --recursive --verbose
alias nixup = nix profile upgrade nix --verbose
alias mosh = ^mosh --no-init
def tree [...args] { ^eza --tree --git-ignore --group-directories-first ...$args }
# def python3 [...args] { print "use uv" }
# def which [...args] { ^which -a ...$args }
def nixbump [
  --old: int = 0
  --cached: int = 0
] {
  let timeout_sec = 999
  let set_status = {|message|
    if (^test -t 2 | complete | get exit_code) == 0 {
      print -n --stderr $"\r(ansi --escape '2K')($message)"
    }
  }
  let flake = ($env.HOME | path join "nc")
  let lockfile = ($flake | path join "flake.lock")
  let candidate_lock = ($flake | path join ".flake.lock.candidate")
  let current_rev = (open --raw $lockfile | from json | get nodes.nixpkgs.locked.rev)
  let system = "@system@"
  let target = $"($flake)#packages.($system).default"
  let run_quiet_build = {|status, reference_lock|
    let runner = 'status="$1"; timeout_sec="$2"; shift 2; log="$(mktemp -t nixbump.XXXXXX)"; trap "rm -f $log" EXIT; if [ -w /dev/tty ]; then tty=/dev/tty; elif [ -t 2 ]; then tty=/dev/stderr; else tty=; fi; start=$(date +%s); timeout --kill-after=5s "$timeout_sec" "$@" >"$log" 2>&1 & pid=$!; while kill -0 "$pid" 2>/dev/null; do if [ -n "$tty" ]; then elapsed=$(($(date +%s) - start)); last_line=$(tail -n 1 "$log" 2>/dev/null | tr -d "\r\033" | cut -c1-100); if [ -n "$last_line" ]; then printf "\r\033[2K%s | %s | elapsed=%ss" "$status" "$last_line" "$elapsed" >"$tty" 2>/dev/null || tty=; else printf "\r\033[2K%s | elapsed=%ss" "$status" "$elapsed" >"$tty" 2>/dev/null || tty=; fi; fi; sleep 1; done; wait "$pid"; code=$?; if [ -n "$tty" ]; then printf "\r\033[2K" >"$tty" 2>/dev/null || true; fi; exit "$code"'
    let cmd = [
      "nix"
      "--no-warn-dirty"
      "build"
      "--reference-lock-file"
      $reference_lock
      $target
      "--no-link"
    ]

    do --ignore-errors {
      run-external "sh" "-c" $runner "sh" $status ($timeout_sec | into string) ...$cmd
    }
    $env.LAST_EXIT_CODE
  }
  let count_uncached = {|ref_lock|
    let dry = (
      do { ^nix --no-warn-dirty build --dry-run --reference-lock-file $ref_lock $target --no-link }
      | complete
    )
    if ($dry.stdout =~ 'will be built') {
      let all_drv = ($dry.stdout | lines | where {|l| $l =~ '\.drv' } | length)
      let ukg_drv = ($dry.stdout | lines | where {|l| $l =~ 'ukg\.drv' } | length)
      ($all_drv - $ukg_drv)
    } else {
      0
    }
  }

  do $set_status $"current nixpkgs rev: ($current_rev | str substring 0..11)"

  if $cached > 0 {
    let scan_depth = $cached
    do $set_status $"scanning up to ($scan_depth) commits for fully-cached rev"

    let commits = (
      ^gh api $"repos/NixOS/nixpkgs/commits?sha=nixos-unstable&per_page=($scan_depth)"
      | from json
      | get sha
    )

    if ($commits | is-empty) {
      error make {msg: "No nixpkgs revisions returned from GitHub."}
    }

    for entry in ($commits | enumerate) {
      let rev = $entry.item
      let attempt = ($entry.index + 1)
      let total = ($commits | length)
      let rev_short = ($rev | str substring 0..11)
      let is_current = ($rev == $current_rev)

      do $set_status $"[($attempt)/($total)] testing nixpkgs rev ($rev_short)"
      let update_result = (
        do {
          ^nix --no-warn-dirty flake update nixpkgs --flake $flake --override-input nixpkgs $"github:NixOS/nixpkgs/($rev)" --output-lock-file $candidate_lock
        }
        | complete
      )
      if $update_result.exit_code != 0 {
        continue
      }

      let n_uncached = (do $count_uncached $candidate_lock)
      if $n_uncached == 0 {
        do $set_status $"[($attempt)/($total)] rev ($rev_short) fully cached, building"
        let check_exit = (do $run_quiet_build $"building nixpkgs rev ($rev_short)" $candidate_lock)
        if $check_exit == 0 {
          ^mv -f $candidate_lock $lockfile
          print --stderr ""
          print $"previous nixpkgs rev: ($current_rev)"
          print $"using nixpkgs rev: ($rev)"
          ^nix profile upgrade nix
          return
        }
        do $set_status $"[($attempt)/($total)] cached rev ($rev_short) build failed unexpectedly"
        continue
      }

      do $set_status $"[($attempt)/($total)] rev ($rev_short) requires ($n_uncached) builds, trying older"
    }

    if ($candidate_lock | path exists) {
      ^rm -f $candidate_lock
    }
    print --stderr ""
    error make {msg: $"No fully-cached nixpkgs revision found in the last ($scan_depth) commits. Kept ($current_rev)."}
  }

  do $set_status $"fetching nixpkgs candidate offset=($old)"
  let per_page = ($old + 1)
  let commits = (
    ^gh api $"repos/NixOS/nixpkgs/commits?sha=nixos-unstable&per_page=($per_page)"
    | from json
    | get sha
  )

  if ($commits | is-empty) {
    error make {msg: "No nixpkgs revisions returned from GitHub."}
  }

  let rev = ($commits | last)
  let rev_short = ($rev | str substring 0..11)
  let is_current = ($rev == $current_rev)

  if $is_current {
    do $set_status $"building current nixpkgs rev ($rev_short)"
    let check_exit = (do $run_quiet_build $"building current nixpkgs rev ($rev_short)" $lockfile)

    if $check_exit == 0 {
      print --stderr ""
      print $"current nixpkgs rev: ($current_rev)"
      print $"using nixpkgs rev: ($rev)"
      ^nix profile upgrade nix
      return
    }

    if $check_exit == 124 {
      do $set_status $"timed out after ($timeout_sec)s at current rev ($rev_short)"
      return 1
    }

    do $set_status $"current nixpkgs rev ($rev_short) build failed"
    return 1
  }

  do $set_status $"updating lock for nixpkgs rev ($rev_short)"

  let update_result = (
    do {
      ^nix --no-warn-dirty flake update nixpkgs --flake $flake --override-input nixpkgs $"github:NixOS/nixpkgs/($rev)" --output-lock-file $candidate_lock
    }
    | complete
  )
  if $update_result.exit_code != 0 {
    error make {msg: $"Failed to update lockfile for rev ($rev)"}
  }

  do $set_status $"building nixpkgs rev ($rev_short)"
  let check_exit = (do $run_quiet_build $"building nixpkgs rev ($rev_short)" $candidate_lock)

  if $check_exit == 124 {
    do $set_status $"timed out after ($timeout_sec)s at rev ($rev_short)"
    return 1
  }

  if $check_exit != 0 {
    do $set_status $"build failed for nixpkgs rev ($rev_short)"
    return 1
  }

  ^mv -f $candidate_lock $lockfile
  print --stderr ""
  print $"previous nixpkgs rev: ($current_rev)"
  print $"using nixpkgs rev: ($rev)"
  ^nix profile upgrade nix
}

def --env y [...args] {
  let tmp = (mktemp -t "yazi-cwd.XXXXXX")
  ^yazi ...$args --cwd-file $tmp
  let cwd = (open $tmp)
  if $cwd != $env.PWD and ($cwd | path exists) { cd $cwd }
  rm -fp $tmp
}

def "nu-keybind commandline-copy" []: nothing -> nothing {
  commandline
  | nu-highlight
  | [
    "```ansi"
    $in
    "```"
  ]
  | str join (char nl)
  | ^@clipboardCopy@
}

$env.config.keybindings ++= [
  {
    name: copy_color_commandline
    modifier: control_alt
    keycode: char_c
    mode: [emacs vi_insert vi_normal]
    event: {
      send: executehostcommand
      cmd: 'nu-keybind commandline-copy'
    }
  }
]

def fing [
  --sweep(-s) # Also ping every host first; slower, but can find devices missed by arp-scan.
  --no-hostnames(-n) # Skip DNS/mDNS/NetBIOS hostname lookups.
] {
  let is_macos = $nu.os-info.name == "macos"
  let iface = if $is_macos {
    let route_result = (do { ^route -n get default } | complete)
    $route_result.stdout
    | lines
    | parse -r '^\s*interface:\s+(?P<interface>\S+)$'
    | get interface.0?
    | default ""
  } else {
    let route_result = (do { ^ip -json route show default } | complete)
    try {
      $route_result.stdout
      | from json
      | get 0.dev
    } catch {
      ""
    }
  }

  if ($iface | is-empty) {
    error make {msg: "Could not determine the default network interface."}
  }

  let address = if $is_macos {
    do { ^ipconfig getifaddr $iface } | complete | get stdout
  } else {
    let address_result = (do { ^ip -json -4 address show dev $iface } | complete)
    try {
      $address_result.stdout
      | from json
      | get 0.addr_info
      | where family == "inet"
      | get 0.local
    } catch {
      ""
    }
  }
  let network = (
    $address
    | str trim
    | split row "."
    | take 3
    | str join "."
  )

  if ($network | is-empty) {
    error make {msg: $"Could not determine the IPv4 network for ($iface)."}
  }

  if $sweep {
    let timeout_args = if $is_macos { ["-W" "200"] } else { ["-W" "1"] }
    seq 1 254 | par-each --threads 64 {|n|
      do { ^ping -q -n -c 1 ...$timeout_args $"($network).($n)" } | complete | ignore
    }
  }

  let arp_scan_entries = (
    do {
      let raw = (^sudo arp-scan --interface=($iface) --localnet e> /dev/null | lines)
      if ($raw | is-empty) { [] } else {
        $raw
        | where {|l| $l =~ '^[0-9]+\.' }
        | parse -r '^(?P<ip>[0-9.]+)\s+(?P<mac>[0-9a-f:]{17})\s+(?P<vendor>.+)'
      }
    }
  )

  # Also check system ARP cache (includes devices from ping sweep that arp-scan missed)
  let system_arp_entries = if $is_macos {
    do {
      let raw = (^arp -a | lines)
      if ($raw | is-empty) { [] } else {
        $raw
        | where {|l| $l =~ '\? \(' }
        | parse -r '^\? \((?P<ip>[0-9.]+)\) at (?P<mac>[0-9a-f:]+) on (?P<iface>\S+)'
        | where iface == $iface
        | each {|e| {ip: $e.ip mac: $e.mac vendor: "(from system ARP)"} }
      }
    }
  } else {
    do {
      let raw = (^ip neigh show dev $iface | lines)
      if ($raw | is-empty) { [] } else {
        $raw
        | parse -r '^(?P<ip>[0-9.]+)\s+.*lladdr\s+(?P<mac>[0-9a-f:]{17})\s+.*$'
        | each {|e| {ip: $e.ip mac: $e.mac vendor: "(from system ARP)"} }
      }
    }
  }

  # Merge and dedupe (arp-scan results take precedence for vendor info)
  let entries = ($arp_scan_entries ++ $system_arp_entries | uniq-by ip)

  let clean_hostname = {|name|
    $name
    | str trim
    | str trim --right --char "."
  }

  let ssh_local_hostnames = (
    if $no_hostnames {
      []
    } else {
      let known_hosts_path = ($env.HOME | path join ".ssh" "known_hosts")
      let known_hosts = (
        if ($known_hosts_path | path exists) {
          open --raw $known_hosts_path
          | lines
          | where {|line| not ($line | str starts-with "#") and not ($line | str starts-with "|") }
          | each {|line|
            $line
            | split row " "
            | get 0?
            | default ""
            | split row ","
            | each {|host|
              let unwrapped_host = (
                $host
                | str replace -r '^\[' ''
                | str replace -r '\]:[0-9]+$' ''
              )
              do $clean_hostname $unwrapped_host
            }
          }
          | flatten
        } else {
          []
        }
      )

      let ssh_config_path = ($env.HOME | path join ".ssh" "config")
      let ssh_config_hosts = (
        if ($ssh_config_path | path exists) {
          open --raw $ssh_config_path
          | lines
          | str trim
          | where {|line| $line =~ '(?i)^(host|hostname)\s+.+' }
          | parse -r '(?i)^(host|hostname)\s+(?P<hosts>.+)$'
          | get hosts
          | each {|hosts| $hosts | split row " " }
          | flatten
          | where {|host| $host =~ '(?i)\.local\.?$' }
          | each {|host| do $clean_hostname $host }
        } else {
          []
        }
      )

      $known_hosts
      | append $ssh_config_hosts
      | where {|host| $host =~ '(?i)\.local$' }
      | uniq
    }
  )

  let ssh_local_hosts_by_ip = (
    $ssh_local_hostnames
    | par-each --threads 16 {|host|
      let ip = if $is_macos {
        let dscache_out = (^dscacheutil -q host -a name $host | lines | str trim)
        let dscache_ip = (
          $dscache_out
          | where {|line| $line =~ '^ip_address:' }
          | get 0?
          | default ""
          | parse -r '^ip_address:\s*(?P<ip>[0-9.]+)$'
          | get ip.0?
          | default ""
        )
        if ($dscache_ip | is-not-empty) {
          $dscache_ip
        } else {
          let dns_sd_result = (do { ^timeout 1 dns-sd -G v4 $host } | complete)
          $dns_sd_result.stdout
          | lines
          | parse -r '.*\s(?P<ip>[0-9]+(?:\.[0-9]+){3})\s+[0-9]+.*'
          | get ip.0?
          | default ""
        }
      } else {
        let avahi_result = (do { ^timeout 1 avahi-resolve-host-name --ipv4 --terminate $host } | complete)
        if $avahi_result.exit_code == 0 {
          $avahi_result.stdout
          | parse -r '^\S+\s+(?P<ip>[0-9.]+)$'
          | get ip.0?
          | default ""
        } else {
          ""
        }
      }

      {
        ip: $ip
        hostname: $host
      }
    }
    | where {|host| $host.ip | is-not-empty }
    | uniq-by ip
  )

  $entries
  | par-each --threads 32 {|e|
    let hostname = (
      if $no_hostnames {
        ""
      } else {
        let ssh_local_hostname = (
          $ssh_local_hosts_by_ip
          | where ip == $e.ip
          | get hostname.0?
          | default ""
        )
        if ($ssh_local_hostname | is-not-empty) {
          $ssh_local_hostname
        } else {
          let system_hostname = if $is_macos {
            let dscache_out = (^dscacheutil -q host -a address $e.ip | lines | str trim)
            $dscache_out
            | where {|line| $line =~ '^name:' }
            | get 0?
            | default ""
            | parse -r '^name:\s*(?P<hostname>.+)$'
            | get hostname.0?
            | default ""
          } else {
            let avahi_result = (do { ^timeout 1 avahi-resolve-address --ipv4 --terminate $e.ip } | complete)
            if $avahi_result.exit_code == 0 {
              $avahi_result.stdout
              | parse -r '^\S+\s+(?P<hostname>\S+)$'
              | get hostname.0?
              | default ""
            } else {
              ""
            }
          }
          if ($system_hostname | is-not-empty) {
            do $clean_hostname $system_hostname
          } else {
            let dig_result = (do { ^dig +time=1 +tries=1 +short -x $e.ip } | complete)
            let dig_out = $dig_result.stdout | lines
            let fallback_hostname = if ($dig_out | is-not-empty) {
              do $clean_hostname ($dig_out | get 0)
            } else if $is_macos {
              let reverse_mdns_name = (
                $e.ip
                | split row "."
                | reverse
                | str join "."
              )
              let mdns_ptr_result = (do { ^timeout 1 dns-sd -q $"($reverse_mdns_name).in-addr.arpa" PTR IN } | complete)
              let mdns_ptr_hostname = (
                $mdns_ptr_result.stdout
                | lines
                | where {|line| $line =~ '\sPTR\s+IN\s+\S+\.local\.?$' }
                | parse -r '.*\sPTR\s+IN\s+(?P<host>\S+\.local\.?)$'
                | get host.0?
                | default ""
              )
              if ($mdns_ptr_hostname | is-not-empty) {
                do $clean_hostname $mdns_ptr_hostname
              } else {
                ""
              }
            } else {
              ""
            }
            if ($fallback_hostname | is-not-empty) {
              $fallback_hostname
            } else {
              let nbtscan_out = (^nbtscan -q -m 1 -t 300 $e.ip e> /dev/null)
              if ($nbtscan_out | is-not-empty) {
                $nbtscan_out | parse -r '^\S+\s+\S+\s+\S+\s+(\S+)' | get capture0.0 | default ""
              } else {
                "<no-hostname>"
              }
            }
          }
        }
      }
    )
    {
      ip: $e.ip
      mac: $e.mac
      vendor: ($e.vendor | str substring 0..<25)
      hostname: $hostname
    }
  }
  | sort-by ip
}

def serialf [...args] {
  let devices = (
    ^tio -l
    | lines
    | parse -r '^(?P<device>/\S+)\s+(?:(?P<tid>\S+)\s+)?(?P<uptime>\d+(?:\.\d+)?)\s*(?P<rest>.*)$'
    | update uptime {|row| $row.uptime | into float }
    | sort-by uptime
    | each {|row| $"($row.device)  uptime=($row.uptime)s" }
  )

  if ($devices | is-empty) {
    error make {msg: "No serial devices found from `tio -l`."}
  }

  let selection = (
    $devices
    | str join (char nl)
    | do {
      ^fzf --prompt 'tio> ' --height 40% --reverse --border
    }
    | complete
  )

  if $selection.exit_code != 0 {
    return
  }

  let choice = ($selection.stdout | str trim)
  let parsed = ($choice | parse -r '^(?P<device>/\S+)')

  if ($parsed | is-empty) {
    error make {msg: $"Couldn't parse a device from: ($choice)"}
  }

  let device = ($parsed | get device | get 0)

  let baud_selection = (
    [9600 19200 38400 57600 115200 230400 460800 921600]
    | each {|baud| $baud | into string }
    | str join (char nl)
    | do {
      ^fzf --prompt 'baud> ' --height 40% --reverse --border
    }
    | complete
  )

  if $baud_selection.exit_code != 0 {
    return
  }

  let baud = ($baud_selection.stdout | str trim)
  ^tio -m ODELBS -b $baud ...$args $device
}
