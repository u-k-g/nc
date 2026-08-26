{ lib, ... }:
let
  inherit (lib.lists) singleton;
in
{
  imports = singleton <| lib.systems.darwinSystem "darwinbook" ./darwinbook/default.nix;
}
