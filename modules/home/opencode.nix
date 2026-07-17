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

  curl = getExe pkgs.curl;
  jq = getExe pkgs.jq;
  sed = getExe pkgs.gnused;
  homeManager = config.home-manager.users.${user.name};
  opencodeInstallDir = "${user.homeDirectory}/.opencode/bin";
  opencodeDesktopDataDir = "${user.homeDirectory}/.local/share/opencode";
  opencodeDesktopApp = "${opencodeDesktopDataDir}/OpenCode.app";
  opencodeDesktopEtag = "${user.homeDirectory}/.local/state/opencode/desktop.etag";
in

{
  home-manager.users.${user.name} = {
    programs.opencode = {
      enable = true;
      package = null;

      settings = {
        autoupdate = true;
        plugin = [ "opencode-handoff" ];

        compaction = {
          auto = true;
          prune = true;
        };

        permission = {
          read = {
            "*" = "allow";
            "*.env" = "deny";
            "*.env.*" = "deny";
            "*.env.example" = "allow";
          };

          bash = {
            "git *" = "deny";
            "git blame" = "allow";
            "git blame *" = "allow";
            "git branch" = "allow";
            "git branch --list *" = "allow";
            "git branch -a" = "allow";
            "git branch -r" = "allow";
            "git cat-file *" = "allow";
            "git config --get *" = "allow";
            "git config --get-regexp *" = "allow";
            "git config --list" = "allow";
            "git describe" = "allow";
            "git describe *" = "allow";
            "git diff" = "allow";
            "git diff *" = "allow";
            "git diff-tree *" = "allow";
            "git for-each-ref" = "allow";
            "git for-each-ref *" = "allow";
            "git grep *" = "allow";
            "git log" = "allow";
            "git log *" = "allow";
            "git ls-remote" = "allow";
            "git ls-remote *" = "allow";
            "git ls-tree *" = "allow";
            "git ls-files" = "allow";
            "git ls-files *" = "allow";
            "git merge-base *" = "allow";
            "git name-rev *" = "allow";
            "git reflog" = "allow";
            "git reflog show *" = "allow";
            "git remote" = "allow";
            "git remote -v" = "allow";
            "git remote get-url *" = "allow";
            "git remote show *" = "allow";
            "git rev-list *" = "allow";
            "git rev-parse" = "allow";
            "git rev-parse *" = "allow";
            "git show" = "allow";
            "git show *" = "allow";
            "git shortlog" = "allow";
            "git shortlog *" = "allow";
            "git stash list" = "allow";
            "git stash show *" = "allow";
            "git status" = "allow";
            "git status *" = "allow";
            "git submodule status" = "allow";
            "git submodule status *" = "allow";
            "git tag" = "allow";
            "git tag --list *" = "allow";
            "git whatchanged" = "allow";
            "git whatchanged *" = "allow";
          };
        };
      };

      tui = {
        theme = "gruvbox";
        scroll_speed = 4;
      };
    };

    home.file."Applications/OpenCode.app" = mkIf pkgs.stdenv.hostPlatform.isDarwin {
      source = homeManager.lib.file.mkOutOfStoreSymlink opencodeDesktopApp;
    };

    home.activation.opencode-latest = homeManager.lib.dag.entryAfter [ "writeBoundary" ] ''
      (
        set -euo pipefail

        install_dir=${lib.escapeShellArg opencodeInstallDir}
        release_api=https://api.github.com/repos/anomalyco/opencode/releases/latest
        host_system=${lib.escapeShellArg pkgs.stdenv.hostPlatform.system}

        if ! release_json="$(${curl} --fail --silent --show-error --location \
          --header 'Accept: application/vnd.github+json' \
          --header 'X-GitHub-Api-Version: 2022-11-28' \
          "$release_api")"; then
          if [ -x "$install_dir/opencode" ]; then
            printf 'warning: could not check for a newer OpenCode release; keeping the installed version\n' >&2
            exit 0
          fi

          printf 'error: could not fetch the latest OpenCode release metadata\n' >&2
          exit 1
        fi

        version="$(printf '%s' "$release_json" | ${jq} --exit-status --raw-output '.tag_name | ltrimstr("v")')"

        if [ -x "$install_dir/opencode" ]; then
          installed_version="$($install_dir/opencode --version 2>/dev/null || true)"
          if [ "$installed_version" = "$version" ]; then
            printf 'OpenCode %s is already installed\n' "$version"
            exit 0
          fi
        fi

        case "$host_system" in
          aarch64-darwin)
            target=darwin-arm64
            archive_extension=.zip
            ;;
          aarch64-linux)
            target=linux-arm64
            archive_extension=.tar.gz
            ;;
          x86_64-linux)
            target=linux-x64
            archive_extension=.tar.gz
            if ! ${pkgs.gnugrep}/bin/grep --quiet --word-regexp --ignore-case avx2 /proc/cpuinfo; then
              target=linux-x64-baseline
            fi
            ;;
          *)
            printf 'error: unsupported OpenCode platform: %s\n' \
              "$host_system" >&2
            exit 1
            ;;
        esac

        filename="opencode-$target$archive_extension"
        asset_url="$(printf '%s' "$release_json" | ${jq} \
          --arg filename "$filename" \
          --exit-status \
          --raw-output \
          '.assets[] | select(.name == $filename) | .browser_download_url')"

        temp_dir="$(${pkgs.coreutils}/bin/mktemp --directory -t opencode-install.XXXXXXXXXX)"
        trap '${pkgs.coreutils}/bin/rm -rf "$temp_dir"' EXIT

        printf 'Installing OpenCode %s from %s\n' "$version" "$filename"
        ${curl} --fail --silent --show-error --location \
          --output "$temp_dir/$filename" \
          "$asset_url"

        if [ "$archive_extension" = .zip ]; then
          ${getExe pkgs.unzip} -q "$temp_dir/$filename" -d "$temp_dir"
        else
          ${getExe pkgs.gnutar} -xzf "$temp_dir/$filename" -C "$temp_dir"
        fi

        ${pkgs.coreutils}/bin/mkdir --parents "$install_dir"
        ${pkgs.coreutils}/bin/install --mode 0755 "$temp_dir/opencode" "$install_dir/.opencode.new"
        ${pkgs.coreutils}/bin/mv --force "$install_dir/.opencode.new" "$install_dir/opencode"
        printf 'Installed OpenCode %s at %s/opencode\n' "$version" "$install_dir"
      )
    '';

    home.activation.opencode-desktop-latest =
      mkIf pkgs.stdenv.hostPlatform.isDarwin
      <| homeManager.lib.dag.entryAfter [ "writeBoundary" ] ''
        (
          set -euo pipefail

          desktop_url=https://opencode.ai/download/stable/darwin-aarch64-dmg
          desktop_app=${lib.escapeShellArg opencodeDesktopApp}
          desktop_data_dir=${lib.escapeShellArg opencodeDesktopDataDir}
          etag_file=${lib.escapeShellArg opencodeDesktopEtag}
          new_app="$desktop_data_dir/.OpenCode.app.new"
          old_app="$desktop_data_dir/.OpenCode.app.old"

          ${pkgs.coreutils}/bin/mkdir --parents "$desktop_data_dir"
          if [ ! -e "$desktop_app" ] && [ -e "$old_app" ]; then
            ${pkgs.coreutils}/bin/mv "$old_app" "$desktop_app"
          fi
          ${pkgs.coreutils}/bin/rm -rf "$new_app"
          if [ -e "$desktop_app" ]; then
            ${pkgs.coreutils}/bin/rm -rf "$old_app"
          fi

          app_is_valid() {
            local app=$1
            local executable

            [ -f "$app/Contents/Info.plist" ] || return 1
            executable="$(/usr/bin/plutil -extract CFBundleExecutable raw "$app/Contents/Info.plist")" || return 1
            [ -x "$app/Contents/MacOS/$executable" ]
          }

          if ! response_headers="$(${curl} --fail --silent --show-error --head "$desktop_url")"; then
            if app_is_valid "$desktop_app"; then
              printf 'warning: could not check for a newer OpenCode Desktop release; keeping the installed version\n' >&2
              exit 0
            fi

            printf 'error: could not check the latest OpenCode Desktop release\n' >&2
            exit 1
          fi

          etag="$(printf '%s\n' "$response_headers" \
            | ${sed} -n 's/^[Ee][Tt][Aa][Gg]:[[:space:]]*//p' \
            | ${pkgs.coreutils}/bin/tr -d '\r' \
            | ${pkgs.coreutils}/bin/tail --lines 1)"

          if app_is_valid "$desktop_app" \
            && [ -n "$etag" ] \
            && [ -f "$etag_file" ] \
            && [ "$(< "$etag_file")" = "$etag" ]; then
            installed_version="$(/usr/bin/plutil \
              -extract CFBundleShortVersionString raw \
              "$desktop_app/Contents/Info.plist")"
            printf 'OpenCode Desktop %s is already installed\n' "$installed_version"
            exit 0
          fi

          temp_dir="$(${pkgs.coreutils}/bin/mktemp --directory -t opencode-desktop.XXXXXXXXXX)"
          mount_dir="$temp_dir/mount"
          mounted=false

          # shellcheck disable=SC2329
          cleanup() {
            if [ "$mounted" = true ]; then
              /usr/bin/hdiutil detach "$mount_dir" >/dev/null || true
            fi
            ${pkgs.coreutils}/bin/rm -rf "$temp_dir"
          }
          trap cleanup EXIT

          ${pkgs.coreutils}/bin/mkdir --parents "$mount_dir"
          printf 'Downloading the latest OpenCode Desktop release\n'
          ${curl} --fail --silent --show-error --location \
            --output "$temp_dir/opencode.dmg" \
            "$desktop_url"

          /usr/bin/hdiutil attach \
            -nobrowse \
            -readonly \
            -mountpoint "$mount_dir" \
            "$temp_dir/opencode.dmg" >/dev/null
          mounted=true

          if ! app_is_valid "$mount_dir/OpenCode.app"; then
            printf 'error: the OpenCode Desktop DMG does not contain a valid OpenCode.app\n' >&2
            exit 1
          fi

          /usr/bin/ditto "$mount_dir/OpenCode.app" "$temp_dir/OpenCode.app"
          /usr/bin/codesign --verify --deep --strict "$temp_dir/OpenCode.app"

          /usr/bin/hdiutil detach "$mount_dir" >/dev/null
          mounted=false

          ${pkgs.coreutils}/bin/mv "$temp_dir/OpenCode.app" "$new_app"

          if [ -e "$desktop_app" ]; then
            ${pkgs.coreutils}/bin/mv "$desktop_app" "$old_app"
          fi
          if ! ${pkgs.coreutils}/bin/mv "$new_app" "$desktop_app"; then
            if [ -e "$old_app" ]; then
              ${pkgs.coreutils}/bin/mv "$old_app" "$desktop_app"
            fi
            exit 1
          fi
          ${pkgs.coreutils}/bin/rm -rf "$old_app"

          if [ -n "$etag" ]; then
            etag_dir="$(${pkgs.coreutils}/bin/dirname "$etag_file")"
            ${pkgs.coreutils}/bin/mkdir --parents "$etag_dir"
            printf '%s' "$etag" > "$etag_file.new"
            ${pkgs.coreutils}/bin/mv --force "$etag_file.new" "$etag_file"
          fi

          installed_version="$(/usr/bin/plutil \
            -extract CFBundleShortVersionString raw \
            "$desktop_app/Contents/Info.plist")"
          printf 'Installed OpenCode Desktop %s at %s\n' "$installed_version" "$desktop_app"
        )
      '';
  };
}
