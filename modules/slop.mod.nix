{ inputs, ... }:

{
  flake.homeModules.slop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets) mapAttrs' mapAttrsToList nameValuePair;
      inherit (lib.lists) elemAt groupBy;
      inherit (lib.strings)
        concatMapStringsSep
        escapeShellArg
        removePrefix
        removeSuffix
        splitString
        ;

      # pstack marks every skill explicit-only. Strip that flag at build time so
      # these fire on their own, like the rest of the set. Everything else in the
      # skill files comes from the repo untouched.
      pstackSkills = [
        "correct"
        "principle-boundary-discipline"
        "principle-encode-lessons-in-structure"
        "principle-fix-root-causes"
        "principle-foundational-thinking"
        "principle-guard-the-context-window"
        "principle-laziness-protocol"
        "principle-minimize-reader-load"
        "principle-subtract-before-you-add"
      ];

      pstackSkill =
        name:
        let
          dir = inputs.pstack + "/skills/${name}";
          skillMd = lib.replaceStrings [ "\ndisable-model-invocation: true\n" ] [ "\n" ] (
            builtins.readFile (dir + "/SKILL.md")
          );
        in
        pkgs.runCommand "agent-skill-${name}" { }
        <| ''
          mkdir -p "$out"
          cp -r ${dir}/. "$out"/
          chmod -R u+w "$out"
          rm -f "$out/SKILL.md"
          cp ${pkgs.writeText "SKILL.md" skillMd} "$out/SKILL.md"
        '';
    in
    {
      # Generate each skill as real files rather than symlinks so every harness reads them.
      files =
        {
          ".agents/skills/handoff/SKILL.md".text = ''
            ---
            name: handoff
            description: Compact the current conversation into a handoff document for another agent to pick up.
            argument-hint: "What will the next session be used for?"
            disable-model-invocation: true
            ---

            Write a handoff document summarising the current conversation so a fresh agent can continue the work. Save to the temporary directory of the user's OS - not the current workspace.

            Include a "suggested skills" section in the document, naming which skills the next agent should call the Skill tool for.

            Do not duplicate content already captured in other artifacts (specs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

            Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

            If the user passed arguments, treat them as a description of what the next session will focus on and tailor the doc accordingly.
          '';

          ".agents/skills/nix/SKILL.md".text = ''
            ---
            name: nix
            description: Use when editing *.nix, flakes, NixOS, nix-darwin, Pi deploy, linux-builder, or Nix CLI.
            ---

            # Nix

            Reference for structure and style: `git@github.com:RGBCube/ncc.git` (local clone `01-projects/02-clones/ncc` if present). Prefer concrete ncc patterns over guesses.

            ## CLI

            - New `nix` CLI only: `nix build`, `nix copy`, `nix profile` / `nix build --profile`. Never `nix-*` (`nix-build`, `nix-env`, `nix-store` except image first-boot `nix-store --load-db`).
            - Never `nh` or `nixos-rebuild`.
            - `--builders`, not `--store`, for remote builds.
            - Long flags in committed scripts.
            - Never `builtins.getFlake`. Use flake refs on the CLI.
            - Never `find /nix/store` or anything equivalent. Run `nix flake archive --json` once, then use its literal paths in separate search commands. Do not chain archive and search commands or put the paths in variables.
            - No `--impure`. No `builtins.getEnv`.

            ## Style

            - Never use `rec`. Worst case, define a custom `fix`.
            - No `builtins.` in modules; use `lib`.
            - `let inherit (lib.lists) head;` with full submodule paths. Never `inherit (lib) foo` unless `foo` has no submodule path. Prefer `lib.lists.singleton` over a one-item list.
            - Dendritic flake-parts: `*.mod.nix` auto-discovery. One concern per file. Packages that are their own tool get their own module with their `perSystem` definition separate from the module that uses them.
            - Prefer `''${getExe pkgs.something}` (or `getExe'`) over bare command names in shell aliases and scripts. Use `package = getExe pkgs.something` when there are multiple usages.
            - Never put values in `let` bindings that duplicate module system options. If a value is set through `config.*`, reference it through `config.*`. Hardcoded `let` values that could be overridden via the module system are forbidden. `let` is fine for computed derivations, helper functions, and `getExe` shortcuts.
            - Prefer destructuring attrset arguments when it improves clarity: `{ home, ... }:` instead of `value: value.home`.
            - On Linux, use KDE applications (except Plasma). Dolphin over Thunar, Ark over xfce archive tools.
            - Use `"''${path}"` when the derivation context must survive. Never `toString` for those paths.
            - Inline packages use `pkgs.callPackage` with destructured args, e.g. `pkgs.callPackage ({ stdenv, writeText }: ...) { }`.
            - For inline source code in packages, use `writeText` directly in the `src` attribute rather than a separate `let` binding.
            - `/* lang */` before multiline code strings.
            - Prefer `mkIf` on the individual option: `foo.bar = mkIf condition value;` rather than `foo = mkIf condition { bar = value; };` when possible.
            - Prefer `<|` (pipe-last) when the parenthesized expression is the final argument: `mkIf condition <| toJSON { ... }` instead of `mkIf condition (toJSON { ... })`. This does not apply when the parenthesized expression is not the last argument, e.g. `callPackage (...) { }`. `if`, `let`, and lambda expressions on the RHS still need parentheses.
            - Empty line between unrelated options.

            Do not invent extra deploy wrappers. The deployable is a store path.

            ## Pi appliances

            Read the project's `AGENTS.md` for its appliance policy. Do not copy workstation tooling (`nh`, `dix`, `nom`, desktop modules) onto the drone. Full-system Darwin uses the project's `darwin.linux-builder` VM only for that `nix build`. x86 Linux uses binfmt/`extra-platforms`. The Pi is never a builder.
          '';

          ".agents/skills/whitelist-git-ignore/SKILL.md".text = ''
            ---
            name: whitelist-git-ignore
            disable-model-invocation: true
            description: Create or update a deny-by-default repository .gitignore that broadly admits project source file types in source directories while requiring exact paths for docs, scripts, configuration, and local agent files. Use for whitelist-only, allowlist, deny-by-default, UKG-style, or nc-style .gitignore requests.
            ---

            # Whitelist Git Ignore

            Create a deny-by-default `.gitignore` with two kinds of allow rules: scoped source extensions for ordinary project code, and exact paths for files that could be local notes, scripts, agent material, or configuration. New source files in approved source directories can be tracked without editing `.gitignore`; other new files stay ignored until deliberately allowed. Inspect the target repository and tailor the whitelist.

            ## Build the whitelist

            1. Read repository instructions such as `AGENTS.md` before editing.
            2. Inspect the existing `.gitignore`, `jj status`, `jj file list`, and the repository's top-level structure. Distinguish source/configuration from build outputs, caches, dependencies, secrets, editor files, and other generated state.
            3. If tracked files already exist, ensure the new rules continue to admit every intentionally tracked file. Treat surprising tracked artifacts as items to flag, not automatically whitelist.
            4. Write rules in this order, with blank lines between groups:

            ```gitignore
            *

            !/.gitignore

            !/src/
            !/src/**/
            !/docs/

            !/src/**/*.ts
            !/src/**/*.tsx

            !/README.md
            !/docs/architecture.md
            ```

            5. Reopen source directories and their descendants only where new files of approved source types belong. Scope broad extension rules to those directories, such as `!/src/**/*.ts`; do not use a repository-wide `!*.ts` unless every reopened directory should admit TypeScript files.
            6. Admit Markdown, Nu, shell scripts, agent skills, local notes, configuration, and shipped assets by exact paths. Do not use broad rules such as `!*.md`, `!*.nu`, or `!*.sh`. Reopen only the exact ancestor directories needed for these files.
            7. Keep the whitelist narrow. Do not reopen generated directories such as `.direnv`, `node_modules`, `dist`, `build`, coverage output, or caches. Do not admit secrets. A local-only file with an approved source extension belongs outside the broadly admitted source directories.
            8. Preserve intentional comments only when they clarify a non-obvious exception. Keep the file compact and deterministic.

            ## Verify the result

            Inspect `jj diff -- .gitignore` and `jj status`. Enumerate `jj file list` and check that every intended tracked file is covered by either a scoped source rule or an exact path. Test at least:

            - an allowed root file;
            - a new source file with an approved extension in a source directory;
            - a new Markdown, Nu, or shell file beside an admitted one that remains ignored;
            - a new agent skill that remains ignored;
            - a file under a generated directory that remains ignored;
            - an exact extensionless allowed file.

            Report the source categories and exact paths added, plus any intentionally excluded existing files. Do not change tracking state unless the user explicitly asks.
          '';

          ".agents/skills/wrtcmtmsg/SKILL.md".text = ''
            ---
            name: wrtcmtmsg
            disable-model-invocation: true
            description: Write a concise one-line VCS commit message subject from a diff or from current uncommitted changes. Use when the user asks for a commit message, commit subject, git commit title, change summary for committing, or invokes $wrtcmtmsg. If the user provides a diff, use that diff instead of inspecting the working tree; otherwise default to staged, unstaged, and untracked local changes.
            ---

            # Write Commit Message

            You are an expert at writing concise VCS commit messages. Write a single-line subject that captures the highest-level intent of the change. Only return the commit message to the user. Do not return anything else.

            ## Source

            - If the user provides a diff, patch, or pasted change summary, use that as the source of truth.
            - If the user does not provide a diff, inspect the current repository's uncommitted changes:
              - `git diff --cached`
              - `git diff`
              - `git status --short` for untracked files
              - Read untracked files only when needed to understand their purpose.
            - Read files and try to understand the relevant codebase context when needed to produce a more relevant scope or description.
            - If no changes can be found, return a short message that says there are no changes to summarize.

            ## Format

            Return plain text in this format:

            <scope>: <description>

            The scope is the area of the codebase being changed, such as a module, component, package, directory, command, feature area, or subsystem. It is not a conventional-commit type like `feat`, `fix`, `refactor`, `chore`, `docs`, or `test` unless that is truly the name of the changed area.

            ## Style

            Every rule below changes the subject. Apply them all.

            - Capture the highest-level intent of the change. Prefer broad architectural or product impact over incidental mechanical edits, renamed symbols, generated files, formatting, or whichever patch hunk appears first.
            - Start with an imperative verb: "add", "remove", "move". Not "adds", "adding", or "addition of".
            - Keep the active voice. Write "the compiler validates queries", not "queries are validated".
            - Use the codebase's own names. Write the real module, file, flag, or command name rather than a description of it, and drop the backticks. A subject that says "the sync worker" when the code says `SyncWorker` teaches the reader a second name.
            - Give each thing one name. Do not cycle synonyms between the scope and the description to avoid repeating a word.
            - Use the short everyday word. "use", not "utilize". "fix", not "remediate". A long word has to buy its length with precision.
            - Cut every word that does no work. If the subject survives without a word, the word goes.
            - Keep the articles where dropping them leaves two readings. "Remove backup file" reads two ways. "Remove the backup file" reads one.
            - One thought per subject. If the change does two things, name the one the rest hangs off.
            - Sentence case. No trailing punctuation.
            - Do not include any backticks anywhere in the output, including inline-code wrappers or Markdown code fences.
            - Do not include bullets, explanation, alternatives, quotes, or prefixes like `Commit message:`.
          '';

        }
        |> mapAttrsToList (path: { text }: { inherit path text; })
        |> groupBy ({ path, ... }: elemAt (splitString "/" path) 2)
        |> mapAttrs' (
          name: files:
          nameValuePair ".agents/skills/${name}" {
            source =
              pkgs.runCommand "agent-skill-${name}" { }
              <| concatMapStringsSep "\n" (
                { path, text }:
                ''
                  install -Dm444 ${pkgs.writeText "skill-file" text} "$out"/${
                    escapeShellArg <| removePrefix ".agents/skills/${name}/" path
                  }
                ''
              ) files;
          }
        )
        |> (
          skills:
          skills
          // lib.listToAttrs (
            map (name: nameValuePair ".agents/skills/${name}" { source = pstackSkill name; }) pstackSkills
          )
          // {
            ".agents/skills/design-taste-frontend".source =
              pkgs.runCommand "agent-skill-design-taste-frontend" { }
              <| ''
                mkdir -p "$out"
                cp -r ${inputs.taste-skill}/skills/taste-skill/. "$out"/
              '';
            ".agents/AGENTS.md".text =
              ''
                Default to `jj`. only use `git` when there is no other option.
                Only run mutating VCS commands when told to

                ## Shell

                The user runs nushell. Commands you hand them must be nushell.

                ## Writing

                Rules for text you create: replies, commit messages, comments, docs, PR descriptions.
                Cut: AI vocabulary (delve, tapestry); "serves as" for "is"; "not just X, but Y"; "in order to"; stacked hedges; unsourced "Experts believe"; em dashes, mid-sentence colons, title case; chatbot phrases, sycophancy; metaphor nouns (substrate, ratchet).

                Write: what a thing does, not how it feels. Name the mechanism or the number. Active voice, plain words. If it could appear in any project's docs, cut it.'';
            ".config/opencode/AGENTS.md".source = config.files.".agents/AGENTS.md".target;
            ".cursor/rules/agents.mdc".text = ''
              ---
              description: Agent instructions. Follow these rules at all times.
              alwaysApply: true
              ---

              ${removeSuffix "\n" config.files.".agents/AGENTS.md".text}
            '';
          }
        )
        |> (
          files:
          files
          // lib.mapAttrs' (
            path: value: nameValuePair (lib.replaceStrings [ ".agents" ] [ ".claude" ] path) value
          ) (lib.filterAttrs (path: _: lib.hasPrefix ".agents/skills/" path) files)
          // {
            ".claude/CLAUDE.md".source = config.files.".agents/AGENTS.md".target;
          }
        );
    };
}
