alias psa = ^ps aux
alias rm = rm --verbose
alias mv = mv --verbose
alias cp = cp --recursive --verbose
alias nixup = nix profile upgrade nix --verbose
def tree [...args] { ^eza --tree --git-ignore --group-directories-first ...$args }
# def python3 [...args] { print "use uv" }
# def which [...args] { ^which -a ...$args }
def bat [...args] { ^bat -P --style=plain ...$args }

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
  let system = (^nix --no-warn-dirty eval --impure --raw --expr builtins.currentSystem | str trim)
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
  | pbcopy
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
  --no-hostnames(-n) # Skip reverse DNS/NetBIOS hostname lookups.
] {
  let iface = "en0"
  let network = (
    ^ipconfig getifaddr $iface
    | str trim
    | split row "."
    | take 3
    | str join "."
  )

  if $sweep and ($network | is-not-empty) {
    seq 1 254 | par-each --threads 64 {|n|
      do { ^ping -q -n -c 1 -W 200 $"($network).($n)" } | complete | ignore
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
  let system_arp_entries = (
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
  )

  # Merge and dedupe (arp-scan results take precedence for vendor info)
  let entries = ($arp_scan_entries ++ $system_arp_entries | uniq-by ip)

  $entries
  | par-each --threads 32 {|e|
    let hostname = (
      if $no_hostnames {
        ""
      } else {
        let dscache_out = (^dscacheutil -q host -a address $e.ip | lines | str trim)
        let h1 = ($dscache_out | where {|l| $l =~ '^name:' } | get 0? | default "")
        if not ($h1 | is-empty) {
          $h1 | parse -r '^name:\s*(.+)$' | get capture0.0 | default ""
        } else {
          let dig_result = (do { ^dig +time=1 +tries=1 +short -x $e.ip } | complete)
          let dig_out = $dig_result.stdout | lines
          if ($dig_out | is-not-empty) {
            $dig_out | get 0 | str trim --right --char '.'
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
