{
  lib,
  self,
  ...
}:

let
  inherit (lib.lists) singleton;
in
{
  imports = singleton <| lib.systems.nixosSystem "manara" ./manara/default.nix;

  perSystem =
    { pkgs, ... }:
    {
      packages =
        lib.optionalAttrs (pkgs.stdenv.hostPlatform.isLinux && pkgs.stdenv.hostPlatform.isx86_64)
        <| {
          capture-manara-hardware = pkgs.callPackage (
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
              name = "capture-manara-hardware";
              text = ''
                if (( EUID != 0 )); then
                  printf 'capture-manara-hardware must run as root\n' >&2
                  exit 77
                fi

                output="''${1:-hosts/manara/facter.json}"
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

          installer-manara = pkgs.callPackage (
            {
              coreutils,
              lib,
              nixos-install,
              util-linux,
              writers,
            }:
            let
              inherit (lib.meta) getExe getExe';
              chmod = getExe' coreutils "chmod";
              copy = getExe' coreutils "cp";
              lsblk = getExe' util-linux "lsblk";
              mkdir = getExe' coreutils "mkdir";
            in
            writers.writeNuBin "install-manara" /* nu */ ''
              def main [] {
                let mountpoint = "/mnt"
                let target = "${self.nixosConfigurations.manara.config.disko.devices.disk.main.device}"

                print "The Manara installer will permanently erase this disk:"
                ^${lsblk} --output NAME,PATH,SIZE,MODEL,SERIAL,TYPE,MOUNTPOINTS $target
                let confirmation = (input "Type 'ERASE manara' to continue: ")
                if $confirmation != "ERASE manara" {
                  print "Installation cancelled."
                  exit 1
                }

                ^${mkdir} --parents $mountpoint
                ^${chmod} 755 $mountpoint

                DISKO_SKIP_SWAP=1 ^${self.nixosConfigurations.manara.config.system.build.diskoScript}

                let connections = "/etc/NetworkManager/system-connections"
                if ($connections | path exists) {
                  let target = $"($mountpoint)/etc/NetworkManager/system-connections"
                  ^${mkdir} --parents $target
                  ^${copy} --archive $"($connections)/." $target
                  ^${chmod} --recursive go-rwx $target
                }

                (exec ${getExe nixos-install}
                  --flake "${self}#manara"
                  --no-channel-copy
                  --no-root-password
                  --option accept-flake-config true
                  --option experimental-features "nix-command flakes pipe-operators"
                  --root $mountpoint)
              }
            ''
          ) { };
        };
    };
}
