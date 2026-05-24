{ lib, ... }:

let
  inherit (lib.modules) mkAliasOptionModule;
  inherit (lib.lists) singleton;
in
{
  imports = singleton (mkAliasOptionModule [ "secrets" ] [ "age" "secrets" ]);
}
