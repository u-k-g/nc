{
  config,
  lib,
  pkgs,
  self,
  ...
}:

let
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkIf;
in
{
  config = mkIf config.nc.nixos.workstation.enable {
    environment.systemPackages = singleton self.packages.${pkgs.stdenv.hostPlatform.system}.dns-switch;

    services.dnscrypt-proxy = {
      enable = true;
      settings = {
        server_names = singleton "mullvad-base";
        listen_addresses = singleton "127.0.0.1:53";

        ipv4_servers = true;
        ipv6_servers = false;
        dnscrypt_servers = false;
        doh_servers = true;
        odoh_servers = false;
        ignore_system_dns = true;

        static.mullvad-base.stamp = "sdns://AgMAAAAAAAAACzE5NC4yNDIuMi40ABRiYXNlLmRucy5tdWxsdmFkLm5ldAovZG5zLXF1ZXJ5";
      };
    };
  };
}
