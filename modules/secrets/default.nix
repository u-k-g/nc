{ lib, ... }:

let
  inherit (builtins) baseNameOf;
  inherit (lib.attrsets) filterAttrs mapAttrs';
  inherit (lib.strings) hasPrefix removeSuffix;
  inherit (lib.modules) mkAliasOptionModule;
  inherit (lib.lists) singleton;

  rules = import ../../secrets.nix;
  repoSecrets = filterAttrs (name: _: hasPrefix "secrets/" name) rules;
  secretName = path: removeSuffix ".age" (baseNameOf path);
in
{
  imports = singleton (mkAliasOptionModule [ "secrets" ] [ "age" "secrets" ]);

  age.secrets = mapAttrs' (
    path: _:
    lib.nameValuePair (secretName path) {
      file = ../../. + "/${path}";
    }
  ) repoSecrets;
}
