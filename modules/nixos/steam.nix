{ config, lib, ... }:

let
  inherit (lib.modules) mkIf;
in
{
  programs.steam.enable = mkIf config.nc.nixos.workstation.enable true;
}
