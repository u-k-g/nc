{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe';
  inherit (lib.modules) mkForce;

  install = getExe' pkgs.coreutils "install";
  grep = getExe' pkgs.gnugrep "grep";
  mktemp = getExe' pkgs.coreutils "mktemp";
  powerProfilesCtl = getExe' pkgs.power-profiles-daemon "powerprofilesctl";
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
  nc.radicle.enable = false;

  networking.hostName = "manara";

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
    interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = singleton 22;
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

  services.upower.ignoreLid = true;

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
    description = "Select the balanced power profile";
    after = singleton "power-profiles-daemon.service";
    requires = singleton "power-profiles-daemon.service";
    wantedBy = singleton "multi-user.target";

    script = /* bash */ ''
      if ${powerProfilesCtl} list | ${grep} --quiet --fixed-strings 'balanced:'; then
        ${powerProfilesCtl} set balanced
      else
        printf 'power-profiles-daemon does not expose a balanced profile\n' >&2
      fi
    '';

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
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
