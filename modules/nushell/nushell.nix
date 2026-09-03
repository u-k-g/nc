{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.generators) toJSON;
  inherit (lib.meta) getExe;
  inherit (lib.strings)
    concatMapStringsSep
    fileContents
    makeLibraryPath
    optionalString
    replaceStrings
    substring
    ;
  inherit (inputs.themes.lib.strings) fromHexString;
  user = config.nc.user;
  theme = config.nc.theme;
  home = user.homeDirectory;
  dotfiles = ../../dotfiles;
  hex = color: "#${color}";
  rgb =
    color:
    concatMapStringsSep ";" (offset: toString <| fromHexString <| substring offset 2 color) [
      0
      2
      4
    ];

  sessionVariables = {
    CARAPACE_BRIDGES = "inshellisense,carapace,zsh,fish,bash";
    CARGO_HTTP_CAINFO = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    CARGO_NET_GIT_FETCH_WITH_CLI = "true";
    CURL_CA_BUNDLE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    DENO_CONFIG = "${home}/.config/deno/config.json";
    DETSYS_IDS_TELEMETRY = "disabled";
    EDITOR = "hx";
    FZF_DEFAULT_OPTS = lib.concatStringsSep " " [
      "--color=bg:${hex theme.base00},bg+:${hex theme.base02},fg:${hex theme.base05},fg+:${hex theme.base06}"
      "--color=hl:${hex theme.base0A},hl+:${hex theme.base0A},pointer:${hex theme.base09},prompt:${hex theme.base0B}"
      "--color=info:${hex theme.base0D},border:${hex theme.base03},marker:${hex theme.base0E},spinner:${hex theme.base0C}"
      "--color=header:${hex theme.base04},label:${hex theme.base06},query:${hex theme.base06}"
    ];
    GIT_SSL_CAINFO = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    HOMEBREW_CELLAR = "/opt/homebrew/Cellar";
    HOMEBREW_PREFIX = "/opt/homebrew";
    HOMEBREW_REPOSITORY = "/opt/homebrew";
    NIX_LINK = "${home}/.local/state/nix/profile";
    NIX_PROFILES = "/nix/var/nix/profiles/default /run/current-system/sw /etc/profiles/per-user/${user.name}";
    NIX_SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    NODE_EXTRA_CA_CERTS = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    PNPM_HOME = "${home}/.local/share/pnpm";
    SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    XDG_CACHE_HOME = "${home}/.cache";
    XDG_CONFIG_HOME = "${home}/.config";
    XDG_DATA_HOME = "${home}/.local/share";
    XDG_STATE_HOME = "${home}/.local/state";
    ZDOTDIR = "${home}/.config/zsh";
  }
  // optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
    LIBRARY_PATH = makeLibraryPath [ pkgs.libiconv ];
  };

  sessionPath = [
    "${home}/.bun/bin"
    "${home}/.deno/bin"
    "${home}/.local/share/pnpm"
    "${home}/.platformio/penv/bin"
    "${home}/.platformio/packages/toolchain-gccarmnoneeabi-teensy/bin"
    "/etc/profiles/per-user/${user.name}/bin"
    "/run/wrappers/bin"
    "/run/current-system/sw/bin"
    "/nix/var/nix/profiles/default/bin"
    "/opt/homebrew/sbin"
    "/opt/homebrew/bin"
    "/opt/homebrew/opt/llvm/bin"
    "${home}/.config/bin"
    "${home}/.cargo/bin"
    "${home}/.local/bin"
    "${home}/.opencode/bin"
    "${home}/.lmstudio/bin"
  ];

  lsColors =
    pkgs.writeTextDir "share/LS_COLORS"
    <| lib.concatStringsSep ":" [
      "di=1;38;2;${rgb theme.base0D}"
      "ln=38;2;${rgb theme.base0C}"
      "so=38;2;${rgb theme.base0E}"
      "pi=38;2;${rgb theme.base09}"
      "ex=1;38;2;${rgb theme.base0B}"
      "bd=38;2;${rgb theme.base08}"
      "cd=38;2;${rgb theme.base08}"
      "*.tar=38;2;${rgb theme.base08}"
      "*.gz=38;2;${rgb theme.base08}"
      "*.zip=38;2;${rgb theme.base08}"
      "*.7z=38;2;${rgb theme.base08}"
      "*.jpg=38;2;${rgb theme.base09}"
      "*.jpeg=38;2;${rgb theme.base09}"
      "*.png=38;2;${rgb theme.base09}"
      "*.gif=38;2;${rgb theme.base09}"
      "*.mp3=38;2;${rgb theme.base0E}"
      "*.flac=38;2;${rgb theme.base0E}"
      "*.mp4=38;2;${rgb theme.base0E}"
      "*.mkv=38;2;${rgb theme.base0E}"
      "*.md=38;2;${rgb theme.base0A}"
      "*.pdf=38;2;${rgb theme.base0A}"
    ];

  shadowPath = "${home}/.local/share/shadow";

  shadowXcode = pkgs.writeScript "shadow-xcode.nu" ''
    #!${getExe pkgs.nushell}
    use std null_device

    let shadow_path = ${toJSON { } shadowPath}
    let original_size = ls /usr/bin/SplitForks | get 0.size

    let shadoweds = ls /usr/bin
    | flatten
    | where {
      $in.size == $original_size and (try {
        open $null_device | ^$in.name out+err>| str contains "xcode-select: note: No developer tools were found, requesting install."
      } catch {
        false
      })
    }
    | get name
    | each { path basename }

    rm -rf $shadow_path
    mkdir $shadow_path

    for shadowed in $shadoweds {
      ln --symbolic /usr/bin/false ($shadow_path | path join $shadowed)
    }
  '';

  terminfoAutogen = pkgs.writeTextDir "terminfo-autogen.nu" (
    replaceStrings [ "@tic@" ] [ (lib.getExe' pkgs.ncurses "tic") ] (fileContents ./terminfo-autogen.nu)
  );

  nuVariables =
    sessionVariables
    |> lib.mapAttrsToList (
      name: value: ''
        $env.${name} = ${toJSON { } value}
      ''
    )
    |> lib.concatStrings;

  nuPath = ''
    let inherited_path = ($env.PATH? | default [])
    let inherited_path = if (($inherited_path | describe) == "string") {
      $inherited_path | split row (char esep)
    } else {
      $inherited_path
    }
    $env.PATH = (${toJSON { } sessionPath} | append $inherited_path | uniq)
    $env.MANPATH = ($env.MANPATH? | default "" | split row (char esep) | prepend "/opt/homebrew/share/man" | uniq | str join (char esep))
    $env.INFOPATH = ($env.INFOPATH? | default "" | split row (char esep) | prepend "/opt/homebrew/share/info" | uniq | str join (char esep))
    $env.XDG_DATA_DIRS = ([
      "/nix/var/nix/profiles/default/share"
      "/run/current-system/sw/share"
      "/etc/profiles/per-user/${user.name}/share"
    ] | append ($env.XDG_DATA_DIRS? | default "" | split row (char esep)) | uniq | str join (char esep))
  '';

  shadowXcodePath = optionalString pkgs.stdenv.hostPlatform.isDarwin ''
    do --env {
      let usr_bin_index = ($env.PATH | enumerate | where item == /usr/bin | get --optional 0.index)
      if $usr_bin_index != null {
        $env.PATH = ($env.PATH | insert $usr_bin_index ${toJSON { } shadowPath})
      }
    }
  '';

  carapaceConfig = pkgs.runCommand "carapace.nu" { } ''
    export HOME="$TMPDIR/home"
    export XDG_CONFIG_HOME="$TMPDIR/config"
    mkdir -p "$HOME" "$XDG_CONFIG_HOME"
    ${getExe pkgs.carapace} _carapace nushell > $out
    substituteInPlace $out --replace-quiet '^carapace' '^${getExe pkgs.carapace}'
  '';

  justCompletions = pkgs.runCommand "just-completions.nu" { } ''
    ${getExe pkgs.just} --completions nushell > $out
    substituteInPlace $out --replace-quiet '(^just ' '(^${getExe pkgs.just} '
  '';

  atuinInit = pkgs.runCommand "atuin.nu" { } ''
    export HOME="$TMPDIR/home"
    export XDG_CONFIG_HOME="$TMPDIR/config"
    mkdir -p "$HOME" "$XDG_CONFIG_HOME"
    ${getExe pkgs.atuin} init nu --disable-up-arrow > $out
  '';

  zoxideInit = pkgs.runCommand "zoxide.nu" { } ''
    ${getExe pkgs.zoxide} init nushell --cmd cd > $out
  '';

  direnvHook = pkgs.writeText "direnv-hook.nu" ''
    $env.config.hooks.env_change.PWD = [
      { ||
        ^${getExe pkgs.direnv} export json | from json | default {} | load-env
      }
    ]
  '';

  clipboardCopy =
    if pkgs.stdenv.hostPlatform.isDarwin then
      "/usr/bin/pbcopy"
    else
      lib.getExe' pkgs.wl-clipboard "wl-copy";

  wrtcmtmsgConfig = ''
    def wrtcmtmsg [] {
      let diff = (^${getExe pkgs.jujutsu} diff --git --no-pager | complete)

      if $diff.exit_code != 0 {
        error make {
          msg: ($diff.stderr | str trim)
          label: {
            text: "jj diff failed"
            span: (metadata $diff.stderr).span
          }
        }
      }

      let skill = open --raw ${toJSON { } "${home}/.agents/skills/wrtcmtmsg/SKILL.md"}
      let prompt = $skill + "\n\n" + $diff.stdout
      let run = (^${getExe pkgs.opencode} run --model opencode-go/glm-5.3-flash --variant low -- $prompt | complete)

      if $run.exit_code != 0 {
        error make {
          msg: "opencode run failed"
          label: {
            text: ($run.stderr | str trim)
            span: (metadata $run.stderr).span
          }
        }
      }

      let commit_message = (
        $run.stdout
        | ansi strip
        | lines
        | each { str trim }
        | where { not ($in | is-empty) }
        | last
      )

      if $commit_message != null {
        let describe = (^${getExe pkgs.jujutsu} describe -m $commit_message | complete)

        if $describe.exit_code != 0 {
          error make {
            msg: "jj describe failed"
            label: {
              text: ($describe.stderr | str trim)
              span: (metadata $describe.stderr).span
            }
          }
        }

        print $commit_message
      }
    }
  '';

  promptConfig =
    replaceStrings
      [
        "@localPromptAccent@"
        "@remotePromptAccent@"
      ]
      [
        "${hex theme.base0D}"
        "${hex theme.base0E}"
      ]
    <| fileContents (dotfiles + /config/nushell/prompts.nu);

  nuConfig = lib.concatStringsSep "\n" [
    nuVariables
    nuPath
    shadowXcodePath
    (fileContents ./nushell.config.nu)
    "use ${terminfoAutogen}/terminfo-autogen.nu"
    (fileContents (dotfiles + /config/nushell/misc.nu))
    (optionalString pkgs.stdenv.hostPlatform.isDarwin (
      fileContents (dotfiles + /config/nushell/misc-darwin.nu)
    ))
    promptConfig
    "source ${carapaceConfig}"
    "source ${justCompletions}"
    "source ${direnvHook}"
    "source ${atuinInit}"
    "source ${zoxideInit}"
    wrtcmtmsgConfig
  ];
in
{
  environment.variables = sessionVariables;

  environment.shells = [
    pkgs.nushell
    pkgs.zsh
  ];

  home.users.${user.name} =
    { lib, ... }:
    {
      xdg.config.files."atuin/config.toml" = {
        generator = (pkgs.formats.toml { }).generate "atuin-config.toml";
        value = {
          auto_sync = false;
          update_check = false;

          search_mode = "fuzzy";
          filter_mode = "global";
          filter_mode_shell_up_key_binding = "directory";
          search_mode_shell_up_key_binding = "fuzzy";
          style = "compact";
          show_preview = false;
          show_tabs = false;
          ctrl_n_shortcuts = true;
          enter_accept = false;
          keymap_mode = "vim-normal";
          keymap_cursor = {
            vim_insert = "blink-bar";
            vim_normal = "steady-block";
          };

          history_filter = [
            "^clear$"
            "^clear ; tmux clear-history"
            "^clear; tmux clear-history"
          ];

          theme.name = "nc";
          search.filters = [
            "global"
            "directory"
          ];
          keymap = {
            emacs."ctrl-r" = "cycle-filter-mode";
            "vim-insert"."ctrl-r" = "cycle-filter-mode";
            "vim-normal"."ctrl-r" = "cycle-filter-mode";
          };
        };

      };

      xdg.config.files."atuin/themes/nc.toml" = {
        generator = (pkgs.formats.toml { }).generate "atuin-theme-nc.toml";
        value = {
          theme.name = theme.name;
          colors = {
            Base = hex theme.base05;
            Title = hex theme.base0A;
            Important = hex theme.base0D;
            Guidance = hex theme.base0C;
            AlertInfo = hex theme.base0B;
            AlertWarn = hex theme.base09;
            AlertError = hex theme.base08;
            Annotation = hex theme.base04;
            Muted = hex theme.base03;
          };
        };
      };

      environment.sessionVariables = sessionVariables;
      packages = [
        pkgs.atuin
        pkgs.carapace
        pkgs.direnv
        pkgs.fzf
        pkgs.nix-direnv
        pkgs.nushell
        pkgs.vivid
        pkgs.zoxide
        lsColors
      ];

      activationScripts.shadow-xcode = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin ''
        ${getExe pkgs.nushell} ${shadowXcode}
      '';

      xdg.config.files = {
        "zsh/.zshrc" = {
          type = "copy";
          text = ''
            export HOME='${home}'
            export USER='${user.name}'
            export PATH='${lib.concatStringsSep ":" sessionPath}':"$PATH"
            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (name: value: "export ${name}='${value}'") sessionVariables
            )}

            if [ -z "$INTELLIJ_ENVIRONMENT_READER" ]; then
              export SHELL='${getExe pkgs.nushell}'
              exec '${getExe pkgs.nushell}' --login --config '${home}/.config/nushell/config.nu'
            fi
          '';
        };
        "nushell/fcdiff.nu" = {
          source = dotfiles + /config/nushell/fcdiff.nu;
          executable = true;
        };
        "nushell/config.nu" = {
          type = "copy";
          text = nuConfig;
        };
        "direnv/lib/nix-direnv.sh".source = "${pkgs.nix-direnv}/share/nix-direnv/direnvrc";
      };

      files = {
        ".zshrc" = {
          type = "copy";
          text = ''
            export XDG_CONFIG_HOME="''${XDG_CONFIG_HOME:-${home}/.config}"
            export ZDOTDIR="''${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}"
            [ -f "$ZDOTDIR/.zshrc" ] && source "$ZDOTDIR/.zshrc"
          '';
        };
      };
    };
}
