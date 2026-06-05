{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.attrsets) optionalAttrs;
  user = config.nc.user;
  home = config.home-manager.users.${user.name}.home.homeDirectory;
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
        max-new-file-size = 2477272
        #:schema https://jj-vcs.github.io/jj/latest/config-schema.json

        [user]
        name = "${user.fullName}"
        email = "${user.email}"

        [signing]
        backend = "ssh"
        behavior = "${if pkgs.stdenv.isDarwin then "own" else "drop"}"

        [signing.backends.ssh]
        program = "ssh-keygen"
        allowed-signers = "${home}/.config/git/allowed_signers"

        [ui]
        editor = "hx"
        diff-formatter = "difft"
        conflict-marker-style = "git"
        default-command = "log"
        merge-editor = "mergiraf"
        graph.style = "square"
        pager.command = ["${pkgs.bat}/bin/bat", "--plain", "--paging=auto", "--color=always", "--pager", "${pkgs.less}/bin/less -FRX --chop-long-lines"]

        [aliases]
        ba = ["bookmark", "advance", "--to", "@-"]
        l = ["log", "-r", "all()"]
        mergiraf = ["resolve", "--tool", "mergiraf"]
        resolve-ast = ["resolve", "--tool", "mergiraf"]
        push = ["git", "push", "-r", "closest_bookmark(@-)"]
        fetch = ["git", "fetch"]
        d = ["diff", "--tool", "difft"]
        df = ["diff", "--tool", "difft"]
        fcd = ["diff", "--tool", "fcstd"]
        gd = ["diff", "--git"]
        gdiff = ["diff", "--git"]
        ls = ["file", "list"]

        [revset-aliases]
        "closest_bookmark(to)" = "heads(::to & bookmarks())"
        "fork_history(to, from)" = "fork_point(to | from)..@"

        [template-aliases]
        "format_timestamp(timestamp)" = "timestamp.ago()"

        [merge-tools.mergiraf]
        program = "mergiraf"
        merge-args = ["merge", "$base", "$left", "$right", "-o", "$output"]

        [merge-tools.difft]
        program = "difft"
        diff-args = ["--context", "5", "--color=always", "$left", "$right"]

        [merge-tools.fcstd]
        program = "${home}/.config/nushell/fcdiff.nu"
        diff-args = ["$left", "$right"]

        [snapshot]
        max-new-file-size = 13200000

        [revsets]
        bookmark-advance-to = '@-'
      '';

      "jjui/config.toml".text = ''
        [revisions]
        revset = ".."
      '';
    };
  };
}
