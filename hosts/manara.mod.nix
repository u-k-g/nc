{
  inputs,
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

          installer-manara =
            pkgs.callPackage
              (
                {
                  bcachefsKernelVersion,
                  bcachefsModule,
                  coreutils,
                  gnugrep,
                  kmod,
                  lib,
                  nixos-install,
                  util-linux,
                  writeShellApplication,
                  writers,
                }:
                let
                  inherit (lib.meta) getExe getExe';
                  chmod = getExe' coreutils "chmod";
                  copy = getExe' coreutils "cp";
                  grep = getExe gnugrep;
                  insmod = getExe' kmod "insmod";
                  lsblk = getExe' util-linux "lsblk";
                  mkdir = getExe' coreutils "mkdir";
                  modprobe = getExe' kmod "modprobe";
                  uname = getExe' coreutils "uname";

                  ensureBcachefs = writeShellApplication {
                    name = "ensure-manara-installer-bcachefs";
                    text = /* bash */ ''
                      if ${grep} --quiet --word-regexp bcachefs /proc/filesystems; then
                        exit 0
                      fi

                      runningKernel="$(${uname} --kernel-release)"
                      if [[ "$runningKernel" != ${lib.escapeShellArg bcachefsKernelVersion} ]]; then
                        printf 'The Manara installer carries Bcachefs for kernel %s, but this installer is running %s.\n' \
                          ${lib.escapeShellArg bcachefsKernelVersion} "$runningKernel" >&2
                        exit 65
                      fi

                      for dependency in lz4_compress libpoly1305 raid6_pq xor libchacha lz4hc_compress; do
                        ${modprobe} "$dependency"
                      done

                      ${insmod} ${bcachefsModule}/lib/modules/${bcachefsKernelVersion}/updates/src/fs/bcachefs/bcachefs.ko.xz

                      if ! ${grep} --quiet --word-regexp bcachefs /proc/filesystems; then
                        printf 'The Bcachefs module loaded without registering the filesystem.\n' >&2
                        exit 69
                      fi
                    '';
                  };
                in
                writers.writeNuBin "install-manara" /* nu */ ''
                  def main [] {
                    let mountpoint = "/mnt"
                    let target = "${self.nixosConfigurations.manara.config.disko.devices.disk.main.device}"

                    ^${getExe ensureBcachefs}

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
              )
              {
                bcachefsKernelVersion =
                  inputs.nixpkgs-install-media.legacyPackages.${pkgs.stdenv.hostPlatform.system}.linuxPackages.kernel.modDirVersion;
                bcachefsModule =
                  inputs.nixpkgs-install-media.legacyPackages.${pkgs.stdenv.hostPlatform.system}.linuxPackages.bcachefs;
              };
        };
    };
}
