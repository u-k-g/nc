{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.generators) toJSON;
  inherit (lib.meta) getExe;
  inherit (lib.strings) concatMapStringsSep escapeShellArg makeBinPath;
  inherit (lib.trivial) importJSON;

  codexHookDir = "/etc/codex/hooks";
  codexGitPolicyName = "codex-git-policy.py";

  blockedGitSubcommands = [
    "am"
    "archimport"
    "backfill"
    "bisect"
    "checkout-index"
    "cherry-pick"
    "clean"
    "commit"
    "commit-tree"
    "credential"
    "credential-cache"
    "credential-store"
    "cvsexportcommit"
    "cvsimport"
    "cvsserver"
    "daemon"
    "fast-import"
    "fetch-pack"
    "filter-branch"
    "gui"
    "history"
    "imap-send"
    "index-pack"
    "init"
    "instaweb"
    "merge"
    "merge-file"
    "merge-index"
    "merge-one-file"
    "mergetool"
    "mktag"
    "mktree"
    "mv"
    "multi-pack-index"
    "pack-objects"
    "pack-refs"
    "p4"
    "prune-packed"
    "push"
    "quiltimport"
    "read-tree"
    "rebase"
    "replay"
    "reset"
    "restore"
    "revert"
    "rm"
    "scalar"
    "send-email"
    "send-pack"
    "sparse-checkout"
    "svn"
    "tag"
    "unpack-objects"
    "update-index"
    "update-ref"
    "update-server-info"
    "write-tree"
  ];

  allowedGitSubcommands = [
    "annotate"
    "archive"
    "blame"
    "cat-file"
    "check-attr"
    "check-ignore"
    "check-mailmap"
    "check-ref-format"
    "checkout"
    "cherry"
    "clone"
    "column"
    "count-objects"
    "describe"
    "diff"
    "diff-files"
    "diff-index"
    "diff-pairs"
    "diff-tree"
    "difftool"
    "fast-export"
    "fetch"
    "for-each-ref"
    "fsck"
    "gc"
    "get-tar-commit-id"
    "grep"
    "help"
    "last-modified"
    "log"
    "ls-files"
    "ls-remote"
    "ls-tree"
    "maintenance"
    "merge-base"
    "merge-tree"
    "name-rev"
    "pack-redundant"
    "prune"
    "pull"
    "range-diff"
    "repack"
    "repo"
    "request-pull"
    "rev-list"
    "rev-parse"
    "shortlog"
    "show"
    "show-branch"
    "show-index"
    "show-ref"
    "status"
    "submodule"
    "switch"
    "var"
    "verify-commit"
    "verify-pack"
    "version"
    "whatchanged"
  ];

  allowGitRule =
    subcommand: ''prefix_rule(pattern = ["git", ${toJSON { } subcommand}], decision = "allow")'';

  gitSubcommandList = values: toJSON { } values;

  codexGitPolicy = pkgs.writeText "codex-git-policy.py" ''
    import json
    import os
    import shlex
    import sys

    ALLOW_ANY = {
        "annotate",
        "archive",
        "blame",
        "cat-file",
        "check-attr",
        "check-ignore",
        "check-mailmap",
        "check-ref-format",
        "cherry",
        "clone",
        "column",
        "count-objects",
        "describe",
        "diff",
        "diff-files",
        "diff-index",
        "diff-pairs",
        "diff-tree",
        "difftool",
        "fast-export",
        "fetch",
        "for-each-ref",
        "fsck",
        "gc",
        "get-tar-commit-id",
        "grep",
        "help",
        "last-modified",
        "log",
        "ls-files",
        "ls-remote",
        "ls-tree",
        "maintenance",
        "merge-base",
        "merge-tree",
        "name-rev",
        "pack-redundant",
        "prune",
        "pull",
        "range-diff",
        "repack",
        "repo",
        "rev-list",
        "rev-parse",
        "request-pull",
        "show",
        "show-branch",
        "show-index",
        "show-ref",
        "shortlog",
        "status",
        "submodule",
        "var",
        "verify-commit",
        "verify-pack",
        "whatchanged",
        "version",
    }
    DENY_ALWAYS = {
        "am",
        "archimport",
        "backfill",
        "bisect",
        "checkout-index",
        "cherry-pick",
        "clean",
        "commit",
        "commit-tree",
        "credential",
        "credential-cache",
        "credential-store",
        "cvsexportcommit",
        "cvsimport",
        "cvsserver",
        "daemon",
        "fast-import",
        "fetch-pack",
        "filter-branch",
        "gui",
        "history",
        "imap-send",
        "index-pack",
        "init",
        "instaweb",
        "merge",
        "merge-file",
        "merge-index",
        "merge-one-file",
        "mergetool",
        "mktag",
        "mktree",
        "mv",
        "multi-pack-index",
        "pack-objects",
        "pack-refs",
        "p4",
        "prune-packed",
        "push",
        "quiltimport",
        "read-tree",
        "rebase",
        "replay",
        "reset",
        "revert",
        "rm",
        "scalar",
        "send-email",
        "send-pack",
        "sparse-checkout",
        "svn",
        "tag",
        "unpack-objects",
        "update-index",
        "update-ref",
        "update-server-info",
        "write-tree",
    }

    SHELL_SEPARATORS = {"&&", "||", ";", "|"}
    SHELL_WRAPPERS = {"builtin", "command", "noglob"}
    BRANCH_INSPECT_FLAGS = {
        "-a",
        "--all",
        "-r",
        "--remotes",
        "-v",
        "-vv",
        "--verbose",
        "--list",
        "--contains",
        "--no-contains",
        "--merged",
        "--no-merged",
        "--points-at",
        "--show-current",
        "--column",
        "--no-column",
        "--color",
        "--no-color",
        "--format",
        "--sort",
    }
    BRANCH_INSPECT_PREFIXES = {
        "--color=",
        "--column=",
        "--format=",
        "--sort=",
    }
    BRANCH_MUTATING_FLAGS = {
        "-c",
        "-C",
        "-d",
        "-D",
        "-f",
        "-m",
        "-M",
        "--copy",
        "--create-reflog",
        "--delete",
        "--edit-description",
        "--force",
        "--move",
        "--no-create-reflog",
        "--set-upstream-to",
        "--track",
        "--unset-upstream",
    }
    BUNDLE_INSPECT_MODES = {"list-heads", "verify"}
    COMMIT_GRAPH_INSPECT_MODES = {"verify"}
    NOTES_INSPECT_MODES = {"list", "show"}
    REPLACE_INSPECT_MODES = {"-l", "--list"}
    RERERE_INSPECT_MODES = {"diff", "status"}
    SYMBOLIC_REF_INSPECT_FLAGS = {"--short", "-q", "--quiet", "--recurse-submodules"}
    WORKTREE_INSPECT_MODES = {"list"}


    def split_commands(command):
        lexer = shlex.shlex(command, posix=True, punctuation_chars=True)
        lexer.whitespace_split = True
        argv = []
        for token in lexer:
            if token in SHELL_SEPARATORS:
                if argv:
                    yield argv
                    argv = []
            else:
                argv.append(token)
        if argv:
            yield argv


    def unwrap_shell_helpers(argv):
        while argv and argv[0] in SHELL_WRAPPERS:
            argv = argv[1:]
        return argv


    def find_git_argv(argv):
        argv = unwrap_shell_helpers(argv)
        if not argv:
            return None

        if os.path.basename(argv[0]) == "git":
            return argv

        if os.path.basename(argv[0]) == "sudo" and any(
            os.path.basename(arg) == "git" for arg in argv[1:]
        ):
            return ["git", "__sudo__"]

        return None


    def is_safe_branch(rest):
        if rest == []:
            return True

        has_inspect_mode = False
        for arg in rest:
            if arg in BRANCH_MUTATING_FLAGS or any(
                arg.startswith(f"{flag}=") for flag in BRANCH_MUTATING_FLAGS
            ):
                return False

            if arg in BRANCH_INSPECT_FLAGS or any(
                arg.startswith(prefix) for prefix in BRANCH_INSPECT_PREFIXES
            ):
                has_inspect_mode = True
                continue

            if arg.startswith("-"):
                return False

            if not has_inspect_mode:
                return False

        return has_inspect_mode


    def is_safe_format_patch(rest):
        if "--stdout" not in rest:
            return False

        return all(
            not arg.startswith("-o")
            and not arg.startswith("--output-directory")
            for arg in rest
        )


    def only_flags_or_args(rest, allowed_flags):
        return all(not arg.startswith("-") or arg in allowed_flags for arg in rest)


    def is_safe_symbolic_ref(rest):
        if not only_flags_or_args(rest, SYMBOLIC_REF_INSPECT_FLAGS):
            return False

        refs = [arg for arg in rest if not arg.startswith("-")]
        return len(refs) == 1


    def is_safe_git(argv):
        if len(argv) < 2:
            return False

        subcommand = argv[1]
        rest = argv[2:]

        if subcommand.startswith("-"):
            return False

        if subcommand in DENY_ALWAYS:
            return False

        if subcommand in ALLOW_ANY:
            return True

        if subcommand == "apply":
            safe_apply_flags = {"--check", "--stat", "--numstat", "--summary"}
            return len(rest) >= 1 and all(
                arg in safe_apply_flags or not arg.startswith("-")
                for arg in rest
            ) and any(arg in safe_apply_flags for arg in rest)

        if subcommand == "branch":
            return is_safe_branch(rest)

        if subcommand == "bugreport":
            return False

        if subcommand == "checkout":
            branch_creation_flags = {"-b", "-B", "-t", "--orphan", "--track"}
            return not any(
                arg in branch_creation_flags
                or arg.startswith("-b")
                or arg.startswith("-B")
                or arg.startswith("-t")
                or arg.startswith("--orphan=")
                or arg.startswith("--track=")
                for arg in rest
            )

        if subcommand == "bundle":
            return len(rest) >= 1 and rest[0] in BUNDLE_INSPECT_MODES

        if subcommand == "config":
            return (
                len(rest) >= 1
                and (
                    rest[0]
                    in {
                        "--get",
                        "--get-all",
                        "--get-color",
                        "--get-colorbool",
                        "--get-regexp",
                        "--includes",
                        "--list",
                        "--name-only",
                        "--null",
                        "-l",
                        "-z",
                    }
                    or rest[0].startswith("--get-urlmatch")
                )
            ) or rest == ["--list"] or rest == ["-l"]

        if subcommand == "commit-graph":
            return len(rest) >= 1 and rest[0] in COMMIT_GRAPH_INSPECT_MODES

        if subcommand == "format-patch":
            return is_safe_format_patch(rest)

        if subcommand == "hash-object":
            return "-w" not in rest and "--stdin-paths" not in rest

        if subcommand == "interpret-trailers":
            return "--parse" in rest or "--only-trailers" in rest

        if subcommand == "notes":
            return rest == [] or rest[0] in NOTES_INSPECT_MODES

        if subcommand == "reflog":
            return rest == [] or (len(rest) >= 1 and rest[0] == "show")

        if subcommand == "remote":
            return (
                rest == []
                or rest == ["-v"]
                or (len(rest) >= 1 and rest[0] in {"get-url", "show"})
            )

        if subcommand == "replace":
            return len(rest) >= 1 and rest[0] in REPLACE_INSPECT_MODES

        if subcommand == "rerere":
            return len(rest) >= 1 and rest[0] in RERERE_INSPECT_MODES

        if subcommand == "stash":
            return rest == ["list"] or (len(rest) >= 1 and rest[0] == "show")

        if subcommand == "switch":
            branch_creation_flags = {
                "-c",
                "-C",
                "-t",
                "--create",
                "--force-create",
                "--orphan",
                "--track",
            }
            return not any(
                arg in branch_creation_flags
                or arg.startswith("-c")
                or arg.startswith("-C")
                or arg.startswith("-t")
                or arg.startswith("--create=")
                or arg.startswith("--force-create=")
                or arg.startswith("--orphan=")
                or arg.startswith("--track=")
                for arg in rest
            )

        if subcommand == "symbolic-ref":
            return is_safe_symbolic_ref(rest)

        if subcommand == "worktree":
            return len(rest) >= 1 and rest[0] in WORKTREE_INSPECT_MODES

        return False


    def deny(event_name, reason):
        if event_name == "PermissionRequest":
            payload = {
                "hookSpecificOutput": {
                    "hookEventName": "PermissionRequest",
                    "decision": {
                        "behavior": "deny",
                        "message": reason,
                    },
                },
            }
        else:
            payload = {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": reason,
                },
            }
        print(json.dumps(payload))


    def patch_touches_git_metadata(patch):
        path_prefixes = (
            "*** Add File: ",
            "*** Update File: ",
            "*** Delete File: ",
            "*** Move to: ",
        )

        for line in patch.splitlines():
            for prefix in path_prefixes:
                if line.startswith(prefix):
                    path = line[len(prefix):].strip().replace("\\", "/")
                    if ".git" in path.split("/"):
                        return True

        return False


    data = json.load(sys.stdin)
    event_name = data.get("hook_event_name", "PreToolUse")
    command = data.get("tool_input", {}).get("command")

    if not isinstance(command, str):
        sys.exit(0)

    if data.get("tool_name") == "apply_patch":
        if patch_touches_git_metadata(command):
            deny(event_name, "Direct edits to Git metadata are blocked.")
        sys.exit(0)

    try:
        commands = list(split_commands(command))
    except ValueError:
        deny(event_name, "Git command blocked because Codex could not parse it safely.")
        sys.exit(0)

    for argv in commands:
        git_argv = find_git_argv(argv)
        if git_argv is not None and not is_safe_git(git_argv):
            deny(event_name, "Git command is not on the protected-repository allowlist.")
            sys.exit(0)
  '';

  hook = {
    type = "command";
    command = "${getExe pkgs.python3} ${codexHookDir}/${codexGitPolicyName}";
    timeout = 5;
    statusMessage = "Checking git command policy";
  };
in
{
  environment.etc = {
    "codex/hooks/${codexGitPolicyName}".source = codexGitPolicy;

    "codex/requirements.toml".text = ''
      [features]
      hooks = true

      [hooks]
      managed_dir = "${codexHookDir}"

      [[hooks.PreToolUse]]
      matcher = "^(Bash|apply_patch)$"

      [[hooks.PreToolUse.hooks]]
      type = "command"
      command = "${hook.command}"
      timeout = ${toString hook.timeout}
      statusMessage = "${hook.statusMessage}"

      [[hooks.PermissionRequest]]
      matcher = "^(Bash|apply_patch)$"

      [[hooks.PermissionRequest.hooks]]
      type = "command"
      command = "${hook.command}"
      timeout = ${toString hook.timeout}
      statusMessage = "${hook.statusMessage}"

      [rules]
      prefix_rules = [
        { pattern = [{ token = "git" }, { any_of = ${gitSubcommandList blockedGitSubcommands} }], decision = "forbidden", justification = "Git staging, history, remote configuration, and publishing operations are blocked." },
        { pattern = [{ token = "git" }, { token = "branch" }, { any_of = ${
          gitSubcommandList [
            "-c"
            "-C"
            "-d"
            "-D"
            "-m"
            "-M"
          ]
        } }], decision = "forbidden" },
        { pattern = [{ token = "git" }, { token = "remote" }, { any_of = ${
          gitSubcommandList [
            "add"
            "remove"
            "rename"
            "set-url"
            "prune"
            "update"
          ]
        } }], decision = "forbidden" },
        { pattern = [{ token = "git" }, { token = "stash" }, { any_of = ${
          gitSubcommandList [
            "apply"
            "branch"
            "clear"
            "drop"
            "pop"
            "push"
            "save"
          ]
        } }], decision = "forbidden" },
        { pattern = [{ token = "git" }, { token = "worktree" }, { any_of = ${
          gitSubcommandList [
            "add"
            "lock"
            "move"
            "prune"
            "remove"
            "unlock"
          ]
        } }], decision = "forbidden" },
      ]
    '';
  };

  home.users.${config.nc.user.name} = {
    # flake.lock pins npm's latest stable package metadata; pnpm installs that version.
    activationScripts.codex-install = /* bash */ ''
      (
        set -euo pipefail
        export PNPM_HOME=${escapeShellArg "${config.nc.user.homeDirectory}/.local/share/pnpm"}
        export PATH="$PNPM_HOME/bin:$PNPM_HOME:${
          makeBinPath [
            pkgs.nodejs
            pkgs.coreutils
          ]
        }:$PATH"
        export SHELL=${getExe pkgs.bashInteractive}
        ${getExe pkgs.pnpm} add --global --save-exact \
          ${escapeShellArg "@openai/codex@${(importJSON inputs.codex.outPath).version}"}
      )
    '';

    files = {
      ".codex/rules/git.rules".text = ''
        # Codex rules are prefix-based. Do not add a broad forbidden ["git"]
        # rule here: forbidden rules override more specific operation allows.
        # The managed hook blocks staging, history, ref, and remote mutations.

        ${concatMapStringsSep "\n" allowGitRule allowedGitSubcommands}
        prefix_rule(pattern = ["git", "apply", "--check"], decision = "allow")
        prefix_rule(pattern = ["git", "apply", "--numstat"], decision = "allow")
        prefix_rule(pattern = ["git", "apply", "--stat"], decision = "allow")
        prefix_rule(pattern = ["git", "apply", "--summary"], decision = "allow")
        prefix_rule(pattern = ["git", "branch", "--all"], decision = "allow")
        prefix_rule(pattern = ["git", "branch", "--contains"], decision = "allow")
        prefix_rule(pattern = ["git", "branch", "--format"], decision = "allow")
        prefix_rule(pattern = ["git", "branch", "--list"], decision = "allow")
        prefix_rule(pattern = ["git", "branch", "--merged"], decision = "allow")
        prefix_rule(pattern = ["git", "branch", "--no-contains"], decision = "allow")
        prefix_rule(pattern = ["git", "branch", "--no-merged"], decision = "allow")
        prefix_rule(pattern = ["git", "branch", "--points-at"], decision = "allow")
        prefix_rule(pattern = ["git", "branch", "--remotes"], decision = "allow")
        prefix_rule(pattern = ["git", "branch", "--show-current"], decision = "allow")
        prefix_rule(pattern = ["git", "branch", "--sort"], decision = "allow")
        prefix_rule(pattern = ["git", "branch", "--verbose"], decision = "allow")
        prefix_rule(pattern = ["git", "branch", "-a"], decision = "allow")
        prefix_rule(pattern = ["git", "branch", "-r"], decision = "allow")
        prefix_rule(pattern = ["git", "branch", "-v"], decision = "allow")
        prefix_rule(pattern = ["git", "branch", "-vv"], decision = "allow")
        prefix_rule(pattern = ["git", "bundle", ["list-heads", "verify"]], decision = "allow")
        prefix_rule(pattern = ["git", "commit-graph", "verify"], decision = "allow")
        prefix_rule(pattern = ["git", "config", ["--get", "--get-all", "--get-color", "--get-colorbool", "--get-regexp", "--get-urlmatch", "--includes", "--list", "--name-only", "--null", "-l", "-z"]], decision = "allow")
        prefix_rule(pattern = ["git", "format-patch", "--stdout"], decision = "allow")
        prefix_rule(pattern = ["git", "notes", ["list", "show"]], decision = "allow")
        prefix_rule(pattern = ["git", "reflog", "show"], decision = "allow")
        prefix_rule(pattern = ["git", "remote", ["get-url", "show"]], decision = "allow")
        prefix_rule(pattern = ["git", "replace", ["-l", "--list"]], decision = "allow")
        prefix_rule(pattern = ["git", "rerere", ["diff", "status"]], decision = "allow")
        prefix_rule(pattern = ["git", "stash", ["list", "show"]], decision = "allow")
        prefix_rule(pattern = ["git", "symbolic-ref", ["--short", "-q", "--quiet", "--recurse-submodules"]], decision = "allow")
        prefix_rule(pattern = ["git", "worktree", "list"], decision = "allow")

        prefix_rule(
            pattern = ["git", ${gitSubcommandList blockedGitSubcommands}],
            decision = "forbidden",
            justification = "Git staging, history, remote configuration, and publishing operations are blocked.",
        )
        prefix_rule(pattern = ["git", "branch", ["-c", "-C", "-d", "-D", "-m", "-M"]], decision = "forbidden")
        prefix_rule(pattern = ["git", "remote", ["add", "remove", "rename", "set-url", "prune", "update"]], decision = "forbidden")
        prefix_rule(pattern = ["git", "stash", ["apply", "branch", "clear", "drop", "pop", "push", "save"]], decision = "forbidden")
        prefix_rule(pattern = ["git", "tag"], decision = "forbidden")
        prefix_rule(pattern = ["git", "worktree", ["add", "lock", "move", "prune", "remove", "unlock"]], decision = "forbidden")
      '';
    };
  };
}
