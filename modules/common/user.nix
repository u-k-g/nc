{ lib, ... }:

let
  inherit (lib) mkOption types;
in
{
  options.nc.user = {
    name = mkOption {
      type = types.str;
      description = "Host-local OS account username.";
    };

    handle = mkOption {
      type = types.str;
      default = "ukg";
      description = "Portable user handle used across machines.";
    };

    fullName = mkOption {
      type = types.str;
      default = "uzair khan ghori";
    };

    email = mkOption {
      type = types.str;
      default = "ukghori08@gmail.com";
    };

    homeDirectory = mkOption {
      type = types.path;
      description = "Home directory for the host-local OS account.";
    };
  };
}
