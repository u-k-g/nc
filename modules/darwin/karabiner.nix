{ config, pkgs, ... }:

let
  user = config.nc.user;
  dotfiles = ../../dotfiles;
  fastWorkspaceSwitch = pkgs.callPackage ../../packages/fast-workspace-switch { };
  gotoWorkspace = pkgs.writeShellApplication {
    name = "goto-workspace";
    runtimeInputs = [ fastWorkspaceSwitch ];
    text = ''
      target="''${1:-}"

      case "$target" in
        1|2|3|4|5|6|7|8|9) ;;
        *)
          printf 'Usage: goto-workspace <1-9>\n' >&2
          exit 1
          ;;
      esac

      fast-workspace-switch goto "$target"
    '';
  };
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
    home.packages = [ gotoWorkspace ];

    xdg.configFile."karabiner/karabiner.json".source = dotfiles + /config/karabiner/karabiner.json;
  };
}
