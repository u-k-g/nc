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
      inherit (lib.attrsets) recursiveUpdate;
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

        settings = mkOption {
          type = (pkgs.formats.json { }).type;
          default = { };
          description = "Host-specific managed Hermes settings merged over the shared defaults.";
        };

        package = mkOption {
          type = package;
          default =
            inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs
              (old: {
                postInstall = (old.postInstall or "") + ''
                  plugin_source=$(readlink "$out/share/hermes-agent/plugins")
                  rm "$out/share/hermes-agent/plugins"
                  cp -rL "$plugin_source" "$out/share/hermes-agent/plugins"
                  chmod u+w "$out/share/hermes-agent/plugins/model-providers/opencode-zen"
                  chmod u+w "$out/share/hermes-agent/plugins/model-providers/opencode-zen/__init__.py"
                  patch -p1 -d "$out/share/hermes-agent" -i ${pkgs.writeText "hermes-go-catalog-reasoning.patch" ''
                    diff --git a/plugins/model-providers/opencode-zen/__init__.py b/plugins/model-providers/opencode-zen/__init__.py
                    --- a/plugins/model-providers/opencode-zen/__init__.py
                    +++ b/plugins/model-providers/opencode-zen/__init__.py
                    @@ -103,4 +103,22 @@ class OpenCodeGoProfile(ProviderProfile):
                                 return re_.thinking_toggle_extras(reasoning_config, re_.KIMI_K2_EFFORTS)
                             if _is_deepseek_thinking_model(model):
                                 return re_.thinking_toggle_extras(reasoning_config, re_.DEEPSEEK_V4_EFFORTS, re_.DEEPSEEK_V4_OVERRIDES)
                    +        # Follow the same models.dev effort options used by OpenCode's picker.
                    +        # A catalog miss is refreshed on demand so newly added Go models work
                    +        # even when Hermes has an older on-disk catalog at startup.
                    +        effort = re_.requested_effort(reasoning_config)
                    +        if effort:
                    +            from agent.models_dev import _find_model_entry, fetch_models_dev
                    +
                    +            catalog = fetch_models_dev(allow_network=False)
                    +            models = catalog.get("opencode-go", {}).get("models", {})
                    +            entry = _find_model_entry(models, model, "opencode-go")
                    +            if entry is None:
                    +                catalog = fetch_models_dev(force_refresh=True)
                    +                models = catalog.get("opencode-go", {}).get("models", {})
                    +                entry = _find_model_entry(models, model, "opencode-go")
                    +            if entry:
                    +                for option in entry.get("reasoning_options", []):
                    +                    if option.get("type") == "effort" and effort in option.get("values", []):
                    +                        return {}, {"reasoning_effort": effort}
                             return {}, {}
                  ''}
                  mkdir -p "$out/share/hermes-agent/python-overlay"
                  provider_source=$(${old.passthru.hermesVenv}/bin/python3 -c 'import providers; print(providers.__file__)')
                  cp -rL "$(dirname "$provider_source")" "$out/share/hermes-agent/python-overlay/providers"
                  ln -s ../plugins "$out/share/hermes-agent/python-overlay/plugins"
                  site_packages=$(dirname "$(dirname "$provider_source")")
                  cp -rL "$site_packages/agent" "$out/share/hermes-agent/python-overlay/agent"
                  cp -rL "$site_packages/tools" "$out/share/hermes-agent/python-overlay/tools"
                  cp -rL "$site_packages/hermes_cli" "$out/share/hermes-agent/python-overlay/hermes_cli"
                  # Hermes puts the directory containing hermes_cli at the front
                  # of sys.path during startup. Keep that root in the overlay so
                  # the patched agent and tools modules win in real CLI turns.
                  source_root=$(realpath "$site_packages")
                  for source_entry in "$source_root"/*; do
                    target="$out/share/hermes-agent/python-overlay/$(basename "$source_entry")"
                    if [ ! -e "$target" ] && [ ! -L "$target" ]; then
                      ln -s "$source_entry" "$target"
                    fi
                  done
                  chmod u+w "$out/share/hermes-agent/python-overlay/hermes_cli"
                  chmod u+w "$out/share/hermes-agent/python-overlay/agent"
                  chmod u+w "$out/share/hermes-agent/python-overlay/tools"
                  chmod u+w "$out/share/hermes-agent/python-overlay/agent/tool_executor.py"
                  chmod u+w "$out/share/hermes-agent/python-overlay/agent/turn_context.py"
                  chmod u+w "$out/share/hermes-agent/python-overlay/agent/models_dev.py"
                  chmod u+w "$out/share/hermes-agent/python-overlay/agent/image_routing.py"
                  chmod u+w "$out/share/hermes-agent/python-overlay/tools/vision_tools.py"
                  patch -p1 -d "$out/share/hermes-agent/python-overlay" -i ${../packages/hermes-image-bridge.patch}
                  for command in hermes hermes-agent hermes-acp; do
                    wrapProgram "$out/bin/$command" --prefix PYTHONPATH : "$out/share/hermes-agent/python-overlay"
                  done
                '';
              });
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

        webTheme = mkOption {
          type = package;
          default = pkgs.callPackage ../packages/hermes-desktop-web-theme.nix {
            theme = config.nc.theme;
            src = inputs.hermes-desktop-web;
          };
          description = "Public Hermes theme data and fonts generated from the active themenix theme.";
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
          <| toJSON { }
          <| recursiveUpdate {
            # Hermes discovers profiles and manages their bots and cron jobs at runtime.
            gateway.multiplex_profiles = true;

            dashboard.public_url = "https://${config.nc.nixos.hermes.hostname}:${toString config.nc.nixos.hermes.httpsPort}";

            # Machine wiring — services this install depends on.
            web.backend = "searxng";
            browser.backend = "browser-use";
            browser.cdp_url = "http://127.0.0.1:9333";
            computer_use.backend = "cua";
            # The sealed env has no pip, so wake.start(gui) cannot install
            # openwakeword and fills errors.log on every arm attempt.
            wake_word.enabled = false;
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
          } config.nc.nixos.hermes.settings;

        # write_file/patch sandbox: sessions may only create or modify files in
        # Hermes' own home and /var/tmp; every other path is denied for the file
        # tools. Managed scope keeps the agent from relaxing it. Terminal and
        # kernel writes into the flake are blocked at the syscall level by the
        # read-only mounts on the services below.
        environment.etc."hermes/.env".text =
          mkIf config.nc.nixos.hermes.enable
          <| ''
            HERMES_WRITE_SAFE_ROOT=${config.nc.user.homeDirectory}/.hermes:/var/tmp
          '';

        # One system gateway runs as the configured user, independently of login.
        # Multiplexing lets Hermes discover profile changes and tick each profile's
        # cron store without per-profile Nix declarations or installed user units.
        # /etc/hermes supplies the managed overlay for profile-local configuration.
        # The gateway and its children share the dashboard's read-only flake mount.
        # This gateway also owns kanban dispatch; remove hand-installed gateways
        # during cutover so they cannot compete for bot connections or its global
        # dispatcher lock (the gateway single-instance lock is per Hermes home).
        systemd.services.hermes-gateway = mkIf config.nc.nixos.hermes.enable {
          description = "Hermes Agent gateway (all profiles, cron and messaging)";
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
            EnvironmentFile = singleton "-${config.nc.nixos.hermes.home}/dashboard.env";
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
              "DENO_DIR=/var/tmp/hermes-deno"
            ];
            ExecStart = escapeShellArgs [
              (getExe pkgs.deno)
              "run"
              "--no-config"
              "--no-lock"
              "--cached-only"
              "--no-check"
              "--allow-net=127.0.0.1:${toString config.nc.nixos.hermes.port},127.0.0.1:${toString config.nc.nixos.hermes.webPort}"
              "--allow-read=${config.nc.nixos.hermes.webPackage}/share/hermes-desktop-web,${config.nc.nixos.hermes.webTheme}"
              (pkgs.writeText "hermes-web.ts" /* typescript */ ''
                import { createProxyHandler } from "${config.nc.nixos.hermes.webPackage}/share/hermes-desktop-web/proxy/main.ts";

                const publicUrl = new URL("https://${config.nc.nixos.hermes.hostname}:${toString config.nc.nixos.hermes.httpsPort}");
                const gateway = "http://127.0.0.1:${toString config.nc.nixos.hermes.port}";
                const handler = createProxyHandler({
                  webDist: "${config.nc.nixos.hermes.webPackage}/share/hermes-desktop-web/dist/",
                  themeDist: "${config.nc.nixos.hermes.webTheme}/",
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
