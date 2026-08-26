{ inputs, ... }:
{
  commonModules.secrets =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.modules) mkAliasOptionModule;
    in
    {
      imports = singleton <| mkAliasOptionModule [ "secrets" ] [ "age" "secrets" ];
    };

  flake.nixosModules.secrets =
    { config, lib, ... }:
    let
      inherit (lib.lists) any singleton;
      inherit (lib.modules) mkDefault mkIf mkMerge;
      inherit (lib.strings) hasPrefix;
    in
    {
      imports = singleton inputs.agenix.nixosModules.age;

      config = mkMerge [
        {
          age.identityPaths = mkDefault [
            "/etc/ssh/ssh_host_ed25519_key"
            "${config.nc.user.homeDirectory}/.config/agenix/keys.txt"
            "${config.nc.user.homeDirectory}/.ssh/id_ed25519"
          ];
        }

        (mkIf (config.age.identityPaths |> any (hasPrefix "/media/key/")) {
          boot.initrd.availableKernelModules = {
            exfat = true;
            usb_storage = true;
            uas = true;
          };

          fileSystems."/media/key" = {
            device = "/dev/disk/by-label/${config.networking.hostName}.s";
            fsType = "exfat";
            options = [
              "ro"
              "umask=0077"
            ];
            neededForBoot = true;
          };
        })
      ];
    };

  flake.darwinModules.secrets =
    { config, lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      imports = singleton inputs.agenix.darwinModules.age;

      age.identityPaths = [
        "${config.nc.user.homeDirectory}/.config/agenix/keys.txt"
        "${config.nc.user.homeDirectory}/.ssh/id_ed25519"
      ];
    };

  flake.homeModules.secrets-manager =
    { pkgs, lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      packages = singleton pkgs.ragenix;
    };
}
