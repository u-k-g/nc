{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.generators) toJSON;
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf;
  user = config.nc.user;
  theme = config.nc.theme;
  themeName = "nc-${theme.slug}";

  opencodeTheme = {
    "$schema" = "https://opencode.ai/theme.json";
    defs = {
      base00 = "#${theme.base00}";
      base01 = "#${theme.base01}";
      base02 = "#${theme.base02}";
      base03 = "#${theme.base03}";
      base04 = "#${theme.base04}";
      base05 = "#${theme.base05}";
      base06 = "#${theme.base06}";
      base07 = "#${theme.base07}";
      base08 = "#${theme.base08}";
      base09 = "#${theme.base09}";
      base0A = "#${theme.base0A}";
      base0B = "#${theme.base0B}";
      base0C = "#${theme.base0C}";
      base0D = "#${theme.base0D}";
      base0E = "#${theme.base0E}";
      base0F = "#${theme.base0F}";
    };
    theme = {
      primary = "base0D";
      secondary = "base0E";
      accent = "base0A";
      error = "base08";
      warning = "base09";
      success = "base0B";
      info = "base0C";
      text = "base05";
      textMuted = "base03";
      background = "base00";
      backgroundPanel = "base01";
      backgroundElement = "base02";
      border = "base02";
      borderActive = "base0A";
      borderSubtle = "base01";
      diffAdded = "base0B";
      diffRemoved = "base08";
      diffContext = "base04";
      diffHunkHeader = "base0D";
      diffHighlightAdded = "base0B";
      diffHighlightRemoved = "base08";
      diffAddedBg = "base01";
      diffRemovedBg = "base01";
      diffContextBg = "base00";
      diffLineNumber = "base03";
      diffAddedLineNumberBg = "base01";
      diffRemovedLineNumberBg = "base01";
      markdownText = "base05";
      markdownHeading = "base0D";
      markdownLink = "base0C";
      markdownLinkText = "base0D";
      markdownCode = "base0B";
      markdownBlockQuote = "base04";
      markdownEmph = "base0E";
      markdownStrong = "base0A";
      markdownHorizontalRule = "base03";
      markdownListItem = "base0D";
      markdownListEnumeration = "base0C";
      markdownImage = "base0E";
      markdownImageText = "base0D";
      markdownCodeBlock = "base05";
      syntaxComment = "base03";
      syntaxKeyword = "base0E";
      syntaxFunction = "base0D";
      syntaxVariable = "base08";
      syntaxString = "base0B";
      syntaxNumber = "base09";
      syntaxType = "base0A";
      syntaxOperator = "base05";
      syntaxPunctuation = "base04";
    };
  };

  opencodeInstallDir = "${user.homeDirectory}/.opencode/bin";
  opencodeCliState = "${user.homeDirectory}/.local/state/opencode/cli.source";
  opencodeDesktopDataDir = "${user.homeDirectory}/.local/share/opencode";
  opencodeDesktopApp = "${opencodeDesktopDataDir}/OpenCode.app";
  opencodeDesktopState = "${user.homeDirectory}/.local/state/opencode/desktop.source";
in

{
  home.users.${user.name} = {
    xdg.config.files."opencode/opencode.json".text = toJSON { } {
      autoupdate = true;
      plugin = [ "opencode-handoff" ];

      compaction = {
        auto = true;
        prune = true;
      };

      permission = {
        edit = {
          "*" = "allow";
          ".git" = "deny";
          ".git/*" = "deny";
          "*/.git" = "deny";
          "*/.git/*" = "deny";
        };

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
          "git checkout" = "allow";
          "git checkout *" = "allow";
          "git checkout --orphan*" = "deny";
          "git checkout --track*" = "deny";
          "git checkout -B *" = "deny";
          "git checkout -B*" = "deny";
          "git checkout -b *" = "deny";
          "git checkout -b*" = "deny";
          "git checkout -t *" = "deny";
          "git checkout -t*" = "deny";
          "git clone *" = "allow";
          "git config --get *" = "allow";
          "git config --get-regexp *" = "allow";
          "git config --list" = "allow";
          "git describe" = "allow";
          "git describe *" = "allow";
          "git diff" = "allow";
          "git diff *" = "allow";
          "git diff-tree *" = "allow";
          "git fetch" = "allow";
          "git fetch *" = "allow";
          "git for-each-ref" = "allow";
          "git for-each-ref *" = "allow";
          "git gc" = "allow";
          "git gc *" = "allow";
          "git grep *" = "allow";
          "git log" = "allow";
          "git log *" = "allow";
          "git ls-remote" = "allow";
          "git ls-remote *" = "allow";
          "git ls-tree *" = "allow";
          "git maintenance" = "allow";
          "git maintenance *" = "allow";
          "git ls-files" = "allow";
          "git ls-files *" = "allow";
          "git merge-base *" = "allow";
          "git name-rev *" = "allow";
          "git prune" = "allow";
          "git prune *" = "allow";
          "git pull" = "allow";
          "git pull *" = "allow";
          "git reflog" = "allow";
          "git reflog show *" = "allow";
          "git remote" = "allow";
          "git remote -v" = "allow";
          "git remote get-url *" = "allow";
          "git remote show *" = "allow";
          "git rev-list *" = "allow";
          "git rev-parse" = "allow";
          "git rev-parse *" = "allow";
          "git repack" = "allow";
          "git repack *" = "allow";
          "git restore" = "deny";
          "git restore *" = "deny";
          "git show" = "allow";
          "git show *" = "allow";
          "git shortlog" = "allow";
          "git shortlog *" = "allow";
          "git stash list" = "allow";
          "git stash show *" = "allow";
          "git status" = "allow";
          "git status *" = "allow";
          "git submodule" = "allow";
          "git submodule *" = "allow";
          "git switch *" = "allow";
          "git switch --create*" = "deny";
          "git switch --force-create*" = "deny";
          "git switch --orphan*" = "deny";
          "git switch --track*" = "deny";
          "git switch -C *" = "deny";
          "git switch -C*" = "deny";
          "git switch -c *" = "deny";
          "git switch -c*" = "deny";
          "git switch -t *" = "deny";
          "git switch -t*" = "deny";
          "git tag" = "allow";
          "git tag --list *" = "allow";
          "git whatchanged" = "allow";
          "git whatchanged *" = "allow";
        };
      };
    };

    xdg.config.files."opencode/tui.json".text = toJSON { } {
      theme = themeName;
      scroll_speed = 4;
    };

    xdg.config.files."opencode/themes/${themeName}.json".text = toJSON { } opencodeTheme;

    activationScripts.opencode-latest = ''
      (
        set -euo pipefail

        export CURL_CA_BUNDLE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt

        install_dir=${lib.escapeShellArg opencodeInstallDir}
        state_file=${lib.escapeShellArg opencodeCliState}
        api=https://api.github.com/repos/anomalyco/opencode/releases/latest

        ${
          if pkgs.stdenv.hostPlatform.system == "aarch64-darwin" then
            ''
              asset_name=opencode-darwin-arm64.zip
            ''
          else if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then
            ''
              if ${getExe pkgs.gnugrep} --quiet --word-regexp --ignore-case avx2 /proc/cpuinfo; then
                asset_name=opencode-linux-x64-musl.tar.gz
              else
                asset_name=opencode-linux-x64-baseline-musl.tar.gz
              fi
            ''
          else
            throw "unsupported OpenCode platform: ${pkgs.stdenv.hostPlatform.system}"
        }

        temp_dir="$(${pkgs.coreutils}/bin/mktemp --directory -t opencode-cli.XXXXXXXXXX)"
        cleanup() {
          ${pkgs.coreutils}/bin/rm -rf "$temp_dir"
        }
        trap cleanup EXIT

        release_json="$temp_dir/release.json"
        if ! ${getExe pkgs.curl} --fail --location --silent --show-error --retry 3 "$api" --output "$release_json"; then
          if [ -x "$install_dir/opencode" ] \
            && installed_version="$("$install_dir/opencode" --version 2>/dev/null)" \
            && [ -n "$installed_version" ]; then
            printf 'warning: failed to check latest OpenCode release; keeping OpenCode %s\n' "$installed_version" >&2
            exit 0
          fi
          printf 'error: failed to check latest OpenCode release; OpenCode is not installed\n' >&2
          exit 1
        fi

        tag="$(${getExe pkgs.jq} --raw-output '.tag_name // empty' "$release_json")"
        asset_url="$(${getExe pkgs.jq} --raw-output --arg name "$asset_name" \
          '.assets[] | select(.name == $name) | .browser_download_url' "$release_json")"

        if [ -z "$tag" ] || [ -z "$asset_url" ]; then
          printf 'error: failed to resolve OpenCode asset %s from latest release metadata\n' "$asset_name" >&2
          exit 1
        fi

        state_value="$tag $asset_name $asset_url"

        if [ -x "$install_dir/opencode" ] \
          && [ -f "$state_file" ] \
          && [ "$(< "$state_file")" = "$state_value" ] \
          && installed_version="$("$install_dir/opencode" --version 2>/dev/null)" \
          && [ -n "$installed_version" ]; then
          printf 'OpenCode %s is already installed\n' "$installed_version"
          exit 0
        fi

        archive="$temp_dir/$asset_name"
        extract_dir="$temp_dir/extract"
        ${pkgs.coreutils}/bin/mkdir --parents "$extract_dir"
        printf 'Installing OpenCode %s from %s\n' "$tag" "$asset_url"
        ${getExe pkgs.curl} --fail --location --silent --show-error --retry 3 "$asset_url" --output "$archive"

        case "$asset_name" in
          *.zip)
            ${getExe pkgs.unzip} -q "$archive" -d "$extract_dir"
            ;;
          *.tar.gz)
            ${getExe pkgs.gnutar} \
              --use-compress-program=${getExe pkgs.gzip} \
              -xf "$archive" \
              -C "$extract_dir"
            ;;
          *)
            printf 'error: unsupported OpenCode archive type: %s\n' "$asset_name" >&2
            exit 1
            ;;
        esac

        if [ ! -x "$extract_dir/opencode" ]; then
          printf 'error: OpenCode archive did not contain an executable opencode file\n' >&2
          exit 1
        fi
        if ! downloaded_version="$("$extract_dir/opencode" --version 2>/dev/null)"; then
          printf 'error: downloaded OpenCode binary is not runnable on this system\n' >&2
          exit 1
        fi
        if [ -z "$downloaded_version" ]; then
          printf 'error: downloaded OpenCode binary did not report a version\n' >&2
          exit 1
        fi

        ${pkgs.coreutils}/bin/mkdir --parents "$install_dir"
        ${pkgs.coreutils}/bin/install --mode 0755 "$extract_dir/opencode" "$install_dir/.opencode.new"
        ${pkgs.coreutils}/bin/mv --force "$install_dir/.opencode.new" "$install_dir/opencode"

        state_dir="$(${pkgs.coreutils}/bin/dirname "$state_file")"
        ${pkgs.coreutils}/bin/mkdir --parents "$state_dir"
        printf '%s' "$state_value" > "$state_file.new"
        ${pkgs.coreutils}/bin/mv --force "$state_file.new" "$state_file"

        printf 'Installed OpenCode %s from %s\n' "$downloaded_version" "$asset_url"
      )
    '';

    activationScripts.opencode-desktop-latest =
      mkIf pkgs.stdenv.hostPlatform.isDarwin
      <| ''
        (
          set -euo pipefail

          export CURL_CA_BUNDLE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt

          api=https://api.github.com/repos/anomalyco/opencode/releases/latest
          asset_name=opencode-desktop-mac-arm64.dmg
          desktop_app=${lib.escapeShellArg opencodeDesktopApp}
          desktop_data_dir=${lib.escapeShellArg opencodeDesktopDataDir}
          state_file=${lib.escapeShellArg opencodeDesktopState}
          new_app="$desktop_data_dir/.OpenCode.app.new"
          old_app="$desktop_data_dir/.OpenCode.app.old"

          ${pkgs.coreutils}/bin/mkdir --parents ${lib.escapeShellArg "${user.homeDirectory}/Applications"}
          ${pkgs.coreutils}/bin/ln --symbolic --force --no-dereference "$desktop_app" ${lib.escapeShellArg "${user.homeDirectory}/Applications/OpenCode.app"}

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

          if app_is_valid "$desktop_app" \
            && [ -f "$state_file" ] \
            && ${getExe pkgs.curl} --fail --location --silent --show-error --retry 3 "$api" --output "$desktop_data_dir/.opencode-desktop-release.json"; then
            tag="$(${getExe pkgs.jq} --raw-output '.tag_name // empty' "$desktop_data_dir/.opencode-desktop-release.json")"
            asset_url="$(${getExe pkgs.jq} --raw-output --arg name "$asset_name" \
              '.assets[] | select(.name == $name) | .browser_download_url' "$desktop_data_dir/.opencode-desktop-release.json")"
            state_value="$tag $asset_name $asset_url"
            ${pkgs.coreutils}/bin/rm -f "$desktop_data_dir/.opencode-desktop-release.json"

            if [ -n "$tag" ] && [ -n "$asset_url" ] && [ "$(< "$state_file")" = "$state_value" ]; then
              installed_version="$(/usr/bin/plutil \
                -extract CFBundleShortVersionString raw \
                "$desktop_app/Contents/Info.plist")"
              printf 'OpenCode Desktop %s is already installed\n' "$installed_version"
              exit 0
            fi
          elif app_is_valid "$desktop_app"; then
            installed_version="$(/usr/bin/plutil \
              -extract CFBundleShortVersionString raw \
              "$desktop_app/Contents/Info.plist")"
            printf 'warning: failed to check latest OpenCode Desktop release; keeping OpenCode Desktop %s\n' "$installed_version" >&2
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

          release_json="$temp_dir/release.json"
          if ! ${getExe pkgs.curl} --fail --location --silent --show-error --retry 3 "$api" --output "$release_json"; then
            printf 'warning: failed to check latest OpenCode Desktop release; skipping OpenCode Desktop install\n' >&2
            exit 0
          fi
          tag="$(${getExe pkgs.jq} --raw-output '.tag_name // empty' "$release_json")"
          asset_url="$(${getExe pkgs.jq} --raw-output --arg name "$asset_name" \
            '.assets[] | select(.name == $name) | .browser_download_url' "$release_json")"

          if [ -z "$tag" ] || [ -z "$asset_url" ]; then
            printf 'error: failed to resolve OpenCode Desktop asset %s from latest release metadata\n' "$asset_name" >&2
            exit 1
          fi

          state_value="$tag $asset_name $asset_url"
          dmg="$temp_dir/$asset_name"
          ${getExe pkgs.curl} --fail --location --silent --show-error --retry 3 "$asset_url" --output "$dmg"

          ${pkgs.coreutils}/bin/mkdir --parents "$mount_dir"
          printf 'Installing OpenCode Desktop %s from %s\n' "$tag" "$asset_url"
          /usr/bin/hdiutil attach \
            -nobrowse \
            -readonly \
            -mountpoint "$mount_dir" \
            "$dmg" >/dev/null
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

          state_dir="$(${pkgs.coreutils}/bin/dirname "$state_file")"
          ${pkgs.coreutils}/bin/mkdir --parents "$state_dir"
          printf '%s' "$state_value" > "$state_file.new"
          ${pkgs.coreutils}/bin/mv --force "$state_file.new" "$state_file"

          installed_version="$(/usr/bin/plutil \
            -extract CFBundleShortVersionString raw \
            "$desktop_app/Contents/Info.plist")"
          printf 'Installed OpenCode Desktop %s at %s\n' "$installed_version" "$desktop_app"
        )
      '';
  };
}
