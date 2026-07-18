{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.meta) getExe;

  user = config.nc.user;
  home = config.home-manager.users.${user.name}.home.homeDirectory;

  gh = getExe pkgs.gh;
  jj = getExe pkgs.jujutsu;
  jjFork = pkgs.writers.writeNu "jj-fork" /* nu */ ''
    def remote-names [] {
      ^${jj} git remote list | lines | parse "{name} {url}" | get name
    }

    mut renamed_origin = false
    let remotes = remote-names

    if ("upstream" not-in $remotes) and ("origin" in $remotes) {
      ^${jj} git remote rename origin upstream
      $renamed_origin = true
    }

    if "origin" not-in (remote-names) {
      let fork = do { ^${gh} repo fork --remote --remote-name origin } | complete

      if $fork.exit_code != 0 {
        if $renamed_origin {
          ^${jj} git remote rename upstream origin
        }

        error make { msg: ($fork.stderr | str trim) }
      }
    }

    ^${jj} git fetch

    let trunk_bookmarks = (
      ^${jj} bookmark list
        --all-remotes
        --revision 'trunk()'
        --template 'if(remote && remote != "git", name ++ "@" ++ remote ++ "\n")'
      | lines
    )

    if not ($trunk_bookmarks | is-empty) {
      ^${jj} bookmark track ...$trunk_bookmarks
    }
  '';
in
{
  home-manager.users.${user.name} = {
    programs.git = {
      enable = true;
      lfs.enable = true;

      settings = {
        user = {
          name = user.fullName;
          email = user.email;
          signingkey = "${home}/.ssh/id_rsa.pub";
        };

        http = {
          postBuffer = 157286400;
          sslBackend = "openssl";
          sslCAInfo = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        };

        pull.rebase = false;

        core = {
          editor = "hx";
          excludesfile = "${home}/.gitignore_global";
          whitespace = "trailing-space,space-before-tab";
          fsmonitor = true;
          untrackedCache = true;
        };

        merge = {
          conflictstyle = "zdiff3";
          tool = "hx";
        };

        init.defaultBranch = "main";

        push = {
          autoSetupRemote = true;
          default = "current";
        };

        github.user = "u-k-g";

        commit.gpgsign = pkgs.stdenv.isDarwin;
        tag.gpgSign = pkgs.stdenv.isDarwin;

        feature.manyFiles = true;
      }
      // optionalAttrs pkgs.stdenv.isDarwin {
        gpg.format = "ssh";
      };
    };

    home.file = {
      ".gitignore_global".source = ../../dotfiles/home/.gitignore_global;
    };

    xdg.configFile = {
      "jj/config.toml".text = ''
        #:schema https://jj-vcs.github.io/jj/latest/config-schema.json

        [user]
        name = "${user.fullName}"
        email = "${user.email}"

        [signing]
        backend = "ssh"
        behavior = "drop"
        key = "${home}/.ssh/id_rsa.pub"

        [signing.backends.ssh]
        program = "${pkgs.openssh}/bin/ssh-keygen"
        allowed-signers = "${home}/.config/git/allowed_signers"

        [ui]
        editor = "hx"
        diff-editor = ":builtin"
        diff-formatter = ["${getExe config.nc.difftastic.package}", "--color", "always", "$left", "$right"]
        conflict-marker-style = "snapshot"
        default-command = "log"
        merge-editor = "mergiraf"
        graph.style = "${if config.nc.theme.cornerRadius > 0 then "curved" else "square"}"
        pager.command = ["${pkgs.bat}/bin/bat", "--plain", "--paging=auto", "--color=always", "--pager", "${pkgs.less}/bin/less -FRX --chop-long-lines"]

        [aliases]
        ".." = ["edit", "@-"]
        ",," = ["edit", "@+"]
        f = ["git", "fetch"]
        p = ["git", "push"]
        cl = ["git", "clone"]
        i = ["git", "init"]
        a = ["abandon"]
        c = ["commit"]
        ci = ["commit", "--interactive"]
        d = ["diff"]
        e = ["edit"]
        l = ["log"]
        la = ["log", "--revisions", "::"]
        s = ["squash"]
        si = ["squash", "--interactive"]
        u = ["undo"]
        fork = ["util", "exec", "--", "${jjFork}"]

        ba = ["bookmark", "advance"]
        resolve-ast = ["resolve", "--tool", "mergiraf"]
        fcd = ["diff", "--tool", "fcstd"]
        gd = ["diff", "--git"]
        ls = ["file", "list"]

        [revset-aliases]
        "closest_bookmark(to)" = "heads(::to & bookmarks())"
        "fork_history(to, from)" = "fork_point(to | from)..@"

        [template-aliases]
        "format_timestamp(timestamp)" = "timestamp.ago()"

        [templates]
        draft_commit_description = ''''
        concat(
          coalesce(description, "\n"),
          surround(
            "\nJJ: This commit contains the following changes:\n", "",
            indent("JJ:     ", diff.stat(72)),
          ),
          "\nJJ: ignore-rest\n",
          diff.git(),
        )
        ''''
        git_push_bookmark = '"${user.handle}/change-" ++ change_id.short()'

        [remotes."*"]
        auto-track-bookmarks = "${user.handle}/*"
        push-new-bookmarks = true

        [git]
        fetch = ["origin", "upstream", "rad"]
        push = "origin"
        sign-on-push = true

        [fsmonitor]
        backend = "watchman"

        [fsmonitor.watchman]
        register-snapshot-trigger = true

        [merge-tools.mergiraf]
        program = "${getExe pkgs.mergiraf}"

        [merge-tools.fcstd]
        program = "${home}/.config/nushell/fcdiff.nu"
        diff-args = ["$left", "$right"]

        [snapshot]
        max-new-file-size = 13200000

        [revsets]
        bookmark-advance-from = 'heads(::to & bookmarks() & ~immutable())'
        bookmark-advance-to = 'heads(::@ & mutable() & ~description(exact:"") & (~empty() | merges()))'
        log = 'present(@) | present(trunk()) | ancestors(remote_bookmarks().. | @.., 8)'
      '';

      "jjui/config.toml".text = ''
        [revisions]
        revset = ".."
      '';
    };
  };
}
