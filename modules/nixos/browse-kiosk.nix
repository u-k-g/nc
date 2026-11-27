{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.meta) getExe getExe';
  inherit (lib.modules) mkIf mkForce;
  inherit (lib.options) mkEnableOption;
  inherit (lib.strings) escapeShellArg;

  user = config.nc.user;
  home = user.homeDirectory;
  stateDir = "${home}/.local/state/nc";
  extensionDir = "${home}/.cache/browse/extension";
  profileDir = "${home}/.local/share/browse-kiosk-profile";

  # The niri and apps modules already take it this way.
  heliumBrowser = inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.helium-widevine;

  # The browse dev-channel extension zip carries a manifest key, so it loads
  # unpacked with the pinned id the relay already allowlists; the stable zip
  # has no key and would get a path-derived id the relay refuses.
  extensionManifest = "https://anoma.ly/release/browse/extension/dev.json";

  guiLibraries = with pkgs; [
    fontconfig
    freetype
    harfbuzz
    mesa
  ];
in
{
  options.nc.nixos.browse-kiosk = {
    enable = mkEnableOption "the Helium browser in a headless sway kiosk, with the browse extension";
  };

  config = mkIf config.nc.nixos.browse-kiosk.enable {
    programs.nix-ld.libraries = guiLibraries;

    # Install the newest dev-channel extension. A failed download keeps the
    # installed extension, the same way the other activation scripts do.
    nc.userActivationScripts.browse-kiosk = /* bash */ ''
      (
        set -euo pipefail

        extension_dir=${escapeShellArg extensionDir}
        state_file=${escapeShellArg "${stateDir}/browse-extension-version"}

        ${pkgs.coreutils}/bin/mkdir --parents "$extension_dir" ${escapeShellArg stateDir}

        release="$(
          ${getExe pkgs.curl} --fail --silent --show-error \
            ${escapeShellArg extensionManifest} \
          | ${getExe pkgs.jq} -r '
              .release
              | "\(.version) \(.targets.chromium.sha256) \(.targets.chromium.url)"
            '
        )"

        if [ -z "$release" ]; then
          if [ -f "$state_file" ]; then
            printf 'warning: no browse extension release found; keeping the installed one\n' >&2
            exit 0
          fi
          printf 'error: no browse extension release found and none is installed\n' >&2
          exit 1
        fi

        read -r version sum url <<<"$release"

        if [ -f "$state_file" ] && [ "$(<"$state_file")" = "$version" ]; then
          printf 'browse extension %s is already installed\n' "$version"
        else
          temp_dir="$(${pkgs.coreutils}/bin/mktemp --directory -t browse-ext.XXXXXXXXXX)"
          trap '${pkgs.coreutils}/bin/rm -rf "$temp_dir"' EXIT

          ${getExe pkgs.curl} --fail --location --silent --show-error --retry 3 \
            "https://anoma.ly$url" --output "$temp_dir/extension.zip"
          printf '%s  %s\n' "$sum" "$temp_dir/extension.zip" \
            | ${pkgs.coreutils}/bin/sha256sum --check --quiet

          staging="$temp_dir/unpacked"
          ${getExe' pkgs.unzip "unzip"} -q "$temp_dir/extension.zip" -d "$staging"

          # The zip unpacks into a top-level folder; the browser loads the
          # folder that holds manifest.json.
          manifest_dir="$(dirname "$(${pkgs.findutils}/bin/find "$staging" -name manifest.json -print -quit)")"
          if [ -z "$manifest_dir" ] || [ "$manifest_dir" = "." ]; then
            printf 'error: the extension zip has no manifest.json\n' >&2
            exit 1
          fi

          if [ -f "$extension_dir/manifest.json" ]; then
            ${pkgs.coreutils}/bin/mv "$extension_dir" "$temp_dir/old"
          fi
          ${pkgs.coreutils}/bin/mkdir --parents "$(dirname "$extension_dir")"
          ${pkgs.coreutils}/bin/mv "$manifest_dir" "$extension_dir"
          printf '%s' "$version" > "$state_file.new"
          ${pkgs.coreutils}/bin/mv --force "$state_file.new" "$state_file"
          printf 'Installed browse extension %s\n' "$version"
          # Chromium loads an unpacked extension only at startup, so a kiosk
          # that is already running (first boot races the activation script;
          # later updates land while it runs) has to restart to pick it up.
          ${getExe' pkgs.systemd "systemctl"} --user try-restart browse-kiosk.service || true
        fi
      )
    '';

    # sway runs headless as a one-window kiosk: it boots with the machine and
    # needs no display, seat, greeter or login. wlroots picks the GPU render
    # node on its own and falls back to pixman without one. sway, unlike cage,
    # has wlr-data-control, which wayvnc needs to sync the clipboard with VNC
    # viewers. wayvnc runs in a loop because it can crash on a client's
    # encoding request (neatvnc's raw encoder did on 2026-11-25) while the
    # browser keeps running. Closing Helium exits sway, and systemd restarts
    # the whole kiosk.
    systemd.user.services.browse-kiosk = {
      description = "Helium browser in a headless sway kiosk, with the browse extension";
      wantedBy = [ "default.target" ];
      environment = {
        WLR_BACKENDS = "headless";
        WLR_LIBINPUT_NO_DEVICES = "1";
        NIX_LD = config.environment.sessionVariables.NIX_LD;
        NIX_LD_LIBRARY_PATH = config.environment.sessionVariables.NIX_LD_LIBRARY_PATH;
      };
      # sway runs `exec` lines through sh, and the systemd user environment
      # has no shell on PATH.
      path = [ pkgs.bash ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${getExe pkgs.sway} --config ${pkgs.writeText "browse-kiosk-sway.conf" /* swayconfig */ ''
          output HEADLESS-1 resolution 1920x1080
          default_border none
          default_floating_border none
          xwayland disable
          for_window [app_id=".*"] fullscreen enable

          exec ${pkgs.writeShellScript "browse-kiosk-wayvnc" ''
            while :; do
              ${getExe pkgs.wayvnc} --render-cursor 127.0.0.1 5900
              ${getExe' pkgs.coreutils "sleep"} 1
            done
          ''}
          exec ${pkgs.writeShellScript "browse-kiosk-helium" ''
            ${getExe heliumBrowser} --user-data-dir=${profileDir} --no-first-run --load-extension=${extensionDir}
            ${getExe' pkgs.sway "swaymsg"} exit
          ''}
        ''}";
        Restart = "always";
        RestartSec = "5s";
      };
    };

    # noVNC in a browser tab: websockify serves the noVNC page and bridges its
    # WebSocket to wayvnc. It listens on every interface, and the firewall
    # admits it only on the trusted tailscale0, so the kiosk opens at
    # http://manara:6080/vnc.html from the tailnet.
    systemd.user.services.browse-kiosk-novnc = {
      description = "noVNC web client for the browse kiosk";
      wantedBy = [ "default.target" ];
      after = [ "browse-kiosk.service" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${getExe' pkgs.python3Packages.websockify "websockify"} --web ${pkgs.novnc}/share/webapps/novnc 0.0.0.0:6080 127.0.0.1:5900";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
