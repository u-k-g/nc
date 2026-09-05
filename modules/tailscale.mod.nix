{ lib, ... }:
let
  inherit (lib.lists) singleton;
  inherit (lib.strings) replaceStrings;
in
{
  flake.darwinModules.tailscale = { config, ... }: {
    homebrew.casks = singleton "tailscale-app";

    launchd.user.envVariables.PATH =
      replaceStrings [ "$HOME" "$USER" ] [ config.nc.user.homeDirectory config.nc.user.name ]
        config.environment.systemPath;
  };

  flake.nixosModules.tailscale = {
    services.tailscale.enable = true;
  };
}
