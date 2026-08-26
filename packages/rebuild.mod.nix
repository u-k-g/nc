{ self, ... }:
{
  perSystem =
    { config, pkgs, ... }:
    {
      packages.rebuild = pkgs.callPackage (
        {
          lib,
          writers,
        }:
        let
          inherit (lib.strings) fileContents removePrefix;
        in
        writers.writeNuBin "rebuild" /* nu */ ''
          $env.NC_FLAKE = "${self}"

          ${removePrefix "#!/usr/bin/env nu\n" <| fileContents ../rebuild.nu}
        ''
      ) { };

      packages.default = config.packages.rebuild;
    };
}
