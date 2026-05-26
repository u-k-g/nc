{
  config,
  inputs,
  pkgs,
  ...
}:

let
  user = config.nc.user;
  dotfiles = ../../dotfiles;
  fastWorkspaceSwitch = pkgs.callPackage ../../packages/fast-workspace-switch { };
  paperwmSpoon = inputs.paperwm;
  hammerspoonConfig = pkgs.runCommand "hammerspoon-config" { } ''
    mkdir -p $out/Spoons
    ln -s ${dotfiles + /config/hammerspoon/init.lua} $out/init.lua
    ln -s ${paperwmSpoon} $out/Spoons/PaperWM.spoon
  '';
  paperwmConfig = pkgs.runCommand "paperwm-config" { } ''
    mkdir -p $out
    ln -s ${fastWorkspaceSwitch}/bin/fast-workspace-switch $out/fast-workspace-switch
  '';
in
{
  system.defaults.CustomSystemPreferences."org.hammerspoon.Hammerspoon".MJConfigFile = "~/.config/hammerspoon/init.lua";

  home-manager.users.${user.name} = {
    home.file.".hammerspoon/init.lua".text = ''
      dofile(os.getenv("HOME") .. "/.config/hammerspoon/init.lua")
    '';

    home.file.".hammerspoon/Spoons/PaperWM.spoon" = {
      recursive = true;
      source = paperwmSpoon;
    };

    xdg.configFile."hammerspoon".source = hammerspoonConfig;
    xdg.configFile."paperwm".source = paperwmConfig;
  };
}
