$env.HOMEBREW_PREFIX = "/opt/homebrew"
$env.HOMEBREW_CELLAR = "/opt/homebrew/Cellar"
$env.HOMEBREW_REPOSITORY = "/opt/homebrew"
$env.MANPATH = ($env.MANPATH? | default [] | prepend "/opt/homebrew/share/man")
$env.INFOPATH = ($env.INFOPATH? | default [] | prepend "/opt/homebrew/share/info")

$env.PATH = [
  ($nu.home-dir | path join ".platformio" "penv" "bin")
  ($nu.home-dir | path join ".platformio" "packages" "toolchain-gccarmnoneeabi-teensy" "bin")
  "/etc/profiles/per-user/uzair/bin"
  "/run/current-system/sw/bin"
  "/nix/var/nix/profiles/default/bin"
  "/opt/homebrew/sbin"
  "/opt/homebrew/bin"
  "/opt/homebrew/opt/llvm/bin"
  ($nu.home-dir | path join ".config" "bin")
  ($nu.home-dir | path join ".cargo" "bin")
  ($nu.home-dir | path join ".local" "bin")
  ($nu.home-dir | path join ".opencode" "bin")
  ($nu.home-dir | path join ".lmstudio" "bin")
  "/usr/local/bin"
  "/usr/bin"
  "/bin"
  "/usr/sbin"
  "/sbin"
]

$env.PATH = ($env.PATH | prepend ($nu.home-dir | path join ".deno" "bin"))

$env.EDITOR = "hx"
$env.XDG_CONFIG_HOME = $"($env.HOME)/.config"
$env.NIX_PROFILES = $"/nix/var/nix/profiles/default /run/current-system/sw /etc/profiles/per-user/uzair"

# Fixed: $env.?XDG_DATA_DIRS -> $env.XDG_DATA_DIRS?
if ($env.XDG_DATA_DIRS? | default null) != null {
  let base = (
    $env.XDG_DATA_DIRS | split row (char esep) | prepend [
      "/nix/var/nix/profiles/default/share"
      "/run/current-system/sw/share"
      "/etc/profiles/per-user/uzair/share"
    ]
  )
  $env.XDG_DATA_DIRS = ($base | str join (char esep))
} else {
  $env.XDG_DATA_DIRS = "/nix/var/nix/profiles/default/share:/run/current-system/sw/share:/etc/profiles/per-user/uzair/share"
}

# Fixed: $env.?XDG_STATE_HOME -> $env.XDG_STATE_HOME?
let nix_link = if ($env.XDG_STATE_HOME? | default null) != null {
  $"($env.XDG_STATE_HOME)/nix/profile"
} else {
  $"($env.HOME)/.local/state/nix/profile"
}

if ($nix_link | path exists) {
  $env.NIX_LINK = $nix_link
} else {
  $env.NIX_LINK = $"($env.HOME)/.nix-profile"
}

# Fixed: $env.?NIX_SSL_CERT_FILE -> $env.NIX_SSL_CERT_FILE?
if ($env.NIX_SSL_CERT_FILE? | default null) == null {
  $env.NIX_SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt"
}

if $nu.os-info.name == "macos" {
  let sdkroot = (try { ^xcrun --show-sdk-path | str trim } catch { "" })
  if ($sdkroot | is-not-empty) {
    $env.SDKROOT = $sdkroot

    if ($env.LIBRARY_PATH? | default null) != null {
      $env.LIBRARY_PATH = $"($sdkroot)/usr/lib(char esep)($env.LIBRARY_PATH)"
    } else {
      $env.LIBRARY_PATH = $"($sdkroot)/usr/lib"
    }

    if ($env.CPATH? | default null) != null {
      $env.CPATH = $"($sdkroot)/usr/include(char esep)($env.CPATH)"
    } else {
      $env.CPATH = $"($sdkroot)/usr/include"
    }
  }
}

try {
  let fnm_env = (^fnm env --json | from json)
  load-env ($fnm_env | select FNM_DIR FNM_COREPACK_ENABLED FNM_ARCH FNM_VERSION_FILE_STRATEGY FNM_RESOLVE_ENGINES FNM_LOGLEVEL FNM_NODE_DIST_MIRROR FNM_MULTISHELL_PATH)
  $env.PATH = ($env.PATH | prepend $"($fnm_env.FNM_MULTISHELL_PATH)/bin")
} catch { }

$env.DETSYS_IDS_TELEMETRY = "disabled"
$env.FZF_DEFAULT_OPTS = (
  [
    ($env.FZF_DEFAULT_OPTS? | default "")
    "--color=bg:#1f1d2e,bg+:#26233a,fg:#908caa,fg+:#f2e9e1"
    "--color=hl:#c4a7e7,hl+:#c4a7e7,pointer:#c4a7e7,prompt:#c4a7e7"
    "--color=info:#f2e9e1,border:#f2e9e1,marker:#c4a7e7,spinner:#c4a7e7"
    "--color=header:#908caa,label:#f2e9e1,query:#f2e9e1"
  ]
  | where {|opt| $opt != "" }
  | str join " "
)
$env.PATH = ($env.PATH | split row (char esep) | prepend ($nu.home-dir | path join ".bun" "bin"))

$env.PNPM_HOME = ($nu.home-dir | path join "Library" "pnpm")
$env.PATH = ($env.PATH | split row (char esep) | prepend $env.PNPM_HOME)

let cacert_cache = ($nu.home-dir | path join ".cache" "shell" "nix-cacert")
let cacert = if ($cacert_cache | path exists) {
  open --raw $cacert_cache | str trim
} else {
  let result = (nix eval --raw nixpkgs#cacert.outPath | str trim)
  mkdir ($cacert_cache | path dirname)
  $result | save --raw $cacert_cache
  $result
}
$env.SSL_CERT_FILE = $"($cacert)/etc/ssl/certs/ca-bundle.crt"
$env.NIX_SSL_CERT_FILE = $env.SSL_CERT_FILE
$env.CARGO_HTTP_CAINFO = $env.SSL_CERT_FILE
$env.CARGO_NET_GIT_FETCH_WITH_CLI = "true"
