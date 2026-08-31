{ ... }:

{
  flake.nixosModules.persist =
    {
      config,
      lib,
      utils,
      ...
    }:
    let
      inherit (lib.attrsets)
        genAttrs
        genAttrs'
        nameValuePair
        optionalAttrs
        ;
      inherit (lib.generators) toINI;
      inherit (lib.lists) head singleton;
      inherit (lib.modules) mkIf;
      inherit (lib.options) mkEnableOption mkOption;
      inherit (lib.types) listOf path str;
      inherit (utils) escapeSystemdPath;

      unitsFor =
        root:
        let
          unitName = mountpoint: "${escapeSystemdPath "${root}${mountpoint}"}.mount";
          anchor = head config.persist.mountpoints;
        in
        genAttrs' config.persist.mountpoints (
          mountpoint:
          nameValuePair (unitName mountpoint) {
            overrideStrategy = "asDropin";
            text =
              toINI { }
              <| optionalAttrs (mountpoint != anchor) {
                Unit.After = unitName anchor;
              };
          }
        );
    in
    {
      options.persist = {
        enable = mkEnableOption "bcachefs-backed persistence";

        filesystemName = mkOption {
          type = str;
          default = "persist";
          description = "Name of the Bcachefs filesystem.";
        };

        extraFormatArgs = mkOption {
          type = listOf str;
          default = [
            "--compression=zstd:9"
            "--background_compression=zstd:9"
            "--block_size=4096"
          ];
          description = "Extra arguments passed to bcachefs format.";
        };

        mountpoints = mkOption {
          type = listOf path;
          default = [ ];
          description = "Directories persisted beneath the ephemeral root filesystem.";
        };

        mountOptions = mkOption {
          type = listOf str;
          default = singleton "lazytime";
          description = "Mount options applied to every persistent subvolume.";
        };
      };

      config = mkIf config.persist.enable {
        assertions = singleton {
          assertion = config.persist.mountpoints != [ ];
          message = "persist.mountpoints must contain at least one mountpoint";
        };

        disko.devices.nodev.root = {
          fsType = "tmpfs";
          mountpoint = "/";
          mountOptions = [
            "defaults"
            "size=25%"
            "mode=755"
          ];
        };

        disko.devices.bcachefs_filesystems.${config.persist.filesystemName} = {
          type = "bcachefs_filesystem";

          inherit (config.persist) extraFormatArgs mountOptions;

          subvolumes = genAttrs config.persist.mountpoints (mountpoint: {
            inherit mountpoint;
            inherit (config.persist) mountOptions;
          });
        };

        boot.initrd.systemd.units = unitsFor "/sysroot";
        systemd.units = unitsFor "";
      };
    };
}
