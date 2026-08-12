use std/clip
use std null_device

$env.config.buffer_editor = "hx"
$env.config.history.file_format = "sqlite"
$env.config.history.isolation = false
$env.config.history.max_size = 10_000_000
$env.config.history.sync_on_enter = true
$env.config.show_banner = false
$env.config.rm.always_trash = false
$env.config.recursion_limit = 100
$env.config.table.mode = "restructured"
$env.config.edit_mode = "vi"
$env.config.cursor_shape.emacs = "line"
$env.config.cursor_shape.vi_insert = "line"
$env.config.cursor_shape.vi_normal = "block"
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
$env.config.shell_integration.osc9_9 = false
$env.config.shell_integration.osc133 = true
$env.config.shell_integration.osc633 = true
$env.config.shell_integration.reset_application_mode = true
$env.config.bracketed_paste = true
$env.config.use_ansi_coloring = "auto"
$env.config.error_style = "fancy"
$env.config.highlight_resolved_externals = true
$env.config.display_errors.exit_code = false
$env.config.display_errors.termination_signal = true
$env.config.footer_mode = 25
$env.config.table.index_mode = "always"
$env.config.table.show_empty = true
$env.config.table.padding.left = 1
$env.config.table.padding.right = 1
$env.config.table.trim.methodology = "wrapping"
$env.config.table.trim.wrapping_try_keep_words = true
$env.config.table.trim.truncating_suffix = "..."
$env.config.table.header_on_separator = true
$env.config.table.abbreviated_row_count = null
$env.config.table.footer_inheritance = true
$env.config.table.missing_value_symbol = $"(ansi magenta_bold)nope(ansi reset)"
$env.config.datetime_format.table = null
$env.config.filesize.unit = "metric"
$env.config.filesize.show_unit = true
$env.config.filesize.precision = 1
$env.config.render_right_prompt_on_last_line = false
$env.config.float_precision = 2
$env.config.ls.use_ls_colors = true
$env.PROMPT_MULTILINE_INDICATOR = ""

$env.config.menus = [
  {
    name: completion_menu
    only_buffer_difference: false
    marker: $"(ansi dark_gray_bold)╰─ (ansi blue):(ansi reset) "
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
      match_text: { attr: u }
      selected_match_text: { attr: ur }
    }
  }
  {
    name: history_menu
    only_buffer_difference: true
    marker: $"(ansi {fg: $themenix_theme.base03 attr: b})╰─ (ansi {fg: $themenix_theme.base0A attr: b}):(ansi reset) "
    type: {
      layout: list
      page_size: 10
    }
    style: {
      text: $themenix_theme.base05
      selected_text: {
        fg: $themenix_theme.base00
        bg: $themenix_theme.base0A
        attr: b
      }
      description_text: $themenix_theme.base04
      match_text: {
        fg: $themenix_theme.base0B
        attr: u
      }
      selected_match_text: {
        fg: $themenix_theme.base00
        bg: $themenix_theme.base0A
        attr: bu
      }
    }
  }
]

$env.config.keybindings ++= [
  {
    name: cdi
    modifier: alt
    keycode: char_c
    mode: [emacs vi_insert vi_normal]
    event: {
      send: executehostcommand
      cmd: "cdi"
    }
  }
]

$env.config.hooks.pre_execution = ($env.config.hooks.pre_execution? | default [] | append [
  {||
    let cmd = (commandline | str trim)
    if ($cmd | is-not-empty) {
      print $"(ansi title)($cmd) -- nu(char bel)"
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
])

$env.config.hooks.display_output = {||
  tee { table --expand | print } | try { if $in != null { $env.last = $in } }
}

$env.config.color_config.bool = {||
  if $in { "light_green_bold" } else { "light_red_bold" }
}
$env.config.color_config.string = {||
  if $in =~ "^(#|0x)[a-fA-F0-9]+$" {
    $in | str replace "0x" "#"
  } else {
    "white"
  }
}

ulimit -n 4096
