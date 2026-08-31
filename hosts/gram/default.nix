{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkForce;
in
{
  imports = singleton ./hardware.nix;

  nc.user = {
    name = "ukg";
    handle = "ukg";
    homeDirectory = "/home/ukg";
  };

  nc.themePreset = "grove";

  nc.nixos.cosmic.enable = true;
  nc.radicle.enable = false;

  networking.hostName = "gram";

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
        label = "nvme.gram";
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

  swapDevices = mkForce [ ];

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
    priority = 100;
  };

  services.bcachefs.autoScrub.enable = true;
  services.fstrim.enable = true;

  services.hardware.bolt.enable = true;
  services.fwupd.enable = true;
  services.thermald.enable = true;

  networking.networkmanager.wifi.powersave = false;

  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  networking.firewall = {
    enable = true;
    interfaces.tailscale0.allowedTCPPorts = singleton 22;
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

  systemd.oomd = {
    enable = true;
    enableRootSlice = true;
  };

  users.users.${config.nc.user.name} = {
    isNormalUser = true;
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
