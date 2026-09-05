{ lib, ... }:
let
  inherit (lib.lists) singleton;
in
{
  flake.darwinModules.tailscale = {
    homebrew.casks = singleton "tailscale-app";
  };

  flake.nixosModules.tailscale = {
    services.tailscale.enable = true;
  };
}
