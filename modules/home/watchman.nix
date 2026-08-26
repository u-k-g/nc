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
  home.users.${user.name}.packages = singleton pkgs.watchman;
}
