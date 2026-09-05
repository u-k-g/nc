{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe getExe';
  inherit (lib.modules) mkForce;

  install = getExe' pkgs.coreutils "install";
  grep = getExe' pkgs.gnugrep "grep";
  mktemp = getExe' pkgs.coreutils "mktemp";
  powerProfilesCtl = getExe' pkgs.power-profiles-daemon "powerprofilesctl";
  systemctl = getExe' pkgs.systemd "systemctl";
  remove = getExe' pkgs.coreutils "rm";
  systemdId128 = getExe' pkgs.systemd "systemd-id128";
  test = getExe' pkgs.coreutils "test";
in
{
  imports = singleton ./hardware.nix;

  nc.user = {
    name = "ukg";
    handle = "ukg";
    homeDirectory = "/home/ukg";
  };

  nc.nixos.cosmic.enable = true;
  nc.nixos.server.enable = true;
  nc.nixos.t3-server.enable = true;
  nc.radicle.enable = false;

  networking.hostName = "manara";

  programs.nix-ld.enable = true;

  disko.devices.disk.main = {
    device = "/dev/nvme0n1";
    type = "disk";

    content.type = "gpt";

    content.partitions.boot = {
      priority = 100;
      size = "1G";
      type = "EF00";

      content = {
        type = "filesystem";
        format = "vfat";
        mountpoint = "/boot";
        mountOptions = [
          "fmask=0077"
          "dmask=0077"
        ];
      };
    };

    content.partitions.bcachefs = {
      priority = 200;
      size = "100%";

      content.type = "bcachefs";
      content = {
        filesystem = config.persist.filesystemName;
        label = "nvme.manara";
      };
    };
  };

  persist = {
    enable = true;
    mountpoints = [
      "/nix"
      "/home"
      "/root"
      "/etc/NetworkManager/system-connections"
      "/etc/ssh"
      "/var/lib/AccountsService"
      "/var/lib/NetworkManager"
      "/var/lib/bluetooth"
      "/var/lib/fwupd"
      "/var/lib/systemd"
      "/var/lib/tailscale"
      "/var/lib/upower"
      "/var/log"
    ];
  };

  boot = {
    initrd.systemd.enable = true;
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = singleton "zswap.enabled=0";

    loader = {
      timeout = 0;

      systemd-boot = {
        enable = true;
        editor = false;
        configurationLimit = 10;
        consoleMode = "keep";
      };

      efi.canTouchEfiVariables = true;
    };
  };

  nix.settings = {
    cores = 4;
    max-jobs = 2;
  };

  swapDevices = mkForce [ ];

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
    priority = 100;
  };

  services.bcachefs.autoScrub.enable = true;
  services.fstrim.enable = true;

  services.fwupd.enable = true;
  services.thermald.enable = true;

  networking.networkmanager.wifi.powersave = false;

  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  networking.firewall = {
    enable = true;
    checkReversePath = "loose";
    extraReversePathFilterRules = ''iifname "${config.services.tailscale.interfaceName}" accept'';
    trustedInterfaces = singleton "tailscale0";
  };

  services.openssh = {
    enable = true;
    openFirewall = false;

    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  security.sudo.wheelNeedsPassword = mkForce false;

  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    IdleAction = "ignore";
  };

  services.upower = {
    ignoreLid = true;
    # The AC-aware policy below owns shutdown; UPower's HybridSleep default
    # falls back to PowerOff when sleep and hibernation are disabled.
    allowRiskyCriticalPowerAction = true;
    criticalPowerAction = "Ignore";
  };

  systemd.sleep.settings.Sleep = {
    AllowSuspend = false;
    AllowHibernation = false;
    AllowSuspendThenHibernate = false;
    AllowHybridSleep = false;
  };

  environment.etc."machine-id".source = "/var/lib/systemd/machine-id";

  system.activationScripts.manara-machine-id = {
    deps = singleton "etc";
    text = /* bash */ ''
      if ! ${test} -s /var/lib/systemd/machine-id; then
        machineIdFile="$(${mktemp})"
        trap '${remove} --force "$machineIdFile"' EXIT
        ${systemdId128} new > "$machineIdFile"
        ${install} --group=root --mode=0444 --owner=root "$machineIdFile" /var/lib/systemd/machine-id
      fi
    '';
  };

  systemd.services.manara-battery-conservation = {
    description = "Enable Lenovo battery conservation mode";
    after = singleton "systemd-modules-load.service";
    wantedBy = singleton "multi-user.target";

    script = /* bash */ ''
      configured=false

      for setting in /sys/class/power_supply/*/charge_types; do
        if [[ -w "$setting" ]] && ${grep} --quiet --extended-regexp 'Long(_| )Life' "$setting"; then
          printf 'Long_Life\n' > "$setting"
          configured=true
        fi
      done

      if [[ "$configured" == false ]]; then
        for setting in /sys/bus/platform/devices/VPC2004:*/conservation_mode; do
          if [[ -w "$setting" ]]; then
            printf '1\n' > "$setting"
          fi
        done
      fi
    '';

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  systemd.services.manara-power-profile = {
    description = "Manage AC/battery power and shut down at 20% on battery";
    after = singleton "power-profiles-daemon.service";
    requires = singleton "power-profiles-daemon.service";
    wantedBy = singleton "multi-user.target";

    serviceConfig = {
      Type = "oneshot";
      ExecStart = getExe <| pkgs.writers.writeNuBin "manara-power-policy" /* nu */ ''
        def read-power [name: string]: nothing -> string {
          open --raw $"/sys/class/power_supply/($name)" | str trim
        }

        # Unknown or unreadable AC state must never authorize a shutdown.
        let ac = read-power "ACAD/online"
        let capacity = read-power "BAT1/capacity" | into int
        let status = read-power "BAT1/status"
        print $"AC=($ac) battery=($capacity)% status=($status)"

        let profile = match $ac {
          "1" => "balanced"
          "0" => "power-saver"
          _ => { error make { msg: "Unknown AC state; skipping power policy" } }
        }
        let current = ^${powerProfilesCtl} get | complete
        if $current.exit_code != 0 or ($current.stdout | str trim) != $profile {
          let result = ^${powerProfilesCtl} set $profile | complete
          if $result.exit_code != 0 {
            print --stderr $"Failed to select ($profile): ($result.stderr)"
          }
        }

        if $ac == "0" and $status == "Discharging" and $capacity >= 0 and $capacity <= 20 {
          # Recheck immediately before shutdown in case AC was reconnected.
          if (read-power "ACAD/online") == "0" and (read-power "BAT1/status") == "Discharging" {
            print $"Battery at ($capacity)% without AC; powering off"
            let result = ^${systemctl} poweroff | complete
            if $result.exit_code != 0 {
              error make { msg: $"Shutdown failed: ($result.stderr)" }
            }
          }
        }
      '';
    };
  };

  systemd.timers.manara-power-profile = {
    description = "Check Manara's power source and battery every minute";
    wantedBy = singleton "timers.target";
    timerConfig = {
      OnBootSec = "30s";
      OnUnitInactiveSec = "60s";
      AccuracySec = "1s";
    };
  };

  users.users.${config.nc.user.name} = {
    isNormalUser = true;
    linger = true;
    home = config.nc.user.homeDirectory;
    shell = pkgs.nushell;

    extraGroups = [
      "input"
      "networkmanager"
      "render"
      "video"
      "wheel"
    ];

    openssh.authorizedKeys.keys = singleton "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPVbh74Osri8TqrnMnwMIN4RWJhXSRpyZ5HJpEK5PTwX ukghori08@gmail.com";
  };

  system.stateVersion = "26.05";
}
