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
          capture-gram-hardware = pkgs.callPackage (
            {
              coreutils,
              lib,
              nixos-facter,
              util-linux,
              writeShellApplication,
            }:
            let
              inherit (lib.meta) getExe getExe';
            in
            writeShellApplication {
              name = "capture-gram-hardware";
              text = ''
                if (( EUID != 0 )); then
                  printf 'capture-gram-hardware must run as root\n' >&2
                  exit 77
                fi

                output="''${1:-hosts/gram/facter.json}"
                ${getExe nixos-facter} --output "$output"

                printf '\nBlock devices:\n'
                ${getExe' util-linux "lsblk"} --output NAME,PATH,SIZE,MODEL,SERIAL,TYPE,MOUNTPOINTS

                printf '\nStable NVMe identifiers:\n'
                for path in /dev/disk/by-id/nvme-*; do
                  if [[ -e "$path" && "$path" != *-part* ]]; then
                    printf '%s -> %s\n' "$path" "$(${getExe' coreutils "readlink"} --canonicalize "$path")"
                  fi
                done
              '';
            }
          ) { };

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
