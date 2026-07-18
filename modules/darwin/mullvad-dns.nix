{ lib, ... }:

let
  inherit (lib) mkForce;
  inherit (lib.lists) singleton;
in
{
  networking = {
    dns = singleton "127.0.0.1";
    knownNetworkServices = singleton "Wi-Fi";
  };

  services.dnscrypt-proxy = {
    enable = true;
    settings = {
      server_names = singleton "mullvad";
      listen_addresses = singleton "127.0.0.1:53";
      user_name = "_dnscrypt-proxy";

      ipv4_servers = true;
      ipv6_servers = false;
      dnscrypt_servers = false;
      doh_servers = true;
      odoh_servers = false;
      ignore_system_dns = true;

      static.mullvad.stamp = "sdns://AgcAAAAAAAAACzE5NC4yNDIuMi4yAA9kbnMubXVsbHZhZC5uZXQKL2Rucy1xdWVyeQ";
    };
  };

  # dnscrypt-proxy must start as root to bind port 53. It drops privileges to
  # _dnscrypt-proxy immediately afterward via settings.user_name above.
  launchd.daemons.dnscrypt-proxy.serviceConfig = {
    GroupName = mkForce "wheel";
    UserName = mkForce "root";
  };
}
