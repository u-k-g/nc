{
  config,
  lib,
  modulesPath,
  ...
}:

{
  imports = lib.lists.singleton <| modulesPath + "/installer/scan/not-detected.nix";

  boot.initrd.availableKernelModules = [
    "nvme"
    "usb_storage"
    "uas"
    "xhci_pci"
  ];
  boot.initrd.kernelModules = lib.lists.singleton "i915";
  boot.kernelModules = [
    "ideapad_laptop"
    "kvm-intel"
  ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
