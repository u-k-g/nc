{ self, ... }:

{
  flake.nixosModules.hermes-local-tools =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets) genAttrs;
      inherit (lib.generators) toJSON;
      inherit (lib.lists) singleton;
      inherit (lib.meta) getExe getExe';
      inherit (lib.modules) mkAfter mkIf;
      inherit (lib.options) mkEnableOption mkOption;
      inherit (lib.strings) escapeShellArgs makeBinPath;
      inherit (lib.types) package port;

      searchSettings =
        pkgs.writeText "searxng-settings.json"
        <| toJSON { } {
          use_default_settings = true;
          server = {
            bind_address = "127.0.0.1";
            port = config.nc.nixos.hermes.local-tools.searchPort;
            limiter = false;
            image_proxy = false;
          };
          search = {
            safe_search = 0;
            autocomplete = "duckduckgo";
            formats = [
              "html"
              "json"
            ];
          };
        };

      initializeSearch = pkgs.writers.writePython3 "searxng-settings" { } /* python */ ''
        import json
        import os
        import pathlib
        import secrets
        import sys
        import tempfile

        state = pathlib.Path(sys.argv[2])
        state.mkdir(mode=0o700, parents=True, exist_ok=True)
        key = state / "secret-key"
        if not key.exists():
            with open(
                key, "x", opener=lambda path, flags: os.open(path, flags, 0o600)
            ) as stream:
                stream.write(secrets.token_hex(32))
        settings = json.loads(pathlib.Path(sys.argv[1]).read_text())
        settings["server"]["secret_key"] = key.read_text().strip()
        fd, temporary = tempfile.mkstemp(dir=state)
        with os.fdopen(fd, "w") as stream:
            json.dump(settings, stream)
        os.replace(temporary, state / "settings.json")
      '';
    in
    {
      options.nc.nixos.hermes.local-tools = {
        enable = mkEnableOption "Nix-managed Hermes search, browser and COSMIC tools";
        browserPackage = mkOption {
          type = package;
          default = self.packages.${pkgs.stdenv.hostPlatform.system}.browser-use;
          description = "Locked browser-use CLI environment.";
        };
        computerUsePackage = mkOption {
          type = package;
          default = self.packages.${pkgs.stdenv.hostPlatform.system}.computer-use-linux;
          description = "Pinned computer-use-linux binaries.";
        };
        searchPackage = mkOption {
          type = package;
          default = pkgs.searxng;
          description = "SearXNG package for local Hermes search.";
        };
        searchPort = mkOption {
          type = port;
          default = 8888;
          description = "Loopback SearXNG port.";
        };
      };

      config = mkIf (config.nc.nixos.hermes.enable && config.nc.nixos.hermes.local-tools.enable) {
        nc.nixos.hermes.settings = {
          web.search_backend = "searxng";
          browser.cdp_url = "http://127.0.0.1:${toString config.nc.nixos.hermes.browser-cdp.port}";
          mcp_servers.computer-use-linux = {
            command = getExe config.nc.nixos.hermes.local-tools.computerUsePackage;
            env.COMPUTER_USE_LINUX_COSMIC_HELPER = getExe' config.nc.nixos.hermes.local-tools.computerUsePackage "computer-use-linux-cosmic";
            env.PATH = "${
              makeBinPath [
                pkgs.wtype
                pkgs.systemd
                pkgs.glib
              ]
            }:/run/current-system/sw/bin";
          };
        };

        environment.etc."hermes/.env".text = mkAfter ''
          SEARXNG_URL=http://127.0.0.1:${toString config.nc.nixos.hermes.local-tools.searchPort}
        '';

        systemd.services = genAttrs [ "hermes" "hermes-gateway" ] (_: {
          path = singleton config.nc.nixos.hermes.local-tools.browserPackage;
          environment.SEARXNG_URL = "http://127.0.0.1:${toString config.nc.nixos.hermes.local-tools.searchPort}";
        });

        home.users.${config.nc.user.name} = {
          packages = [
            config.nc.nixos.hermes.local-tools.browserPackage
            config.nc.nixos.hermes.local-tools.computerUsePackage
            pkgs.wtype
          ];

          # Replace the old uv entrypoints, including Hermes' preferred bin
          # directory, so a mutable installation cannot shadow the package.
          files =
            genAttrs
              [
                ".local/bin/browser"
                ".local/bin/browser-use"
                ".local/bin/browseruse"
                ".local/bin/bu"
              ]
              (_: {
                source = getExe' config.nc.nixos.hermes.local-tools.browserPackage "browser-use";
              })
            // {
              "hermes-browser-use" = {
                relativeTo = config.nc.nixos.hermes.home;
                target = "bin/browser-use";
                source = getExe' config.nc.nixos.hermes.local-tools.browserPackage "browser-use";
              };
              ".local/bin/browser-use-tui".source =
                getExe' config.nc.nixos.hermes.local-tools.browserPackage "browser-use-tui";
              ".local/bin/computer-use-linux".source =
                getExe config.nc.nixos.hermes.local-tools.computerUsePackage;
              ".local/bin/computer-use-linux-cosmic".source =
                getExe' config.nc.nixos.hermes.local-tools.computerUsePackage "computer-use-linux-cosmic";
            };

          # Hjem owns the same ~/.config/systemd/user/searxng.service and
          # enablement link that were previously created by Hermes.
          systemd.services.searxng = {
            description = "SearXNG metasearch for Hermes (loopback only)";
            wantedBy = singleton "default.target";
            after = singleton "network.target";
            restartTriggers = [
              config.nc.nixos.hermes.local-tools.searchPackage
              searchSettings
              initializeSearch
            ];
            environment.SEARXNG_SETTINGS_PATH = "%h/.local/state/searxng/settings.json";

            serviceConfig = {
              ExecStartPre = escapeShellArgs [
                "${initializeSearch}"
                "${searchSettings}"
                "%h/.local/state/searxng"
              ];
              ExecStart = getExe config.nc.nixos.hermes.local-tools.searchPackage;
              Restart = "on-failure";
              RestartSec = 3;
              UMask = "0077";
            };
          };
        };
      };
    };
}
