{ ... }:
{
  flake.darwinModules.suzuri =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    let
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkIf;
      user = config.nc.user;

      suzuriDataDir = "${user.homeDirectory}/.local/share/suzuri";
      suzuriApp = "${suzuriDataDir}/Suzuri.app";
      suzuriState = "${user.homeDirectory}/.local/state/suzuri/source";
    in
    {
      home.users.${user.name} = {
        activationScripts.suzuri-latest =
          mkIf (config.networking.hostName == "darwinbook")
          <| ''
            (
              set -euo pipefail

              export CURL_CA_BUNDLE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt

              api='https://api.github.com/repos/harrywang/suzuri/releases/latest'
              suzuri_app=${lib.escapeShellArg suzuriApp}
              suzuri_data_dir=${lib.escapeShellArg suzuriDataDir}
              state_file=${lib.escapeShellArg suzuriState}
              new_app="$suzuri_data_dir/.Suzuri.app.new"
              old_app="$suzuri_data_dir/.Suzuri.app.old"

              ${pkgs.coreutils}/bin/mkdir --parents ${lib.escapeShellArg "${user.homeDirectory}/Applications"}
              ${pkgs.coreutils}/bin/ln --symbolic --force --no-dereference "$suzuri_app" ${lib.escapeShellArg "${user.homeDirectory}/Applications/Suzuri.app"}

              app_is_valid() {
                local app=$1
                local executable

                [ -f "$app/Contents/Info.plist" ] || return 1
                executable="$(/usr/bin/plutil -extract CFBundleExecutable raw "$app/Contents/Info.plist")" || return 1
                [ -x "$app/Contents/MacOS/$executable" ]
              }

              ${pkgs.coreutils}/bin/mkdir --parents "$suzuri_data_dir"
              if [ ! -e "$suzuri_app" ] && [ -e "$old_app" ]; then
                ${pkgs.coreutils}/bin/mv "$old_app" "$suzuri_app"
              fi
              ${pkgs.coreutils}/bin/rm -rf "$new_app"
              if [ -e "$suzuri_app" ]; then
                ${pkgs.coreutils}/bin/rm -rf "$old_app"
              fi

              release_probe="$suzuri_data_dir/.suzuri-release.json"
              if ${getExe pkgs.curl} --fail --location --silent --show-error --retry 3 "$api" --output "$release_probe"; then
                release="$(${getExe pkgs.jq} --compact-output '
                  [
                    select(.draft == false and .prerelease == false)
                    | select(.tag_name | test("^suzuri-v[0-9]+[.][0-9]+[.][0-9]+$")) as $release
                    | $release.assets[]
                    | select(.name | . == "suzuri-aarch64.dmg")
                    | {
                        asset_name: .name,
                        asset_url: .browser_download_url,
                        tag: $release.tag_name
                      }
                  ]
                  | first // {}
                ' "$release_probe")"
                ${pkgs.coreutils}/bin/rm -f "$release_probe"
                tag="$(printf '%s' "$release" | ${getExe pkgs.jq} --raw-output '.tag // empty')"
                asset_name="$(printf '%s' "$release" | ${getExe pkgs.jq} --raw-output '.asset_name // empty')"
                asset_url="$(printf '%s' "$release" | ${getExe pkgs.jq} --raw-output '.asset_url // empty')"
              else
                ${pkgs.coreutils}/bin/rm -f "$release_probe"
                if app_is_valid "$suzuri_app"; then
                  installed_version="$(/usr/bin/plutil \
                    -extract CFBundleShortVersionString raw \
                    "$suzuri_app/Contents/Info.plist")"
                  printf 'warning: failed to check latest Suzuri release; keeping installed app (bundle version %s)\n' "$installed_version" >&2
                  exit 0
                fi
                printf 'warning: failed to check latest Suzuri release; skipping Suzuri install\n' >&2
                exit 0
              fi

              if [ -z "$tag" ] || [ -z "$asset_name" ] || [ -z "$asset_url" ]; then
                printf 'error: failed to resolve the latest stable Suzuri Apple Silicon DMG from release metadata\n' >&2
                exit 1
              fi

              version="''${tag#suzuri-v}"
              state_value="$tag $asset_name $asset_url"
              if app_is_valid "$suzuri_app" \
                && [ -f "$state_file" ] \
                && [ "$(< "$state_file")" = "$state_value" ]; then
                printf 'Suzuri %s is already installed\n' "$version"
                exit 0
              fi

              temp_dir="$(${pkgs.coreutils}/bin/mktemp --directory -t suzuri.XXXXXXXXXX)"
              mount_dir="$temp_dir/mount"
              mounted=false
              cleanup() {
                if [ "$mounted" = true ]; then
                  /usr/bin/hdiutil detach "$mount_dir" >/dev/null || true
                fi
                ${pkgs.coreutils}/bin/rm -rf "$temp_dir"
              }
              trap cleanup EXIT

              dmg="$temp_dir/$asset_name"
              printf 'Installing Suzuri %s from %s\n' "$tag" "$asset_url"
              ${getExe pkgs.curl} --fail --location --silent --show-error --retry 3 "$asset_url" --output "$dmg"

              ${pkgs.coreutils}/bin/mkdir --parents "$mount_dir"
              /usr/bin/hdiutil attach \
                -nobrowse \
                -readonly \
                -mountpoint "$mount_dir" \
                "$dmg" >/dev/null
              mounted=true

              source_app=
              for candidate in "$mount_dir"/*.app; do
                [ -d "$candidate" ] || continue
                if [ -n "$source_app" ]; then
                  printf 'error: the Suzuri disk image contains multiple top-level app bundles\n' >&2
                  exit 1
                fi
                source_app=$candidate
              done

              if [ -z "$source_app" ] || ! app_is_valid "$source_app"; then
                printf 'error: the Suzuri disk image does not contain one valid top-level app bundle\n' >&2
                exit 1
              fi

              /usr/bin/ditto "$source_app" "$new_app"
              /usr/bin/codesign --verify --deep --strict "$new_app"

              /usr/bin/hdiutil detach "$mount_dir" >/dev/null
              mounted=false

              if [ -e "$suzuri_app" ]; then
                ${pkgs.coreutils}/bin/mv "$suzuri_app" "$old_app"
              fi
              if ! ${pkgs.coreutils}/bin/mv "$new_app" "$suzuri_app"; then
                if [ -e "$old_app" ]; then
                  ${pkgs.coreutils}/bin/mv "$old_app" "$suzuri_app"
                fi
                exit 1
              fi
              ${pkgs.coreutils}/bin/rm -rf "$old_app"

              state_dir="$(${pkgs.coreutils}/bin/dirname "$state_file")"
              ${pkgs.coreutils}/bin/mkdir --parents "$state_dir"
              printf '%s' "$state_value" > "$state_file.new"
              ${pkgs.coreutils}/bin/mv --force "$state_file.new" "$state_file"

              printf 'Installed Suzuri %s at %s\n' "$version" "$suzuri_app"
            )
          '';
      };
    };
}
