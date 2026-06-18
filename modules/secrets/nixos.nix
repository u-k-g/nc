{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.lists) singleton;
in
{
  imports = singleton inputs.agenix.nixosModules.age;

  age.identityPaths = [
    "${config.nc.user.homeDirectory}/.config/agenix/keys.txt"
    "${config.nc.user.homeDirectory}/.ssh/id_ed25519"
  ];

  home-manager.users.${config.nc.user.name}.home.packages = [
    pkgs.age
    pkgs.rage
    pkgs.ragenix
  ];
}
