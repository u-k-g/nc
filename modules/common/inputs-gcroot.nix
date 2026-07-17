{ self, lib, ... }:

let
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists) elem foldl' singleton;

  # Large platform-specific release artifacts. Each machine keeps the one
  # its activation scripts actually reference; the rest should be collected.
  excluded = [
    "opencode-darwin-arm64"
    "opencode-desktop"
    "opencode-linux-x64"
    "opencode-linux-x64-baseline"
  ];
  excludedPaths = map (name: "${self.inputs.${name}}") excluded;

  collect =
    collected: inputs:
    foldl' (
      acc: child:
      if elem "${child}" excludedPaths || elem "${child}" acc then
        acc
      else
        collect (singleton "${child}" ++ acc) (child.inputs or { })
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
