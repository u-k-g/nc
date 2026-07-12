{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.lists) optionals;
  inherit (lib.meta) getExe;
  inherit (lib.strings) optionalString;
  user = config.nc.user;
  theme = config.nc.theme;
  home = user.homeDirectory;
  dotfiles = ../../dotfiles;
  hex = color: "#${color}";

  sessionVariables = {
    BAT_PAGING = "never";
    BAT_STYLE = "plain";
    CARAPACE_BRIDGES = "inshellisense,carapace,zsh,fish,bash";
    CARGO_HTTP_CAINFO = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    CARGO_NET_GIT_FETCH_WITH_CLI = "true";
    CURL_CA_BUNDLE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    DENO_CONFIG = "${home}/.config/deno/config.json";
    DETSYS_IDS_TELEMETRY = "disabled";
    EDITOR = "hx";
    FZF_DEFAULT_OPTS = lib.concatStringsSep " " [
      "--color=bg:#1d2021,bg+:#3c3836,fg:#ebdbb2,fg+:#fbf1c7"
      "--color=hl:#fabd2f,hl+:#fabd2f,pointer:#fe8019,prompt:#b8bb26"
      "--color=info:#83a598,border:#665c54,marker:#d3869b,spinner:#8ec07c"
      "--color=header:#928374,label:#fbf1c7,query:#fbf1c7"
    ];
    GIT_SSL_CAINFO = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    HOMEBREW_CELLAR = "/opt/homebrew/Cellar";
    HOMEBREW_PREFIX = "/opt/homebrew";
    HOMEBREW_REPOSITORY = "/opt/homebrew";
    NIX_LINK = "${home}/.local/state/nix/profile";
    NIX_PROFILES = "/nix/var/nix/profiles/default /run/current-system/sw /etc/profiles/per-user/${user.name}";
    NIX_SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    NODE_EXTRA_CA_CERTS = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    XDG_CACHE_HOME = "${home}/.cache";
    XDG_CONFIG_HOME = "${home}/.config";
    XDG_DATA_HOME = "${home}/.local/share";
    XDG_STATE_HOME = "${home}/.local/state";
    ZDOTDIR = "${home}/.config/zsh";
  };

  sessionPath = [
    "${home}/.bun/bin"
    "${home}/.deno/bin"
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

  lsColors = pkgs.runCommand "ls-colors" { } ''
    mkdir -p $out/share
    ${getExe pkgs.vivid} generate gruvbox-dark-hard > $out/share/LS_COLORS
  '';

  shadowPath = "${home}/.local/share/shadow";

  shadowXcode = pkgs.writeScript "shadow-xcode.nu" ''
    #!${getExe pkgs.nushell}
    use std null_device

    let shadow_path = ${builtins.toJSON shadowPath}
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
    builtins.replaceStrings [ "@tic@" ] [ (lib.getExe' pkgs.ncurses "tic") ] (
      builtins.readFile ./terminfo-autogen.nu
    )
  );

  nuVariables =
    sessionVariables
    |> lib.mapAttrsToList (
      name: value: ''
        $env.${name} = ${builtins.toJSON value}
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
    $env.PATH = (${builtins.toJSON sessionPath} | append $inherited_path | uniq)
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
        $env.PATH = ($env.PATH | insert $usr_bin_index ${builtins.toJSON shadowPath})
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

      let skill = open --raw ${builtins.toJSON "${home}/.agents/skills/wrtcmtmsg/SKILL.md"}
      let prompt = $skill + "\n\n" + $diff.stdout
      ^${getExe pkgs.opencode} run --model opencode-go/minimax-m3 -- $prompt
    }
  '';

  nuConfig = lib.concatStringsSep "\n" [
    nuVariables
    nuPath
    shadowXcodePath
    (builtins.readFile ./nushell.config.nu)
    "use ${terminfoAutogen}/terminfo-autogen.nu"
    (builtins.readFile (dotfiles + /config/nushell/misc.nu))
    (optionalString pkgs.stdenv.hostPlatform.isDarwin (
      builtins.readFile (dotfiles + /config/nushell/misc-darwin.nu)
    ))
    (builtins.readFile (dotfiles + /config/nushell/prompts.nu))
    "source ${carapaceConfig}"
    "source ${justCompletions}"
    wrtcmtmsgConfig
  ];
in
{
  environment.variables = sessionVariables;

  environment.shells = [
    pkgs.nushell
    pkgs.zsh
  ];

  home-manager.users.${user.name} =
    { lib, ... }:
    {
      programs.atuin = {
        enable = true;
        enableBashIntegration = false;
        enableFishIntegration = false;
        enableNushellIntegration = true;
        enableZshIntegration = false;

        settings = {
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

        themes.nc = {
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

      programs.zoxide = {
        enable = true;
        options = [
          "--cmd"
          "cd"
        ];
        enableBashIntegration = false;
        enableFishIntegration = false;
        enableNushellIntegration = true;
        enableZshIntegration = false;
      };

      programs.carapace = {
        enable = true;
        enableBashIntegration = false;
        enableFishIntegration = false;
        enableNushellIntegration = false;
        enableZshIntegration = false;
      };

      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;
        enableNushellIntegration = true;
      };

      programs.nushell = {
        enable = true;
        extraConfig = nuConfig;
      };

      home.sessionVariables = sessionVariables;
      home.sessionPath = sessionPath;
      home.packages =
        optionals pkgs.stdenv.isLinux [
          pkgs.skim
        ]
        ++ [
          pkgs.vivid
          lsColors
        ];

      home.activation.shadow-xcode = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          ${getExe pkgs.nushell} ${shadowXcode}
        ''
      );

      xdg.configFile = {
        "zsh/.zshrc".text = ''
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
        "nushell/fcdiff.nu" = {
          source = dotfiles + /config/nushell/fcdiff.nu;
          executable = true;
        };
      };

      home.file.".zshrc".text = ''
        export XDG_CONFIG_HOME="''${XDG_CONFIG_HOME:-${home}/.config}"
        export ZDOTDIR="''${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}"
        [ -f "$ZDOTDIR/.zshrc" ] && source "$ZDOTDIR/.zshrc"
      '';
    };
}
