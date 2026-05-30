{ config, ... }:

let
  user = config.nc.user;
  dotfiles = ../../dotfiles;
in
{
  system.defaults.CustomSystemPreferences."com.apple.spaces".spans-displays = false;

  home-manager.users.${user.name} = {
    xdg.configFile."omniwm/settings.toml".source = dotfiles + /config/omniwm/settings.toml;

    launchd.agents.omniwm = {
      enable = false;
      config = {
        Label = "com.barut.OmniWM";
        ProgramArguments = [
          "/usr/bin/open"
          "-a"
          "OmniWM"
        ];
        RunAtLoad = true;
        ProcessType = "Interactive";
        StandardOutPath = "/tmp/omniwm.log";
        StandardErrorPath = "/tmp/omniwm.err.log";
      };
    };
  };
}
