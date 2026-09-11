{ ... }:
{
  commonModules.syncthing =
    { config, lib, ... }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.options) mkEnableOption mkOption;
      inherit (lib.types)
        attrsOf
        bool
        listOf
        nullOr
        str
        submodule
        ;
    in
    {
      options.nc.syncthing = {
        enable = mkEnableOption "vault synchronization";

        vaultPath = mkOption {
          type = str;
          default = "${config.nc.user.homeDirectory}/Documents/vault";
          description = "Writable vault directory, outside the Nix store.";
        };

        stateDirectory = mkOption {
          type = str;
          default = "${config.nc.user.homeDirectory}/.local/state/syncthing";
          description = "Persistent private identity, configuration and database directory.";
        };

        tailnetOnly = mkOption {
          type = bool;
          default = false;
          description = "Also disable LAN discovery and bind only to tailnet addresses.";
        };

        devices = mkOption {
          default = { };
          description = "Shared device registry. Fill in IDs after each device's first start.";
          type =
            attrsOf
            <| submodule {
              options = {
                id = mkOption {
                  type = nullOr str;
                  default = null;
                  description = "Public Syncthing device ID; null until enrolled.";
                };
                addresses = mkOption {
                  type = listOf str;
                  default = [ ];
                  description = "Explicit sync addresses, normally tailnet IPs.";
                };
              };
            };
        };
      };

      config.nc.syncthing.devices = {
        manara.addresses = singleton "tcp://100.96.29.81:22000";
        darwinbook.addresses = singleton "tcp://100.93.128.84:22000";
        phone.addresses = singleton "tcp://100.78.224.36:22000";
      };
    };

  flake.nixosModules.syncthing =
    { config, lib, ... }:
    let
      inherit (lib.attrsets) attrNames filterAttrs mapAttrs;
      inherit (lib.lists) optional singleton;
      inherit (lib.modules) mkIf;
      cfg = config.nc.syncthing;
      peers = filterAttrs (
        name: device: name != config.networking.hostName && device.id != null
      ) cfg.devices;
    in
    {
      services.syncthing = mkIf cfg.enable {
        enable = true;
        user = config.nc.user.name;
        group = config.users.users.${config.nc.user.name}.group;
        dataDir = config.nc.user.homeDirectory;
        configDir = cfg.stateDirectory;
        databaseDir = cfg.stateDirectory;
        guiAddress = "127.0.0.1:8384";
        openDefaultPorts = false;
        overrideDevices = false;
        overrideFolders = false;
        settings = {
          devices = mapAttrs (_: device: {
            inherit (device) id;
            addresses = device.addresses ++ optional (!cfg.tailnetOnly) "dynamic";
          }) peers;
          folders.notes = {
            path = cfg.vaultPath;
            label = "Vault";
            devices = attrNames peers;
            type = "sendreceive";
            ignorePerms = true;
            fsWatcherEnabled = true;
            versioning = {
              type = "staggered";
              params.maxAge = "31536000";
            };
          };
          options = {
            listenAddresses =
              if cfg.tailnetOnly then
                cfg.devices.${config.networking.hostName}.addresses
              else
                singleton "tcp://:22000";
            globalAnnounceEnabled = false;
            localAnnounceEnabled = !cfg.tailnetOnly;
            relaysEnabled = false;
            natEnabled = false;
            urAccepted = -1;
            crashReportingEnabled = false;
          };
        };
      };

      networking.firewall.interfaces.tailscale0.allowedTCPPorts = mkIf cfg.enable <| singleton 22000;
      networking.firewall.allowedTCPPorts = mkIf (cfg.enable && !cfg.tailnetOnly) <| singleton 22000;
      networking.firewall.allowedUDPPorts = mkIf (cfg.enable && !cfg.tailnetOnly) <| singleton 21027;
    };

  flake.darwinModules.syncthing =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets) filterAttrs;
      inherit (lib.lists) singleton;
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkIf;
      inherit (lib.strings) toJSON;
      cfg = config.nc.syncthing;
      # Configure the writable XML before exec, while this agent's daemon is stopped.
      # Keep generated keys, GUI credentials and unrelated folders intact.
      launcher = pkgs.writeText "syncthing-vault.py" /* python */ ''
        import json
        import os
        from pathlib import Path
        import subprocess
        import xml.etree.ElementTree as ET

        settings = json.loads(${
          toJSON
          <| toJSON {
            inherit (cfg) vaultPath stateDirectory tailnetOnly;
            devices = filterAttrs (
              name: device: name != config.networking.hostName && device.id != null
            ) cfg.devices;
            addresses = cfg.devices.${config.networking.hostName}.addresses;
          }
        })
        binary = "${getExe pkgs.syncthing}"
        os.umask(0o077)
        state = Path(settings["stateDirectory"])
        state.mkdir(parents=True, exist_ok=True)
        path = state / "config.xml"
        if not path.exists():
            subprocess.run([binary, "generate", "--home", str(state)], check=True)
        tree = ET.parse(path)
        root = tree.getroot()

        def element(parent, tag, **attrs):
            for child in parent.findall(tag):
                if all(child.get(k) == v for k, v in attrs.items()):
                    return child
            return ET.SubElement(parent, tag, attrs)

        def value(parent, tag, text):
            element(parent, tag).text = str(text)

        gui = element(root, "gui")
        value(gui, "address", "127.0.0.1:8384")
        options = element(root, "options")
        enabled = "false" if settings["tailnetOnly"] else "true"
        value(options, "localAnnounceEnabled", enabled)
        for name in ("globalAnnounceEnabled", "relaysEnabled", "natEnabled"):
            value(options, name, "false")
        for node in options.findall("listenAddress"):
            options.remove(node)
        for address in settings["addresses"] if settings["tailnetOnly"] else ["tcp://:22000"]:
            ET.SubElement(options, "listenAddress").text = address
        value(options, "startBrowser", "false")
        value(options, "urAccepted", -1)
        value(options, "crashReportingEnabled", "false")
        value(options, "autoUpgradeIntervalH", 0)

        folder = element(root, "folder", id="notes")
        folder.attrib.update(path=settings["vaultPath"], label="Vault", type="sendreceive",
                             ignorePerms="true", fsWatcherEnabled="true", rescanIntervalS="3600")
        # Folder membership is authoritative, matching the NixOS module.
        for node in folder.findall("device"):
            folder.remove(node)
        for name, peer in settings["devices"].items():
            device = element(root, "device", id=peer["id"])
            device.set("name", name)
            for node in device.findall("address"):
                device.remove(node)
            addresses = peer["addresses"] + ([] if settings["tailnetOnly"] else ["dynamic"])
            for address in addresses:
                ET.SubElement(device, "address").text = address
            ET.SubElement(folder, "device", id=peer["id"])

        temporary = path.with_suffix(".xml.tmp")
        tree.write(temporary, encoding="utf-8", xml_declaration=True)
        os.replace(temporary, path)
        os.environ["STNOUPGRADE"] = "1"
        os.environ["STNORESTART"] = "1"
        os.execv(binary, [binary, "serve", "--home", str(state), "--no-browser"])
      '';
    in
    {
      environment.systemPackages = mkIf cfg.enable <| singleton pkgs.syncthing;

      launchd.user.agents.syncthing = mkIf cfg.enable {
        serviceConfig = {
          ProgramArguments = [
            (getExe pkgs.python3)
            "${launcher}"
          ];
          RunAtLoad = true;
          KeepAlive = true;
          ThrottleInterval = 10;
          ProcessType = "Background";
          StandardOutPath = "${config.nc.user.homeDirectory}/Library/Logs/syncthing.log";
          StandardErrorPath = "${config.nc.user.homeDirectory}/Library/Logs/syncthing.log";
        };
      };
    };
}
