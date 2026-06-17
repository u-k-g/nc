{
  flake.darwinModules.tailscale =
    { lib, pkgs, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      environment.systemPackages = singleton pkgs.tailscale;
    };

  flake.nixosModules.tailscale = {
    services.tailscale.enable = true;
  };
}
