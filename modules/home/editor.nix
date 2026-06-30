{
  config,
  lib,
  pkgs,
  ...
}:

let
  user = config.nc.user;
  dotfiles = ../../dotfiles;
  clipboardProvider = if pkgs.stdenv.isLinux then "wayland" else "pasteboard";
  zedKeymapSource = dotfiles + /config/zed/keymap.json;
  zedKeymapTarget = "${config.home-manager.users.${user.name}.xdg.configHome}/zed/keymap.json";
  zedSettingsSource = dotfiles + /config/zed/settings.json;
  zedSettingsTarget = "${config.home-manager.users.${user.name}.xdg.configHome}/zed/settings.json";
in
{
  home-manager.users.${user.name} = {
    home.packages = lib.optionals pkgs.stdenv.isLinux [ pkgs.wl-clipboard ];

    programs.helix = {
      enable = true;
      defaultEditor = true;

      settings = {
        theme = "gruvbox_dark_hard";

        editor = {
          auto-completion = false;
          bufferline = "multiple";
          color-modes = true;
          cursorline = true;
          idle-timeout = 1;
          shell = [
            "nu"
            "--commands"
          ];
          text-width = 100;
          clipboard-provider = clipboardProvider;

          file-picker.hidden = false;

          cursor-shape = {
            insert = "bar";
            normal = "block";
            select = "underline";
          };

          statusline.mode = {
            insert = "INSERT";
            normal = "NORMAL";
            select = "SELECT";
          };

          indent-guides = {
            character = "▏";
            render = true;
          };

          whitespace = {
            characters.tab = "→";
            render.tab = "all";
          };

          soft-wrap.enable = true;
        };

        keys.normal.b = ":echo %sh{git blame --date=short -L %{cursor_line},+1 %{buffer_name}}";
      };
    };

    xdg.configFile = {
      "helix/languages.toml".source = dotfiles + /config/helix/languages.toml;
      "helix/themes".source = dotfiles + /config/helix/themes;
    };

    home.activation.zed-keymap =
      config.home-manager.users.${user.name}.lib.dag.entryAfter [ "writeBoundary" ]
        ''
          target=${lib.escapeShellArg zedKeymapTarget}
          ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$target")"
          ${pkgs.coreutils}/bin/rm -f "$target"
          ${pkgs.coreutils}/bin/install -m 0666 ${zedKeymapSource} "$target"
        '';

    home.activation.zed-settings =
      config.home-manager.users.${user.name}.lib.dag.entryAfter [ "writeBoundary" ]
        ''
          target=${lib.escapeShellArg zedSettingsTarget}
          ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$target")"
          ${pkgs.coreutils}/bin/rm -f "$target"
          ${pkgs.coreutils}/bin/install -m 0666 ${zedSettingsSource} "$target"
        '';
  };
}
