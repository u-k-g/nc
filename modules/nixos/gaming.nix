{ pkgs, ... }:

{
  boot = {
    kernelPackages = pkgs.linuxPackages_cachyos;
    kernelParams = [
      "mitigations=off"
      "nowatchdog"
      "nmi_watchdog=0"
      "rcupdate.rcu_expedited=1"
      "amd_pstate=active"
      "processor.max_cstate=1"
      "split_lock_detect=off"
      "transparent_hugepage=madvise"
      "rcu_nocbs=0-15"
      "nohz_full=0-15"
      "isolcpus=1-15"
    ];

    kernel.sysctl = {
      "vm.swappiness" = 10;
      "vm.vfs_cache_pressure" = 50;
      "vm.max_map_count" = 2147483642;
      "net.core.netdev_max_backlog" = 30000;
      "net.core.rmem_max" = 134217728;
      "net.core.wmem_max" = 134217728;
      "kernel.split_lock_mitigate" = 0;
      "kernel.sched_child_runs_first" = 1;
      "kernel.sched_migration_cost_ns" = 500;
      "kernel.sched_min_granularity_ns" = 100000;
      "kernel.sched_wakeup_granularity_ns" = 50000;
      "kernel.timer_slack_ns" = 50;
      "kernel.nmi_watchdog" = 0;
    };
  };

  powerManagement = {
    cpuFreqGovernor = "performance";
    powertop.enable = false;
  };

  services = {
    power-profiles-daemon.enable = false;
    tlp.enable = false;

    udev.extraRules = ''
      ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
    '';
  };

  programs = {
    gamemode.enable = true;
    gamescope.enable = true;
  };

  services.scx = {
    enable = true;
    # scx_lavd is latency-oriented and usually feels good on the desktop.
    # For Minecraft on the Ryzen 3 3100, compare generations with:
    # - "scx_bpfland": can improve gaming-oriented interactivity/frame pacing.
    # - "scx_rusty": can behave better for mixed desktop + game workloads.
    # - services.scx.enable = false: lets CachyOS/BORE handle scheduling itself.
    # Keep whichever gives the best 1% lows and least frametime spikes, not just
    # the highest average FPS.
    scheduler = "scx_lavd";
  };

  environment.systemPackages = with pkgs; [
    jdk17
    jdk21
    mangohud
    protonup-qt
  ];
}
