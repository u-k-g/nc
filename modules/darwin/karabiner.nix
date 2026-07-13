{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.meta) getExe;
  user = config.nc.user;
  dotfiles = ../../dotfiles;
  fastWorkspaceSwitch = pkgs.callPackage ../../packages/fast-workspace-switch { };
  gotoWorkspace = pkgs.writers.writeNuBin "goto-workspace" ''
    def main [target?: string] {
      let workspace = (try { $target | into int } catch { 0 })
      if $workspace not-in 1..9 {
        print --stderr "Usage: goto-workspace <1-9>"
        exit 1
      }

      exec ${getExe fastWorkspaceSwitch} goto $workspace
    }
  '';
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
    home.packages = lib.lists.singleton gotoWorkspace;

    xdg.configFile."karabiner/karabiner.json".source = dotfiles + /config/karabiner/karabiner.json;
  };
}
