{ inputs, ... }:
{
  flake.nixosModules.arura =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets) mapAttrs';
      inherit (lib.lists) singleton;
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkForce mkIf mkMerge;
      inherit (lib.options) mkEnableOption mkOption;
      inherit (lib.strings) escapeShellArg escapeShellArgs;
      inherit (lib.types) port;
    in
    {
      imports = singleton inputs.arura.nixosModules.default;

      options.nc.nixos.arura = {
        enable = mkEnableOption "Arura alongside the existing Hermes web client";
        httpsPort = mkOption {
          type = port;
          default = 8444;
        };
        convexHttpsPort = mkOption {
          type = port;
          default = 8445;
        };
      };

      config = {
        assertions =
          mkIf config.nc.nixos.arura.enable
          <| singleton {
            assertion = config.nc.nixos.hermes.enable;
            message = "Arura requires the existing nc Hermes dashboard.";
          };

        services.arura = mkIf config.nc.nixos.arura.enable {
          enable = true;
          publicUrl = "https://${config.nc.nixos.hermes.hostname}:${toString config.nc.nixos.arura.httpsPort}";
          convexPublicUrl = "https://${config.nc.nixos.hermes.hostname}:${toString config.nc.nixos.arura.convexHttpsPort}";
          # The same dashboard used by hermes-web: no second Hermes home or DB.
          hermesUrl = "http://127.0.0.1:${toString config.nc.nixos.hermes.port}";
          environmentFile = "/var/lib/arura-credentials/arura.env";
          convexEnvironmentFile = "/var/lib/arura-credentials/convex.env";
        };

        systemd.services = mkMerge [
          {
            arura-initialize = mkIf config.nc.nixos.arura.enable {
              description = "Initialize persistent Arura credentials and reuse Hermes dashboard access";
              requires = singleton "hermes.service";
              after = singleton "hermes.service";
              environment.CONVEX_EXECUTABLE = getExe config.services.arura.convexPackage;
              before = [
                "arura.service"
                "arura-convex.service"
              ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                StateDirectory = "arura-credentials";
                StateDirectoryMode = "0700";
                UMask = "0077";
                LoadCredential = singleton "dashboard.env:${config.nc.nixos.hermes.home}/dashboard.env";
                ExecStart =
                  getExe
                  <| pkgs.writers.writePython3Bin "arura-initialize" { } /* python */ ''
                    import json
                    import os
                    import pathlib
                    import secrets
                    import subprocess
                    import tempfile

                    root = pathlib.Path(os.environ["STATE_DIRECTORY"])


                    def write(name, value):
                        fd, temporary = tempfile.mkstemp(
                            prefix=".initialize-", dir=root
                        )
                        with os.fdopen(fd, "w") as stream:
                            stream.write(value)
                            stream.flush()
                            os.fsync(stream.fileno())
                        os.replace(temporary, root / name)


                    identity = root / "identity.json"
                    if not identity.exists():
                        write("identity.json", json.dumps({
                            "name": "arura-" + secrets.token_hex(8),
                            "secret": secrets.token_hex(32),
                            "access": secrets.token_urlsafe(32),
                        }))
                    state = json.loads(identity.read_text())
                    result = subprocess.run([
                        os.environ["CONVEX_EXECUTABLE"], "keygen", "admin-key",
                        "--instance-name", state["name"],
                        "--instance-secret", state["secret"],
                    ], capture_output=True, text=True)
                    if result.returncode:
                        raise SystemExit("Could not derive Convex administrator key")
                    credentials = (
                        pathlib.Path(os.environ["CREDENTIALS_DIRECTORY"])
                        / "dashboard.env"
                    )
                    dashboard = dict(
                        line.split("=", 1)
                        for line in credentials.read_text().splitlines()
                        if "=" in line
                    )
                    password = dashboard["HERMES_DASHBOARD_BASIC_AUTH_PASSWORD"]
                    write("convex.env", "CONVEX_INSTANCE_NAME=" + state["name"] + "\n"
                          + "CONVEX_INSTANCE_SECRET=" + state["secret"] + "\n")
                    write("arura.env", "ARURA_ACCESS_KEY=" + state["access"] + "\n"
                          + "CONVEX_SELF_HOSTED_ADMIN_KEY=" + result.stdout.strip() + "\n"
                          + "HERMES_USERNAME=${config.nc.user.name}\n"
                          + "HERMES_PASSWORD=" + password + "\n")
                  '';
              };
            };

            arura = mkIf config.nc.nixos.arura.enable {
              requires = singleton "arura-initialize.service";
              after = [
                "arura-initialize.service"
                "hermes.service"
              ];
            };
            arura-convex = mkIf config.nc.nixos.arura.enable {
              requires = singleton "arura-initialize.service";
              after = singleton "arura-initialize.service";
              # The pinned Arura module omits the backend's required site origin.
              # Remove this override after updating to the fixed Arura release.
              serviceConfig.ExecStart = mkForce "${getExe config.services.arura.convexPackage} --interface 127.0.0.1 --port ${toString config.services.arura.convexPort} --site-proxy-port ${toString config.services.arura.convexSitePort} --convex-origin ${escapeShellArg config.services.arura.convexPublicUrl} --convex-site ${escapeShellArg "${config.services.arura.convexPublicUrl}/http"} --instance-name \${CONVEX_INSTANCE_NAME} --instance-secret \${CONVEX_INSTANCE_SECRET} --disable-beacon --redact-logs-to-client";
            };

            # Each foreground Serve owns only its listener. Never reset T3 or Hermes.
          }
          (
            mkIf config.nc.nixos.arura.enable
            <|
              mapAttrs'
                (name: route: {
                  name = "${name}-serve";
                  value = {
                    description = "Publish ${name} on the tailnet";
                    wantedBy = singleton "multi-user.target";
                    after = [
                      "tailscaled.service"
                      "${name}.service"
                    ];
                    wants = [
                      "tailscaled.service"
                      "${name}.service"
                    ];
                    startLimitIntervalSec = 0;
                    serviceConfig = {
                      ExecStart = escapeShellArgs [
                        (getExe pkgs.tailscale)
                        "serve"
                        "--yes"
                        "--https=${toString route.httpsPort}"
                        "http://127.0.0.1:${toString route.port}"
                      ];
                      Restart = "always";
                      RestartSec = 5;
                    };
                  };
                })
                {
                  arura = {
                    inherit (config.services.arura) port;
                    httpsPort = config.nc.nixos.arura.httpsPort;
                  };
                  arura-convex = {
                    port = config.services.arura.convexPort;
                    httpsPort = config.nc.nixos.arura.convexHttpsPort;
                  };
                }
          )
        ];
      };
    };
}
