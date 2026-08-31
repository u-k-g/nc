{ config, lib, ... }:

let
  inherit (lib.modules) mkIf;
in
{
  config = mkIf config.nc.nixos.workstation.enable {
    services.printing.enable = true;

    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
  };
}
