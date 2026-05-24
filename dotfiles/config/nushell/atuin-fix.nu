# Work around Atuin's multiline `executehostcommand` bindings, which
# recent Ghostty/Nushell combinations no longer execute reliably.

def atuin-search-ctrl-r [] {
  with-env {ATUIN_LOG: error ATUIN_QUERY: (commandline) ATUIN_SHELL: nu} {
    let output = (run-external atuin search "--interactive" e>| str trim)
    if ($output | str starts-with "__atuin_accept__:") {
      commandline edit --accept ($output | str replace "__atuin_accept__:" "")
    } else {
      commandline edit $output
    }
  }
}

def atuin-search-up [] {
  with-env {ATUIN_LOG: error ATUIN_QUERY: (commandline) ATUIN_SHELL: nu} {
    let output = (run-external atuin search "--shell-up-key-binding" "--interactive" e>| str trim)
    if ($output | str starts-with "__atuin_accept__:") {
      commandline edit --accept ($output | str replace "__atuin_accept__:" "")
    } else {
      commandline edit $output
    }
  }
}

let existing_keybindings = ($env.config.keybindings? | default [])
let filtered_keybindings = (
  $existing_keybindings | where {|kb|
    let name = ($kb.name? | default "")
    let modifier = ($kb.modifier? | default "")
    let keycode = ($kb.keycode? | default "")

    not (
      ($name == "atuin") and (
        (($modifier == "control") and ($keycode == "char_r")) or
        (($modifier == "none") and ($keycode == "up"))
      )
    )
  }
)

$env.config = (
  $env.config
  | upsert keybindings (
    $filtered_keybindings
    | append [
      {
        name: atuin_search_ctrl_r
        modifier: control
        keycode: char_r
        mode: [emacs vi_normal vi_insert]
        event: {
          send: executehostcommand
          cmd: "atuin-search-ctrl-r"
        }
      }
      {
        name: atuin_search_up
        modifier: none
        keycode: up
        mode: [emacs vi_normal vi_insert]
        event: {
          until: [
            {send: menuup}
            {
              send: executehostcommand
              cmd: "atuin-search-up"
            }
          ]
        }
      }
    ]
  )
)

let existing_hooks = ($env.config.hooks? | default {})
let existing_pre_execution = ($existing_hooks.pre_execution? | default [])
let patched_pre_execution = (
  $existing_pre_execution | each {|hook|
    let current_hook = $hook
    {||
      let cmd = (commandline | str trim)
      if ($cmd == "atuin-search-ctrl-r") or ($cmd == "atuin-search-up") {
        return
      }

      do $current_hook
    }
  }
)

$env.config = (
  $env.config
  | upsert hooks (
    $existing_hooks
    | upsert pre_execution $patched_pre_execution
  )
)
