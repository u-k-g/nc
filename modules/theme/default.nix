{ inputs, lib, ... }:

let
  inherit (lib) mkOption types;
in
{
  options.nc.theme = mkOption {
    type = types.raw;
    default = inputs.themes.rose-pine;
    description = "Shared ThemeNix theme for NC modules.";
  };
}
