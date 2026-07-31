{ config, lib, ... }:

let
  inherit (lib.modules) mkIf;
in
{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services.blueman.enable = mkIf config.hardware.bluetooth.enable true;
}
