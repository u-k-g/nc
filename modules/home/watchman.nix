{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkIf;
  user = config.nc.user;
  workstation = pkgs.stdenv.hostPlatform.isDarwin || config.nc.nixos.workstation.enable;
in
{
  home.users.${user.name}.packages = mkIf workstation <| singleton pkgs.watchman;
}
