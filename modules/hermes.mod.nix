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
          default = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.hermes-desktop-web;
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

        # Managed scope pins only the reverse-proxy URL. Provider, model and
        # all other user settings remain writable in ~/.hermes/config.yaml.
        environment.etc."hermes/config.yaml".text =
          mkIf config.nc.nixos.hermes.enable
          <| toJSON { } {
            dashboard.public_url = "https://${config.nc.nixos.hermes.hostname}:${toString config.nc.nixos.hermes.httpsPort}";
          };

        services.tailscale.enable = mkIf config.nc.nixos.hermes.enable true;

        systemd.services.hermes = mkIf config.nc.nixos.hermes.enable {
          description = "Hermes browser dashboard";
          wantedBy = singleton "multi-user.target";
          wants = singleton "network-online.target";
          after = singleton "network-online.target";
          unitConfig.RequiresMountsFor = singleton config.nc.nixos.hermes.home;
          startLimitIntervalSec = 0;
          restartTriggers = singleton config.environment.etc."hermes/config.yaml".source;

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
