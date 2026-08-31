{ lib, ... }:

let
  inherit (lib.options) mkEnableOption;
in
{
  options.nc.nixos.workstation.enable = mkEnableOption "workstation applications and tuning";
}
