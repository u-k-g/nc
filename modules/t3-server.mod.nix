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
      inherit (lib.meta) getExe getExe';
      inherit (lib.modules) mkIf;
      inherit (lib.options) mkEnableOption;
      inherit (lib.strings) escapeShellArg;

      home = config.nc.user.homeDirectory;
      pnpmHome = "${home}/.local/share/pnpm";
      stateDir = "${home}/.local/state/nc";

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
        # Install the latest release as the host user during activation. A
        # failed download keeps the installed version instead of failing the
        # switch, the same way the OpenCode activation script does.
        nc.userActivationScripts.t3-install = mkIf config.nc.nixos.t3-server.enable /* bash */ ''
          (
            set -euo pipefail

            export PNPM_HOME=${escapeShellArg pnpmHome}
            export PATH="$PNPM_HOME/bin:${pkgs.nodejs}/bin:${pkgs.coreutils}/bin:${pkgs.gnused}/bin:$PATH"
            export SHELL=${getExe pkgs.bashInteractive}

            if ! ${getExe pnpm} add --global \
              --allow-build=node-pty --allow-build=msgpackr-extract \
              --config.minimumReleaseAge=0 \
              t3@latest; then
              if [ ! -x "$PNPM_HOME/bin/t3" ]; then
                printf 'error: failed to install t3 and none is installed\n' >&2
                exit 1
              fi
              printf 'warning: failed to update t3; keeping the installed version\n' >&2
            fi

            # Restart the unit only when the version actually moved, so a
            # rebuild that changes nothing else leaves running sessions alone.
            # The shim needs node and coreutils on PATH, hence the export above.
            version="$("$PNPM_HOME/bin/t3" --version 2>/dev/null \
              | ${getExe' pkgs.gnugrep "grep"} --only-matching --extended-regexp '[0-9]+\.[0-9]+\.[0-9]+' || true)"
            ${pkgs.coreutils}/bin/mkdir --parents ${escapeShellArg stateDir}
            if [ -z "$version" ]; then
              printf 'warning: could not read the t3 version; restarting t3code.service\n' >&2
              printf 'unknown' > ${escapeShellArg "${stateDir}/t3-restart-pending"}
            else
              previous="$(${pkgs.coreutils}/bin/cat ${escapeShellArg "${stateDir}/t3-version"} 2>/dev/null || true)"
              printf '%s' "$version" > ${escapeShellArg "${stateDir}/t3-version"}
              if [ "$version" != "$previous" ]; then
                printf 't3 %s -> %s; restarting t3code.service\n' "''${previous:-none}" "$version"
                printf '%s' "$version" > ${escapeShellArg "${stateDir}/t3-restart-pending"}
              fi
            fi
          )
        '';

        # `t3 service install` writes a user unit whose ExecStart pins a
        # versioned runtime path. Keeping it alongside this module's system
        # unit makes both claim 127.0.0.1:3773 and ~/.t3/userdata, and the
        # pinned path goes stale on every t3 upgrade. Remove it so the system
        # unit is the only owner. t3 itself stays installed by pnpm.
        nc.userActivationScripts.t3-user-service-cleanup =
          mkIf config.nc.nixos.t3-server.enable /* bash */ ''
            unit_dir="$HOME/.config/systemd/user"
            unit="$unit_dir/t3code.service"
            wants="$unit_dir/default.target.wants/t3code.service"
            if [ -e "$unit" ] || [ -L "$wants" ]; then
              export XDG_RUNTIME_DIR="/run/user/$(${pkgs.coreutils}/bin/id -u)"
              export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
              ${getExe' pkgs.systemd "systemctl"} --user disable --now t3code.service || true
              ${pkgs.coreutils}/bin/rm -f "$unit" "$wants"
              ${pkgs.coreutils}/bin/rm -rf "$unit_dir/t3code.service.d"
              ${getExe' pkgs.systemd "systemctl"} --user daemon-reload || true
              ${getExe' pkgs.systemd "systemctl"} --user reset-failed t3code.service || true
            fi
          '';

        # The unit file never changes when pnpm installs a new t3, so the
        # restart has to be requested explicitly, and only after the user
        # activation decided the version moved.
        system.activationScripts.t3-restart = mkIf config.nc.nixos.t3-server.enable {
          deps = singleton "nc-user";
          text = ''
            if [ -e ${escapeShellArg "${stateDir}/t3-restart-pending"} ]; then
              echo t3code.service >> /run/nixos/activation-restart-list
              ${pkgs.coreutils}/bin/rm -f ${escapeShellArg "${stateDir}/t3-restart-pending"}
            fi
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
            "${home}/.local/bin"
            pnpmHome
            pkgs.nodejs
            pkgs.git
            pkgs.tailscale
          ];

          environment = {
            HOME = home;
            PNPM_HOME = pnpmHome;
            SHELL = getExe pkgs.bashInteractive;
            T3CODE_HOME = "${home}/.t3";
            T3CODE_HOST = "127.0.0.1";
            T3CODE_PORT = "3773";
            T3CODE_TAILSCALE_SERVE = "true";
            OPENCODE_DISABLE_AUTOUPDATE = "true";
            # nix-ld only reads its library path from the environment, and
            # systemd services do not inherit environment.variables. Without
            # this the downloaded chrome-headless-shell cannot start, so
            # html_render fails with a list of missing libraries.
            NIX_LD_LIBRARY_PATH = lib.makeLibraryPath config.programs.nix-ld.libraries;
          };

          serviceConfig = {
            User = config.nc.user.name;
            WorkingDirectory = home;
            ExecStart = "${pnpmHome}/bin/t3 serve";
            Restart = "on-failure";
            RestartSec = 5;
            KillMode = "control-group";
          };
        };
      };
    };
}
