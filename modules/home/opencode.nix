{ config, ... }:

{
  home-manager.users.${config.nc.user.name} = {
    programs.opencode = {
      enable = true;

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
        scroll_speed = 1;
      };
    };

  };
}
