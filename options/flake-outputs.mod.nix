{
  lib,
  moduleLocation,
  ...
}:

let
  inherit (lib.attrsets) mapAttrs optionalAttrs;
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
    kind: name: value:
    {
      _file = "${toString moduleLocation}#${kind}.${name}";
      imports = singleton value;
    }
    // optionalAttrs (value ? meta) {
      inherit (value) meta;
    };
in
{
  options.flake.commonModules = mkOption {
    type = lazyAttrsOf deferredModule;
    default = { };
    apply = mapAttrs (wrap "commonModules");
    description = "Modules shared between NixOS and Darwin.";
  };

  options.flake.darwinModules = mkOption {
    type = lazyAttrsOf deferredModule;
    default = { };
    apply = mapAttrs (wrap "darwinModules");
    description = "Darwin modules.";
  };

  options.flake.homeModules = mkOption {
    type = lazyAttrsOf deferredModule;
    default = { };
    apply = mapAttrs (wrap "homeModules");
    description = "Home Manager modules shared by users.";
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

}
