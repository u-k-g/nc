{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.generators) toJSON;
  inherit (lib.meta) getExe;
  inherit (lib.strings) makeBinPath optionalString;
  user = config.nc.user;
  theme = config.nc.theme;
  themeName = "nc-${theme.slug}";

  permissionRule = action: resource: effect: {
    inherit action resource effect;
  };

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

  opencodePnpmHome = "${user.homeDirectory}/.local/share/pnpm";
  opencodeDesktopDataDir = "${user.homeDirectory}/.local/share/opencode";
  opencodeDesktopApp = "${opencodeDesktopDataDir}/OpenCode.app";
  opencodeDesktopState = "${user.homeDirectory}/.local/state/opencode/desktop.source";

  opencodeDesktopInstall = ''
    (
      set -euo pipefail

      export CURL_CA_BUNDLE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt

      version="$(
        "$PNPM_HOME/bin/opencode" --version 2>/dev/null \
          | ${getExe pkgs.gnugrep} --only-matching --extended-regexp '[0-9]+\.[0-9]+\.[0-9]+'
      )"
      if [ -z "$version" ]; then
        printf 'warning: could not determine the installed OpenCode version; skipping the OpenCode desktop update\n' >&2
        exit 0
      fi

      asset_name=opencode-desktop-mac-arm64.dmg
      asset_url="https://opencode.ai/files/bin/$version/$asset_name"
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

      state_value="$version $asset_name"
      if app_is_valid "$desktop_app" \
        && [ -f "$state_file" ] \
        && [ "$(< "$state_file")" = "$state_value" ]; then
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

      dmg="$temp_dir/$asset_name"
      printf 'Installing OpenCode Desktop %s from %s\n' "$version" "$asset_url"
      if ! ${getExe pkgs.curl} --fail --location --silent --show-error --retry 3 "$asset_url" --output "$dmg"; then
        if app_is_valid "$desktop_app"; then
          printf 'warning: failed to download OpenCode Desktop %s; keeping the installed version\n' "$version" >&2
          exit 0
        fi
        printf 'error: failed to download OpenCode Desktop %s\n' "$version" >&2
        exit 1
      fi

      ${pkgs.coreutils}/bin/mkdir --parents "$mount_dir"
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
in

{
  home.users.${user.name} = {
    xdg.config.files."opencode/opencode.json" = {
      type = "copy";
      permissions = "644";
      text = toJSON { } {
        "$schema" = "https://opencode.ai/config.json";
        update = "disable";
        compaction = {
          auto = true;
        };

        permissions = [
          (permissionRule "shell" "*" "ask")
          (permissionRule "shell" "git *" "deny")
          (permissionRule "shell" "git blame *" "allow")
          (permissionRule "shell" "git branch" "allow")
          (permissionRule "shell" "git branch --list *" "allow")
          (permissionRule "shell" "git branch -a" "allow")
          (permissionRule "shell" "git branch -r" "allow")
          (permissionRule "shell" "git cat-file *" "allow")
          (permissionRule "shell" "git checkout *" "allow")
          (permissionRule "shell" "git clone *" "allow")
          (permissionRule "shell" "git config --get *" "allow")
          (permissionRule "shell" "git config --get-regexp *" "allow")
          (permissionRule "shell" "git config --list" "allow")
          (permissionRule "shell" "git describe *" "allow")
          (permissionRule "shell" "git diff *" "allow")
          (permissionRule "shell" "git diff-tree *" "allow")
          (permissionRule "shell" "git fetch *" "allow")
          (permissionRule "shell" "git for-each-ref *" "allow")
          (permissionRule "shell" "git gc *" "allow")
          (permissionRule "shell" "git grep *" "allow")
          (permissionRule "shell" "git log *" "allow")
          (permissionRule "shell" "git ls-files *" "allow")
          (permissionRule "shell" "git ls-remote *" "allow")
          (permissionRule "shell" "git ls-tree *" "allow")
          (permissionRule "shell" "git maintenance *" "allow")
          (permissionRule "shell" "git merge-base *" "allow")
          (permissionRule "shell" "git name-rev *" "allow")
          (permissionRule "shell" "git prune *" "allow")
          (permissionRule "shell" "git pull *" "allow")
          (permissionRule "shell" "git reflog" "allow")
          (permissionRule "shell" "git reflog show *" "allow")
          (permissionRule "shell" "git remote" "allow")
          (permissionRule "shell" "git remote -v" "allow")
          (permissionRule "shell" "git remote get-url *" "allow")
          (permissionRule "shell" "git remote show *" "allow")
          (permissionRule "shell" "git repack *" "allow")
          (permissionRule "shell" "git rev-list *" "allow")
          (permissionRule "shell" "git rev-parse *" "allow")
          (permissionRule "shell" "git show *" "allow")
          (permissionRule "shell" "git shortlog *" "allow")
          (permissionRule "shell" "git stash list" "allow")
          (permissionRule "shell" "git stash show *" "allow")
          (permissionRule "shell" "git status *" "allow")
          (permissionRule "shell" "git submodule" "allow")
          (permissionRule "shell" "git submodule *" "allow")
          (permissionRule "shell" "git switch *" "allow")
          (permissionRule "shell" "git tag" "allow")
          (permissionRule "shell" "git tag --list *" "allow")
          (permissionRule "shell" "git whatchanged *" "allow")
          (permissionRule "shell" "git checkout --orphan*" "deny")
          (permissionRule "shell" "git checkout --track*" "deny")
          (permissionRule "shell" "git checkout -B*" "deny")
          (permissionRule "shell" "git checkout -b*" "deny")
          (permissionRule "shell" "git checkout -t*" "deny")
          (permissionRule "shell" "git restore" "deny")
          (permissionRule "shell" "git restore *" "deny")
          (permissionRule "shell" "git switch --create*" "deny")
          (permissionRule "shell" "git switch --force-create*" "deny")
          (permissionRule "shell" "git switch --orphan*" "deny")
          (permissionRule "shell" "git switch --track*" "deny")
          (permissionRule "shell" "git switch -C*" "deny")
          (permissionRule "shell" "git switch -c*" "deny")
          (permissionRule "shell" "git switch -t*" "deny")
          (permissionRule "edit" "*" "allow")
          (permissionRule "edit" ".git" "deny")
          (permissionRule "edit" ".git/*" "deny")
          (permissionRule "edit" "*/.git" "deny")
          (permissionRule "edit" "*/.git/*" "deny")
          (permissionRule "read" "*" "allow")
          (permissionRule "read" "*.env" "deny")
          (permissionRule "read" "*.env.*" "deny")
          (permissionRule "read" "*.env.example" "allow")
        ];
      };
    };

    xdg.config.files."opencode/cli.json".text = toJSON { } {
      "$schema" = "https://opencode.ai/v2/cli.json";
      theme = {
        name = themeName;
      };
      scroll = {
        speed = 4;
      };
    };

    xdg.config.files."opencode/themes/${themeName}.json".text = toJSON { } opencodeTheme;

    activationScripts.opencode-latest = ''
      (
        set -euo pipefail

        export PNPM_HOME=${lib.escapeShellArg opencodePnpmHome}
        export PATH="$PNPM_HOME/bin:${
          makeBinPath [
            pkgs.nodejs
            pkgs.coreutils
          ]
        }:$PATH"

        if ! ${getExe pkgs.pnpm} add --global \
          --allow-build=@opencode/cli \
          @opencode/cli@latest; then
          if [ ! -x "$PNPM_HOME/bin/opencode" ]; then
            printf 'error: failed to install OpenCode and none is installed\n' >&2
            exit 1
          fi
          printf 'warning: failed to update OpenCode; keeping the installed version\n' >&2
        fi

        ${optionalString pkgs.stdenv.hostPlatform.isDarwin opencodeDesktopInstall}
      )
    '';
  };
}
