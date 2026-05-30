{ config, pkgs, ... }:

let
  user = config.nc.user;
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

      # Reset to the first space, then move right to the requested index.
      fast-workspace-switch left 9

      if [ "$target" -gt 1 ]; then
        fast-workspace-switch right "$((target - 1))"
      fi
    '';
  };
  skhdrc = pkgs.writeText "skhdrc" ''
    # App launchers formerly handled by Hammerspoon.
    alt - w : open -a "Helium"
    alt - o : open -a "Obsidian"
    alt - g : open -a "Ghostty"
    alt - y : open -a "Finder"
    alt - c : open -a "FreeCAD"
    alt - r : open -a "Codex"
    alt - z : open -a "Zed"
    alt - t : open -a "T3 Code (Nightly)"

    # Absolute space switching via fast-workspace-switch.
    alt - 1 : ${gotoWorkspace}/bin/goto-workspace 1
    alt - 2 : ${gotoWorkspace}/bin/goto-workspace 2
    alt - 3 : ${gotoWorkspace}/bin/goto-workspace 3
    alt - 4 : ${gotoWorkspace}/bin/goto-workspace 4
    alt - 5 : ${gotoWorkspace}/bin/goto-workspace 5
    alt - 6 : ${gotoWorkspace}/bin/goto-workspace 6
    alt - 7 : ${gotoWorkspace}/bin/goto-workspace 7
    alt - 8 : ${gotoWorkspace}/bin/goto-workspace 8
    alt - 9 : ${gotoWorkspace}/bin/goto-workspace 9
  '';
in
{
  home-manager.users.${user.name} = {
    home.packages = [ pkgs.skhd ];
    xdg.configFile."skhd/skhdrc".source = skhdrc;

    launchd.agents.skhd = {
      enable = false;
      config = {
        Label = "com.koekeishiya.skhd";
        ProgramArguments = [
          "${pkgs.skhd}/bin/skhd"
          "-c"
          "${user.homeDirectory}/.config/skhd/skhdrc"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Interactive";
        StandardOutPath = "/tmp/skhd.log";
        StandardErrorPath = "/tmp/skhd.err.log";
      };
    };
  };
}
