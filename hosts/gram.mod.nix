{
  lib,
  self,
  ...
}:

let
  inherit (lib.lists) singleton;
in
{
  imports = singleton <| lib.systems.nixosSystem "gram" ./gram/default.nix;

  perSystem =
    { pkgs, ... }:
    {
      packages =
        lib.optionalAttrs (pkgs.stdenv.hostPlatform.isLinux && pkgs.stdenv.hostPlatform.isx86_64)
        <| {
          installer-gram = pkgs.callPackage (
            {
              lib,
              nix,
              nixos-install,
              writers,
            }:
            let
              inherit (lib.meta) getExe getExe';
            in
            writers.writeNuBin "install-gram" /* nu */ ''
              def main [] {
                let mountpoint = "/mnt"

                ^${getExe' pkgs.coreutils "mkdir"} --parents $mountpoint
                ^${getExe' pkgs.coreutils "chmod"} 755 $mountpoint

                DISKO_SKIP_SWAP=1 ^${self.nixosConfigurations.gram.config.system.build.diskoScript}

                (^${getExe nix} copy
                  --no-check-sigs
                  --to $"local?root=($mountpoint)"
                  ${self.nixosConfigurations.gram.config.system.build.toplevel})

                (exec ${getExe nixos-install}
                  --no-channel-copy
                  --no-root-password
                  --system ${self.nixosConfigurations.gram.config.system.build.toplevel}
                  --root $mountpoint)
              }
            ''
          ) { };
        };
    };
}
