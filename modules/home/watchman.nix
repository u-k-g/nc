{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.lists) singleton;
  user = config.nc.user;
in
{
  home-manager.users.${user.name}.home.packages = singleton pkgs.watchman;
}
