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
          skillMd =
            lib.replaceStrings [ "\ndisable-model-invocation: true\n" ] [ "\n" ]
              (builtins.readFile (dir + "/SKILL.md"));
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
          ".agents/skills/ast-grep/SKILL.md".text = ''
            ---
            name: ast-grep
            description: Use when a code search requires AST-aware structural matching or the user asks for ast-grep.
            ---

            # ast-grep structural search

            Use ast-grep when text search cannot express the required code structure. Confirm the language, target pattern, scope, and exclusions, then test the simplest viable rule on a small representative snippet before searching the codebase.

            Prefer `ast-grep run --pattern` for a single-node pattern. Use `ast-grep scan` with a YAML rule for relationships such as `inside` or `has`, negative matches, or combined conditions. Add `stopBy: end` to relational rules unless a nearer stopping boundary is intentional.

            Read [references/workflow.md](references/workflow.md) when selecting commands, testing a rule, debugging a miss, or handling shell escaping. Read [references/rule_reference.md](references/rule_reference.md) only when detailed rule syntax, relationships, composite rules, or metavariables are needed.

            If ast-grep is unavailable, continue with ordinary search or report the limitation; do not install it unless asked.
          '';

          ".agents/skills/ast-grep/references/rule_reference.md".text = ''
            # ast-grep Rule Reference

            This document provides comprehensive documentation for ast-grep rule syntax, covering all rule types and metavariables.

            ## Introduction to ast-grep Rules

            ast-grep rules are declarative specifications for matching and filtering Abstract Syntax Tree (AST) nodes. They enable structural code search and analysis by defining conditions an AST node must meet to be matched.

            ### Rule Categories

            ast-grep rules are categorized into three types:

            * **Atomic Rules**: Match individual AST nodes based on intrinsic properties like code patterns (`pattern`), node type (`kind`), or text content (`regex`).
            * **Relational Rules**: Define conditions based on a target node's position or relationship to other nodes (e.g., `inside`, `has`, `precedes`, `follows`).
            * **Composite Rules**: Combine other rules using logical operations (AND, OR, NOT) to form complex matching criteria (e.g., `all`, `any`, `not`, `matches`).

            ## Anatomy of an ast-grep Rule Object

            The ast-grep rule object is the core configuration unit defining how ast-grep identifies and filters AST nodes. It's typically written in YAML format.

            ### General Structure

            Every field within an ast-grep Rule Object is optional, but at least one "positive" key (e.g., `kind`, `pattern`) must be present.

            A node matches a rule if it satisfies all fields defined within that rule object, implying an implicit logical AND operation.

            For rules using metavariables that depend on prior matching, explicit `all` composite rules are recommended to guarantee execution order.

            ### Rule Object Properties

            | Property | Type | Category | Purpose | Example |
            | :--- | :--- | :--- | :--- | :--- |
            | `pattern` | String or Object | Atomic | Matches AST node by code pattern. | `pattern: console.log($ARG)` |
            | `kind` | String | Atomic | Matches AST node by its kind name. | `kind: call_expression` |
            | `regex` | String | Atomic | Matches node's text by Rust regex. | `regex: ^[a-z]+$` |
            | `nthChild` | number, string, Object | Atomic | Matches nodes by their index within parent's children. | `nthChild: 1` |
            | `range` | RangeObject | Atomic | Matches node by character-based start/end positions. | `range: { start: { line: 0, column: 0 }, end: { line: 0, column: 10 } }` |
            | `inside` | Object | Relational | Target node must be inside node matching sub-rule. | `inside: { pattern: class $C { $$$ }, stopBy: end }` |
            | `has` | Object | Relational | Target node must have descendant matching sub-rule. | `has: { pattern: await $EXPR, stopBy: end }` |
            | `precedes` | Object | Relational | Target node must appear before node matching sub-rule. | `precedes: { pattern: return $VAL }` |
            | `follows` | Object | Relational | Target node must appear after node matching sub-rule. | `follows: { pattern: import $M from '$P' }` |
            | `all` | Array<Rule> | Composite | Matches if all sub-rules match. | `all: [ { kind: call_expression }, { pattern: foo($A) } ]` |
            | `any` | Array<Rule> | Composite | Matches if any sub-rules match. | `any: [ { pattern: foo() }, { pattern: bar() } ]` |
            | `not` | Object | Composite | Matches if sub-rule does not match. | `not: { pattern: console.log($ARG) }` |
            | `matches` | String | Composite | Matches if predefined utility rule matches. | `matches: my-utility-rule-id` |

            ## Atomic Rules

            Atomic rules match individual AST nodes based on their intrinsic properties.

            ### pattern: String and Object Forms

            The `pattern` rule matches a single AST node based on a code pattern.

            **String Pattern**: Directly matches using ast-grep's pattern syntax with metavariables.

            ```yaml
            pattern: console.log($ARG)
            ```

            **Object Pattern**: Offers granular control for ambiguous patterns or specific contexts.

            * `selector`: Pinpoints a specific part of the parsed pattern to match.
              ```yaml
              pattern:
                selector: field_definition
                context: class { $F }
              ```

            * `context`: Provides surrounding code context for correct parsing.

            * `strictness`: Modifies the pattern's matching algorithm (`cst`, `smart`, `ast`, `relaxed`, `signature`).
              ```yaml
              pattern:
                context: foo($BAR)
                strictness: relaxed
              ```

            ### kind: Matching by Node Type

            The `kind` rule matches an AST node by its `tree_sitter_node_kind` name, derived from the language's Tree-sitter grammar. Useful for targeting constructs like `call_expression` or `function_declaration`.

            ```yaml
            kind: call_expression
            ```

            ### regex: Text-Based Node Matching

            The `regex` rule matches the entire text content of an AST node using a Rust regular expression. It's not a "positive" rule, meaning it matches any node whose text satisfies the regex, regardless of its structural kind.

            ### nthChild: Positional Node Matching

            The `nthChild` rule finds nodes by their 1-based index within their parent's children list, counting only named nodes by default.

            * `number`: Matches the exact nth child. Example: `nthChild: 1`
            * `string`: Matches positions using An+B formula. Example: `2n+1`
            * `Object`: Provides granular control:
              * `position`: `number` or An+B string.
              * `reverse`: `true` to count from the end.
              * `ofRule`: An ast-grep rule to filter the sibling list before counting.

            ### range: Position-Based Node Matching

            The `range` rule matches an AST node based on its character-based start and end positions. A `RangeObject` defines `start` and `end` fields, each with 0-based `line` and `column`. `start` is inclusive, `end` is exclusive.

            ## Relational Rules

            Relational rules filter targets based on their position relative to other AST nodes. They can include `stopBy` and `field` options.

            ### inside: Matching Within a Parent Node

            Requires the target node to be inside another node matching the `inside` sub-rule.

            ```yaml
            inside:
              pattern: class $C { $$$ }
              stopBy: end
            ```

            ### has: Matching with a Descendant Node

            Requires the target node to have a descendant node matching the `has` sub-rule.

            ```yaml
            has:
              pattern: await $EXPR
              stopBy: end
            ```

            ### precedes and follows: Sequential Node Matching

            * `precedes`: Target node must appear before a node matching the `precedes` sub-rule.
            * `follows`: Target node must appear after a node matching the `follows` sub-rule.

            Both include `stopBy` but not `field`.

            ### stopBy and field: Refining Relational Searches

            **stopBy**: Controls search termination for relational rules.

            * `"neighbor"` (default): Stops when immediate surrounding node doesn't match.
            * `"end"`: Searches to the end of the direction (root for `inside`, leaf for `has`).
            * `Rule object`: Stops when a surrounding node matches the provided rule (inclusive).

            **field**: Specifies a sub-node within the target node that should match the relational rule. Only for `inside` and `has`.

            **Best Practice**: When unsure, always use `stopBy: end` to ensure the search goes to the end of the direction.

            ## Composite Rules

            Composite rules combine atomic and relational rules using logical operations.

            ### all: Conjunction (AND) of Rules

            Matches a node only if all sub-rules in the list match. Guarantees order of rule matching, important for metavariables.

            ```yaml
            all:
              - kind: call_expression
              - pattern: console.log($ARG)
            ```

            ### any: Disjunction (OR) of Rules

            Matches a node if any sub-rules in the list match.

            ```yaml
            any:
              - pattern: console.log($ARG)
              - pattern: console.warn($ARG)
              - pattern: console.error($ARG)
            ```

            ### not: Negation (NOT) of a Rule

            Matches a node if the single sub-rule does not match.

            ```yaml
            not:
              pattern: console.log($ARG)
            ```

            ### matches: Rule Reuse and Utility Rules

            Takes a rule-id string, matching if the referenced utility rule matches. Enables rule reuse and recursive rules.

            ## Metavariables

            Metavariables are placeholders in patterns to match dynamic content in the AST.

            ### $VAR: Single Named Node Capture

            Captures a single named node in the AST.

            * **Valid**: `$META`, `$META_VAR`, `$_`
            * **Invalid**: `$invalid`, `$123`, `$KEBAB-CASE`
            * **Example**: `console.log($GREETING)` matches `console.log('Hello World')`.
            * **Reuse**: `$A == $A` matches `a == a` but not `a == b`.

            ### $$VAR: Single Unnamed Node Capture

            Captures a single unnamed node (e.g., operators, punctuation).

            **Example**: To match the operator in `a + b`, use `$$OP`.

            ```yaml
            rule:
              kind: binary_expression
              has:
                field: operator
                pattern: $$OP
            ```

            ### $$$MULTI_META_VARIABLE: Multi-Node Capture

            Matches zero or more AST nodes (non-greedy). Useful for variable numbers of arguments or statements.

            * **Example**: `console.log($$$)` matches `console.log()`, `console.log('hello')`, and `console.log('debug:', key, value)`.
            * **Example**: `function $FUNC($$$ARGS) { $$$ }` matches functions with varying parameters/statements.

            ### Non-Capturing Metavariables (_VAR)

            Metavariables starting with an underscore (`_`) are not captured. They can match different content even if named identically, optimizing performance.

            * **Example**: `$_FUNC($_FUNC)` matches `test(a)` and `testFunc(1 + 1)`.

            ### Important Considerations for Metavariable Detection

            * **Syntax Matching**: Only exact metavariable syntax (e.g., `$A`, `$$B`, `$$$C`) is recognized.
            * **Exclusive Content**: Metavariable text must be the only text within an AST node.
            * **Non-working**: `obj.on$EVENT`, `"Hello $WORLD"`, `a $OP b`, `$jq`.

            The ast-grep playground is useful for debugging patterns and visualizing metavariables.

            ## Common Patterns and Examples

            ### Finding Functions with Specific Content

            Find functions that contain await expressions:

            ```yaml
            rule:
              kind: function_declaration
              has:
                pattern: await $EXPR
                stopBy: end
            ```

            ### Finding Code Inside Specific Contexts

            Find console.log calls inside class methods:

            ```yaml
            rule:
              pattern: console.log($$$)
              inside:
                kind: method_definition
                stopBy: end
            ```

            ### Combining Multiple Conditions

            Find async functions that use await but don't have try-catch:

            ```yaml
            rule:
              all:
                - kind: function_declaration
                - has:
                    pattern: await $EXPR
                    stopBy: end
                - not:
                    has:
                      pattern: try { $$$ } catch ($E) { $$$ }
                      stopBy: end
            ```

            ### Matching Multiple Alternatives

            Find any type of console method call:

            ```yaml
            rule:
              any:
                - pattern: console.log($$$)
                - pattern: console.warn($$$)
                - pattern: console.error($$$)
                - pattern: console.debug($$$)
            ```

            ## Troubleshooting Tips

            1. **Rule doesn't match**: Use `dump_syntax_tree` to see the actual AST structure
            2. **Relational rule issues**: Ensure `stopBy: end` is set for deep searches
            3. **Wrong node kind**: Check the language's Tree-sitter grammar for correct kind names
            4. **Metavariable not working**: Ensure it's the only content in its AST node
            5. **Pattern too complex**: Break it down into simpler sub-rules using `all`
          '';

          ".agents/skills/ast-grep/references/workflow.md".text = ''
            # ast-grep workflow

            ## Choose the smallest command

            Use `run` for a direct pattern:

            ```shell
            ast-grep run --pattern 'console.log($ARG)' --lang javascript <path>
            ```

            Use `scan` for relational, composite, or reusable YAML rules:

            ```yaml
            id: async-with-await
            language: javascript
            rule:
              kind: function_declaration
              has:
                pattern: await $EXPR
                stopBy: end
            ```

            ```shell
            ast-grep scan --rule rule.yml <path>
            ```

            ## Build and verify a rule

            1. Write a minimal snippet containing one match and, when useful, one near miss.
            2. Start with `pattern`; add `kind`, relational rules, or `all`/`any`/`not` only when required.
            3. Test against the snippet before scanning the repository.
            4. Search the narrowest relevant path and inspect representative results for false positives and negatives.
            5. Report the rule, scope, and any known limitations with the results.

            Test without a fixture file when convenient:

            ```shell
            printf '%s\n' 'const x = await fetch();' | ast-grep scan --inline-rules 'id: test
            language: javascript
            rule:
              pattern: await $EXPR' --stdin
            ```

            ## Debug misses

            Inspect how ast-grep parses a pattern:

            ```shell
            ast-grep run --pattern 'class $NAME { $$$BODY }' --lang javascript --debug-query=cst
            ```

            If a rule misses expected code:

            - Simplify it until the base pattern matches.
            - Confirm the language and Tree-sitter node `kind`.
            - Add `stopBy: end` when a relational search must traverse the full direction.
            - Check that metavariables occupy complete syntax nodes.
            - Reintroduce conditions one at a time.

            ## Shell escaping

            Prefer single quotes around inline patterns so the shell does not expand `$VAR`. When double quotes are necessary, escape metavariable dollars as `\$VAR`.

            Use `--json` only when another command or program will process the results; use normal text output for direct inspection.
          '';


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
            map (name: nameValuePair ".agents/skills/${name}" { source = pstackSkill name; })
              pstackSkills
          )
          // {
            ".agents/skills/design-taste-frontend".source =
              pkgs.runCommand "agent-skill-design-taste-frontend" { }
              <| ''
                mkdir -p "$out"
                cp -r ${inputs.taste-skill}/skills/taste-skill/. "$out"/
              '';
            ".agents/AGENTS.md".text = ''
              Default to `jj`. only use `git` when there is no other option.
              Only run mutating VCS commands when told to

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
        );
    };
}
