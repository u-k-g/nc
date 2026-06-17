{
  flake.darwinModules.tailscale = {
    services.tailscale.enable = true;
  };

  flake.nixosModules.tailscale = {
    services.tailscale.enable = true;
  };
}
