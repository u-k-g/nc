{ self, lib, ... }:

let
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists)
    elem
    foldl'
    singleton
    ;

  collect =
    collected: inputs:
    foldl' (
      acc: child:
      if elem "${child}" acc then acc else collect (singleton "${child}" ++ acc) (child.inputs or { })
    ) collected (attrValues inputs);
in
{
  home-manager.sharedModules = [
    {
      home.extraOutputsToInstall = [ ];
      home.extraBuilderCommands = ''
        mkdir -p $out/nix-support
        ${lib.concatMapStringsSep "\n" (input: ''
          echo ${input} >> $out/nix-support/extra-gc-roots
        '') (collect [ ] self.inputs)}
      '';
    }
  ];
}
