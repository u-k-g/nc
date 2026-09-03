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

  writerDataDir = "${user.homeDirectory}/.local/share/writer";
  writerApp = "${writerDataDir}/Writer.app";
  writerState = "${user.homeDirectory}/.local/state/writer/source";
in
{
  home.users.${user.name} = {
    activationScripts.writer-latest =
      mkIf pkgs.stdenv.hostPlatform.isDarwin
      <| ''
        (
          set -euo pipefail

          export CURL_CA_BUNDLE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt

          api='https://api.github.com/repos/joelbqz/writer-computer/releases?per_page=100'
          writer_app=${lib.escapeShellArg writerApp}
          writer_data_dir=${lib.escapeShellArg writerDataDir}
          state_file=${lib.escapeShellArg writerState}
          new_app="$writer_data_dir/.Writer.app.new"
          old_app="$writer_data_dir/.Writer.app.old"

          ${pkgs.coreutils}/bin/mkdir --parents ${lib.escapeShellArg "${user.homeDirectory}/Applications"}
          ${pkgs.coreutils}/bin/ln --symbolic --force --no-dereference "$writer_app" ${lib.escapeShellArg "${user.homeDirectory}/Applications/Writer.app"}

          app_is_valid() {
            local app=$1
            local executable

            [ -f "$app/Contents/Info.plist" ] || return 1
            executable="$(/usr/bin/plutil -extract CFBundleExecutable raw "$app/Contents/Info.plist")" || return 1
            [ -x "$app/Contents/MacOS/$executable" ]
          }

          ${pkgs.coreutils}/bin/mkdir --parents "$writer_data_dir"
          if [ ! -e "$writer_app" ] && [ -e "$old_app" ]; then
            ${pkgs.coreutils}/bin/mv "$old_app" "$writer_app"
          fi
          ${pkgs.coreutils}/bin/rm -rf "$new_app"
          if [ -e "$writer_app" ]; then
            ${pkgs.coreutils}/bin/rm -rf "$old_app"
          fi

          release_probe="$writer_data_dir/.writer-release.json"
          if ${getExe pkgs.curl} --fail --location --silent --show-error --retry 3 "$api" --output "$release_probe"; then
            release="$(${getExe pkgs.jq} --compact-output '
              [
                .[]
                | select(.draft | not) as $release
                | $release.assets[]
                | select(.name | endswith("_aarch64.dmg"))
                | {
                    asset_name: .name,
                    asset_url: .browser_download_url,
                    published_at: $release.published_at,
                    tag: $release.tag_name
                  }
              ]
              | sort_by(.published_at)
              | last // {}
            ' "$release_probe")"
            ${pkgs.coreutils}/bin/rm -f "$release_probe"
            tag="$(printf '%s' "$release" | ${getExe pkgs.jq} --raw-output '.tag // empty')"
            asset_name="$(printf '%s' "$release" | ${getExe pkgs.jq} --raw-output '.asset_name // empty')"
            asset_url="$(printf '%s' "$release" | ${getExe pkgs.jq} --raw-output '.asset_url // empty')"
          else
            ${pkgs.coreutils}/bin/rm -f "$release_probe"
            if app_is_valid "$writer_app"; then
              installed_version="$(/usr/bin/plutil \
                -extract CFBundleShortVersionString raw \
                "$writer_app/Contents/Info.plist")"
              printf 'warning: failed to check latest Writer release; keeping Writer %s\n' "$installed_version" >&2
              exit 0
            fi
            printf 'warning: failed to check latest Writer release; skipping Writer install\n' >&2
            exit 0
          fi

          if [ -z "$tag" ] || [ -z "$asset_name" ] || [ -z "$asset_url" ]; then
            printf 'error: failed to resolve the newest Writer arm64 DMG from release metadata\n' >&2
            exit 1
          fi

          state_value="$tag $asset_name $asset_url"
          if app_is_valid "$writer_app" \
            && [ -f "$state_file" ] \
            && [ "$(< "$state_file")" = "$state_value" ]; then
            installed_version="$(/usr/bin/plutil \
              -extract CFBundleShortVersionString raw \
              "$writer_app/Contents/Info.plist")"
            printf 'Writer %s is already installed\n' "$installed_version"
            exit 0
          fi

          temp_dir="$(${pkgs.coreutils}/bin/mktemp --directory -t writer.XXXXXXXXXX)"
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
          printf 'Installing Writer %s from %s\n' "$tag" "$asset_url"
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
              printf 'error: the Writer disk image contains multiple top-level app bundles\n' >&2
              exit 1
            fi
            source_app=$candidate
          done

          if [ -z "$source_app" ] || ! app_is_valid "$source_app"; then
            printf 'error: the Writer disk image does not contain one valid top-level app bundle\n' >&2
            exit 1
          fi

          /usr/bin/ditto "$source_app" "$new_app"
          /usr/bin/codesign --verify --deep --strict "$new_app"

          /usr/bin/hdiutil detach "$mount_dir" >/dev/null
          mounted=false

          if [ -e "$writer_app" ]; then
            ${pkgs.coreutils}/bin/mv "$writer_app" "$old_app"
          fi
          if ! ${pkgs.coreutils}/bin/mv "$new_app" "$writer_app"; then
            if [ -e "$old_app" ]; then
              ${pkgs.coreutils}/bin/mv "$old_app" "$writer_app"
            fi
            exit 1
          fi
          ${pkgs.coreutils}/bin/rm -rf "$old_app"

          state_dir="$(${pkgs.coreutils}/bin/dirname "$state_file")"
          ${pkgs.coreutils}/bin/mkdir --parents "$state_dir"
          printf '%s' "$state_value" > "$state_file.new"
          ${pkgs.coreutils}/bin/mv --force "$state_file.new" "$state_file"

          installed_version="$(/usr/bin/plutil \
            -extract CFBundleShortVersionString raw \
            "$writer_app/Contents/Info.plist")"
          printf 'Installed Writer %s at %s\n' "$installed_version" "$writer_app"
        )
      '';
  };
}
