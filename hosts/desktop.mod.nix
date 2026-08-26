{ lib, ... }:
let
  inherit (lib.lists) singleton;
in
{
  imports = singleton <| lib.systems.nixosSystem "desktop" ./desktop/default.nix;
}
