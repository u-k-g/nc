{ inputs, ... }:

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
      inherit (lib.options) mkEnableOption mkOption;
      inherit (lib.strings) escapeShellArg makeBinPath;
      inherit (lib.trivial) importJSON;
      inherit (lib.types) str;
    in
    {
      options.nc.nixos.t3-server = {
        enable = mkEnableOption "headless T3 Code over Tailscale";

        version = mkOption {
          type = str;
          default = (importJSON "${inputs.t3}/apps/server/package.json").version;
          description = "T3 npm version declared by the pinned t3 source input.";
        };
      };

      config = {
        # Install as the host user during activation. PNPM_HOME is already on
        # the Nushell PATH, so the same t3 command is available over SSH.
        nc.userActivationScripts.t3-install = mkIf config.nc.nixos.t3-server.enable /* bash */ ''
          (
            set -eu
            export PNPM_HOME=${escapeShellArg config.systemd.services.t3code.environment.PNPM_HOME}
            export PATH="$PNPM_HOME/bin:$PNPM_HOME:${
              makeBinPath [
                pkgs.nodejs
                pkgs.bashInteractive
                pkgs.coreutils
                pkgs.gnused
                pkgs.python3
                pkgs.gnumake
                pkgs.stdenv.cc
              ]
            }:$PATH"
            export SHELL=${getExe pkgs.bashInteractive}
            ${getExe pkgs.pnpm} add --global --save-exact \
              --allow-build=node-pty --allow-build=msgpackr-extract \
              ${escapeShellArg "t3@${config.nc.nixos.t3-server.version}"}
          )
        '';

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
            pkgs.nodejs
            pkgs.git
            pkgs.codex
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
