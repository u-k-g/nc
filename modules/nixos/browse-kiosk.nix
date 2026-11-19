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
  browse = "${home}/.local/share/pnpm/bin/browse";
  extensionDir = "${home}/.cache/browse/extension";

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
    enable = mkEnableOption "the Helium browser in a cage kiosk, paired with browse";
  };

  config = mkIf config.nc.nixos.browse-kiosk.enable {
    programs.nix-ld.libraries = guiLibraries;

    home.users.${user.name} = {
      # The browse relay treats the pairing code as secret material (it is
      # stored only as a slow hash), so keep the extension folder private.
      files.".cache/browse/extension/.keep".text = "";
    };

    # Install the newest dev-channel extension and, on a browser that has not
    # paired yet, mint a one-time code and leave it in the extension's folder:
    # the extension's service worker exchanges it for its own token during the
    # next relay handshake, with no person involved. A failed download keeps
    # the installed extension, the same way the other activation scripts do.
    nc.userActivationScripts.browse-kiosk = /* bash */ ''
      (
        set -euo pipefail

        extension_dir=${escapeShellArg extensionDir}
        state_file=${escapeShellArg "${stateDir}/browse-extension-version"}
        browse=${escapeShellArg browse}

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
          ${getExe' pkgs.unzip "unzip"} --quiet "$temp_dir/extension.zip" -d "$staging"

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
          systemctl --user try-restart browse-kiosk.service || true
        fi

        # Pairing: the relay keeps codes as slow hashes with a one-hour life
        # and burns each after one use, so a code in the folder is worth
        # nothing once the extension redeemed it. The token it gets back
        # persists in the browser profile, so this whole block is a no-op
        # after the first successful handshake.
        if "$browse" pair --list | ${getExe' pkgs.gnugrep "grep"} --quiet 'No paired browsers'; then
          code_line="$("$browse" pair --wait-seconds 1 || true)"
          code="$(printf '%s' "$code_line" | ${getExe' pkgs.gnugrep "grep"} --only-matching --extended-regexp '[A-HJKMNP-TV-Z0-9]{4}-[A-HJKMNP-TV-Z0-9]{4}' | head -1 || true)"
          if [ -n "$code" ]; then
            printf '{"code": "%s", "port": 19988}\n' "$code" > "$extension_dir/relay-pairing.json"
            printf 'Left a pairing code for the browse extension\n'
          else
            printf 'warning: could not mint a pairing code; the extension stays unpaired\n' >&2
          fi
        fi
      )
    '';

    # cage is a kiosk compositor that exists only to host the browser: it
    # boots with the machine, needs no display, seat, greeter or login, and
    # restarts on failure. wayvnc starts once the compositor's socket exists
    # and serves the screen on loopback for handoffs.
    systemd.user.services.browse-kiosk = {
      description = "Helium browser in a cage kiosk compositor, paired with browse";
      wantedBy = [ "default.target" ];
      environment = {
        WLR_BACKENDS = "headless";
        WLR_RENDERER = "pixman";
        WLR_LIBINPUT_NO_DEVICES = "1";
        NIX_LD = config.environment.sessionVariables.NIX_LD;
        NIX_LD_LIBRARY_PATH = config.environment.sessionVariables.NIX_LD_LIBRARY_PATH;
      };
      serviceConfig = {
        Type = "simple";
        # The client runs through an absolute shell path because the systemd
        # user environment has no shell on PATH.
        ExecStart = pkgs.writeShellScript "browse-kiosk" ''
          exec ${getExe pkgs.cage} -- ${pkgs.runtimeShell} -c '${getExe pkgs.wayvnc} 127.0.0.1 5900 & exec ${getExe heliumBrowser} --load-extension=${extensionDir}'
        '';
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
