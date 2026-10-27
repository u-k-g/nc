{ ... }:

{
  flake.nixosModules.t3-server =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkIf;
      inherit (lib.options) mkEnableOption;
      inherit (lib.strings) escapeShellArg;

      # node-pty compiles native code through node-gyp, so keep the toolchain
      # next to the interpreter and shell pnpm's lifecycle scripts need.
      pnpm = lib.mkExtraPath pkgs pkgs.pnpm [
        pkgs.nodejs
        pkgs.bashInteractive
        pkgs.coreutils
        pkgs.gnused
        pkgs.python3
        pkgs.gnumake
        pkgs.stdenv.cc
      ];
    in
    {
      options.nc.nixos.t3-server = {
        enable = mkEnableOption "headless T3 Code over Tailscale";

      };

      config = {
        # Install the latest release as the host user during activation. PNPM_HOME is already on
        # the Nushell PATH, so the same t3 command is available over SSH.
        nc.userActivationScripts.t3-install = mkIf config.nc.nixos.t3-server.enable /* bash */ ''
          (
            set -euo pipefail
            export PNPM_HOME=${escapeShellArg config.systemd.services.t3code.environment.PNPM_HOME}
            export PATH="$PNPM_HOME/bin:$PNPM_HOME:$PATH"
            export SHELL=${getExe pkgs.bashInteractive}
            ${getExe pnpm} add --global \
              --allow-build=node-pty --allow-build=msgpackr-extract \
              --config.minimumReleaseAge=0 \
              t3@latest
          )
        '';

        system.activationScripts.t3-restart = mkIf config.nc.nixos.t3-server.enable {
          deps = singleton "nc-user";
          text = ''
            echo t3code.service >> /run/nixos/activation-restart-list
          '';
        };

        services.tailscale.enable = mkIf config.nc.nixos.t3-server.enable true;
        services.tailscale.extraSetFlags =
          mkIf config.nc.nixos.t3-server.enable <| singleton "--operator=${config.nc.user.name}";

        systemd.services.t3code = mkIf config.nc.nixos.t3-server.enable {
          description = "T3 Code over Tailscale";
          after = [
            "network-online.target"
            "tailscaled.service"
            "tailscaled-set.service"
          ];
          wants = singleton "network-online.target";
          requires = singleton "tailscaled.service";
          wantedBy = singleton "multi-user.target";

          path = [
            "${config.nc.user.homeDirectory}/.local/bin"
            "${config.nc.user.homeDirectory}/.local/share/pnpm"
            pkgs.nodejs
            pkgs.git
            pkgs.tailscale
          ];

          environment = {
            HOME = config.nc.user.homeDirectory;
            PNPM_HOME = "${config.nc.user.homeDirectory}/.local/share/pnpm";
            SHELL = getExe pkgs.bashInteractive;
            T3CODE_HOME = "${config.nc.user.homeDirectory}/.t3";
            T3CODE_HOST = "127.0.0.1";
            T3CODE_PORT = "3773";
            T3CODE_TAILSCALE_SERVE = "true";
            OPENCODE_DISABLE_AUTOUPDATE = "true";
          };

          serviceConfig = {
            User = config.nc.user.name;
            WorkingDirectory = config.nc.user.homeDirectory;
            ExecStart = "${config.systemd.services.t3code.environment.PNPM_HOME}/bin/t3 serve";
            Restart = "on-failure";
            RestartSec = 5;
            KillMode = "control-group";
          };
        };
      };
    };
}
