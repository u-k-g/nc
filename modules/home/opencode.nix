{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  inherit (lib.modules) mkIf;
  user = config.nc.user;

  homeManager = config.home-manager.users.${user.name};
  opencodeInstallDir = "${user.homeDirectory}/.opencode/bin";
  opencodeCliState = "${user.homeDirectory}/.local/state/opencode/cli.source";
  opencodeDesktopDataDir = "${user.homeDirectory}/.local/share/opencode";
  opencodeDesktopApp = "${opencodeDesktopDataDir}/OpenCode.app";
  opencodeDesktopState = "${user.homeDirectory}/.local/state/opencode/desktop.source";

  # null on x86_64-linux, where the AVX2 check happens at activation time
  opencodeCli =
    if pkgs.stdenv.hostPlatform.system == "aarch64-darwin" then
      "${inputs.opencode-darwin-arm64}/opencode"
    else if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then
      null
    else
      throw "unsupported OpenCode platform: ${pkgs.stdenv.hostPlatform.system}";
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
        state_file=${lib.escapeShellArg opencodeCliState}

        ${
          if opencodeCli != null then
            ''
              source_path=${lib.escapeShellArg opencodeCli}
            ''
          else
            ''
              if ${pkgs.gnugrep}/bin/grep --quiet --word-regexp --ignore-case avx2 /proc/cpuinfo; then
                source_path=${lib.escapeShellArg "${inputs.opencode-linux-x64}/opencode"}
              else
                source_path=${lib.escapeShellArg "${inputs.opencode-linux-x64-baseline}/opencode"}
              fi
            ''
        }

        if [ -x "$install_dir/opencode" ] \
          && [ -f "$state_file" ] \
          && [ "$(< "$state_file")" = "$source_path" ]; then
          installed_version="$("$install_dir/opencode" --version 2>/dev/null || true)"
          printf 'OpenCode %s is already installed\n' "$installed_version"
          exit 0
        fi

        ${pkgs.coreutils}/bin/mkdir --parents "$install_dir"
        ${pkgs.coreutils}/bin/install --mode 0755 "$source_path" "$install_dir/.opencode.new"
        ${pkgs.coreutils}/bin/mv --force "$install_dir/.opencode.new" "$install_dir/opencode"

        state_dir="$(${pkgs.coreutils}/bin/dirname "$state_file")"
        ${pkgs.coreutils}/bin/mkdir --parents "$state_dir"
        printf '%s' "$source_path" > "$state_file.new"
        ${pkgs.coreutils}/bin/mv --force "$state_file.new" "$state_file"

        installed_version="$("$install_dir/opencode" --version 2>/dev/null || true)"
        printf 'Installed OpenCode %s from %s\n' "$installed_version" "$source_path"
      )
    '';

    home.activation.opencode-desktop-latest =
      mkIf pkgs.stdenv.hostPlatform.isDarwin
      <| homeManager.lib.dag.entryAfter [ "writeBoundary" ] ''
        (
          set -euo pipefail

          dmg=${lib.escapeShellArg inputs.opencode-desktop}
          desktop_app=${lib.escapeShellArg opencodeDesktopApp}
          desktop_data_dir=${lib.escapeShellArg opencodeDesktopDataDir}
          state_file=${lib.escapeShellArg opencodeDesktopState}
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

          if app_is_valid "$desktop_app" \
            && [ -f "$state_file" ] \
            && [ "$(< "$state_file")" = "$dmg" ]; then
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
          printf 'Installing OpenCode Desktop from %s\n' "$dmg"
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
          printf '%s' "$dmg" > "$state_file.new"
          ${pkgs.coreutils}/bin/mv --force "$state_file.new" "$state_file"

          installed_version="$(/usr/bin/plutil \
            -extract CFBundleShortVersionString raw \
            "$desktop_app/Contents/Info.plist")"
          printf 'Installed OpenCode Desktop %s at %s\n' "$installed_version" "$desktop_app"
        )
      '';
  };
}
