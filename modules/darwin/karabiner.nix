{
  config,
  lib,
  pkgs,
  ...
}:

let
  user = config.nc.user;
  dotfiles = ../../dotfiles;
  fastWorkspaceSwitch = pkgs.callPackage ../../packages/fast-workspace-switch { };
in
{
  system.activationScripts.preActivation.text = ''
    launchctl bootout system/org.nixos.karabiner.Core-Service 2>/dev/null || true
    launchctl bootout system/org.nixos.karabiner.VirtualHIDDevice-Daemon 2>/dev/null || true
    rm -f /Library/LaunchDaemons/org.nixos.karabiner.Core-Service.plist
    rm -f /Library/LaunchDaemons/org.nixos.karabiner.VirtualHIDDevice-Daemon.plist
    rm -rf /Applications/.Nix-Karabiner
  '';

  home-manager.users.${user.name} = {
    home.packages = lib.lists.singleton fastWorkspaceSwitch;

    xdg.configFile."karabiner/karabiner.json".source = dotfiles + /config/karabiner/karabiner.json;
  };
}
