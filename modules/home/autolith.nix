{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption;
  inherit (lib.types) bool;
in
{
  options.nc.autolith.enable = mkOption {
    type = bool;
    default = true;
    description = "Whether to install Autolith for the user.";
  };

  # Autolith keeps its mutable images and private state per user, so it belongs
  # in the user's profile rather than the system profile.
  config.home.users.${config.nc.user.name}.packages =
    mkIf config.nc.autolith.enable
    <| singleton inputs.autolith.packages.${pkgs.stdenv.hostPlatform.system}.default;
}
