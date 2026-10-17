{ inputs, ... }:

{
  # Autolith is declared for the user in modules/home/autolith.nix. This module
  # only wires its upstream startup check into `nix flake check`, so a bad input
  # bump fails the flake instead of surfacing at runtime.
  perSystem =
    { system, ... }:
    {
      checks.autolith = inputs.autolith.checks.${system}.startup;
    };
}
