{
  config,
  inputs,
  lib,
  moduleLocation,
  ...
}:

let
  inherit (lib.attrsets) mapAttrs optionalAttrs;
  inherit (lib.fixedPoints) fix;
  inherit (lib.lists) singleton;
  inherit (lib.options) mkOption;
  inherit (lib.types)
    attrsOf
    deferredModule
    lazyAttrsOf
    listOf
    str
    ;

  wrap =
    {
      kind,
      class ? null,
    }:
    name: value:
    fix (
      module:
      {
        _file = "${moduleLocation}#${kind}.${name}";
        key = module._file;

        ${if class == null then null else "_class"} = class;

        imports = singleton value;
      }
      // optionalAttrs (value ? meta) {
        inherit (value) meta;
      }
    );
in
{
  # flake-parts does not give exported NixOS modules a key, so repeated imports
  # cannot be deduplicated. Redeclare the output with stable keys.
  disabledModules = singleton "${inputs.flake-parts}/modules/nixosModules.nix";

  options.flake.nixosModules = mkOption {
    type = lazyAttrsOf deferredModule;
    default = { };
    apply =
      mapAttrs
      <| wrap {
        kind = "nixosModules";
        class = "nixos";
      };
    description = "NixOS modules.";
  };

  options.commonModules = mkOption {
    type = lazyAttrsOf deferredModule;
    default = { };
    apply = mapAttrs <| wrap { kind = "commonModules"; };
    description = "Modules shared between NixOS and Darwin.";
  };

  options.flake.darwinModules = mkOption {
    type = lazyAttrsOf deferredModule;
    default = { };
    apply =
      mapAttrs
      <| wrap {
        kind = "darwinModules";
        class = "darwin";
      };
    description = "Darwin modules.";
  };

  options.flake.homeModules = mkOption {
    type = lazyAttrsOf deferredModule;
    default = { };
    apply =
      mapAttrs
      <| wrap {
        kind = "homeModules";
        class = "hjem";
      };
    description = "Hjem modules shared by users.";
  };

  options.flake.keys = mkOption {
    type = attrsOf str;
    default = { };
    description = "Public SSH keys used for age recipients.";
  };

  options.flake.keys-admin = mkOption {
    type = listOf str;
    default = [ ];
    description = "Admin public SSH keys used for shared secrets.";
  };

  config.flake.nixosModules = config.commonModules;
  config.flake.darwinModules = config.commonModules;
}
