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

    system.disableInstallerTools = true;

    nix.settings = {
      experimental-features = mkAfter <| singleton "cgroups";
      keep-derivations = mkForce false;
      keep-outputs = mkForce false;
      use-cgroups = true;
    };

    nix.gc = {
      dates = "weekly";
      persistent = true;
    };

    boot.kernel.sysctl = {
      "fs.protected_fifos" = 2;
      "fs.protected_regular" = 2;
      "fs.suid_dumpable" = 0;
      "kernel.dmesg_restrict" = 1;
      "kernel.ftrace_enabled" = 0;
      "kernel.kptr_restrict" = 2;
      "kernel.perf_event_paranoid" = 3;
      "kernel.sysrq" = 0;
      "kernel.unprivileged_bpf_disabled" = 1;
      "net.core.bpf_jit_enable" = 0;
    };

    boot.kernelParams = [
      "page_alloc.shuffle=1"
      "randomize_kstack_offset=on"
      "slab_nomerge"
      "sysrq_always_enabled=0"
      "vsyscall=none"
    ];

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

    services.logind.settings.Login.WallMessages = false;

    services.smartd.enable = true;

    system.autoUpgrade.enable = false;

    systemd.oomd = {
      enable = true;
      enableRootSlice = false;
      enableSystemSlice = false;
      enableUserSlices = true;
    };

    systemd.suppressedSystemUnits = [
      "debug-shell.service"
      "systemd-ask-password-wall.path"
      "systemd-ask-password-wall.service"
    ];
  };
}
