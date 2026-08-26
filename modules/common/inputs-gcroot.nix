{
  config,
  self,
  lib,
  ...
}:

let
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists) elem foldl' singleton;

  collect =
    collected: inputs:
    foldl' (
      acc: child: if elem child acc then acc else collect (singleton child ++ acc) (child.inputs or { })
    ) collected (attrValues inputs);
in
{
  home.users.${config.nc.user.name}.extraDependencies = collect [ ] self.inputs;
}
