{
  flake.commonModules.tailscale =
    { lib, pkgs, ... }:
    let
      inherit (lib.lists) optionals singleton;
    in
    {
      services.tailscale.enable = true;

      environment.systemPackages = optionals pkgs.stdenv.isDarwin (singleton pkgs.tailscale-gui);
    };
}
