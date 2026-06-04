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

        keys.normal.b = '':echo %sh{git blame --date=short -L %{cursor_line},+1 %{buffer_name}}'';
      };
    };

    xdg.configFile = {
      "helix/languages.toml".source = dotfiles + /config/helix/languages.toml;
      "helix/themes".source = dotfiles + /config/helix/themes;
      "zed/settings.json".source = dotfiles + /config/zed/settings.json;
      "zed/keymap.json".source = dotfiles + /config/zed/keymap.json;
    };
  };
}
