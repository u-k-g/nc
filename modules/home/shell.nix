{ config, lib, pkgs, ... }:

let
  inherit (lib) getExe;
  user = config.nc.user;
  theme = config.nc.theme;
  dotfiles = ../../dotfiles;
  nushellHelperDir = "${user.homeDirectory}/.config/nushell";
  hex = color: "#${color}";
  nushellConfig = builtins.replaceStrings
    [
      "@nushellHelperDir@"
      "@nushellDarwinConfig@"
    ]
    [
      nushellHelperDir
      (if pkgs.stdenv.hostPlatform.isDarwin then ''source "${nushellHelperDir}/misc-darwin.nu"'' else "")
    ]
    (builtins.readFile (dotfiles + /config/nushell/config.nu));
  nushellIntegrations = pkgs.runCommand "nushell-integrations.nu" { } ''
    export HOME="$TMPDIR/home"
    export XDG_CONFIG_HOME="$TMPDIR/config"
    mkdir -p "$HOME" "$XDG_CONFIG_HOME"

    {
      ${pkgs.zoxide}/bin/zoxide init nushell --cmd cd
      ${pkgs.carapace}/bin/carapace _carapace nushell
    } > $out

    substituteInPlace $out \
      --replace-quiet '^zoxide' '^${pkgs.zoxide}/bin/zoxide' \
      --replace-quiet '^carapace' '^${pkgs.carapace}/bin/carapace'
  '';
in
{
  home-manager.users.${user.name} = {
    programs.atuin = {
      enable = true;
      enableBashIntegration = false;
      enableFishIntegration = false;
      enableNushellIntegration = true;
      enableZshIntegration = false;
      forceOverwriteSettings = true;

      settings = {
        auto_sync = true;
        update_check = false;
        sync_address = "https://api.atuin.sh";

        search_mode = "fuzzy";
        filter_mode = "global";
        filter_mode_shell_up_key_binding = "global";
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

        stats.common_subcommands = [
          "brew"
          "bun"
          "git"
        ];

        sync.records = true;
        dotfiles.enabled = true;
        theme.name = "nc";
        search.filters = [
          "global"
          "directory"
        ];
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
      enableBashIntegration = false;
      enableFishIntegration = false;
      enableNushellIntegration = false;
      enableZshIntegration = false;
    };

    programs.carapace = {
      enable = true;
      enableBashIntegration = false;
      enableFishIntegration = false;
      enableNushellIntegration = false;
      enableZshIntegration = false;
    };

    programs.nushell = {
      enable = true;
      configFile.text = nushellConfig;
      envFile.source = dotfiles + /config/nushell/env.nu;
    };

    programs.zsh = {
      enable = true;
      dotDir = user.homeDirectory;
      initContent = ''
        if [ -z "$INTELLIJ_ENVIRONMENT_READER" ]; then
          SHELL='${getExe pkgs.nushell}' exec "$SHELL"
        fi
      '';
    };

    xdg.configFile = {
      "nushell/integrations.nu".source = nushellIntegrations;
      "nushell/misc.nu".source = dotfiles + /config/nushell/misc.nu;
      "nushell/misc-darwin.nu".source = dotfiles + /config/nushell/misc-darwin.nu;
      "nushell/prompts.nu".source = dotfiles + /config/nushell/prompts.nu;
      "nushell/fcdiff.nu" = {
        source = dotfiles + /config/nushell/fcdiff.nu;
        executable = true;
      };
    };

    home.sessionVariables = {
      DENO_CONFIG = "${user.homeDirectory}/.config/deno/config.json";
    };
  };
}
