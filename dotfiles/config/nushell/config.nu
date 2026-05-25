$env.config.buffer_editor = "hx"
$env.config.show_banner = false
$env.config.recursion_limit = 100
$env.config.table.mode = "restructured"
$env.config.edit_mode = "vi"
$env.config.cursor_shape.vi_insert = "line"
$env.config.cursor_shape.vi_normal = "block"
$env.CARAPACE_BRIDGES = "inshellisense,carapace,zsh,fish,bash"
$env.config.completions.algorithm = "substring"
$env.config.completions.sort = "smart"
$env.config.completions.case_sensitive = false
$env.config.completions.quick = true
$env.config.completions.partial = true
$env.config.completions.use_ls_colors = true
$env.config.use_kitty_protocol = true
$env.config.shell_integration.osc2 = true
$env.config.shell_integration.osc7 = true
$env.config.shell_integration.osc8 = true
$env.config.shell_integration.osc9_9 = true
$env.config.shell_integration.osc133 = true
$env.config.shell_integration.osc633 = true
$env.config.shell_integration.reset_application_mode = true
$env.config.bracketed_paste = true
$env.config.use_ansi_coloring = "auto"
$env.config.error_style = "fancy"
$env.config.highlight_resolved_externals = true
$env.config.display_errors.exit_code = false
$env.config.display_errors.termination_signal = false
$env.config.footer_mode = 25
$env.config.table.index_mode = "always"
$env.config.table.show_empty = true
$env.config.table.padding.left = 1
$env.config.table.padding.right = 1
$env.config.table.trim.methodology = "wrapping"
$env.config.table.trim.wrapping_try_keep_words = true
$env.config.table.trim.truncating_suffix = "..."
$env.config.table.header_on_separator = true
$env.config.table.footer_inheritance = true
$env.config.render_right_prompt_on_last_line = false
$env.config.float_precision = 2
$env.config.ls.use_ls_colors = true
$env.PROMPT_MULTILINE_INDICATOR = ""
const helper_dir = "@nushellHelperDir@"

source ($helper_dir | path join "misc.nu")
@nushellDarwinConfig@
source ($helper_dir | path join "prompts.nu")
$env.HAS_DIRENV = (try { ((^which direnv | complete).exit_code == 0) } catch { false })
def --env load-direnv [] {
  if not ($env.HAS_DIRENV? | default false) {
    return
  }

  if not (".envrc" | path exists) {
    return
  }

  ^direnv reload | ignore
  let direnv_env = (^direnv export json | from json | default {})
  if ($direnv_env | is-empty) {
    return
  }

  load-env ($direnv_env | reject --optional PATH)

  if ($direnv_env | get --optional PATH | default "" | is-not-empty) {
    $env.PATH = ($direnv_env.PATH | split row (char esep))
  }
}
$env.config.menus = [
  {
    name: completion_menu
    only_buffer_difference: false
    marker: $env.PROMPT_INDICATOR_VI_INSERT
    type: {
      layout: ide
      min_completion_width: 0
      max_completion_width: 150
      max_completion_height: 25
      padding: 0
      border: false
      cursor_offset: 0
      description_mode: "prefer_right"
      min_description_width: 0
      max_description_width: 50
      max_description_height: 10
      description_offset: 1
      correct_cursor_pos: true
    }
    style: {
      text: white
      selected_text: white_reverse
      description_text: yellow
      match_text: {attr: u}
      selected_match_text: {attr: ur}
    }
  }
]
$env.config.hooks.pre_execution = [
  {||
    let cmd = (commandline | str trim)
    if ($cmd | is-not-empty) {
      $env.TERM_TITLE = $"(ansi title)($cmd) — nu"
    }
    if ($cmd == "git") or ($cmd | str starts-with "git ") {
      $env.GIT_PROMPT_PWD = ""
      $env.GIT_PROMPT_VALUE = ""
    }
    if ($cmd == "jj") or ($cmd | str starts-with "jj ") {
      $env.JJ_WORKSPACE_ROOT_PWD = ""
      $env.JJ_RIGHT_PROMPT_PWD = ""
      $env.JJ_RIGHT_PROMPT_VALUE = ""
    }
  }
]
$env.config.hooks.display_output = {||
  tee { table --expand | print } | try { (if $in != null { ($env.last = $in) }) }
}
$env.config.color_config.bool = "light_green_bold"
$env.config.color_config.false_bool = "light_red_bold"
$env.config.color_config.string = {|| (if $in =~ "^(#|0x)[a-fA-F0-9]+$" { ($in | str replace "0x" "#") } else { "white" }) }

if ($env.TMUX? | is-empty) { tmux new -A -s main }

source ($helper_dir | path join "integrations.nu")

$env.NODE_EXTRA_CA_CERTS = "/etc/ssl/cert.pem"


ulimit -n 4096
$env.DENO_CONFIG = ($nu.home-dir | path join ".config" "deno" "config.json")
$env.config.hooks.env_change.PWD = (
  $env.config.hooks.env_change.PWD?
  | default []
  | append {|| load-direnv }
)

load-direnv
