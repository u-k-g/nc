{
  config,
  lib,
  ...
}:

let
  inherit (lib.lists) singleton;
  inherit (lib.modules)
    mkAfter
    mkForce
    mkIf
    ;
  inherit (lib.options) mkEnableOption;
in
{
  options.nc.nixos.server.enable = mkEnableOption "unattended server defaults";

  config = mkIf config.nc.nixos.server.enable {
    users.mutableUsers = false;

    environment.defaultPackages = [ ];
    environment.stub-ld.enable = false;

    programs.nano.enable = false;

    documentation.nixos.enable = false;

    nix.settings = {
      experimental-features = mkAfter <| singleton "cgroups";
      keep-derivations = mkForce false;
      keep-outputs = mkForce false;
      use-cgroups = true;
    };

    boot.kernel.sysctl = {
      "fs.protected_fifos" = 2;
      "fs.protected_regular" = 2;
      "fs.suid_dumpable" = 0;
      "kernel.dmesg_restrict" = 1;
      "kernel.kptr_restrict" = 2;
      "kernel.unprivileged_bpf_disabled" = 1;
    };

    networking.nftables.enable = true;

    networking.networkmanager = {
      ethernet.macAddress = "permanent";

      wifi = {
        backend = "iwd";
        macAddress = "permanent";
        scanRandMacAddress = false;
      };
    };

    networking.wireless.iwd.settings.General = {
      AddressRandomization = "disabled";
      AddressRandomizationRange = "full";
    };

    services.journald.extraConfig = ''
      Compress=yes
      Seal=yes
      SystemKeepFree=5G
      SystemMaxUse=2G
      MaxRetentionSec=1month
    '';

    services.smartd.enable = true;

    system.autoUpgrade.enable = false;

    systemd.oomd = {
      enable = true;
      enableRootSlice = false;
      enableSystemSlice = false;
      enableUserSlices = true;
    };
  };
}
