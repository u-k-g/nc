{
  config,
  lib,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf;
in
{
  options.nc.nixos.nvidia.enable = mkEnableOption "NVIDIA desktop graphics";

  config = mkIf config.nc.nixos.nvidia.enable {
    boot.kernelParams = [ "nvidia-drm.modeset=1" ];

    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      modesetting.enable = true;
      nvidiaSettings = true;
      open = false;
      package = config.boot.kernelPackages.nvidiaPackages.stable;

      powerManagement = {
        enable = false;
        finegrained = false;
      };
    };
  };
}
