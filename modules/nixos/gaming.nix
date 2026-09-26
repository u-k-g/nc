{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.modules) mkIf;
in
{
  config = mkIf config.nc.nixos.workstation.enable {
    boot = {
      kernelPackages = pkgs.linuxPackages_latest;

      kernel.sysctl = {
        "vm.swappiness" = 10;
        "vm.vfs_cache_pressure" = 50;
        "vm.max_map_count" = 2147483642;
        "net.core.netdev_max_backlog" = 30000;
        "net.core.rmem_max" = 134217728;
        "net.core.wmem_max" = 134217728;
      };
    };

    programs = {
      gamemode.enable = true;
      gamescope.enable = true;
    };

    environment.systemPackages = with pkgs; [
      jdk17
      jdk21
      mangohud
      protonup-qt
    ];
  };
}
