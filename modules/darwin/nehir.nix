{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;

  user = config.nc.user;
  theme = config.nc.theme;
in
{
  options.nc.darwin.nehir.enable = mkEnableOption "Nehir window manager";

  config = mkIf config.nc.darwin.nehir.enable {
    homebrew.casks = singleton "guria/tap/nehir";

    launchd.user.agents.nehir.serviceConfig = {
      ProgramArguments = singleton "/Applications/Nehir.app/Contents/MacOS/Nehir";
      KeepAlive = {
        Crashed = true;
        SuccessfulExit = false;
      };
      ProcessType = "Interactive";
      RunAtLoad = true;
    };

    home.users.${user.name}.xdg.config.files = {
      "nehir/settings.toml" = {
        type = "copy";
        source = pkgs.replaceVars ../../dotfiles/config/nehir/settings.toml {
          appearanceMode = if theme.isDark then "dark" else "light";
        };
      };

      "nehir/hotkeys.toml" = {
        type = "copy";
        source = ../../dotfiles/config/nehir/hotkeys.toml;
      };

      "nehir/workspaces.toml" = {
        type = "copy";
        source = ../../dotfiles/config/nehir/workspaces.toml;
      };

      "nehir/apprules.d/com-chabomakers-Antinote.toml" = {
        type = "copy";
        source = ../../dotfiles/config/nehir/apprules.d/com-chabomakers-Antinote.toml;
      };
    };
  };
}
