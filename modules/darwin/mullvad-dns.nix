{
  config,
  lib,
  pkgs,
  self,
  ...
}:

let
  inherit (lib.modules) mkForce;
  inherit (lib.lists) singleton;
in
{
  environment.systemPackages = singleton self.packages.${pkgs.stdenv.hostPlatform.system}.dns-switch;

  security.sudo.extraConfig = ''
    ${config.nc.user.name} ALL = (root) NOPASSWD: /run/current-system/sw/bin/dns cycle
  '';

  networking = {
    dns = singleton "127.0.0.1";
    knownNetworkServices = singleton "Wi-Fi";
  };

  services.dnscrypt-proxy = {
    enable = true;
    settings = {
      server_names = singleton "mullvad-base";
      listen_addresses = singleton "127.0.0.1:53";
      user_name = "_dnscrypt-proxy";

      ipv4_servers = true;
      ipv6_servers = false;
      dnscrypt_servers = false;
      doh_servers = true;
      odoh_servers = false;
      ignore_system_dns = true;

      static.mullvad-base.stamp = "sdns://AgMAAAAAAAAACzE5NC4yNDIuMi40ABRiYXNlLmRucy5tdWxsdmFkLm5ldAovZG5zLXF1ZXJ5";
    };
  };

  # dnscrypt-proxy must start as root to bind port 53. It drops privileges to
  # _dnscrypt-proxy immediately afterward via settings.user_name above.
  launchd.daemons.dnscrypt-proxy.serviceConfig = {
    GroupName = mkForce "wheel";
    UserName = mkForce "root";
  };
}
