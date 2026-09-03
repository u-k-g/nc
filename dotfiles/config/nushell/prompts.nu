let PROMPT_STYLE = "flowy"
# let PROMPT_STYLE = "boxy"
let PROMPT_ACCENT_COLOR = if (($env.SSH_CONNECTION? | default "") | is-not-empty) {
  "@remotePromptAccent@"
} else {
  "@localPromptAccent@"
}
let PROMPT_ACCENT = ansi { fg: $PROMPT_ACCENT_COLOR }
let PROMPT_ACCENT_BOLD = ansi { fg: $PROMPT_ACCENT_COLOR attr: b }
let PROMPT_ACCENT_DIMMED = ansi { fg: $PROMPT_ACCENT_COLOR attr: d }
let PROMPT_ACCENT_ITALIC = ansi { fg: $PROMPT_ACCENT_COLOR attr: i }
$env.JJ_WORKSPACE_ROOT = ""
$env.JJ_WORKSPACE_ROOT_PWD = ""
$env.JJ_WORKSPACE_ROOT_TS = ""
$env.JJ_RIGHT_PROMPT_PWD = ""
$env.JJ_RIGHT_PROMPT_VALUE = ""
$env.JJ_RIGHT_PROMPT_TS = ""
$env.GIT_PROMPT_PWD = ""
$env.GIT_PROMPT_VALUE = ""
$env.GIT_PROMPT_TS = ""
def get-jj-workspace-root [] {
  let now = (date now | format date "%s" | into int)
  if $env.JJ_WORKSPACE_ROOT_PWD? == $env.PWD and ($env.JJ_WORKSPACE_ROOT_TS? | default "" | is-not-empty) {
    if ($now - ($env.JJ_WORKSPACE_ROOT_TS | into int)) < 2 {
      return $env.JJ_WORKSPACE_ROOT
    }
  }
  let root = try { ^jj workspace root err> $null_device } catch { "" }
  $env.JJ_WORKSPACE_ROOT = $root
  $env.JJ_WORKSPACE_ROOT_PWD = $env.PWD
  $env.JJ_WORKSPACE_ROOT_TS = $now
  $root
}
def get-jj-right-prompt [] {
  let now = (date now | format date "%s" | into int)
  if $env.JJ_RIGHT_PROMPT_PWD? == $env.PWD and ($env.JJ_RIGHT_PROMPT_TS? | default "" | is-not-empty) {
    if ($now - ($env.JJ_RIGHT_PROMPT_TS | into int)) < 2 {
      return $env.JJ_RIGHT_PROMPT_VALUE
    }
  }

  let jj_workspace_root = get-jj-workspace-root
  if ($jj_workspace_root | is-empty) {
    $env.JJ_RIGHT_PROMPT_PWD = $env.PWD
    $env.JJ_RIGHT_PROMPT_TS = $now
    $env.JJ_RIGHT_PROMPT_VALUE = ""
    return ""
  }

  let change_id_shortest = try {
    do -i { ^jj --no-pager log -r '@' --no-graph -T 'change_id.shortest()' err> $null_device | str trim }
  } catch { "" }
  let closest_bookmark = try {
    do -i { ^jj --no-pager log -r 'heads(ancestors(@) & bookmarks())' --no-graph -T 'local_bookmarks.map(|b| b.name()).join(", ")' err> $null_device | str trim }
  } catch { "" }
  let has_changes = try {
    do -i { (^jj --no-pager status | str contains "orking copy change") }
  } catch { false }
  let bookmark_part = if ($closest_bookmark | is-not-empty) { $"($PROMPT_ACCENT)[($PROMPT_ACCENT_ITALIC)($closest_bookmark)(ansi reset)($PROMPT_ACCENT)](ansi reset)" } else { "" }
  let change_id_part = if ($change_id_shortest | is-not-empty) { $"(ansi reset)($PROMPT_ACCENT_ITALIC)($change_id_shortest)(ansi reset)" } else { "" }
  let status_part = if $has_changes { $"($PROMPT_ACCENT_DIMMED)(ansi bo)*(ansi reset) " } else { $"(ansi dark_gray_bold)·(ansi reset) " }
  let parts = [$bookmark_part $change_id_part $status_part] | where {|x| $x | is-not-empty }
  let value = if ($parts | is-empty) {
    ""
  } else {
    $parts | enumerate | each {|i| if $i.index == 0 { $i.item } else { $"(ansi dark_gray_bold) · (ansi reset)($i.item)" } } | str join ""
  }

  $env.JJ_RIGHT_PROMPT_PWD = $env.PWD
  $env.JJ_RIGHT_PROMPT_TS = $now
  $env.JJ_RIGHT_PROMPT_VALUE = $value
  $value
}
def get-git-prompt [] {
  let now = (date now | format date "%s" | into int)
  if $env.GIT_PROMPT_PWD? == $env.PWD and ($env.GIT_PROMPT_TS? | default "" | is-not-empty) {
    if ($now - ($env.GIT_PROMPT_TS | into int)) < 2 {
      return $env.GIT_PROMPT_VALUE
    }
  }

  let branch = try { ^git rev-parse --abbrev-ref HEAD err> $null_device | str trim } catch { "" }
  $env.GIT_PROMPT_PWD = $env.PWD
  let branch = if ($branch == "HEAD") {
    try { ^git rev-parse --short HEAD err> $null_device | str trim } catch { "" }
  } else {
    $branch
  }
  let value = if ($branch | is-not-empty) {
    $"(ansi reset)($PROMPT_ACCENT_ITALIC)($branch)(ansi reset)"
  } else {
    ""
  }

  $env.GIT_PROMPT_TS = $now
  $env.GIT_PROMPT_VALUE = $value
  $value
}
def prompt-header [--left-char: string] {
  let jj_workspace_root = get-jj-workspace-root
  let body = if ($jj_workspace_root | is-not-empty) {
    let subpath = pwd | path relative-to $jj_workspace_root
    let subpath = if ($subpath | is-not-empty) { $"(ansi dark_gray_bold) › (ansi reset)($PROMPT_ACCENT_ITALIC)($subpath)" }
    $"($PROMPT_ACCENT_BOLD)($jj_workspace_root | path basename)($subpath)(ansi reset)"
  } else {
    let pwd = if (pwd | str starts-with $env.HOME) {
      "~" | path join (pwd | path relative-to $env.HOME)
    } else { pwd }
    $"($PROMPT_ACCENT_ITALIC)($pwd)(ansi reset)"
  }
  $"(ansi dark_gray_bold)($left_char)(ansi reset) ($body)(char newline)"
}
$env.PROMPT_INDICATOR_VI_NORMAL = if $PROMPT_STYLE == "boxy" { $"(ansi dark_gray_bold)┗━ ($PROMPT_ACCENT)$(ansi reset) " } else { $"(ansi dark_gray_bold)╰─ ($PROMPT_ACCENT)$(ansi reset) " }
$env.PROMPT_INDICATOR_VI_INSERT = if $PROMPT_STYLE == "boxy" { $"(ansi dark_gray_bold)┗━ ($PROMPT_ACCENT)$(ansi reset) " } else { $"(ansi dark_gray_bold)╰─ ($PROMPT_ACCENT)$(ansi reset) " }
$env.PROMPT_MULTILINE_INDICATOR = ""
$env.PROMPT_COMMAND = { prompt-header --left-char (if $PROMPT_STYLE == "boxy" { "┏━" } else { "╭─" }) }
$env.PROMPT_COMMAND_RIGHT = {||
  if ((get-jj-workspace-root) | is-not-empty) {
    get-jj-right-prompt
  } else {
    get-git-prompt
  }
}
$env.TRANSIENT_PROMPT_INDICATOR = null
$env.TRANSIENT_PROMPT_INDICATOR_VI_INSERT = null
$env.TRANSIENT_PROMPT_INDICATOR_VI_NORMAL = null
$env.TRANSIENT_PROMPT_MULTILINE_INDICATOR = null
$env.TRANSIENT_PROMPT_COMMAND = null
$env.TRANSIENT_PROMPT_COMMAND_RIGHT = null
