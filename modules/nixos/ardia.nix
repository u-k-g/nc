{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.meta) getExe getExe';
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;
  inherit (lib.strings) escapeShellArg;

  user = config.nc.user;
  home = user.homeDirectory;
  stateDir = "${home}/.local/state/nc";
  installDir = "${home}/.local/share/ardia";
  current = "${installDir}/current";
  ardia = "${current}/ardia/bin/ardia";

  browseExtensionId = "mfnicocicmmlkpjnaffgihfjhdgjkdjg";
  browseCrxUrl = "https://clients2.google.com/service/update2/crx";

  # The nix-ld set on this host was tuned for chrome-headless-shell; the GUI
  # Chromium build also needs text shaping and a software GL stack.
  guiLibraries = with pkgs; [
    fontconfig
    freetype
    harfbuzz
    mesa
  ];
in
{
  options.nc.nixos.ardia = {
    enable = mkEnableOption "the Ardia nightly browser in a cage kiosk, for browse";
  };

  config = mkIf config.nc.nixos.ardia.enable {
    # The browse extension installs itself from the Web Store through the
    # force-list, so agents find a paired-capable browser without a click.
    # If Ardia ignores this policy directory, the fallback is building the
    # extension from the browse source and passing --load-extension to the
    # browser.
    environment.etc."chromium/policies/managed/browse.json".text =
      builtins.toJSON
        {
          ExtensionInstallForcelist = [ "${browseExtensionId};${browseCrxUrl}" ];
        };

    programs.nix-ld.libraries = guiLibraries;

    home.users.${user.name} = {
      files.".local/bin/ardia".source = pkgs.writeShellScript "ardia" ''
        exec ${ardia} "$@"
      '';

      files.".local/share/applications/ardia.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Ardia
        Exec=${home}/.local/bin/ardia
        Icon=web-browser
        Terminal=false
        Categories=Network;WebBrowser;
      '';
    };

    # Install the newest nightly during activation. A failed download keeps
    # the installed version, the same way the OpenCode activation script
    # does. Pairing the browse extension stays a one-time manual step:
    # `browse pair` over ssh, then the code through wayvnc.
    nc.userActivationScripts.ardia-nightly = /* bash */ ''
      (
        set -euo pipefail

        install_dir=${escapeShellArg installDir}
        state_file=${escapeShellArg "${stateDir}/ardia-nightly-version"}
        current="$install_dir/current"

        ${pkgs.coreutils}/bin/mkdir --parents "$install_dir" ${escapeShellArg stateDir}

        release="$(
          ${getExe pkgs.curl} --fail --silent --show-error \
            'https://api.github.com/repos/ardia-browser/ardia/releases?per_page=30' \
          | ${getExe pkgs.jq} -r '
              [ .[]
                | select(.prerelease)
                | select(any(.assets[]; (.name | endswith("-linux-x64.tar.xz"))))
                | { tag: .tag_name
                  , url: (first(.assets[] | select((.name | endswith("-linux-x64.tar.xz")))
                      | .browser_download_url))
                }][0]
              | if . == null then empty else "\(.tag) \(.url)" end
            '
        )"

        if [ -z "$release" ]; then
          if [ -x "$current/ardia/bin/ardia" ]; then
            printf 'warning: no Ardia nightly release found; keeping the installed version\n' >&2
            exit 0
          fi
          printf 'error: no Ardia nightly release found and none is installed\n' >&2
          exit 1
        fi

        tag="''${release%% *}"
        url="''${release#* }"
        version="''${tag#v}"

        if [ -x "$current/ardia/bin/ardia" ] \
          && [ -f "$state_file" ] \
          && [ "$(<"$state_file")" = "$version" ]; then
          printf 'Ardia nightly %s is already installed\n' "$version"
          exit 0
        fi

        temp_dir="$(${pkgs.coreutils}/bin/mktemp --directory -t ardia.XXXXXXXXXX)"
        trap '${pkgs.coreutils}/bin/rm -rf "$temp_dir"' EXIT
        name="Ardia-''${version}-linux-x64.tar.xz"

        if ! (
          ${getExe pkgs.curl} --fail --location --silent --show-error --retry 3 \
            "$url" --output "$temp_dir/$name"
          ${getExe pkgs.curl} --fail --location --silent --show-error --retry 3 \
            "$url.sha256" --output "$temp_dir/$name.sha256"
          (
            cd "$temp_dir"
            ${pkgs.coreutils}/bin/sha256sum --check "$name.sha256" >/dev/null
          )
          ${pkgs.coreutils}/bin/rm -rf "$install_dir/$version.new"
          ${pkgs.coreutils}/bin/mkdir --parents "$install_dir/$version.new"
          ${getExe pkgs.gnutar} --extract \
            --use-compress-program=${getExe' pkgs.xz "xz"} \
            --file "$temp_dir/$name" \
            --directory "$install_dir/$version.new"
          ${pkgs.coreutils}/bin/rm -rf "$install_dir/$version"
          ${pkgs.coreutils}/bin/mv "$install_dir/$version.new" "$install_dir/$version"
          ${pkgs.coreutils}/bin/ln --symbolic --force --no-dereference \
            "$install_dir/$version" "$current"
          printf '%s' "$version" > "$state_file.new"
          ${pkgs.coreutils}/bin/mv --force "$state_file.new" "$state_file"
        ); then
          ${pkgs.coreutils}/bin/rm -rf "$install_dir/$version.new"
          if [ -x "$current/ardia/bin/ardia" ]; then
            printf 'warning: failed to install Ardia %s; keeping the installed version\n' "$version" >&2
            exit 0
          fi
          printf 'error: failed to install Ardia %s and none is installed\n' "$version" >&2
          exit 1
        fi

        printf 'Installed Ardia nightly %s\n' "$version"
      )
    '';

    # cage is a kiosk compositor that exists only to host the browser: it
    # boots with the machine, needs no display, seat, greeter or login, and
    # restarts on failure. wayvnc rides inside cage so it inherits the
    # compositor's Wayland socket and serves the screen on loopback.
    systemd.user.services.ardia = {
      description = "Ardia browser in a cage kiosk compositor";
      wantedBy = [ "default.target" ];
      environment = {
        WLR_BACKENDS = "headless";
        WLR_RENDERER = "pixman";
        WLR_LIBINPUT_NO_DEVICES = "1";
        # The lingered user manager at boot has no shell session, so the
        # nix-ld variables are passed explicitly, the same way the t3 service
        # receives its environment.
        NIX_LD = config.environment.sessionVariables.NIX_LD;
        NIX_LD_LIBRARY_PATH = config.environment.sessionVariables.NIX_LD_LIBRARY_PATH;
      };
      serviceConfig = {
        Type = "simple";
        # The client runs through an absolute shell path because the systemd
        # user environment has no shell on PATH, and native Wayland because
        # cosmic's own Xwayland owns display :0.
        ExecStart = pkgs.writeShellScript "ardia-kiosk" ''
          exec ${getExe pkgs.cage} -- ${pkgs.runtimeShell} -c '${getExe pkgs.wayvnc} 127.0.0.1 5900 & exec ${ardia} --no-first-run --ozone-platform=wayland'
        '';
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
