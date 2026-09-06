{ inputs, ... }:

{
  flake.nixosModules.hermes =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.generators) toJSON;
      inherit (lib.lists) singleton;
      inherit (lib.meta) getExe getExe';
      inherit (lib.modules) mkIf;
      inherit (lib.options) mkEnableOption mkOption;
      inherit (lib.strings) escapeShellArgs;
      inherit (lib.types) package port str;
    in
    {
      options.nc.nixos.hermes = {
        enable = mkEnableOption "Hermes dashboard over Tailscale";

        package = mkOption {
          type = package;
          default = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
          description = "Pinned Hermes package, including the browser UI.";
        };

        home = mkOption {
          type = str;
          default = "${config.nc.user.homeDirectory}/.hermes";
          description = "Persistent Hermes settings, credentials, sessions and workspace.";
        };

        port = mkOption {
          type = port;
          default = 9119;
          description = "Loopback dashboard port.";
        };

        webPort = mkOption {
          type = port;
          default = 9120;
          description = "Loopback desktop UI proxy port.";
        };

        webPackage = mkOption {
          type = package;
          default = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.hermes-desktop-web.override {
            theme = config.nc.theme;
            themeAssets = pkgs.callPackage ../packages/hermes-desktop-web/theme.nix {
              theme = config.nc.theme;
            };
            mobileAssets = pkgs.callPackage ../packages/hermes-desktop-web/mobile.nix {
              src = inputs.hermes-desktop-web;
              background = "#${config.nc.theme.base00}";
            };
          };
          description = "Pinned desktop browser UI and proxy.";
        };

        httpsPort = mkOption {
          type = port;
          default = 8443;
          description = "Tailnet HTTPS port, separate from T3.";
        };

        hostname = mkOption {
          type = str;
          description = "Full Tailscale DNS name used by browsers.";
        };
      };

      config = {
        environment.systemPackages =
          mkIf config.nc.nixos.hermes.enable <| singleton config.nc.nixos.hermes.package;

        # Managed scope pins machine wiring and policy the agent (and drift)
        # can't touch: reverse-proxy URL, COSMIC/browser service wiring, and
        # terminal deny rules guarding the flake. Model/provider, agent tuning
        # and approval mode deliberately stay runtime-configurable in
        # ~/.hermes/config.yaml.
        environment.etc."hermes/config.yaml".text =
          mkIf config.nc.nixos.hermes.enable
          <| toJSON { } {
            dashboard.public_url = "https://${config.nc.nixos.hermes.hostname}:${toString config.nc.nixos.hermes.httpsPort}";

            # Machine wiring — services this install depends on.
            web.backend = "searxng";
            browser.backend = "browser-use";
            browser.cdp_url = "http://127.0.0.1:9333";
            computer_use.backend = "cua";
            wake_word.enabled = true;
            voice.auto_tts = false;
            memory.memory_enabled = false;
            memory.user_profile_enabled = false;
            session_reset.mode = "none";
            display.tool_progress = "all";

            # Frozen preferences.
            skills.disabled = [
              "airtable"
              "claude-code"
              "devops/sdlc-review"
            ];
            platform_toolsets.cli = [
              "a2a"
              "browser"
              "clarify"
              "code_execution"
              "computer_use"
              "cronjob"
              "delegation"
              "file"
              "kanban"
              "session_search"
              "skills"
              "terminal"
              "todo"
              "vision"
              "web"
            ];

            # COSMIC computer-use MCP server.
            mcp_servers."computer-use-linux" = {
              command = "${config.nc.user.homeDirectory}/.local/bin/computer-use-linux";
              args = singleton "mcp";
              env = {
                DBUS_SESSION_BUS_ADDRESS = "unix:path=/run/user/1000/bus";
                WAYLAND_DISPLAY = "wayland-1";
                XDG_SESSION_TYPE = "wayland";
                XDG_CURRENT_DESKTOP = "COSMIC";
                COMPUTER_USE_LINUX_COSMIC_HELPER = "${config.nc.user.homeDirectory}/.local/bin/computer-use-linux-cosmic";
                PATH = "/run/current-system/sw/bin:${config.nc.user.homeDirectory}/.local/state/nix/profile/bin:${config.nc.user.homeDirectory}/.local/bin:/usr/bin:/bin";
              };
              connect_timeout = 30.0;
              enabled = true;
            };

            # Deny rules survive --yolo and approvals.mode: off, and managed
            # scope keeps the agent from editing this list back out. Patterns
            # are fnmatch globs over the whole (deobfuscated) command text,
            # matched case-insensitively; reads are unaffected. rm rules are
            # word-boundary anchored so hermes.mod.nix / medium / warm never
            # match, and dd is narrowed to its if=/of= flags for the same
            # reason.
            approvals.deny = [
              # redirects into the flake (covers >, >> and heredoc targets)
              "*>*nc*"
              # deletes
              "rm*nc*"
              "* rm*nc*"
              "*;rm*nc*"
              "*&&rm*nc*"
              "*|rm*nc*"
              "*rmdir*nc*"
              "* rmdir*nc*"
              "*nc* rm *"
              # copies, moves, links
              "*cp*nc*"
              "*mv*nc*"
              "*install*nc*"
              "*rsync*nc*"
              "*ln*nc*"
              # in-place edits and byte-level writes
              "*sed*-i*nc*"
              "*tee*nc*"
              "*dd if*nc*"
              "*dd of*nc*"
              "*truncate*nc*"
              "*shred*nc*"
              # permission and ownership changes
              "*chmod*nc*"
              "*chown*nc*"
            ];
          };

        # write_file/patch sandbox: sessions may only create or modify files in
        # Hermes' own home and /tmp; every other path is denied for the file
        # tools. Managed scope keeps the agent from relaxing it. Terminal and
        # kernel writes into the flake are blocked at the syscall level by the
        # read-only mounts on the services below.
        environment.etc."hermes/.env".text =
          mkIf config.nc.nixos.hermes.enable
          <| ''
            HERMES_WRITE_SAFE_ROOT=${config.nc.user.homeDirectory}/.hermes:/tmp
          '';

        # The cron scheduler only ticks inside a running gateway — Hermes
        # ships no standalone cron daemon, and its own installer writes a
        # hand-maintained user unit to ~/.config/systemd/user. Declaring the
        # gateway here makes it a first-class service instead, with the same
        # kernel-level read-only flake the dashboard has (cron jobs, messaging
        # sessions and subagents all run under it). Hermes' single-instance
        # lock means exactly one gateway may run; after switching, remove the
        # old user unit (see the cutover note in the module comment below).
        systemd.services.hermes-gateway = mkIf config.nc.nixos.hermes.enable {
          description = "Hermes Agent gateway (cron scheduler and messaging platforms)";
          wantedBy = singleton "multi-user.target";
          wants = singleton "network-online.target";
          after = singleton "network-online.target";
          startLimitIntervalSec = 0;
          unitConfig.RequiresMountsFor = singleton config.nc.nixos.hermes.home;
          restartTriggers = [
            config.environment.etc."hermes/config.yaml".source
            config.environment.etc."hermes/.env".source
          ];

          environment = {
            HOME = config.nc.user.homeDirectory;
            HERMES_HOME = config.nc.nixos.hermes.home;
            SHELL = getExe pkgs.bashInteractive;
            HERMES_SUPERVISED_CHILD = "1";
          };

          path = [
            pkgs.git
            pkgs.bashInteractive
          ];

          serviceConfig = {
            User = config.nc.user.name;
            WorkingDirectory = config.nc.nixos.hermes.home;
            UMask = "0077";
            ReadOnlyPaths = singleton "${config.nc.user.homeDirectory}/nc";
            Restart = "always";
            RestartSec = 5;
            ExecStart = escapeShellArgs [
              (getExe' config.nc.nixos.hermes.package "hermes")
              "gateway"
              "run"
            ];
          };
        };

        services.tailscale.enable = mkIf config.nc.nixos.hermes.enable true;

        systemd.services.hermes = mkIf config.nc.nixos.hermes.enable {
          description = "Hermes browser dashboard";
          wantedBy = singleton "multi-user.target";
          wants = singleton "network-online.target";
          after = singleton "network-online.target";
          unitConfig.RequiresMountsFor = singleton config.nc.nixos.hermes.home;
          startLimitIntervalSec = 0;
          restartTriggers = [
            config.environment.etc."hermes/config.yaml".source
            config.environment.etc."hermes/.env".source
          ];

          environment = {
            HOME = config.nc.user.homeDirectory;
            HERMES_HOME = config.nc.nixos.hermes.home;
            SHELL = getExe pkgs.bashInteractive;
            HERMES_DASHBOARD_BASIC_AUTH_USERNAME = config.nc.user.name;
          };

          path = [
            pkgs.git
            pkgs.bashInteractive
          ];

          # Generate local dashboard credentials once, never in the Nix store
          # or journal. Systemd rereads EnvironmentFile before ExecStart.
          preStart =
            escapeShellArgs
            <| singleton
            <| pkgs.writers.writePython3 "hermes-initialize" { } /* python */ ''
              import os
              import pathlib
              import secrets
              import tempfile

              home = pathlib.Path(os.environ["HERMES_HOME"])
              home.mkdir(mode=0o700, parents=True, exist_ok=True)
              credentials = home / "dashboard.env"
              if not credentials.exists():
                  password = secrets.token_urlsafe(24)
                  signing_key = secrets.token_urlsafe(48)
                  fd, temporary = tempfile.mkstemp(prefix=".dashboard-", dir=home)
                  with os.fdopen(fd, "w") as stream:
                      stream.write(f"HERMES_DASHBOARD_BASIC_AUTH_PASSWORD={password}\n")
                      stream.write(f"HERMES_DASHBOARD_BASIC_AUTH_SECRET={signing_key}\n")
                  os.replace(temporary, credentials)
            '';

          serviceConfig = {
            User = config.nc.user.name;
            WorkingDirectory = config.nc.user.homeDirectory;
            EnvironmentFile = "-${config.nc.nixos.hermes.home}/dashboard.env";
            # Kernel-enforced read-only for everything the dashboard spawns:
            # chat sessions, terminal children and the execute_code kernel all
            # share this mount namespace, so the flake is read-only to the
            # agent at the syscall level, not just at the tool level.
            ReadOnlyPaths = singleton "${config.nc.user.homeDirectory}/nc";
            ExecStart = escapeShellArgs [
              (getExe' config.nc.nixos.hermes.package "hermes")
              "dashboard"
              "--host"
              "127.0.0.1"
              "--port"
              (toString config.nc.nixos.hermes.port)
              "--no-open"
              "--skip-build"
            ];
            Restart = "always";
            RestartSec = 5;
            UMask = "0077";
          };
        };

        systemd.services.hermes-web = mkIf config.nc.nixos.hermes.enable {
          description = "Hermes desktop browser UI";
          wantedBy = singleton "multi-user.target";
          wants = singleton "hermes.service";
          after = singleton "hermes.service";
          startLimitIntervalSec = 0;

          serviceConfig = {
            User = config.nc.user.name;
            Restart = "always";
            RestartSec = 5;
            UMask = "0077";
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            Environment = [
              "DENO_NO_UPDATE_CHECK=1"
              "DENO_DIR=/tmp/hermes-deno"
            ];
            ExecStart = escapeShellArgs [
              (getExe pkgs.deno)
              "run"
              "--no-config"
              "--no-lock"
              "--cached-only"
              "--no-check"
              "--allow-net=127.0.0.1:${toString config.nc.nixos.hermes.port},127.0.0.1:${toString config.nc.nixos.hermes.webPort}"
              "--allow-read=${config.nc.nixos.hermes.webPackage}/share/hermes-desktop-web"
              (pkgs.writeText "hermes-web.ts" /* typescript */ ''
                import { createProxyHandler } from "${config.nc.nixos.hermes.webPackage}/share/hermes-desktop-web/proxy/main.ts";

                const publicUrl = new URL("https://${config.nc.nixos.hermes.hostname}:${toString config.nc.nixos.hermes.httpsPort}");
                const gateway = "http://127.0.0.1:${toString config.nc.nixos.hermes.port}";
                const handler = createProxyHandler({
                  webDist: "${config.nc.nixos.hermes.webPackage}/share/hermes-desktop-web/dist/",
                  allowedTargets: [gateway],
                  defaultGatewayUrl: gateway,
                });

                Deno.serve({ hostname: "127.0.0.1", port: ${toString config.nc.nixos.hermes.webPort} }, (request) => {
                  const origin = request.headers.get("origin");
                  if (request.headers.get("host") !== publicUrl.host || (origin !== null && origin !== publicUrl.origin)) {
                    return new Response("Forbidden", { status: 403 });
                  }
                  return handler(request);
                });
              '')
            ];
          };
        };

        # Foreground Serve has a systemd-owned lifecycle. It removes only its
        # own listener when stopped; never reset the shared T3 Serve config.
        systemd.services.hermes-serve = mkIf config.nc.nixos.hermes.enable {
          description = "Publish Hermes on the tailnet";
          wantedBy = singleton "multi-user.target";
          after = [
            "tailscaled.service"
            "hermes-web.service"
          ];
          wants = [
            "tailscaled.service"
            "hermes-web.service"
          ];
          startLimitIntervalSec = 0;

          serviceConfig = {
            ExecStart = escapeShellArgs [
              (getExe pkgs.tailscale)
              "serve"
              "--yes"
              "--https=${toString config.nc.nixos.hermes.httpsPort}"
              "http://127.0.0.1:${toString config.nc.nixos.hermes.webPort}"
            ];
            Restart = "always";
            RestartSec = 5;
          };
        };
      };
    };
}
