{ config, pkgs, ... }:

let
  user = config.nc.user;
  fastWorkspaceSwitch = pkgs.callPackage ../packages/fast-workspace-switch { };
  paperwmConfig = pkgs.runCommand "paperwm-config" { } ''
    mkdir -p $out
    ln -s ${fastWorkspaceSwitch}/bin/fast-workspace-switch $out/fast-workspace-switch
  '';
in
{
  home-manager.users.${user.name}.xdg.configFile."paperwm".source = paperwmConfig;
}
