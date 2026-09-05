{ ... }:

{
  flake.homeModules.slop = {
    # Link files individually so the skill directories remain writable.
    files = {
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

      ".agents/skills/ast-grep/agents/openai.yaml".text = ''
        policy:
          allow_implicit_invocation: true
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

      ".agents/skills/automate-me/SKILL.md".text = ''
        ---
        disable-model-invocation: true
        name: automate-me
        description: "Use for \"automate me\", \"create/update/refresh my -mode skill\", \"turn/capture my preferences or working style into a skill\", or wanting agents to follow how the user works. Drafts or revises a personal -mode skill, optionally pulling fresh evidence from recent transcripts."
        ---

        # Automate me

        A guided flow for turning the user's working conventions into a skill agents will follow. The output is one `-mode` skill tailored to them (e.g. `jay-mode`, `priya-mode`).

        This skill combines an inline mining pass with the host agent's skill-authoring workflow and available prose-cleanup guidance. It sequences those capabilities; it doesn't replace them.

        ## Flow

        ### 0. Check for an existing skill

        Search the skill roots configured by the current agent for `**/*-mode/SKILL.md` matching the user's handle. Start with project-local and user-level Agent Skills directories, such as `.agents/skills/` and the host's personal skill directory. Mode skills may live in a category directory, not only at the top level. If one exists, confirm intent with the host's structured question tool when available, or ask a concise plain-text question. Skip confirmation when the user already said "update my skill" or similar.

        - Update the existing skill (default for repeat runs)
        - Start fresh (rare; ask why before doing it)

        Update mode changes the rest of the flow:
        - Step 1 mines only history since the skill was last edited (`git log -1 --format=%cI <path>`).
        - Step 2 asks what's changed or missing, not what to capture from zero.
        - Step 4 edits the existing file in place. Preserve sections the user hasn't contradicted; revise ones with new evidence; add new sections only for genuinely new rules.

        ### 1. Mine their history

        Use recent conversations only when the host explicitly exposes workspace-scoped transcript history. Stay inside the active workspace or project scope. Never search user-wide conversation stores or unrelated projects. If no scoped transcript source is available, skip mining and rely on the current conversation plus direct questions.

        Survey recent agent conversations within that scope for recurring patterns. If the host supports delegation, split a substantial history into a few independent slices and inspect them concurrently. Otherwise inspect a representative sample sequentially. Each pass returns a short structured list of patterns with evidence pointers. Default signals worth hunting:

        - Response preferences (length, tone, format, "dumb it down" corrections)
        - Delegation habits (subagents, models, specialized workflows, parallelism)
        - Verification posture (what "done" means; unit tests vs live repro; reviewers)
        - Code and prose discipline (style, principles cited, lint/format tools)
        - Process conventions (worktrees, commits, PRs, review/merge tooling)
        - Meta preferences (fixing skills mid-task, proposing new ones)

        Cross-check across slices before elevating a signal. Patterns seen in 2+ slices are high-confidence; lone signals are weak and usually get dropped.

        ### 2. Ask the user directly

        Mining misses intent that hasn't come up yet. Prefer a structured multi-choice question tool when the host provides one. Otherwise ask concise questions in chat.

        Shape: one or two questions with 4-6 options each, `allow_multiple: true` for category questions. Start broad ("Which areas matter most?"), then follow up on selected areas with specific options. After the structured rounds, one free-form chat question catches anything the options missed.

        Don't dump 20 questions. Two structured rounds plus one open question is usually enough.

        ### 3. Cluster findings

        Group the combined signals into sections. Common ones (use only what applies):

        - **Response style**: length, tone, format.
        - **Autonomy**: how much to do without asking; MCP tool use.
        - **Understand first**: which skills to reach for when scoping or investigating a change.
        - **Subagents**: default, parallelism, model-to-task, specialized workflows.
        - **Prose / code discipline**: principles, lint tools, style guides.
        - **Review and verify**: repro posture, verification skills, live-testing tools.
        - **Process**: git worktrees, commits, PRs, review/merge tooling.
        - **Skills**: skill-authoring habits, fix-the-skill-first, proposing new skills.

        If an existing mode skill is available, use it only as a structural example. Don't copy its content; the user's rules are their own.

        ### 4. Draft the skill

        Use the host's skill-authoring capability when one is available. In Codex, use `skill-creator`; in another agent, use its equivalent or follow the Agent Skills format directly. Placement:

        - Path: preserve an existing mode skill's root and category. For a new mode, use the project's established Agent Skills directory, commonly `.agents/skills/<handle>-mode/`, or the host's user-level skill directory when the user wants it available across projects.
        - Handle: the user's first name or chosen identifier.
        - Frontmatter `description`: trigger on their name + `/<handle>-mode` + "work in their style", not on generic keywords like "write code" or "review PR".
        - Frontmatter formatting: follow the active agent's skill-authoring rules. Keep `description` as one YAML scalar; quote it or use `description: >-` with indented continuation lines when punctuation or wrapping requires it.
        - Invocation policy: mode skills are heavy and opinionated, so make them explicit-only unless the user asks for automatic use. Express this through host-supported metadata. In Codex, set `policy.allow_implicit_invocation: false` in `agents/openai.yaml`. Do not add product-specific keys that the active host does not support.

        ### 5. Iterate on prose

        Apply `unslop` when it is available, plus the active skill-authoring guidance. Otherwise perform the same plain-language cleanup directly. These rules apply to any agent-read prose, not just skills.

        Show the draft to the user and take feedback. Expect multiple iterations. Cut ruthlessly; a mode skill is not a manual.

        ### 6. Land it

        Write the skill in the selected project or personal skill root. Follow the repository's existing change workflow. Create a worktree, commit, or open a pull request only when the user or repository instructions call for it.

        ## Guardrails

        - **Don't overfit to one conversation.** A preference stated once and contradicted another time is noise. Require multiple instances before codifying it.
        - **Don't be clever.** Restating other skills' contents, inventing metaphors, or writing "poetic" prose for an agent reader is cost without benefit. Keep it operational.
        - **Reference, don't inline.** Other skills the user relies on should appear as path references, not pasted excerpts. Same for any principle docs they maintain elsewhere.
        - **Keep sections minimal.** Only add a section if the user has a specific, non-default rule there. "Communicate clearly" is not a section. "Short paragraphs. Tables when comparing options. Bullets only when items are genuinely parallel." is.
        - **Name conventions generic.** Use "the user" or "the human" in imperatives, not the author's first name. Others may read or adopt the skill.
        - **Don't force symmetry.** If a user has no process rules worth writing down, skip the Process section entirely. Sparse is fine; bloated is not.

        ## Evaluation

        A `-mode` skill is subjective output. A general benchmark loop is rarely useful here. Check it with the user: does it read like them, and did it miss anything? Then finish the requested delivery workflow.

        Run a description-optimization loop only if the skill's trigger accuracy turns out to be a problem in practice.

        ## When not to use

        - User wants a task-specific skill rather than working conventions: use the host's normal skill-authoring workflow, with no transcript mining.
        - User wants to capture one narrow workflow (e.g. "how I write commit messages"): that's a regular skill, not a mode skill.

        ## Reference files

        - Any existing mode skill: example of the output shape only.
        - The available prose-cleanup skill or equivalent editing pass.
        - The host's skill-authoring instructions or the Agent Skills format.
      '';

      ".agents/skills/automate-me/agents/openai.yaml".text = ''
        policy:
          allow_implicit_invocation: false
      '';

      ".agents/skills/codex-review/SKILL.md".text = ''
        ---
        name: codex-review
        disable-model-invocation: true
        description: Perform a read-only, defect-first review of a specified code change and return every actionable finding. Use when asked to review uncommitted changes, a base-branch diff, a commit, a pull request, or custom review instructions; when invoked as $codex-review; or when concise defect-first findings are needed.
        ---

        # Code Review

        Inspect the requested target directly and return every finding that the author would likely fix.
        Do not modify files, create commits, push branches, post review comments, or hand the review off.

        ## Review target

        Infer the target from the request:

        1. No argument: review current uncommitted changes.
           - Unstaged: `git diff`
           - Staged: `git diff --cached`
           - Untracked: `git status --short`, then read those files directly.
        2. Commit hash: review that commit with `git show <sha>`.
        3. Branch name: compare the changes that would actually merge, not a tip-to-tip diff.
           - Resolve the comparison ref to the branch's upstream when that upstream exists and is ahead of the local branch; otherwise use the local branch.
           - Run `git merge-base HEAD <comparison-ref>`, then inspect `git diff <merge-base-sha>`.
           - If the named branch cannot be resolved, try its configured upstream before reporting that the target is unavailable.
           - Do not use `git diff HEAD..<branch>` or any comparison that treats changes present only on the base branch as removals by the reviewed branch.
        4. Pull request number or URL: gather PR context and diff.
           - For inputs like `pr #151`, normalize to `151`.
           - Run `gh pr view <target>` for description, checks, and comments as context.
           - Run `gh pr diff <target>` and treat that patch as authoritative.
           - Do not check out the PR branch, recompute a local reverse diff, or post review comments.
           - If `gh pr diff` fails, say so and use the best available fallback rather than guessing from local branch state.
        5. Custom instructions: follow them while keeping this skill's finding bar.

        Verify ambiguous inputs before treating them as branches, paths, or PR identifiers.

        Confirm the diff direction before reviewing. Added lines should be code introduced by the reviewed change; removed lines should be code the change deletes.

        ## Review the change

        1. Read the applicable `AGENTS.md` instructions.
        2. Inspect the complete diff for the requested target and enough surrounding code to understand each changed path.
        3. Identify concrete regressions introduced by the change. Continue through the whole diff after finding the first issue.
        4. Check the relevant tests and call sites to confirm that each finding is real and actionable.

        Flag an issue only when all of these are true:

        - It affects correctness, security, performance, or maintainability in a meaningful way.
        - It is discrete and actionable.
        - It was introduced by the reviewed change.
        - The affected scenario or call path can be demonstrated from the code.
        - The author would probably fix it if they knew about it.

        Do not flag speculative concerns, pre-existing problems, intentional behavior changes, or style nits that do not obscure the code.

        ## Write the result

        Present findings first, ordered by severity. Use one entry per issue in this form:

        `[P1] Imperative finding title — path/to/file.rs:line`

        Follow the title with one short paragraph explaining the affected scenario and why the behavior is wrong. Keep the cited range as small as possible and make sure it overlaps the reviewed diff.

        Use these priorities:

        - `P0`: universal release blocker or critical failure.
        - `P1`: urgent defect that should be fixed next.
        - `P2`: ordinary defect that should be fixed.
        - `P3`: low-impact issue that is still worth fixing.

        If there are no qualifying findings, say `No findings.` Do not invent a finding to fill the result.
        After the findings, add a brief overall assessment and mention any material test gaps or residual risks.
      '';

      ".agents/skills/codex-review/agents/openai.yaml".text = ''
        interface:
          display_name: "Code Review"
          short_description: "Read-only defect-first review of a specified code change"
          default_prompt: "Use $codex-review to review the current code changes and return every actionable finding."

        policy:
          allow_implicit_invocation: false
      '';

      ".agents/skills/frontend-design/LICENSE.txt".text = ''
        ${""}
                                         Apache License
                                   Version 2.0, January 2004
                                http://www.apache.org/licenses/

           TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

           1. Definitions.

              "License" shall mean the terms and conditions for use, reproduction,
              and distribution as defined by Sections 1 through 9 of this document.

              "Licensor" shall mean the copyright owner or entity authorized by
              the copyright owner that is granting the License.

              "Legal Entity" shall mean the union of the acting entity and all
              other entities that control, are controlled by, or are under common
              control with that entity. For the purposes of this definition,
              "control" means (i) the power, direct or indirect, to cause the
              direction or management of such entity, whether by contract or
              otherwise, or (ii) ownership of fifty percent (50%) or more of the
              outstanding shares, or (iii) beneficial ownership of such entity.

              "You" (or "Your") shall mean an individual or Legal Entity
              exercising permissions granted by this License.

              "Source" form shall mean the preferred form for making modifications,
              including but not limited to software source code, documentation
              source, and configuration files.

              "Object" form shall mean any form resulting from mechanical
              transformation or translation of a Source form, including but
              not limited to compiled object code, generated documentation,
              and conversions to other media types.

              "Work" shall mean the work of authorship, whether in Source or
              Object form, made available under the License, as indicated by a
              copyright notice that is included in or attached to the work
              (an example is provided in the Appendix below).

              "Derivative Works" shall mean any work, whether in Source or Object
              form, that is based on (or derived from) the Work and for which the
              editorial revisions, annotations, elaborations, or other modifications
              represent, as a whole, an original work of authorship. For the purposes
              of this License, Derivative Works shall not include works that remain
              separable from, or merely link (or bind by name) to the interfaces of,
              the Work and Derivative Works thereof.

              "Contribution" shall mean any work of authorship, including
              the original version of the Work and any modifications or additions
              to that Work or Derivative Works thereof, that is intentionally
              submitted to Licensor for inclusion in the Work by the copyright owner
              or by an individual or Legal Entity authorized to submit on behalf of
              the copyright owner. For the purposes of this definition, "submitted"
              means any form of electronic, verbal, or written communication sent
              to the Licensor or its representatives, including but not limited to
              communication on electronic mailing lists, source code control systems,
              and issue tracking systems that are managed by, or on behalf of, the
              Licensor for the purpose of discussing and improving the Work, but
              excluding communication that is conspicuously marked or otherwise
              designated in writing by the copyright owner as "Not a Contribution."

              "Contributor" shall mean Licensor and any individual or Legal Entity
              on behalf of whom a Contribution has been received by Licensor and
              subsequently incorporated within the Work.

           2. Grant of Copyright License. Subject to the terms and conditions of
              this License, each Contributor hereby grants to You a perpetual,
              worldwide, non-exclusive, no-charge, royalty-free, irrevocable
              copyright license to reproduce, prepare Derivative Works of,
              publicly display, publicly perform, sublicense, and distribute the
              Work and such Derivative Works in Source or Object form.

           3. Grant of Patent License. Subject to the terms and conditions of
              this License, each Contributor hereby grants to You a perpetual,
              worldwide, non-exclusive, no-charge, royalty-free, irrevocable
              (except as stated in this section) patent license to make, have made,
              use, offer to sell, sell, import, and otherwise transfer the Work,
              where such license applies only to those patent claims licensable
              by such Contributor that are necessarily infringed by their
              Contribution(s) alone or by combination of their Contribution(s)
              with the Work to which such Contribution(s) was submitted. If You
              institute patent litigation against any entity (including a
              cross-claim or counterclaim in a lawsuit) alleging that the Work
              or a Contribution incorporated within the Work constitutes direct
              or contributory patent infringement, then any patent licenses
              granted to You under this License for that Work shall terminate
              as of the date such litigation is filed.

           4. Redistribution. You may reproduce and distribute copies of the
              Work or Derivative Works thereof in any medium, with or without
              modifications, and in Source or Object form, provided that You
              meet the following conditions:

              (a) You must give any other recipients of the Work or
                  Derivative Works a copy of this License; and

              (b) You must cause any modified files to carry prominent notices
                  stating that You changed the files; and

              (c) You must retain, in the Source form of any Derivative Works
                  that You distribute, all copyright, patent, trademark, and
                  attribution notices from the Source form of the Work,
                  excluding those notices that do not pertain to any part of
                  the Derivative Works; and

              (d) If the Work includes a "NOTICE" text file as part of its
                  distribution, then any Derivative Works that You distribute must
                  include a readable copy of the attribution notices contained
                  within such NOTICE file, excluding those notices that do not
                  pertain to any part of the Derivative Works, in at least one
                  of the following places: within a NOTICE text file distributed
                  as part of the Derivative Works; within the Source form or
                  documentation, if provided along with the Derivative Works; or,
                  within a display generated by the Derivative Works, if and
                  wherever such third-party notices normally appear. The contents
                  of the NOTICE file are for informational purposes only and
                  do not modify the License. You may add Your own attribution
                  notices within Derivative Works that You distribute, alongside
                  or as an addendum to the NOTICE text from the Work, provided
                  that such additional attribution notices cannot be construed
                  as modifying the License.

              You may add Your own copyright statement to Your modifications and
              may provide additional or different license terms and conditions
              for use, reproduction, or distribution of Your modifications, or
              for any such Derivative Works as a whole, provided Your use,
              reproduction, and distribution of the Work otherwise complies with
              the conditions stated in this License.

           5. Submission of Contributions. Unless You explicitly state otherwise,
              any Contribution intentionally submitted for inclusion in the Work
              by You to the Licensor shall be under the terms and conditions of
              this License, without any additional terms or conditions.
              Notwithstanding the above, nothing herein shall supersede or modify
              the terms of any separate license agreement you may have executed
              with Licensor regarding such Contributions.

           6. Trademarks. This License does not grant permission to use the trade
              names, trademarks, service marks, or product names of the Licensor,
              except as required for reasonable and customary use in describing the
              origin of the Work and reproducing the content of the NOTICE file.

           7. Disclaimer of Warranty. Unless required by applicable law or
              agreed to in writing, Licensor provides the Work (and each
              Contributor provides its Contributions) on an "AS IS" BASIS,
              WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
              implied, including, without limitation, any warranties or conditions
              of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
              PARTICULAR PURPOSE. You are solely responsible for determining the
              appropriateness of using or redistributing the Work and assume any
              risks associated with Your exercise of permissions under this License.

           8. Limitation of Liability. In no event and under no legal theory,
              whether in tort (including negligence), contract, or otherwise,
              unless required by applicable law (such as deliberate and grossly
              negligent acts) or agreed to in writing, shall any Contributor be
              liable to You for damages, including any direct, indirect, special,
              incidental, or consequential damages of any character arising as a
              result of this License or out of the use or inability to use the
              Work (including but not limited to damages for loss of goodwill,
              work stoppage, computer failure or malfunction, or any and all
              other commercial damages or losses), even if such Contributor
              has been advised of the possibility of such damages.

           9. Accepting Warranty or Additional Liability. While redistributing
              the Work or Derivative Works thereof, You may choose to offer,
              and charge a fee for, acceptance of support, warranty, indemnity,
              or other liability obligations and/or rights consistent with this
              License. However, in accepting such obligations, You may act only
              on Your own behalf and on Your sole responsibility, not on behalf
              of any other Contributor, and only if You agree to indemnify,
              defend, and hold each Contributor harmless for any liability
              incurred by, or claims asserted against, such Contributor by reason
              of your accepting any such warranty or additional liability.

           END OF TERMS AND CONDITIONS
      '';

      ".agents/skills/frontend-design/SKILL.md".text = ''
        ---
        disable-model-invocation: true
        name: frontend-design
        description: Guidance for distinctive, intentional visual design when building new UI or reshaping an existing one. Helps with aesthetic direction, typography, and making choices that don't read as templated defaults.
        license: Complete terms in LICENSE.txt
        ---

        # Frontend Design

        Approach this as the design lead at a small studio known for giving every client a visual identity that could not be mistaken for anyone else's. This client has already rejected proposals that felt templated, and is paying for a distinctive point of view: make deliberate, opinionated choices about palette, typography, and layout that are specific to this brief, and take one real aesthetic risk you can justify.

        ## Ground it in the subject

        If the brief does not pin down what the product or subject is, pin it yourself before designing: name one concrete subject, its audience, and the page's single job, and state your choice. If there's any information in your memory about the human's preferences, context about what they're building, or designs you've made before – use that as a hint. The subject's own world, its materials, instruments, artifacts, and vernacular, is where distinctive choices come from. Build with the brief's real content and subject matter throughout.

        ## Design principles

        For web designs, the hero is a thesis. Open with the most characteristic thing in the subject's world, in whatever form makes sense for it: a headline, an image, an animation, a live demo, an interactive moment. Be deliberate with your choice: a big number with a small label, supporting stats, and a gradient accent is the template answer, only use if that's truly the best option.

        Typography carries the personality of the page. Pair the display and body faces deliberately, not the same families you would reach for on any other project, and set a clear type scale with intentional weights, widths, and spacing. Make the type treatment itself a memorable part of the design, not a neutral delivery vehicle for the content.

        Structure is information. Structural devices, numbering, eyebrows, dividers, labels, should encode something true about the content, not decorate it. Many generic designs use numbered markers (01 / 02 / 03), but that's only appropriate if the content actually is a sequence - like a real process or a typed timeline where order carries information the reader needs. Question if choices like numbered markers actually make sense before incorporating them.

        Leverage motion deliberately. Think about where and if animation can serve the subject: a page-load sequence, a scroll-triggered reveal, hover micro-interactions, ambient atmosphere. An orchestrated moment usually lands harder than scattered effects; choose what the direction calls for. However, sometimes less is more, and extra animation contributes to the feeling that the design is AI-generated.

        Match complexity to the vision. Maximalist directions need elaborate execution; minimal directions need precision in spacing, type, and detail. Elegance is executing the chosen vision well.

        Consider written content carefully. Often a design brief may not contain real content, and it's up to you to come up with copy. Copy can make a design feel as templated as the design itself. See the below section on writing for more guidance.

        ## Process: brainstorm, explore, plan, critique, build, critique again

        For calibration: AI-generated design right now clusters around three looks: (1) a warm cream background (near #F4F1EA) with a high-contrast serif display and a terracotta accent; (2) a near-black background with a single bright acid-green or vermilion accent; (3) a broadsheet-style layout with hairline rules, zero border-radius, and dense newspaper-like columns. All three are legitimate for some briefs, but they are defaults rather than choices, and they appear regardless of subject. Where the brief pins down a visual direction, follow it exactly — the brief's own words always win, including when it asks for one of these looks. Where it leaves an axis free, don't spend that freedom on one of these defaults. Just like a human designer who's hired, there's often a careful balance between doing what you're good at and taking each project as a chance to experiment and learn.

        Work in two passes. First, brainstorm a short design plan based on the human's design brief: create a compact token system with color, type, layout, and signature. Color: describe the palette as 4–6 named hex values. Type: the typefaces for 2+ roles (a characterful display face that's used with restraint, a complementary body face, and a utility face for captions or data if needed). Layout: a layout concept, using one-sentence prose descriptions and ASCII wireframes to ideate and compare. Signature: the single unique element this page will be remembered by that embodies the brief in an appropriate way.

        Then review that plan against the brief before building: if any part of it reads like the generic default you would produce for any similar page (work through a similar prompt to see if you arrive somewhere similar) rather than a choice made for this specific brief — revise that part, say what you changed and why. Only after you've confirmed the relative uniqueness of your design plan should you start to write the code, following the revised plan exactly and deriving every color and type decision from it.

        When writing the code, be careful of structuring your CSS selector specificities. It's easy to generate CSS classes that cancel each other out (especially with a type-based selector like .section and a element-based selector like .cta). This can happen often with paddings/margins between sections.

        Try to do a lot of this planning and iteration in your thinking, and only show ideas to the user when you have higher confidence it'll delight them.

        ## Restraint and self-critique

        Spend your boldness in one place. Let the signature element be the one memorable thing, keep everything around it quiet and disciplined, and cut any decoration that does not serve the brief. Not taking a risk can be a risk itself! Build to a quality floor without announcing it: responsive down to mobile, visible keyboard focus, reduced motion respected. Critique your own work as you build, taking screenshots if your environment supports it – a picture is worth 1000 tokens. Consider Chanel's advice: before leaving the house, take a look in the mirror and remove one accessory. Human creators have memory and always try to do something new, so if you have a space to quickly jot down notes about what you've tried, it can help you in future passes.

        ## More on writing in design

        Words appear in a design for one reason: to make it easier to understand, and therefore easier to use. They are design material, not decoration. Bring the same intentionality to copy that you would bring to spacing and color. Before writing anything, ask what the design needs to say, and how it can best be said to help the person navigate the experience.

        Write from the end user's side of the screen. Name things by what people control and recognize, never by how the system is built. A person manages notifications, not webhook config. Describe what something does in plain terms rather than selling it. Being specific is always better than being clever.

        Use active voice as default. A control should say exactly what happens when it's used: "Save changes," not "Submit." An action keeps the same name through the whole flow, so the button that says "Publish" produces a toast that says "Published." The vocabulary of an interface is the signposting for someone navigating the product. Cohesion and consistency are how people learn their way around.

        Treat failure and emptiness as moments for direction, not mood. Explain what went wrong and how to fix it, in the interface's voice rather than a person's. Errors don't apologize, and they are never vague about what happened. An empty screen is an invitation to act.

        Keep the register conversational and tuned: plain verbs, sentence case, no filler, with tone matched to the brand and the audience. Let each element do exactly one job. A label labels, an example demonstrates, and nothing quietly does double duty.
      '';

      ".agents/skills/gh-pr-rewrite/SKILL.md".text = ''
        ---
        name: gh-pr-rewrite
        disable-model-invocation: true
        description: Use gh CLI to inspect a specified GitHub pull request, rewrite its title and body, apply the edit with gh pr edit, and return only the applied title and PR summary. Use when the user invokes $gh-pr-rewrite or asks to improve, rewrite, title, summarize, or edit a GitHub PR using a PR number, PR URL, branch, or other PR selector.
        ---

        # GH PR Rewrite

        Rewrite and apply a better GitHub PR title and body for the PR specified by the user.

        ## Workflow

        1. Identify the PR selector from the user's request.
           - Accept selectors such as `<number>`, `#<number>`, a PR URL, or a branch name.
           - Do not use a hardcoded PR number.
           - If no PR is specified, ask for the PR selector.

        2. Gather PR context with `gh`.
           - Start with:

        ```bash
        gh pr view "$PR" --json title,body,author,baseRefName,headRefName,state,isDraft,labels,commits,files,additions,deletions,url
        gh pr diff "$PR"
        ```

           - If the change is still unclear, inspect more context with targeted commands such as:

        ```bash
        gh pr view "$PR" --comments
        gh pr checks "$PR"
        ```

        3. Write the title.
           - Use this format:

        ```text
        [TYPE]: concise lower-case description
        ```

           - Choose the type from the dominant intent of the PR, usually `[FEAT]`, `[FIX]`, `[CHORE]`, `[REFACTOR]`, `[DOCS]`, `[TEST]`, `[BUILD]`, `[CI]`, or `[PERF]`.
           - Prefer `[FEAT]` for new product, workflow, or user-visible capability.
           - Keep the description short and concrete, similar to:

        ```text
        [FEAT]: drone-to-tpf console
        [FEAT]: make nixos actions deterministic
        ```

           - Use plain language, no trailing punctuation, and no extra prefix.

        4. Write the body exactly in this shape:

        ```markdown
        ## summary
        - brief bullet
        - brief bullet

        ## why
        - brief bullet
        - brief bullet
        ```

           - Use only bullet points under both sections.
           - Keep bullets very brief, concise, and easy to understand.
           - Use simple wording.
           - Prefer 2-4 bullets per section.
           - Do not include test plans, implementation notes, long prose, or extra sections unless the user explicitly asks.

        5. Apply the edit.
           - Write the body to a temporary file and run:

        ```bash
        gh pr edit "$PR" --title "$TITLE" --body-file "$BODY_FILE"
        ```

           - If `gh pr edit` fails, report the failure instead of claiming the title/body was applied.

        6. On success, output only the applied title and PR body.
           - Do not include explanations, command output, code fences, alternatives, or any surrounding commentary.
      '';

      ".agents/skills/gh-pr-rewrite/agents/openai.yaml".text = ''
        interface:
          display_name: "Rewrite GH PR"
          short_description: "Rewrite and apply GitHub PR titles and summaries"
          default_prompt: "Use $gh-pr-rewrite for PR <number-or-url>."

        policy:
          allow_implicit_invocation: false
      '';

      ".agents/skills/grilling/SKILL.md".text = ''
        ---
        name: grilling
        description: Grill the user relentlessly about a plan, decision, or idea. Use when the user wants to stress-test their thinking, or uses any 'grill' trigger phrases.
        disable-model-invocation: true
        ---

        Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

        Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask _now_ without guessing at answers you haven't heard yet. Ask the whole frontier in one round: number each question and give your recommended answer. Then wait for the user's answers before the next round.

        Format a round like so:

        ```
        ❓ **Q1** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

        ➡️ <your recommended answer>

        ---

        ❓ **Q2** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

        ➡️ <your recommended answer>
        ```

        Each round the user answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a _later_ round, not this one.

        Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, etc.), dispatch a sub-agent to find it; don't ask the user for anything you could look up yourself. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report; ask the rest of the frontier now. The _decisions_ are the user's: put each to them and wait.

        The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on it until the user confirms you have reached a shared understanding.
      '';

      ".agents/skills/grilling/agents/openai.yaml".text = ''
        interface:
          display_name: "Grilling"
          short_description: "Stress-test thinking a round of questions at a time"
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

      ".agents/skills/handoff/agents/openai.yaml".text = ''
        interface:
          display_name: "Handoff"
          short_description: "Compact a conversation into a handoff"
        policy:
          allow_implicit_invocation: false
      '';

      ".agents/skills/how/SKILL.md".text = ''
        ---
        name: how
        description: "Use for \"how does X work\", code walkthroughs before changing something, and placement / ownership / layering questions (\"where should this live\", \"which package owns this\", \"is this the right layer\"). Explains subsystem architecture, runtime flow, onboarding mental models. Can critique architecture. Use why for motivation."
        ---

        # How

        Explore the codebase to answer "how does X work?" questions. Produce clear architectural explanations at the level of a senior engineer onboarding onto a subsystem. Enough to build a working mental model, not annotated source code.

        Two modes:

        1. **Explain** (default). Explore the codebase and produce a clear explanation
        2. **Critique.** Explain first, then gather independent architectural critiques when the host supports delegation

        ## Explain Mode

        ### Step 1. Understand the Question and Assess Complexity

        Parse what the user is asking about:

        - "How does the rate limiter work?", a subsystem
        - "How do we handle billing for on-demand usage?", a feature flow
        - "How is the auth service structured?", an architectural overview
        - "Walk me through what happens when a user submits a form", a runtime trace

        Identify the scope. If ambiguous, state your best-guess interpretation before exploring. Don't ask. Let the user redirect if you're off.

        **Assess complexity to decide the approach:**

        - **Simple** (a single module, a small utility, a narrow question like "how does function X work"): skip explorer agents; the explainer explores and explains in a single pass. Go to Step 2b.
        - **Complex** (a subsystem spanning multiple files/services, a cross-cutting feature, a full architectural overview): divide the work into independent exploration angles, using parallel workers when available, then synthesize the findings. Go to Step 2a.

        When in doubt, lean simple. You can always expand into multiple exploration angles if the direct pass hits a wall.

        ### Step 2a. Explore (complex questions only)

        Decompose the question into 2-4 parallel exploration angles, each a distinct slice of the subsystem so explorers don't duplicate work. Example split for "how does the rate limiter work?":

        - Explorer 1: data model and state management
        - Explorer 2: request path and enforcement
        - Explorer 3: configuration and metrics infrastructure

        The right decomposition depends on the question. Use your judgment. Narrow questions: 2 explorers is fine. Broad subsystems: up to 4.

        Use the host's parallel delegation capability when available and launch all explorers together. Do not assume a particular subagent type, model name, or permission flag. Give each explorer a read-only task and respect the host's actual permission model. If delegation is unavailable, explore the same angles sequentially in the lead agent.

        Each explorer gets the same base prompt from `references/explorer-prompt.md` plus a specific exploration angle naming its slice. Each explorer should:
        - Start broad: use the available filesystem search tools to find relevant directories, files, and symbols
        - Follow the thread: from an entry point, trace the call chain (callers, callees, data flow, type definitions)
        - Read the actual code, don't guess from file names
        - Stop when it can describe the full path from input to output (or trigger to effect) without hand-waving any step
        - Note things that are surprising, non-obvious, or that a newcomer would get wrong

        Each explorer returns structured findings: components found, flow traced, files read, anything non-obvious. Overlap between explorers is fine; the explainer reconciles.

        Then proceed to Step 3.

        ### Step 2b. Direct Explain (simple questions)

        Explore and explain in one pass. The lead agent may delegate this to one available worker, but delegation is not required for a narrow question. Use the host's available file search and reading tools. Follow `references/explainer-prompt.md` for the communication style and output format, with no explorer findings as input.

        Proceed to Step 4.

        ### Step 3. Synthesize (complex questions only)

        Once exploration finishes, synthesize the findings into one coherent explanation. The lead agent can do this directly or delegate it to one available worker. The explainer gets all explorer findings and writes the human-facing explanation. Follow `references/explainer-prompt.md`; reconcile overlap, verify contradictions against the code, and weave the slices into a unified picture.

        ### Step 4. Present

        Present the explainer's output to the user. You may lightly edit for clarity or add context from the conversation, but don't substantially rewrite. The explainer's communication is the product.

        ### Output Format

        Follow this structure, adapted to the question. Not every section is needed for every question.

        **Overview.** 1-2 paragraphs. What it is, what it does, why it exists. Enough to decide whether to keep reading.

        **Key Concepts.** The important types, services, or abstractions. Brief definition of each. Not exhaustive, just the ones needed to understand the rest.

        **How It Works.** The core of the explanation. Walk through the flow: what triggers it, what happens step by step, where data goes, the decision points. Prose, not pseudocode. Reference specific files and functions so the reader can go look, but don't dump code blocks unless a snippet is genuinely necessary.

        **Where Things Live.** A brief map of the relevant files/directories. Not every file, just the ones needed to start working in this area.

        **Gotchas.** Non-obvious or surprising things that would trip someone up. Historical context that explains why something looks weird. Known sharp edges.

        ## Critique Mode

        Triggered when the user asks for architectural issues, problems, or improvements, not just understanding.

        ### Step 1. Explain First

        Run the full explain flow above (Steps 1-4). You must understand the architecture before critiquing it.

        ### Step 2. Gather Independent Critiques

        After the explanation is complete, gather up to three independent architectural critiques when the host supports delegation. Use different available workers or models when practical, but do not depend on named vendors or model IDs. If delegation is unavailable, perform one explicit critique pass after the explanation.

        Read `references/critic-prompt.md` for the prompt template. Each critic gets:
        1. The explanation from Step 1 (so they don't re-explore)
        2. The relevant file paths (so they can read the actual code)
        3. The architectural critique rubric from `references/critique-rubric.md`

        ### Step 3. Lead Judgment

        Same framework as the interrogate skill. You're a pragmatic lead, not an aggregator.

        Categorize findings:
        - **Act on.** Architectural problems worth fixing now
        - **Consider.** Real concerns, but the cost/benefit is unclear
        - **Noted.** Valid observations, low priority
        - **Dismissed.** Wrong, missing context, or style preference

        Present the explanation first (from Step 1), then the critique verdict below it. The explanation should stand on its own; someone who just wants to understand the system shouldn't wade through critique.
      '';

      ".agents/skills/how/agents/openai.yaml".text = ''
        policy:
          allow_implicit_invocation: false
      '';

      ".agents/skills/how/references/critic-prompt.md".text = ''
        # Critic Prompt Template

        Build each critic subagent's prompt from this template. Fill in the placeholders.

        ---

        You are reviewing the architecture of a codebase subsystem. An explanation of how it works has already been written. Read it to orient yourself, then read the actual code to form your own judgment.

        ## Architectural Explanation

        {EXPLANATION}

        ## Relevant Files

        {FILE_PATHS}

        ## Critique Rubric

        {CRITIQUE_RUBRIC_CONTENTS}

        ## Instructions

        Read the files listed above. Use the explanation as a map, but form your own opinions from the code itself. The explanation might miss things or frame them charitably.

        Find architectural problems, not line-level bugs or style issues. Ask whether this subsystem is built well for what it needs to do and how it will need to evolve.

        For each finding:

        1. **Severity**: `structural` | `concern` | `observation`
           - `structural`: a fundamental architectural problem. Wrong abstraction boundary, broken data model, coupling that will block future work
           - `concern`: a real issue that makes the system harder to work with or reason about, but not fundamentally broken
           - `observation`: worth noting. A tradeoff that might not age well, a pattern inconsistent with the rest of the codebase, technical debt
        2. **Finding**: the architectural issue. Be specific. Name the components, the boundary, the coupling.
        3. **Evidence**: concrete code that demonstrates the problem. Don't just assert that "this is too coupled". Show the dependency chain.
        4. **Impact**: what the issue costs. Harder to test? Harder to change? Performance cliff at scale? Be concrete about the consequence.

        ## What to Avoid

        - Line-level code review (not your job here)
        - Suggesting rewrites without demonstrating a problem with the current approach
        - "This could use more abstraction" without showing what the abstraction would actually solve
        - Flagging intentional tradeoffs with clear benefits as issues

        If the architecture is sound, say so. An empty critique is a valid outcome.

        ## Output

        ```
        ## Findings

        ### 1. [Severity] Short title
        **Components**: Which parts of the system are involved
        **Finding**: What's wrong architecturally
        **Evidence**: Concrete code references
        **Impact**: What this costs in practice

        ### 2. [Severity] Short title
        ...
        ```
      '';

      ".agents/skills/how/references/critique-rubric.md".text = ''
        # Architectural Critique Rubric

        Review through whichever of these lenses are relevant. Not every lens applies to every subsystem.

        ## Abstraction Fit

        Are the abstractions pulling their weight?

        - Does each abstraction represent a real concept, or is it an indirection layer "in case we need it"?
        - Are the boundaries in the right place? Do they separate things that change independently?
        - Is there accidental coupling where components share implementation details they shouldn't need to know about?
        - Is business logic entangled with framework wiring, or cleanly separated?

        Over-abstraction is as much a problem as under-abstraction. A flat, simple design is fine when the domain is simple.

        ## Data Model

        Do the data structures fit the actual usage patterns?

        - Are the data models designed for how data is actually accessed, or for how it was conceptually modeled?
        - Are there impedance mismatches, places where code constantly reshapes data because the model doesn't match the access pattern?
        - Are types honest? Do they represent what data actually looks like at runtime, or claim more structure than exists?

        ## Boundary Discipline

        Are system boundaries clean and well-placed?

        - Is validation concentrated at entry points, or scattered through internal code?
        - Are errors handled at boundaries and propagated cleanly, or caught and re-thrown at every layer?
        - Does data cross boundaries in well-typed shapes, or as bags of optional fields?
        - Could this subsystem be tested in isolation, or does it require the entire system to be running?

        ## Evolution Readiness

        How well will this architecture handle likely changes?

        - If the most probable next requirement landed tomorrow, how much would change? "One file" or "everything"?
        - Are there hardcoded assumptions that would need to be relaxed?
        - Is the design bolted-on (integrated as an afterthought) or integrated (looks like it was always part of the plan)?
        - Are legacy paths preserved for compatibility that no one depends on?

        Don't penalize for not handling hypothetical changes. Focus on changes plausible given the codebase's trajectory.

        ## Complexity vs. Value

        Is the complexity budget spent wisely?

        - Is complexity concentrated in the parts that need it (core logic, tricky invariants) or in accidental places (boilerplate, unnecessary indirection, configuration)?
        - Are there simpler ways to achieve the same behavior?
        - Does every component earn its existence, or are there vestigial pieces from an earlier design?

        ## Consistency

        Does this subsystem follow the patterns established elsewhere in the codebase?

        - Are similar problems solved the same way here as elsewhere, or does this area invent its own patterns?
        - If the patterns differ, is there a good reason, or did it just evolve independently?
        - Inconsistency isn't automatically bad. But unexplained inconsistency is a maintenance burden.
      '';

      ".agents/skills/how/references/explainer-prompt.md".text = ''
        # Explainer Prompt Template

        Build the explainer subagent's prompt from this template. Fill in the placeholders.

        ---

        You are writing an architectural explanation for a senior engineer. Multiple explorer agents have traced different slices of the codebase in parallel and gathered findings. Synthesize their findings into one coherent, well-structured explanation.

        ## Original Question

        > {QUESTION}

        ## Explorer Findings

        {EXPLORER_FINDINGS_ALL}

        ## Instructions

        The explorers each investigated a different angle of the same subsystem. Their findings will overlap in places and may occasionally contradict. Reconcile them. Merge overlapping descriptions, resolve contradictions by checking the code yourself, and weave the separate slices into a unified picture.

        Write an explanation a senior engineer unfamiliar with this area could read and walk away with a solid mental model, understanding the architecture well enough to start working in it confidently.

        Use the host's available read-only code-search and file-reading capabilities to check anything, clarify a detail, or fill a gap. The explorers did the heavy lifting, so you shouldn't need to re-explore from scratch.

        ## Output Format

        Use this structure, adapted to what makes sense for the question. Not every section is needed for every question.

        ### Overview
        1-2 paragraphs. What is this thing, what does it do, why does it exist. Someone should be able to read just this and decide whether to keep reading.

        ### Key Concepts
        The important types, services, or abstractions needed to follow the rest. Brief definitions, not exhaustive.

        ### How It Works
        The core of the explanation, and the longest section. Walk through the flow: what triggers it, what happens step by step, where data goes, what the decision points are.

        Use prose, not pseudocode. Reference specific files and functions so the reader knows where to look, but don't dump large code blocks unless a snippet is genuinely essential to a point.

        When the flow involves multiple components talking to each other, or data transforming through stages, include a diagram. Use mermaid (```mermaid) for structured flows (sequence diagrams, flowcharts, component graphs) or ASCII art for simpler relationships where mermaid would be overkill. Use your judgment. A diagram should clarify, not decorate. If prose covers the flow, skip the diagram.

        ### Where Things Live
        A brief file/directory map. Just the ones someone would need to start working here.

        ### Gotchas
        Non-obvious things, surprising behavior, historical context, sharp edges. Skip this section if there's nothing worth calling out.

        ## Communication Style

        - Use concrete language, not abstractions-about-abstractions
        - Say "the `UserService` calls `AuthClient.refresh()`" not "the service delegates to the client"
        - When something is complex, explain why it's complex. Don't just describe the complexity
        - When something is simple, don't pad it out
        - If there's a helpful analogy, use it; if there isn't, don't force one
        - If the explorers flagged open questions or gaps, acknowledge them honestly rather than papering over them
      '';

      ".agents/skills/how/references/explorer-prompt.md".text = ''
        # Explorer Prompt Template

        Build each explorer subagent's prompt from this template. Fill in the placeholders.

        ---

        You are exploring a codebase to understand how something works. Gather facts: trace code paths, read implementations, map components. A separate agent will write the human-facing explanation from your findings, so favor thoroughness and accuracy over prose.

        Other explorers are investigating different slices of the same subsystem in parallel. Don't try to cover everything. Focus on your assigned angle and go deep.

        ## Question

        > {QUESTION}

        ## Your Exploration Angle

        {EXPLORATION_ANGLE}

        ## Exploration Instructions

        Start by finding the relevant code. Use the host's available file-listing, text-search, structural-search, and reading tools. Don't guess from names. Read the code.

        Follow this pattern:
        1. **Find the entry point.** What triggers this behavior? A user action, an API call, a scheduled job? Find where it starts.
        2. **Trace the flow.** Follow the call chain from the entry point. Read each function. Understand what data flows through and how it transforms.
        3. **Map the key abstractions.** What types, interfaces, services, or classes are central? Read their definitions. Understand what they represent and why they exist.
        4. **Find the boundaries.** Where does this subsystem interface with others? What goes in, what comes out?
        5. **Look for the non-obvious.** Anything surprising? Anything that looks like a historical artifact? Anything a newcomer would misunderstand?

        Keep exploring until you can describe the full picture without hand-waving. If you hit a part you can't trace, say so explicitly. "I couldn't determine how X connects to Y" is better than making something up.

        ## Output

        Return your findings in this structure. Be factual and specific. Reference exact file paths, function names, type names, and line numbers where relevant.

        ### Components Found
        The key types, services, classes, and abstractions. For each: name, file path, and a one-sentence description of what it does.

        ### Flow
        The execution flow step by step. For each step: what function/method runs, what file it's in, what it does, what it calls next. Include the data that flows between steps.

        ### Files Read
        Every file you read during exploration, so the explainer can reference them.

        ### Boundaries
        Where this subsystem connects to other parts of the codebase. The inputs and outputs.

        ### Non-Obvious Things
        Anything surprising, historically motivated, or easy to get wrong. Things that look like they should work one way but actually work another.

        ### Open Questions
        Anything you couldn't fully trace or understand. Be honest about gaps.
      '';

      ".agents/skills/opencode-review/SKILL.md".text = ''
        ---
        disable-model-invocation: true
        name: opencode-review
        description: Review code changes like OpenCode's built-in /review command. Use when the user asks to review uncommitted changes, a commit, branch comparison, PR number, PR URL, pull request diff, or code changes with actionable bug-focused feedback. Also use when invoked as $opencode-review or /opencode-review.
        ---

        # OpenCode Review

        Act as a code reviewer. Review only the relevant changes and provide actionable feedback.

        ## Input

        Treat the user's request text after the skill or command name as the review argument. If there is no argument, review all uncommitted changes.

        ## Determine What To Review

        Choose the review target from the input:

        1. No argument: review all uncommitted changes.
           - Inspect unstaged changes with `git diff`.
           - Inspect staged changes with `git diff --cached`.
           - Inspect untracked files with `git status --short`.
        2. Commit hash, either full SHA or short hash: review that specific commit.
           - Inspect with `git show <argument>`.
        3. Branch name: compare the current branch to that branch.
           - Inspect with `git diff <argument>...HEAD`.
        4. Pull request URL or PR number: review the pull request.
           - Use `gh pr view <argument>` for PR context when GitHub CLI is available.
           - Use `gh pr diff <argument>` for the PR diff when GitHub CLI is available.
           - If `gh` is unavailable, explain that PR context could not be fetched and review any locally available diff instead.

        Use judgment for ambiguous arguments. If the argument looks like a branch and a path, verify before proceeding.

        ## Gather Context

        Do not review from the diff alone.

        - Use the diff to identify changed files and changed hunks.
        - Read the complete contents of modified files before deciding whether a hunk is wrong.
        - For untracked files, read the full file content because it will not appear in ordinary `git diff`.
        - Check nearby tests, callers, types, config, and project conventions when they affect correctness.
        - Check local instruction and convention files such as `AGENTS.md`, `CONVENTIONS.md`, `.editorconfig`, README files, or package-specific docs.
        - Keep review scope to changed code. Do not report unrelated pre-existing issues unless the change directly exposes or worsens them.

        ## Review Priorities

        Prioritize likely bugs over style.

        Look for:

        - Logic errors, incorrect conditionals, off-by-one mistakes, unreachable branches, missing guards, and broken state transitions.
        - Edge cases involving null, undefined, empty input, failed I/O, invalid user input, concurrency, ordering, timeouts, retries, cancellation, or partial failures.
        - Security issues such as injection, authorization bypass, unsafe path handling, secret exposure, confused deputy behavior, and unsafe deserialization.
        - Error handling that swallows failures, throws from unexpected places, drops important result values, or returns errors that callers do not handle.
        - Behavior changes that appear unintended or insufficiently tested.
        - Structure that conflicts with established project patterns or misses an obvious local abstraction.
        - Performance problems only when they are concrete and meaningful, such as unbounded quadratic work, N+1 queries, blocking work in hot paths, or avoidable large memory use.

        ## Before Reporting

        Be certain before calling something a bug.

        - Investigate first when context could change the conclusion.
        - Do not invent hypothetical problems. State the realistic scenario, input, or environment required for the issue to happen.
        - Do not report style preferences unless they clearly violate established conventions or create maintainability risk.
        - Do not overstate severity.
        - If something remains uncertain after reasonable investigation, say it is uncertain instead of presenting it as a finding.

        ## Output

        Lead with findings.

        For each finding:

        - Include severity, file, and line or hunk location when available.
        - Explain why the issue is a bug or concrete risk.
        - Name the scenario, input, environment, or condition required for the issue to occur.
        - Suggest a specific remediation that fits the codebase.

        Use a matter-of-fact tone. Avoid praise, filler, or accusatory language.

        If there are no material findings, say that clearly. Mention any important residual risk, such as tests not run, PR context unavailable, generated code not inspected, or hardware/runtime behavior not verifiable locally.
      '';

      ".agents/skills/opencode-review/agents/openai.yaml".text = ''
        interface:
          display_name: "OpenCode Review"
          short_description: "Review code changes like OpenCode /review"
          default_prompt: "Use $opencode-review to review the current code changes like OpenCode /review."

        policy:
          allow_implicit_invocation: false
      '';

      ".agents/skills/outline/SKILL.md".text = ''
        ---
        name: ast-grep-outline
        description: Use when mapping an unfamiliar or large source file or directory before reading its implementation.
        ---

        # ast-grep outline

        `ast-grep outline` prints a compact, line-numbered map of imports, exports, declarations, and direct members without reading full implementations. Use it when the map is likely to prevent substantial file reads, not as a reflex on every coding task.

        Find candidates with file or text search, outline them, then read only the relevant ranges:

        ```shell
        ast-grep outline <file>
        ast-grep outline <dir> --items exports --view names
        ast-grep outline <file> --match <symbol> --view expanded
        ast-grep outline <dir> --items imports --view signatures
        ```

        Key options:

        - `--items structure|exports|imports|all` selects the surface.
        - `--view names|signatures|digest|expanded` controls detail.
        - `--match <regex>` and `--type <types>` narrow top-level items.
        - `--pub-members` hides private members; `--json=stream` is for machine processing.

        This command is syntax-only: it does not resolve references, infer types, follow re-exports, or build call graphs. Use `rg`, `ast-grep run`, or compiler-backed tools for those jobs; if `ast-grep outline` is unavailable, continue with ordinary search and targeted reads rather than installing it unless asked.
      '';

      ".agents/skills/ponytail/SKILL.md".text = ''
        ---
        disable-model-invocation: true
        name: ponytail
        description: >
          Forces the laziest solution that actually works, simplest, shortest, most
          minimal. Channels a senior dev who has seen everything: question whether the
          task needs to exist at all (YAGNI), reach for the standard library before
          custom code, native platform features before dependencies, one line before
          fifty. Supports intensity levels: lite, full (default), ultra. Use on ANY
          coding task: writing, adding, refactoring, fixing, reviewing, or designing
          code, and choosing libraries or dependencies. Also use whenever the user
          says "ponytail", "be lazy", "lazy mode", "simplest solution", "minimal
          solution", "yagni", "do less", or "shortest path", or complains about
          over-engineering, bloat, boilerplate, or unnecessary dependencies. Do NOT
          use for non-coding requests (general knowledge, prose, translation,
          summaries, recipes).
        argument-hint: "[lite|full|ultra]"
        license: MIT
        ---

        # Ponytail

        You are a lazy senior developer. Lazy means efficient, not careless. You have
        seen every over-engineered codebase and been paged at 3am for one. The best
        code is the code never written.

        ## Persistence

        ACTIVE EVERY RESPONSE. No drift back to over-building. Still active if
        unsure. Off only: "stop ponytail" / "normal mode". Default: **full**.
        Switch: `/ponytail lite|full|ultra`.

        ## The ladder

        Stop at the first rung that holds:

        1. **Does this need to exist at all?** Speculative need = skip it, say so in one line. (YAGNI)
        2. **Already in this codebase?** A helper, util, type, or pattern that already lives here → reuse it. Look before you write; re-implementing what's a few files over is the most common slop.
        3. **Stdlib does it?** Use it.
        4. **Native platform feature covers it?** `<input type="date">` over a picker lib, CSS over JS, DB constraint over app code.
        5. **Already-installed dependency solves it?** Use it. Never add a new one for what a few lines can do.
        6. **Can it be one line?** One line.
        7. **Only then:** the minimum code that works.

        The ladder is a reflex, not a research project — but it runs *after* you
        understand the problem, not instead of it. Read the task and the code it
        touches first, trace the real flow end to end, then climb. Two rungs work →
        take the higher one and move on. The first lazy solution that works is the
        right one — once you actually know what the change has to touch.

        **Bug fix = root cause, not symptom.** A report names a symptom. Before you
        edit, grep every caller of the function you're about to touch. The lazy fix IS
        the root-cause fix: one guard in the shared function is a smaller diff than a
        guard in every caller — and patching only the path the ticket names leaves
        every sibling caller still broken. Fix it once, where all callers route through.

        ## Rules

        - No unrequested abstractions: no interface with one implementation, no factory for one product, no config for a value that never changes.
        - No boilerplate, no scaffolding "for later", later can scaffold for itself.
        - Deletion over addition. Boring over clever, clever is what someone decodes at 3am.
        - Fewest files possible. Shortest working diff wins — but only once you understand the problem. The smallest change in the wrong place isn't lazy, it's a second bug.
        - Complex request? Ship the lazy version and question it in the same response, "Did X; Y covers it. Need full X? Say so." Never stall on an answer you can default.
        - Two stdlib options, same size? Take the one that's correct on edge cases. Lazy means writing less code, not picking the flimsier algorithm.
        - Mark deliberate simplifications that cut a real corner with a known ceiling (global lock, O(n²) scan, naive heuristic) with a `ponytail:` comment naming the ceiling and upgrade path (`# ponytail: global lock, per-account locks if throughput matters`).

        ## Output

        Code first. Then at most three short lines: what was skipped, when to add it.
        No essays, no feature tours, no design notes. If the explanation is longer
        than the code, delete the explanation, every paragraph defending a
        simplification is complexity smuggled back in as prose. Explanation the user
        explicitly asked for (a report, a walkthrough, per-phase notes) is not debt,
        give it in full, the rule is only against unrequested prose.

        Pattern: `[code] → skipped: [X], add when [Y].`

        ## Intensity

        | Level | What change |
        |-------|------------|
        | **lite** | Build what's asked, but name the lazier alternative in one line. User picks. |
        | **full** | The ladder enforced. Stdlib and native first. Shortest diff, shortest explanation. Default. |
        | **ultra** | YAGNI extremist. Deletion before addition. Ship the one-liner and challenge the rest of the requirement in the same breath. |

        Example: "Add a cache for these API responses."
        - lite: "Done, cache added. FYI: `functools.lru_cache` covers this in one line if you'd rather not own a cache class."
        - full: "`@lru_cache(maxsize=1000)` on the fetch function. Skipped custom cache class, add when lru_cache measurably falls short."
        - ultra: "No cache until a profiler says so. When it does: `@lru_cache`. A hand-rolled TTL cache class is a bug farm with a hit rate."

        ## When NOT to be lazy

        Never simplify away: input validation at trust boundaries, error handling
        that prevents data loss, security measures, accessibility basics, anything
        explicitly requested. User insists on the full version → build it, no
        re-arguing.

        Never lazy about understanding the problem. The ladder shortens the
        solution, never the reading. Trace the whole thing first — every file the
        change touches, the actual flow — before picking a rung. Laziness that skips
        comprehension to ship a small diff is the dangerous kind: it dresses up as
        efficiency and ships a confident wrong fix. Read fully, then be lazy.

        Hardware is never the ideal on paper: a real clock drifts, a real sensor
        reads off, a PCA9685 runs a few percent fast. Leave the calibration knob, not
        just less code, the physical world needs tuning a minimal model can't see.

        Lazy code without its check is unfinished. Non-trivial logic (a branch, a
        loop, a parser, a money/security path) leaves ONE runnable check behind, the
        smallest thing that fails if the logic breaks: an `assert`-based
        `demo()`/`__main__` self-check or one small `test_*.py`. No frameworks, no
        fixtures, no per-function suites unless asked. Trivial one-liners need no
        test, YAGNI applies to tests too.

        ## Boundaries

        Ponytail governs what you build, not how you talk (pair with Caveman for
        terse prose). "stop ponytail" / "normal mode": revert. Level persists until
        changed or session end.

        The shortest path to done is the right path.
      '';

      ".agents/skills/ponytail/agents/openai.yaml".text = ''
        policy:
          allow_implicit_invocation: false
      '';

      ".agents/skills/ponytail-review/SKILL.md".text = ''
        ---
        disable-model-invocation: true
        name: ponytail-review
        description: Use when the user asks for an over-engineering or simplification review of code changes.
        ---

        Review diffs for unnecessary complexity. One line per finding: location, what
        to cut, what replaces it. The diff's best outcome is getting shorter.

        ## Format

        `L<line>: <tag> <what>. <replacement>.`, or `<file>:L<line>: ...` for
        multi-file diffs.

        Tags:

        - `delete:` dead code, unused flexibility, speculative feature. Replacement: nothing.
        - `stdlib:` hand-rolled thing the standard library ships. Name the function.
        - `native:` dependency or code doing what the platform already does. Name the feature.
        - `yagni:` abstraction with one implementation, config nobody sets, layer with one caller.
        - `shrink:` same logic, fewer lines. Show the shorter form.

        ## Examples

        ❌ "This EmailValidator class might be more complex than necessary, have you
        considered whether all these validation rules are needed at this stage?"

        ✅ `L12-38: stdlib: 27-line validator class. "@" in email, 1 line, real validation is the confirmation mail.`

        ✅ `L4: native: moment.js imported for one format call. Intl.DateTimeFormat, 0 deps.`

        ✅ `repo.py:L88: yagni: AbstractRepository with one implementation. Inline it until a second one exists.`

        ✅ `L52-71: delete: retry wrapper around an idempotent local call. Nothing replaces it.`

        ✅ `L30-44: shrink: manual loop builds dict. dict(zip(keys, values)), 1 line.`

        ## Scoring

        End with the only metric that matters: `net: -<N> lines possible.`

        If there is nothing to cut, say `Lean already. Ship.` and stop.

        ## Boundaries

        Scope: over-engineering and complexity only. Correctness bugs, security holes,
        and performance are explicitly out of scope. Route them to a normal review
        pass, not this one. A single smoke test or `assert`-based
        self-check is the ponytail minimum, not bloat, never flag it for deletion.
        Does not apply the fixes, only lists them.
        "stop ponytail-review" or "normal mode": revert to verbose review style.
      '';

      ".agents/skills/principle-foundational-thinking/SKILL.md".text = ''
        ---
        name: principle-foundational-thinking
        description: Use before implementing logic whose core data structures, ownership, concurrency, or sequencing are unclear.
        ---

        # Foundational Thinking

        **Structural decisions** protect option value. **Code-level decisions** protect simplicity. Over-engineering is often a premature decision that closes doors. The right foundational data structure keeps doors open.

        **Data structures first.** Get the data shape right before writing logic. The right shape makes downstream code obvious. Define core types early, trace every access pattern, and choose structures that match the dominant paths. A data-structure change late is a rewrite. Early, it is often a one-line diff.

        At code level, DRY the structure, not every line. Types and data models should converge. Three similar statements still beat a premature abstraction. Prefer explicit over clever. Test behavior and edge cases, not line counts.

        **Concurrency corollary.** Before sharing state between actors, ask "what happens if another actor modifies this concurrently?" If not "nothing", isolate.

        **Scaffold first.** If something helps every later phase, do it first. Ask "does every subsequent phase benefit from this existing?" CI, linting, test infrastructure, and shared types are scaffold. Sequence for option value: setup before features, tests before fixes. Keep commits small and single-purpose.

        Each increment should land a coherent abstraction or deepen one that exists. Do not spread a new capability across callers as special-case coordination.

        Subtraction comes before scaffolding: remove dead weight first, then lay foundations.
      '';

      ".agents/skills/principle-guard-the-context-window/SKILL.md".text = ''
        ---
        name: principle-guard-the-context-window
        description: Use when large files, outputs, or repeated reads threaten to fill the context window.
        ---

        # Guard the Context Window

        The context window is finite and non-renewable within a session. Every token that enters should earn its place.

        **Why:** Context overflow degrades reasoning quality, creates compression artifacts, and halts progress. Unlike compute or time, context spent inside a session cannot be reclaimed.

        **Pattern:**
        - **Isolate large payloads.** Route verbose outputs, screenshots, and large documents to subagents. The main context gets summaries, not raw data.
        - **Don't read what you won't use.** Read selectively based on relevance. If a file isn't needed for the current task, skip it.
        - **Keep frequently used content inline.** Templates and references used on every invocation belong in the skill file, not in separate files that cost a read each time.
        - **Size phases and cap scope.** Limit files per phase, set turn budgets, account for mechanism costs.
      '';

      ".agents/skills/principle-laziness-protocol/SKILL.md".text = ''
        ---
        name: principle-laziness-protocol
        description: Use when refactoring or designing code where deletion or a smaller change may avoid extra abstraction.
        ---

        # Laziness Protocol

        Writing code is cheap for you, which makes over-engineering easy. Counter it by borrowing a human maintainer's fatigue. Aim for the most result with the least code and complexity.

        - **Prefer deletion.** When asked to refactor or improve, look for removals before additions.
        - **Maintain a flat call hierarchy.** Avoid deep call chains. A rich interface that hides substantial work is not a deep call chain. If answering a question requires tracing through more than 3 files or layers, flatten it.
        - **Consolidate decisions.** Do not repeat the same choice in several places. Put it behind one source of truth and pass the result as a simple flag.
        - **Minimize the diff.** Make the smallest change that solves the problem. Fewer lines beat "elegant" boilerplate.
        - **Question the threading.** If a task asks you to pass a new signal through types, schemas, pipelines, or similar layers, stop and look for a more direct path.
        - **Sweat the small leaks.** Remove tiny pass-throughs, representation leaks, and duplicated choices before they spread. Small leaks compound into permanent coordination costs.

        **Prime directive:** If a human developer would find the code exhausting to maintain, it is a bad solution. Be lazy. Stay simple.
      '';

      ".agents/skills/principle-subtract-before-you-add/SKILL.md".text = ''
        ---
        name: principle-subtract-before-you-add
        description: Use when an addition, refactor, or rewrite can begin by removing obsolete or redundant code.
        ---

        # Subtract Before You Add

        When evolving a system, remove complexity first, then build. Deletion gives you a simpler base, which makes the next addition smaller and less brittle.

        **Why:** Adding to a complex system compounds complexity. Removing first cuts the surface area, reveals the essential structure, and usually makes the next design obvious. Default to subtraction.

        Make simplification a continual investment. Leave the design slightly simpler and more capable behind the same or smaller surface than you found it.

        **The pattern:**
        - Sequence removal before construction
        - Cut before you polish (get to the minimum before investing in quality)
        - Design for observed usage, not speculative edge cases
        - No speculative validators, parsers, or guards beyond what the spec demands
        - Out-of-spec features drag validators behind them. Persistence, retry-on-startup, and schema migration each need guards to defend their inputs.
        - Simplify prompts (remove redundant instructions, excessive templates)
        - When a reference has no novel content, delete it rather than leaving a stub
      '';

      ".agents/skills/teach/SKILL.md".text = ''
        ---
        disable-model-invocation: true
        name: teach
        description: "Explain a body of work plainly so a person actually understands it. Runs the `how` and `why` workflows and weaves what they find into one clear explanation. Use for 'teach me this', 'help me really understand X', 'explain this change or subsystem to me'."
        ---

        # Teach

        **You explain what a thing is, how it works, and why it's built that way, in one plain account at the person's pace. The goal is that they understand it, not that you change anything.** For "teach me this", "help me really understand X", or "explain this change or subsystem to me".

        Teach sits on top of the `how` and `why` workflows. Explicitly invoke those skills when the host supports skill invocation; otherwise follow their workflows directly. Blend what they find into one plain explanation, lead with what matters to the person, and go deeper when they ask. Reword freely for teaching, with one exception: keep `why`'s confidence language intact because its hedges are findings, not style. Let those workflows do the investigation. Don't redo it independently.

        1. Decide the few things they should walk away understanding. Choose them from why they're asking (about to change it, reviewing it, debugging it, new to it) and what they already know, both read from the conversation, not quizzed out of them. Skip what they plainly already know. Put the depth where their question is.
        2. Let `how` and `why` do the work, don't redo it. Read the code yourself to get oriented, then run `how` for how it works and `why` for why. Run them concurrently when the host supports it; otherwise run them sequentially and combine the results. Match the size to the question: run both for a subsystem, maybe one is enough for a small change. Keep `why` narrow by default since its full sweep is slow: put the narrowing in the ask itself (a scoped question, version history plus a source or two) so `why` records the skipped categories per its own contract, and widen it only when the reasons are the point.
        3. Start with a plain definition. Name the thing and say what it is in general terms, the way a senior engineer would say it out loud, with its common name if it has one. Then tie it to the case in front of you ("in X, we use this to ...") and build from there: how it works, the deeper reasons, the edge cases. Explain how it works, don't just name it. For each part, explain the idea so it clicks: the problem it solves and how it actually works. Walk through what happens as the person does the thing (opens a long chat, scrolls up) when that is what makes it land. Listing functions and constants is reference, not teaching. Don't print framing labels ("the one idea to hold onto", "the thing to walk away with", "the key insight", "at its core", "TL;DR"). Give the smallest complete answer first, a sentence or two, not a dense paragraph, then stop. Add layers when they ask. Never a wall of text.
        4. Keep it a conversation, not a lecture or a performance. Offer to go deeper or move on, and follow their lead. No quizzes. No pacing theater: don't print "Pause", don't ask them to say it back, don't announce "the sentence to nail", and don't flag a part as important or hard ("here is the part worth slowing down on", "this is the tricky part", "here is where it gets interesting"). Just say it. When you would pause, stop and let them respond. Running one-shot with no live human, deliver it cleanly and put any offer to go deeper at the end.
        5. Show, don't only tell, and build the picture up diagram by diagram. Open the diff, the code, or the debugger when that is the fastest way to land it. Draw when a picture lands faster than words. For anything with three or more moving parts, do not draw one diagram with all of them at once. Draw a short series instead, where each diagram redraws the last and adds a single part, so the reader watches the system assemble. That series is not a wall. It is the opposite of one, since each step is small and adds exactly one idea. A single all-at-once diagram, especially one saved for the end, is a reference, not teaching. Concretely, to teach a flow from A to B to C, draw it three times. First A to B. Then redraw and add C. Then redraw and add the return edge or the next piece. Three small growing diagrams beat one crowded diagram. Match the medium to the idea, and use both kinds when both help. A mermaid diagram fits a flow or structure where the labels carry the meaning. When the idea is spatial, like layout, overlap, scroll position, or a before and after, reach for the image-generation tool and draw it marker-on-whiteboard style with a few short labels, since image models garble long text. Generate that picture, don't settle for describing it in words. The build-up rule holds for generated images too. A single simple point needs no figure. A visual earns its place by teaching, not decorating.

        Write every response through the **unslop** skill, in plain spoken English, the way you'd explain it to a colleague. Be tight, not terse: cut filler and hedging, keep the part that makes it click. Padding is the enemy, not ideas. Don't list functions and constants like a changelog. State the concrete mechanism, not a metaphor, a framing, or a preview of what is coming. This is the target density: "Virtualization runs in two parts, one for rendering and one for loading from disk. When an item scrolls out past the buffer, both its DOM node and its in-memory data are evicted." Normal sentence case, not all-lowercase. No em dashes. Prefer periods over commas. Keep each sentence to one or two commas. If clauses pile up, split them into separate sentences. Give each concept one name and keep it, since switching between synonyms for the same thing (bubble, message, row) makes the reader re-derive that they are the same. Avoid mirror sentences ("A without B, or B without A") and tidy closers ("the rest follows", "it all falls out"). The words in these steps are directions to you, not labels to print. Don't echo the scaffolding as headers or stock phrases.

        **Reply:** the explanation itself, never a report about what you did or delivered. Lead with the main point, then the plain account of what it is, how it works, and why, and the threads worth chasing with `how` or `why`.
      '';

      ".agents/skills/teach/agents/openai.yaml".text = ''
        policy:
          allow_implicit_invocation: false
      '';

      ".agents/skills/too-much-review/SKILL.md".text = ''
        ---
        name: too-much-review
        disable-model-invocation: true
        description: Review a change target with $codex-review and $opencode-review in a fix-and-rerun loop until both are clean, then run $ponytail-review and fix everything it finds, then run $ponytail-review one final time. Use after completing a task when the user asks to run both reviewers on a change target, defaulting to the current working copy relative to the dev branch.
        ---

        # Too Much Review

        Three phases, in order:

        1. **Dual review loop** — `$codex-review` + `$opencode-review` until both clean.
        2. **Ponytail pass** — `$ponytail-review`, apply every finding.
        3. **Final ponytail pass** — `$ponytail-review` once more, apply findings, then end.

        The invoking agent owns all fixes and never reviews inline. Every review pass runs in a subagent that only reports findings; never ask a subagent to edit.

        ## Running Reviews Via Subagents

        Dispatch every review pass to a subagent (Task tool, `general` agent type):

        - Launch the `$codex-review` and `$opencode-review` subagents in parallel in a single message; launch `$ponytail-review` passes alone.
        - The subagent prompt must:
          - state that this is a read-only review task and the subagent must not modify any files,
          - tell it to read the relevant skill file and follow it exactly (`/Users/uzair/.agents/skills/codex-review/SKILL.md`, `/Users/uzair/.agents/skills/opencode-review/SKILL.md`, or `/Users/uzair/.agents/skills/ponytail-review/SKILL.md`),
          - pass the review target through verbatim,
          - require it to return every finding in the skill's output format, or the skill's clean verdict (`No findings.` / no material findings / `Lean already. Ship.`).
        - Run the fixes yourself in the working copy, then dispatch fresh subagents for the rerun. Never reuse a previous subagent session for a rerun.

        ## Review Target

        If the user specifies a target, pass that target through exactly. Examples:

        - `main`
        - `origin/main`
        - `HEAD~1`
        - `pr 123`
        - `current staged changes only`
        - `the changes in packages/api relative to dev`

        If the user does not specify a target, use:

        ```text
        current working copy relative to dev
        ```

        For the default target, each review must inspect committed changes since the merge base with `dev` and all staged, unstaged, and untracked working tree changes. The reviewed patch is what the current working copy introduces relative to `dev`.

        ## Phase 1: Dual Review Loop

        Dispatch both review subagents against the target:

        - `$codex-review <target>`
        - `$opencode-review <target>`

        Run them as parallel subagents, per "Running Reviews Via Subagents" above.

        Then loop:

        - If either review reports actionable findings, fix those issues in the working copy.
        - After fixing, rerun **both** review skills with the same target.
        - Repeat until both reviews report no actionable/material findings, or until a finding cannot be fixed without user input or contradicts the user's request.
        - If a repeated review raises a new actionable finding caused by a fix, treat it as part of the same loop and fix it before continuing.

        ## Phase 2: Ponytail Pass

        Once both reviews are clean, run:

        - `$ponytail-review <target>`

        Ponytail-review only lists findings; it does not apply them. Apply every finding it reports: cut the dead code, inline the one-implementation abstraction, replace the hand-rolled code with the stdlib or platform equivalent, shrink the verbose logic. Do not skip findings unless applying one would break correctness or contradict the user's request — in that case note it in the final report.

        If it reports `Lean already. Ship.`, apply nothing and continue.

        ## Phase 3: Final Ponytail Pass

        After applying Phase 2 fixes, run `$ponytail-review <target>` one more time.

        - Apply any findings from this final pass the same way.
        - This is a single pass, not a loop. When it is done, end.

        ## Report Back

        - Summarize findings from each pass only as needed to explain what was fixed.
        - State plainly when the final reviews were clean.
        - Include any residual risks, skipped fixes, or blockers.
        - Include the final ponytail-review verdict (`net: -<N> lines possible` or `Lean already. Ship.`).
      '';

      ".agents/skills/unslop/SKILL.md".text = ''
        ---
        name: unslop
        description: Use on every response to remove obvious AI writing patterns while preserving meaning and tone.
        ---

        # Unslop

        Write plainly and specifically, with natural rhythm and no filler, puffery, sycophancy, canned chatbot phrases, or vague claims.
        Prefer concrete facts, active voice, simple words, and short sentences; avoid forced structure, repeated headings, synonym cycling, and decorative punctuation.
        Preserve the user's meaning and intended tone, then make one final pass to cut anything that sounds generic or machine-written.
      '';

      ".agents/skills/whitelist-git-ignore/SKILL.md".text = ''
        ---
        name: whitelist-git-ignore
        disable-model-invocation: true
        description: Create or update a repository .gitignore as a strict whitelist that ignores everything by default and explicitly admits only approved directories, filenames, extensions, and exceptional paths. Use when the user asks for a whitelist-only, allowlist, deny-by-default, UKG-style, or nc-style .gitignore, or wants a repository to make unexpected files untrackable by default.
        ---

        # Whitelist Git Ignore

        Create a deny-by-default `.gitignore` in the style used by `/Users/uzair/01-projects/ukg` and `/Users/uzair/nc`. Inspect the target repository and tailor the whitelist; do not blindly copy either repository's entries.

        ## Build the whitelist

        1. Read repository instructions such as `AGENTS.md` before editing.
        2. Inspect the existing `.gitignore`, `git status --short`, `git ls-files`, and the repository's top-level structure. Distinguish source/configuration from build outputs, caches, dependencies, secrets, editor files, and other generated state.
        3. If tracked files already exist, ensure the new rules continue to admit every intentionally tracked file. Treat surprising tracked artifacts as items to flag, not automatically whitelist.
        4. Write rules in this order, with blank lines between groups:

        ```gitignore
        *

        !.gitignore

        !source-directory/
        !source-directory/**/

        !README.md
        !project-root-file

        !*.ext

        !path/to/extensionless-file
        ```

        5. Reopen only directories that may contain versioned content. For each admitted directory, include both `!dir/` and `!dir/**/` so Git can traverse nested directories while the initial `*` continues to ignore files unless another rule admits them.
        6. Admit exact root filenames before extension rules. Use extension rules for file types that are intentionally versioned throughout reopened directories. Put extensionless or unusually named path exceptions last.
        7. Keep the whitelist narrow. Do not admit broad generated directories such as `.direnv`, `node_modules`, `dist`, `build`, coverage output, caches, or secret material merely because a matching extension exists.
        8. Preserve intentional comments only when they clarify a non-obvious exception. Keep the file compact and deterministic.

        ## Verify the result

        Run `git diff --check` and inspect `git diff -- .gitignore`.

        Use `git check-ignore -v --no-index <path>` on representative allowed and forbidden paths. Remember that `git check-ignore` can print the matching negation rule for an allowed path; use the reported pattern and exit status together, and supplement it with `git status --short --untracked-files=all` when needed.

        Enumerate tracked files and check that none are excluded by the completed rules. Test at least:

        - an allowed root file;
        - an allowed file in a nested reopened directory;
        - a disallowed extension in an otherwise reopened directory;
        - a file under a directory that must remain ignored;
        - every explicit extensionless exception.

        Report the whitelist categories added and any intentionally excluded existing files. Do not run `git add`, remove files, or alter tracking state unless the user explicitly asks.
      '';

      ".agents/skills/whitelist-git-ignore/agents/openai.yaml".text = ''
        interface:
          display_name: "Whitelist Git Ignore"
          short_description: "Create whitelist-only repository gitignores"
          default_prompt: "Use $whitelist-git-ignore to create or update this repository’s strict whitelist .gitignore."

        policy:
          allow_implicit_invocation: false
      '';

      ".agents/skills/why/SKILL.md".text = ''
        ---
        name: why
        description: "Use for 'why does X work this way', 'why we picked Y', design rationale, regressions, postmortems, or data-backed thresholds. Discovers available evidence sources and queries relevant categories (source control, issue tracker, long-form docs, real-time chat, infrastructure observability, error tracking, product analytics warehouse), then returns a cited read on decisions and tradeoffs. Use how for runtime behavior."
        ---

        # Why

        Investigate the motivation and intent behind code. Why was it built this way? What edge cases were considered? What product, business, or operational constraints shaped the design? What alternatives were rejected, and why?

        Companion to the `how` skill. `how` answers what the code does and how it works. `why` answers what forces led to its shape.

        ## How this skill works

        Historical context spreads across seven evidence categories: source control history, issue or ticket tracking, long-form documents, real-time team chat, infrastructure observability, error or exception tracking, and product analytics warehouses. You cannot predict from the question alone which one holds the answer, so the skill enumerates available MCPs at run time, maps each to a category, queries all seven in parallel, then synthesizes with explicit confidence calibration. Null results from searched categories are first-class evidence about how the decision was made; report them alongside positive findings. The default is coverage, not minimalism.

        ## Operating Posture

        Operate as a careful, cautious, precise investigator. Think like a detective piecing together a historical case from fragmentary records. When the record is thin, say so.

        Concretely:

        - **Evidence before narrative.** Collect the pieces first, then see what story they support. Never pick a story and recruit the evidence that fits it.
        - **Precision over polish.** Prefer the exact quote and citation over a smooth paraphrase. A reader should be able to follow any claim back to its source and verify it in under a minute.
        - **Consider what you haven't seen.** The evidence you find is a sample, not the whole truth. Before concluding, ask what you would expect to see if an alternative explanation were true, and whether you looked for it.
        - **Name the gaps.** If a thread goes cold, a source isn't searchable, or a question has no answer, document the gap. Don't paper it over with an authoritative-sounding guess.
        - **Hedge on purpose.** When evidence is indirect, your language should signal it ("appears to", "likely", "suggests"). Confidence-matching phrasing is a feature of the output, not a stylistic choice the synthesizer may override.
        - **No shortcut by code-reading.** The code tells you what it does, rarely why it exists. Resist inferring intent from code shape.

        This posture is the working method, not a disclaimer.

        ## Core Epistemics

        This skill builds a **patchwork understanding** from fragmented historical evidence. Tickets go stale. Chat threads get deleted. Commit messages lie. People change their minds between the PR description and the implementation. The original author may have left the company.

        Be ruthlessly honest about what you know versus what you're inferring. The goal is not a satisfying story; it is to surface evidence, calibrate confidence, and let the user decide.

        Principles:

        - **Cite everything.** Every claim about intent should reference a specific commit hash, PR number, ticket ID, doc URL, chat permalink, or code comment. If you can't cite it, it's inference, not fact, and must be labeled as such.
        - **Prefer "appears to" over "because".** Hedge when evidence is indirect. Reserve confident language for direct, explicit evidence.
        - **Surface contradictions.** If two sources disagree, show both. Don't quietly pick the one that fits your narrative.
        - **Acknowledge gaps.** If a question has no answer in any source you searched, say so. An honest "we couldn't find out why" beats a confident guess.
        - **Multiple hypotheses are valid.** When the evidence fits several stories, present them all with the evidence for each. Let the user triangulate.
        - **Beware rationalization.** Code that makes sense today may have been written for reasons that no longer apply, or for no good reason at all. Don't retrofit intent.

        Read `references/epistemics.md` for the full confidence framework and phrasing guide. The synthesizer must follow it.

        ## Step 1. Understand the Target and the Question

        Parse what the user is asking. The **target** is usually a chunk of code, a pattern, a feature, or a named design decision. The **question** is usually one of:

        - "Why was X designed this way?" Design rationale.
        - "Why do we do X instead of Y?" Tradeoff or alternatives.
        - "What edge cases motivated this?" Defensive reasoning.
        - "What business or product constraint led to this?" External forcing function.
        - "Why does this code still exist?" Dead-code territory.
        - "What's the history of X?" Broad archaeological sweep.

        If the target is vague ("why do we do it this way?" with no clear referent), make your best guess from available conversation and workspace context, such as open files, recent edits, or what was just discussed. State your interpretation briefly so the user can redirect if you're off, then proceed.

        ## Step 2. Establish the Code Anchor

        Before spawning investigators, anchor the investigation in concrete code. You need:

        - The relevant file path(s) and line range(s)
        - The key symbols (function names, class names, constants)
        - An initial commit list. The last few commits touching the target.
        - PR numbers from merge commits (pattern `(#1234)` in the subject line)

        Build this inline. It's cheap, and every investigator needs it.

        ```bash
        # Blame target lines for last-touch commits
        git blame -L <start>,<end> <file>

        # Full file history, with patches, through renames
        git log --follow -p -- <file>

        # Last N commits touching the file, PR numbers visible
        git log --oneline -20 -- <file>

        # Extract PR numbers from a commit message
        git log -1 --format=%B <commit>
        ```

        When an authenticated hosting CLI or API is available, use it to pull PR bodies and discussion for substantive commits. For GitHub with `gh` installed:

        ```bash
        gh pr view <number> --json title,body,author,createdAt,mergedAt,labels,closingIssuesReferences,comments,reviews
        ```

        Capture this as seed context (file paths, symbols, commits, PR numbers, linked ticket IDs). Pass it to the investigators so they don't rediscover it.

        ## Step 3. Investigate Evidence Categories (default posture)

        **Default to the full parallel investigation.** Each evidence category lives in a different kind of system, and you cannot tell from the question alone which one holds the answer without looking. So look across every available category, in parallel, by default.

        ### Discovery

        Before launching investigators, inspect the tools, connectors, MCP servers, apps, and local commands that the current host actually exposes. Use the host's tool inventory or discovery mechanism. Do not assume a particular product directory or invent unavailable integrations.

        Map each available MCP to one evidence category:

        1. Source control history
        2. Issue / ticket tracker
        3. Long-form documents
        4. Real-time team chat
        5. Infrastructure observability
        6. Error / exception tracking
        7. Product analytics warehouse

        Local source-control history is usually available through the repository's VCS. Use an authenticated hosting CLI or API, such as `gh`, only when the host exposes it. For the other six categories, classify available integrations using their names, instructions, tool names, and resource descriptors. If an integration could fit more than one category, choose the one matching its primary evidence. Record ambiguous cases in the coverage map.

        Aim for a complete **coverage map**, not a minimal one. A null result from an issue tracker is evidence the decision was not ticketed, a useful fact in itself. Document the null, don't skip the search.

        When the host supports delegation, launch all matching investigators together so they run concurrently. One investigator per category lets each specialize in one source's query vocabulary and result shape. Do not assume a particular subagent type, model ID, or permission flag. Give investigators a non-mutating task, while granting whatever source access the host requires. If delegation is unavailable, run the same category searches sequentially in the lead agent.

        Each investigator gets:
        1. The base prompt from `references/investigator-prompt.md`
        2. The category playbook `references/sources/<source>.md` for the selected MCP, adapted from the examples in `references/source-playbook.md`
        3. The cross-cutting `references/sources/incident-postmortem.md` **if the target code looks defensive** (null checks, retry logic, timeout handling, rate limiting, feature flags, egress guards, OOM handlers)
        4. The code anchor from Step 2 (file paths, symbols, commit hashes, PR numbers, ticket IDs)
        5. The user's original question

        ### Investigator roster. One pass per available evidence category

        Assign one investigation pass per category that has a matching source. When using workers, each owns exactly one tool or integration.

        Each entry lists what the category physically contains and the kind of "why" it uniquely surfaces. Use it to know what to expect back, how to name a gap when a category returns empty, and (only in the rare provably-irrelevant case) to justify a skip. Every category overlaps, but each owns a kind of evidence the others cannot recover.

        1. **Source control investigator**. Repository history, hosting metadata when available, code comments, and tests. Always run this pass when the target is in a version-controlled workspace; otherwise record the missing history as a gap. Best at surfacing *implementation-time rationale captured during review*. PR descriptions stating the problem, review threads debating alternatives, inline comments encoding non-obvious constraints, test names that encode motivating edge cases, and commit messages linking tickets or incidents. Most trustworthy because it ties directly to the diff that shipped.

        2. **Issue / ticket tracker investigator** (e.g. Linear, Jira, GitHub Issues, Plane, Shortcut MCP). Tickets, project docs, status updates, spec attachments. Best at surfacing *the product or business forcing function*. Customer requests ("Acme needs X for their SOC2 audit"), compliance deadlines, parent-initiative framing ("Q3 enterprise readiness"), ticket-level scope changes, and labels that categorize the motivation (`customer:*`, `incident-followup`, `compliance`, `perf-regression`). Strongest when the why is external to engineering.

        3. **Long-form documents investigator** (e.g. Notion, Confluence, Google Docs, Coda MCP). PRDs, specs, RFCs, design docs, ADRs, postmortems, team pages, meeting notes. Best at surfacing *long-form design rationale*. Problem statements, explicit "alternatives considered" and "rejected approaches" sections, strategy documents that set priorities, ADRs with finalized decisions, and postmortem action items that tie directly to code. Where the why is written out before it becomes code.

        4. **Real-time team chat investigator** (e.g. Slack, Discord, Microsoft Teams, Mattermost MCP). Feature-name and symbol searches, PR URL mentions, incident channels (`#sev-*`, `#incident-*`), author-handle activity around the ship date. Best at surfacing *real-time deliberation that never reached a doc*. Fire-drill decisions during incidents, Q&A between the PR author and reviewers, casual "we decided X because Y" threads, and rationale for small changes that didn't warrant a PRD. Especially important when the source control, ticket, and doc paper trail is thin.

        5. **Infrastructure observability investigator** (e.g. Datadog, New Relic, Honeycomb, Grafana, Splunk MCP). Metrics, monitors, dashboards, logs, APM traces, formal incidents. Infra/runtime view. Best at surfacing *infrastructure and runtime reality that motivated the code*. Monitor thresholds whose numbers match code constants, metric spikes in the window right before a PR merge, dashboards created as postmortem action items, incident timelines that reference the target. Strongest when the target reacts to an infra signal (timeouts, retries, rate limits, circuit breakers).

        6. **Error / exception tracking investigator** (e.g. Sentry, Rollbar, Bugsnag, Airbrake MCP). Issues, events, stack traces, releases. Best at surfacing *the specific exceptions and error trajectories that motivated defensive or corrective code*. Stack traces that pass through the target function, issues whose first-seen/last-seen windows bracket the PR ship date, release correlations that show an error stopping at a specific version. Strongest for catch blocks, null guards, type checks, retries, and other defenses.

        7. **Product analytics warehouse investigator** (e.g. Databricks, Snowflake, BigQuery, ClickHouse, dbt, Redshift MCP). Product-analytics events, experiment and feature-flag exposure tables, usage and billing events, query history, warehouse telemetry. Product/data view. Complements infrastructure observability by covering *user behavior and data reality* around the ship date rather than infra metrics. Best at surfacing *product and data reality that shaped the code*. Feature-usage trajectories (a step-function ramp from zero is strong evidence that this PR launched it), experiment/flag exposure data tied to ship decisions, pre-ship distributions that reveal where a threshold constant came from (e.g., `limit = 128 * 1024` matching the p99 of an upload-size column), and data-pipeline scale evidence for migrations/backfills. Strongest for flag-gated code, experiment-driven ships, data migrations, and "where did this number come from" questions.

        ### When to skip an investigator

        Only skip with an **explicit, written justification** that goes in the final "Sources Consulted" section. Two valid reasons:

        - **No MCP is available for that category** in this environment. Flag this as a gap, not a choice. Example: "Real-time team chat skipped. No matching MCP available, so the conversational record was not searchable."
        - **The source is provably irrelevant**, not just "probably irrelevant." A high bar. Example: "Error / exception tracking skipped. Target is a build-time script with no runtime code path." Not "probably not in error tracking, it's a feature not an error."

        "It's pure feature code, error tracking won't have anything" is **not** sufficient, and neither is "I doubt long-form docs would have this." Run the search; let the null result speak. The cost of an investigator returning empty is one subagent. The cost of missing a design doc that actually exists is a wrong answer.

        If your scope assessment suggests a single-commit trivial target where the PR description already contains the complete answer, you may answer inline **only after** confirming all seven available category searches would be redundant. Say so explicitly. This should be rare.

        ## Step 4. Synthesize

        Synthesize the findings in the lead agent or delegate the work to one available worker. Do not assume a particular model, subagent type, or permission mode. The synthesizer must be able to spot-check citations through the same non-mutating evidence sources used by investigators.

        The synthesizer gets:
        1. The investigator findings, including any null results and any categories skipped with justification
        2. The code anchor from Step 2 (file paths, symbols, commit hashes, PR numbers, ticket IDs)
        3. The user's original question
        4. The epistemics framework from `references/epistemics.md`
        5. The synthesizer prompt template from `references/synthesizer-prompt.md`

        Its job is the final output: a confidence-weighted, evidence-cited narrative with clearly separated "what we know" and "what we're inferring" sections, plus honest acknowledgment of gaps and null-result sources.

        ## Step 5. Present

        Take the synthesizer's output and present it to the user. You may lightly edit for clarity or add context from the conversation, but **do not rewrite the confidence language**. The epistemic framing is the product. Dropping the hedges to sound more authoritative is the exact failure mode this skill exists to prevent.

        ## Output Format

        The final output uses this structure. Adapt as needed, but keep the confidence separation intact.

        **The Question**. Restate what the user asked, concisely.

        **The Code in Question**. File paths, line ranges, and key symbols. One or two lines so the reader is anchored.

        **What We Found (direct evidence)**. Claims with explicit citations (PR #, ticket ID, doc URL, chat permalink, commit hash, code comment with file:line). Each bullet is a thing we have textual evidence for. Use present tense and quote or paraphrase the source.

        **What We Can Reasonably Infer**. Claims well-supported by indirect evidence or combinations of signals, but not explicitly stated anywhere. Each bullet must explain the inference chain: "Given A and B, it's likely that C." Use hedged language ("appears to", "likely", "suggests").

        **Competing Hypotheses**. If the evidence fits multiple stories, list them. For each, give the hypothesis, the evidence for it, and the evidence against it. Don't force a winner when the record doesn't support one. (Skip this section if there's a clear answer.)

        **What We Don't Know**. Explicit gaps. Questions the user asked that the evidence didn't answer. Sources we searched and came up empty. Be specific. "We searched the issue tracker for 'rate limit' and found no ticket discussing this specific threshold" is more useful than "we don't know why."

        **Sources Consulted**. One line per investigator, including the ones that returned nothing. The reader should see at a glance (a) which MCPs were queried, (b) which came back empty, and (c) which were skipped and why. This coverage map lets the user judge breadth and redirect if something obvious was missed.

        Format each line as: `- <Source>: <what was searched>. <what was found, or "no relevant results," or "skipped. reason">.`

        Example:
        - Source control (git/gh): `git log --follow backend/retry.ts`, PRs #49074, #47812. Found PR #49074 introduced exponential backoff and linked ENG-4421.
        - Issue tracker (Linear): searched for "retry" and ENG-4421. Found ENG-4421 parent issue but no discussion of backoff parameters.
        - Long-form docs (Notion): searched for "retry policy," "backend retries," "ENG-4421." No relevant results.
        - Real-time team chat (Slack): skipped. No matching MCP available in this environment. Gap: conversational record not searched.
        - Infrastructure observability (Datadog): searched for `retry_count` metric and monitors around 2024-08-14. Found monitor "Upstream 5xx rate > 1%" created same day as PR #49074.
        - Error / exception tracking (Sentry): searched for issues first-seen in Aug 2024 with stack through `retry.ts`. Found issue SENTRY-3821 spiking in the week before the PR.
        - Product analytics warehouse (Databricks): queried `<your_analytics_db>.<schema>.stg_backend_upstream_retry` for the 30-day window around 2024-08-14. Daily failure-classified event count fell from ~1.2k/day pre-PR to <50/day post-PR. Also checked `system.query.history` for relevant migration queries. None found.

        After the Sources Consulted block, if the user's `why` question is a precursor to actually changing this code, convert the lineage findings into a Preserve / Change / Avoid / Risk constraint set suitable for planning the change.

        ## Common Failure Modes to Avoid

        - **Confident storytelling**. A plausible narrative built from thin evidence. A bullet with no citation goes in "inferred" or "hypotheses," not "what we found."
        - **Citing the code as evidence for its own intent**. "Handles the null case because it checks for null" is mechanics, not motivation. Motivation comes from an external source (PR discussion, ticket, comment, conversation) or is labeled as inference.
        - **Recency bias**. Assuming the most recent commit is authoritative. The current shape is often the accretion of many earlier decisions. Trace back.
        - **Sycophantic agreement**. If the user suggests a reason ("I assume this is for performance?"), treat it as a hypothesis and check the evidence independently, don't just confirm it.
        - **Skipping the gaps section**. An honest accounting of what you couldn't find out is part of the value.
        - **Skipping investigators by anticipation**. Deciding up front that "long-form docs probably don't have this" or "this isn't an error tracking thing" without searching. The default-to-all-seven posture prevents this. A null result is a data point; a skipped search is a blind spot.
        - **Collapsing investigators into one agent**. Each MCP has its own query vocabulary, result shape, and pitfalls; pooling them dilutes specialization and makes coverage harder to reason about. Always one investigator per category.

        ## Reference Files

        - `references/epistemics.md`. Confidence tiers and phrasing guide. The synthesizer must follow it.
        - `references/investigator-prompt.md`. Base prompt template for investigator subagents.
        - `references/source-playbook.md`. Index pointing at the category playbooks below.
        - `references/sources/*.md`. One self-contained example playbook per category, plus cross-cutting `incident-postmortem.md`. Give an investigator the single file that matches its category and adapt it to the available MCP.
        - `references/synthesizer-prompt.md`. Prompt template for the synthesizer subagent, including the output format.
      '';

      ".agents/skills/why/agents/openai.yaml".text = ''
        policy:
          allow_implicit_invocation: false
      '';

      ".agents/skills/why/references/epistemics.md".text = ''
        # Epistemics

        How to reason about confidence when evidence is historical, fragmentary, and sometimes contradictory, and how to communicate it without flattening it into false certainty.

        Code doesn't carry its own motivation. You can read what code does; you can't read *why it exists*. That lives in commits, PRs, tickets, docs, and conversations, all incomplete, biased, and sometimes missing entirely. Pretending otherwise produces confident-sounding guesses that mislead the user.

        ## Confidence Tiers

        Every claim in the final output must sit in one of these tiers. The tier determines which output section the claim goes in and how it's phrased.

        ### 1. Direct

        An explicit, textual citation that answers the question. Not "the code does X so the author must have wanted X." Something an author actually *wrote* that says why.

        Examples:
        - A PR description that says "this fixes the bug where users with >1000 items couldn't paginate"
        - A ticket that says "we're adding this because customer Acme requested it in their security review"
        - A code comment that says "// clamp to 100 because the upstream API rejects larger values"
        - A design doc that says "we chose option A over option B because we need persistence across restarts"
        - A chat message from the author saying "switching to this approach since the old one was flaky in tests"

        Phrasing: confident, present tense. "This exists because X." Cite the source.

        ### 2. Supported

        Multiple pieces of indirect evidence converge. No single source states it explicitly, but the pattern across sources makes it likely.

        Examples:
        - The PR title says "improve performance," the ticket is labeled "perf," and the surrounding commits all touch the same hot path
        - Multiple tests were added alongside the change, all exercising edge cases with very large inputs
        - The author's other PRs from the same week all mention the same incident in their descriptions

        Phrasing: confident but clearly derived. "The evidence points strongly to X: [the specific pieces]." Cite multiple sources.

        ### 3. Inferred

        A reasonable reading of the context, but nothing explicitly supports it. The reader should understand this is *your interpretation*, not a fact from the record.

        Examples:
        - The PR doesn't say why, but given the error was happening in production (per the incident channel timing) and the fix was rushed (merged the same day), it was likely a hotfix.
        - The function name suggests retry logic; the retry count is 3; this matches the team's general convention of "3 retries" seen elsewhere in the codebase.

        Phrasing: hedged. "It appears", "likely", "suggests", "is consistent with", "one reading is". Make the inference chain explicit: "Given A and B, C seems likely because D."

        ### 4. Speculative

        A plausible hypothesis, but the evidence is thin and other explanations fit equally well. Presenting these is valuable, but mark them clearly as guesses.

        Examples:
        - "This might be a workaround for a browser bug that's since been fixed, but we found no contemporary evidence of that."
        - "It's possible this threshold was chosen to match an SLA commitment, but no SLA doc references it."

        Phrasing: explicitly speculative. "One possibility is X, but we have no direct evidence." Usually lives in the "Competing Hypotheses" section alongside other possibilities.

        ### 5. Unknown

        You looked and couldn't find out. A valid and important outcome. Document it.

        Phrasing: "We searched X, Y, and Z and found no evidence of why." Be specific about *what* you searched. "We couldn't find out" is less useful than "we searched the ticket tracker with keywords A and B, scanned the 6 PRs that touched this file since 2023, and grep'd the repo for string literals matching the threshold; none surfaced a rationale."

        ## Phrasing Guide

        ### Words that carry confidence. Use carefully

        These imply **Direct** or **Supported** confidence. Don't use them for inferences.

        - "because". Implies a causal claim with evidence
        - "the reason is". Same
        - "was designed to". Claims author intent
        - "fixes", "addresses", "solves". Claims the change achieved its goal
        - "the team decided". Claims a group decision happened

        If you're using these, you should have a citation immediately adjacent.

        ### Words that hedge. Use for inferences

        - "appears to"
        - "seems to"
        - "likely"
        - "suggests"
        - "is consistent with"
        - "one reading is"
        - "plausibly"
        - "may have been"
        - "the evidence points toward"

        These signal that you're interpreting, not reporting. Use them liberally in the "What We Can Reasonably Infer" section.

        ### Words to avoid

        - "obviously". If it were obvious, the user wouldn't be asking
        - "clearly". Almost always precedes a claim that isn't clear
        - "of course". Same
        - "just" (as in "it's just X for performance"). Dismissive and usually hides uncertainty
        - "I think" / "I believe". You're synthesizing evidence, not giving a personal opinion. Use "the evidence suggests" instead.

        ### Avoid rationalization

        Code that "makes sense" today may have been written for reasons that no longer apply, or that were wrong when they were written. Don't retrofit a clean rationale onto messy history.

        Resist the urge to:
        - Assume the author did the "right" thing and work backward to justify it
        - Assume a consistent pattern across the codebase was intentional when it might be copy-paste
        - Turn an absence of evidence into evidence of absence ("no one mentioned security concerns, so it must not have been a concern")

        ## The Sycophancy Trap

        Users often phrase `why` questions with an embedded hypothesis: "Why do we do it this way, I assume it's for performance?" Don't simply confirm it. Treat it as one candidate among others and check the evidence independently. If the evidence supports it, say so with citations; if not, say so and present what the evidence *does* support.

        The user's guess is a prompt for investigation, not a conclusion to validate.

        ## When Evidence Contradicts

        If two sources disagree (the PR description says one thing, the ticket says another), surface both. Don't pick the one that fits a tidier narrative. A typical pattern:

        - **The ticket says** "we need this for customer X's compliance requirement"
        - **The PR says** "cleaning up tech debt in this area"

        Both may be true (the ticket motivated the work, the PR is the author's framing of it), or one may be wrong. Present both with their citations and let the user make the call.

        ## When Evidence Is Missing

        An honest "we don't know" is one of the most valuable outputs this skill can produce. The user now knows:

        - The answer isn't in the obvious places
        - They'll need to ask a human (the original author, the product owner, the team lead) to find out
        - Or they can decide the question isn't worth pursuing further

        Failing to mark a gap and filling it with a confident guess actively harms the user; they'll act on the guess.

        When you hit a gap, name it concretely:
        - What question you were trying to answer
        - What sources you searched
        - What you searched for in each
        - What you found (nothing, or only tangentially related material)

        ## Calibration Check Before Finalizing

        Before delivering the output, the synthesizer should review every claim in "What We Found" and "What We Can Reasonably Infer" and ask:

        1. Does this claim have a citation? If not, either add one or move it to "Inferred" / "Hypotheses".
        2. Is the phrasing calibrated to the tier? (A Direct claim can use "because"; an Inferred claim cannot.)
        3. Am I treating the code itself as evidence for its own intent? If so, that's not evidence. Remove or reclassify.
        4. Does the output include a "What We Don't Know" section? If no gaps are mentioned, that's suspicious. Either the evidence was unusually complete or something is being swept under the rug.
      '';

      ".agents/skills/why/references/investigator-prompt.md".text = ''
        # Investigator Prompt Template

        Build each investigator's prompt from this template; fill in the placeholders. Append the single category playbook `sources/<source>.md` matching this investigator's evidence category (see `source-playbook.md` for the index). If the target code looks defensive (null checks, retry logic, timeout handling, rate limiting, feature flags, egress guards, OOM handlers), also append `sources/incident-postmortem.md` for the incident-flavored queries to run inside its own source.

        ---

        You are investigating the historical context and motivation behind a piece of code. A separate synthesizer combines your findings with other investigators' into a final answer, so gather evidence accurately rather than writing prose.

        Other investigators search different sources in parallel. Don't try to cover everything. Focus on your assigned source and go deep.

        ## Operating Posture

        Work like a careful, cautious, precise investigator. Don't produce a narrative; surface evidence and describe it accurately, including the parts that don't fit a tidy story. The more boring and exact your output, the more useful it is. A single verbatim quote with a precise citation beats a paragraph of plausible-sounding summary.

        - **Quote, don't paraphrase** when the exact wording matters. Citations should let the reader jump to the source and confirm the claim in seconds.
        - **Go wide before going deep.** Cast a broad first net so you don't miss related context. Only then narrow in.
        - **Track what you searched, not just what you found.** An absence is only useful if the reader knows what was looked for. Record queries verbatim.
        - **Resist the story.** If three pieces of evidence line up neatly and a fourth contradicts them, the contradiction is the most interesting finding. Don't file it away.
        - **Consider the counterfactual.** Before reporting a finding as strong, ask whether you would expect to find it if your current reading were wrong, and how the evidence would differ.
        - **Never invent.** If you're tempted to round a partial finding up into a confident statement, stop and label it partial. The synthesizer is counting on your output being accurate.

        ## The Question

        > {QUESTION}

        ## The Code Anchor

        **Target files:** {FILES_WITH_LINE_RANGES}

        **Key symbols:** {SYMBOLS}

        **Initial commits touching this code (most recent first):**
        {COMMIT_LIST}

        **PR numbers extracted from commit messages:** {PR_NUMBERS}

        **Ticket IDs mentioned in commits or PR bodies (if any):** {TICKET_IDS}

        ## Your Assigned Source

        {SOURCE_NAME}

        {SOURCE_PLAYBOOK_SECTION}

        ## Investigation Instructions

        Gather **evidence**; don't answer the question directly. The synthesizer weighs the evidence and forms conclusions. Follow this loop:

        1. **Cast a wide net first.** Start broad so you don't miss related context, then narrow in on specific items.
        2. **Read the whole thing.** Read any PR, ticket, doc, or thread fully, not just the title or summary. The key evidence is often buried in a comment, a subtask, or a follow-up.
        3. **Follow links within your assigned source.** If a PR references another PR or commit, pull it. If a ticket links a parent or sibling, pull it. If a doc links another doc, pull it. Stay inside your assigned source. When you spot a cross-source reference, do NOT chase it yourself. Record it under "Additional Leads" so the investigator assigned to that source can pick it up. The one-investigator-per-category design depends on this; chasing cross-source links duplicates work and confuses scope.
        4. **Capture quotes verbatim** with their location (PR number, ticket ID, URL, commit hash, file:line). The synthesizer needs to cite this precisely.
        5. **Note absences.** If you searched for something and came up empty, that's also a finding. Record what you searched for and what you didn't find.
        6. **Watch for contradictions.** If two items in your source disagree, record both. Don't suppress the inconvenient one.

        Don't synthesize or form a final opinion on "the why." Collect the raw material honestly and completely; the synthesizer does the reasoning.

        ## Epistemic Discipline

        - **Don't confuse mechanics with motivation.** A commit changing `limit = 50` to `limit = 100` shows the change, not necessarily why. Look for the explanation in the commit message, PR description, linked ticket, or review comments.
        - **Don't infer intent from code style.** "The author chose a functional approach" is an observation about code, not evidence of intent. Claim intent only when the author stated it.
        - **Preserve uncertainty.** If the evidence is ambiguous, say so. If one reading is more plausible but not certain, say that. Don't collapse ambiguity to look decisive.
        - **No silent substitutions.** If the question is about feature X and you only find evidence about feature Y, don't present Y's evidence as if it answers X.

        ## Output Format

        Return your findings in this structure. The synthesizer will read it directly.

        ### Source
        Which source you investigated (source control, issue / ticket tracker, long-form documents, real-time team chat, infrastructure observability, error / exception tracking, product analytics warehouse, code comments, etc.).

        ### What I Searched
        The queries you ran, the items you opened, the places you looked. Be specific. This tells the synthesizer how thorough the investigation was and what might still be unsearched.

        ### Direct Evidence Found
        For each piece that explicitly addresses the question:
        - **What it says**: verbatim quote or accurate paraphrase
        - **Where it's from**: PR #123, ticket ID, doc URL, chat permalink, commit hash, or file:line
        - **Author and date** (if available)
        - **Relevance**: one sentence on how it bears on the question

        ### Indirect / Circumstantial Evidence
        Items that don't explicitly answer the question but bear on it. For each:
        - **What it is**: brief description
        - **Where it's from**: location
        - **What it suggests**: what a careful reader might infer, and why. Name the inference chain.
        - **Alternative readings**: if the same evidence could support a different interpretation, note it

        ### Contradictions
        Two items that disagree with each other, with both citations.

        ### Gaps
        What you searched for and didn't find. Be specific: "Searched the issue tracker for [query] across [time range]. No matching issues." These absences are valuable data.

        ### Additional Leads
        Anything that suggests further investigation in a different source. For example, if a PR references a chat thread that wasn't in your source, note it so the real-time team chat investigator or a follow-up pass can pursue it.

        ## What You're Not Doing

        - Writing the final answer. The synthesizer does that.
        - Picking sides in contradictions. Surface them.
        - Speculating beyond what the evidence supports. A hunch with no evidence isn't evidence.
        - Reading the code itself to figure out intent. You may read the code to understand what the target *is*, but don't confuse "what the code does" with "why."
      '';

      ".agents/skills/why/references/source-playbook.md".text = ''
        # Source playbooks

        The why skill spawns one investigator per available evidence category, each reading a single source-specific playbook below. The playbooks are concrete examples for common MCPs; adapt them for a different MCP in the same category.

        | Category | Playbook | Example MCP it documents |
        |---|---|---|
        | Source control history | [`code-archaeology.md`](./sources/code-archaeology.md) | git, `gh` |
        | Issue / ticket tracker | [`linear.md`](./sources/linear.md) | Linear (adapt for Jira, GitHub Issues, Plane, Shortcut) |
        | Long-form documents | [`notion.md`](./sources/notion.md) | Notion (adapt for Confluence, Google Docs, Coda) |
        | Real-time team chat | [`slack.md`](./sources/slack.md) | Slack (adapt for Discord, Microsoft Teams, Mattermost) |
        | Infrastructure observability | [`datadog.md`](./sources/datadog.md) | Datadog (adapt for New Relic, Honeycomb, Grafana, Splunk) |
        | Error / exception tracking | [`sentry.md`](./sources/sentry.md) | Sentry (adapt for Rollbar, Bugsnag, Airbrake) |
        | Product analytics warehouse | [`databricks.md`](./sources/databricks.md) | Databricks SQL (adapt for Snowflake, BigQuery, ClickHouse, dbt) |

        Cross-cutting:

        - [`incident-postmortem.md`](./sources/incident-postmortem.md). Add this if the target code looks defensive (null checks, retry, timeout, rate limit, feature flag, egress guard, OOM handler).
      '';

      ".agents/skills/why/references/sources/code-archaeology.md".text = ''
        # Code Archaeology (git + in-repo)

        ## What this source contains

        - Commit history (messages, dates, authors, diffs)
        - PR descriptions, review comments, and discussion threads (via `gh`)
        - Inline code comments, TODOs, FIXMEs, deprecation notes
        - ADRs (architectural decision records) if the repo keeps them
        - Tests. Names and assertions often encode the edge cases that motivated a change
        - Related files modified in the same commits (co-change signal)
        - CHANGELOG entries, release notes in the repo
        - Issue/ticket IDs mentioned in commit messages and PR bodies

        The most trustworthy source, tied directly to the code, and the most complete. Everything that went through the repo should be here.

        ## How to search it

        Expand the seed commit list:

        ```bash
        # Full history of the file through renames
        git log --follow --oneline -- <file>

        # Pickaxe: commits that added or removed this exact text
        git log -S '<exact_string_from_code>' -- <file>

        # Or for patterns:
        git log -G '<regex>' -- <file>

        # Who wrote each line and when
        git blame -L <start>,<end> <file>

        # The full diff of a specific commit
        git show <hash>

        # Commits between two points affecting this file
        git log <old>..<new> -p -- <file>
        ```

        For each substantive commit, pull the PR context:

        ```bash
        # Find the PR number from the merge commit or branch
        git log -1 --format=%B <hash>

        # Full PR context: body, review comments, linked issues
        gh pr view <number> --json title,body,author,createdAt,mergedAt,labels,closingIssuesReferences,comments,reviews,files

        # The --json reviews and comments fields are where the real signal is
        ```

        Look for out-of-band docs:

        ```bash
        # ADRs often live in docs/adr/ or similar
        rg -l -i 'architecture.decision' --glob '*.md'

        # TODOs and FIXMEs near the target
        rg -n -C2 '(TODO|FIXME|HACK|XXX|NOTE)' <target_file>

        # Related tests. Names often encode the "why"
        rg -l '<symbol>' --glob '*test*'
        ```

        ## What good evidence looks like here

        - A PR description that explains the problem being solved, not just the change ("This fixes the pagination bug that caused X")
        - A long review thread where alternatives were debated
        - An inline comment near the target line that explains a non-obvious constraint
        - A test named `test_handles_edge_case_when_X` that reveals an edge case motivating the code
        - A commit message that references a ticket or incident ID
        - A CHANGELOG entry that summarizes the user-visible rationale

        ## Common pitfalls

        - **Squash-merge flatlands.** If the repo squashes PRs, individual commits in the branch history are lost. Fall back to PR body and comments.
        - **Misleading commit messages.** "Small refactor" sometimes hides an intentional behavior change. Look at the diff, not the message.
        - **Cargo-culted patterns.** The author may have copied a pattern without understanding why. Check if the pattern originated earlier in the codebase and investigate *that* commit.
        - **Bot commits and auto-merges.** Dependabot, Renovate, and automated backports usually don't carry motivation. Skip them when trying to find intent.
        - **Treating code as evidence of intent.** The code itself isn't evidence for why it exists. Evidence comes from commit messages, PRs, comments, tests, docs. Don't cite "the function is named X" as evidence of intent.

        ## What to return

        Every commit/PR/comment that bears on the question, with:
        - The exact text (quoted)
        - The hash / PR number / file:line
        - Author and date
        - Whether it's direct (explicitly addresses the question) or circumstantial
      '';

      ".agents/skills/why/references/sources/databricks.md".text = ''
        # Databricks Analytics & System Tables

        ## What this source contains

        Databricks is the product-analytics, data-pipeline, and warehouse-telemetry layer. It complements Datadog: Datadog is the *infra/runtime* view, Databricks is the *product/data* view (what users did, which experiments ran, how feature usage evolved, where a threshold constant came from).

        - **Product analytics events.** `your_warehouse.events.analytics_track_event` (raw) and typed, deduplicated per-event dbt models in `<your_analytics_db>.<schema>.<table>`. User behavior: feature invocations, clicks, accepts/rejects, submissions, client-reported errors.
        - **Usage & billing events.** `your_warehouse.events.usage_event` / `<your_analytics_db>.<schema>.stg_usage_events`; `your_warehouse.events.raw_model_event` / `<your_analytics_db>.<schema>.stg_raw_model_events`. For cost- or volume-driven decisions.
        - **Experiment / feature-flag data.** Exposure and outcome tables. **Schema is company-specific.** Probe with `SHOW TABLES` before assuming names.
        - **System tables.** `system.query.history`, `system.compute.warehouses`, `system.billing.*`, `system.access.audit`. Answer "was this query expensive?", "how often did anyone run this?", "when did warehouse load spike?"
        - **dbt lineage.** Models in `<your_analytics_db>.<schema>` reveal what pipelines depend on a table/field; upstream changes frequently motivate consumer-code changes.
        - **Databricks notebooks.** Exploratory analyses engineers wrote before code changes. **Not queryable via the SQL MCP.** If you suspect the rationale lives in a notebook, name it as a gap.

        ## How to search it

        Use the Databricks SQL MCP. Primary tool: `execute_sql_read_only`. If it returns a `statement_id`, poll with `poll_sql_result` rather than re-running.

        **Orient before querying.** Schemas are company-specific; probe before trusting a table name:

        ```sql
        SHOW TABLES IN <your_analytics_db>.<schema> LIKE '*<keyword>*';
        DESCRIBE TABLE <your_analytics_db>.<schema>.stg_<event>;
        ```

        **Time-bound every query.** These tables are huge and unconstrained scans time out. Filter on `_timestamp` (events) or `start_time` (`system.query.history`) with a window bracketing the ship date, typically ~30 days before and after, wider only for strong reason.

        **Prefer typed dbt models over the raw table.** `<your_analytics_db>.<schema>.<table>` is deduplicated, typed, and liquid-clustered; `your_warehouse.events.analytics_track_event` has duplicates and untyped `properties_json`. Model-name pattern: `stg_<source>_<event_name_with_underscores>`, where `<source>` is `app`, `backend`, `website`, or `cli`; confirm the exact model name with `SHOW TABLES` when the pattern alone doesn't resolve it. Drop to the raw table only when there's no dbt model yet, or you need events from inside the dbt refresh lag.

        **Column conventions on the typed dbt models** (knowing these avoids a `DESCRIBE` round-trip):

        - `_timestamp`, `_id`, `_auth_id`, `_request_id`, `event_name`. Standard on every model
        - `properties_<name>`. Typed, underscore-cased event properties (`properties_entrypoint`, `properties_size_bytes`, …)
        - `context_team_id`, `context_client_version`, `context_country`, `context_client_os`. Pre-extracted client context

        ### Investigation patterns that tend to pay off

        Pick the table + column combination that matches the target:

        1. **Event usage trajectory.** Daily counts on the relevant `stg_*` model across a ±30d window around the PR merge. A step function from zero to steady volume within a day or two of the merge is strong circumstantial evidence the PR launched the feature. A decay to zero suggests a deprecation or deletion.
        2. **Guard-rail / defensive-check origin.** Distribution (median / p99 / max) of the relevant `properties_<name>` column in the 14 days *before* the PR. A p99 that matches the target's threshold constant suggests the number was chosen from data.
        3. **Experiment / feature-flag lookup.** `SHOW TABLES ... LIKE '*experiment*'` to find the exposure table, then pull exposure counts by variant for the relevant flag key near the PR date.
        4. **Query-history evidence for migrations, backfills, or perf rewrites.** `system.query.history` filtered by `statement_text ILIKE '%<table_or_symbol>%'` with a tight `start_time` window surfaces the expensive queries that likely motivated the change (sort by `total_duration_ms` or aggregate `SUM(read_bytes)`, `COUNT(*)`).
        5. **dbt lineage.** If the target reads from or writes into a `<your_analytics_db>.<schema>` model, the model's own git history (in this repo) often carries the rationale. Hand that lead back to the git investigator rather than chasing it yourself.

        ## What good evidence looks like here

        Beyond the pattern shapes above:

        - An error-classifying event's count drops to near zero in the days after a defensive-code PR. Suggests the PR resolved that error class
        - An exposure table row names the target's feature-flag key with a "shipped" / "concluded" decision around the PR ship date

        ## Common pitfalls

        - **Instrumented ≠ caused.** An event's existence means someone cared enough to log it, not that the target code exists *because* of it. Pair with a PR/commit citation from the git investigator before claiming causation.
        - **Silent instrumentation changes.** A step function in event volume may mean a new event started being logged, not that user behavior changed. Check for instrumentation PRs in the same window before reading the ramp as a feature-launch signal.
        - **Schema drift.** Event properties evolve; a column on the typed dbt model today may not have existed when the target was written. Older data may carry the property only inside raw `properties_json`.
        - **dbt refresh lag.** `<your_analytics_db>.<schema>.*` is rebuilt on a schedule (often hourly/daily). For events from the last few hours, fall back to `your_warehouse.events.*` and deduplicate by `_id`.
        - **Company-specific tables.** Experiment, feature-flag, billing, and usage tables vary. Reporting a result from a table whose existence you never confirmed is a classic failure mode. Probe with `SHOW TABLES` / `DESCRIBE TABLE` first.
        - **Retention cliff.** If the relevant window predates the table's retention or the dbt model's creation date, that's a *gap*, not a null result. Name it explicitly so the synthesizer doesn't read "no results" as "no activity."
        - **Notebooks aren't queryable.** The SQL MCP can't see Databricks notebooks. If you suspect the rationale lives in one, return a gap.

        ## What to return

        For each relevant finding:
        - Type (product event / experiment exposure / usage or billing event / system-table row / dbt model)
        - Fully-qualified table name and the exact query you ran
        - Time window queried
        - Compact numeric summary (counts, percentiles, first/last-seen timestamps). **Don't dump raw rows.**
        - Temporal correlation with the target's ship date (e.g., "first row 2024-08-15; PR #49074 merged 2024-08-14")
        - Relevance + strength: direct / circumstantial / weak
      '';

      ".agents/skills/why/references/sources/datadog.md".text = ''
        # Datadog Telemetry

        ## What this source contains

        Datadog holds the runtime record: what actually happened in production, as opposed to what was planned or discussed.

        - **Metrics.** Counters, gauges, histograms instrumented by the team. A metric's *presence* is itself evidence: someone thought this number worth watching.
        - **Monitors & alerts.** Conditions the team decided warranted waking someone up. A monitor firing on `rate_limit_hit > 10/min` is direct evidence the team worried about that threshold.
        - **Dashboards.** Curated views. The charts tell you what the team considers important for a subsystem.
        - **APM traces & spans.** Request-level runtime data. Useful for "why is this slow" / "why is there a timeout here" questions.
        - **Logs.** High-volume event records. Often contain the error conditions that motivated defensive code.
        - **Incidents.** Formal incident records with timelines and linked postmortems.
        - **Notebooks.** Exploratory investigations; often contain hypotheses and analyses.

        Datadog answers "what was the production reality around the time this code was written?", which often explains the code's shape.

        ## How to search it

        Use the Datadog MCP. Start broad, then narrow.

        1. **Identify the owning service(s).**

           ```
           search_datadog_services (filter by name or team)
           search_datadog_service_dependencies (see upstream/downstream)
           ```

        2. **Dashboards and monitors first. They tell you what the team cares about.**

           ```
           search_datadog_dashboards (query: feature name, service name, symbol)
           search_datadog_monitors   (same queries)
           ```

           When a dashboard or monitor covers the target, note its queries and watched thresholds. The threshold is frequently the answer to "why is this clamped at N?"

        3. **Metrics around the target.**

           ```
           search_datadog_metrics (by name pattern, e.g., the feature or symbol)
           get_datadog_metric_context (metadata: description, units, tags)
           get_datadog_metric (timeseries; "was there a spike around the PR date?")
           ```

           Correlating a metric's trajectory with the target's add/change date is strong supporting evidence: "the `payment_timeout` metric spiked 2023-11-03, and the retry logic merged 2023-11-06."

        4. **Logs. Narrow, don't dump.**

           ```
           search_datadog_logs (raw log patterns near the target, set use_log_patterns=true)
           analyze_datadog_logs (SQL-style aggregations, only when you need counts)
           ```

           Search with symbols, error strings, or feature names. **Strongly prefer time-bounded queries** (e.g., 30 days before/after the change). Log volume is huge; unconstrained searches waste time and may time out.

        5. **APM spans and traces.**

           ```
           aggregate_spans    (stats: "how often does this endpoint fail?")
           search_datadog_spans (inspect individual spans)
           get_datadog_trace  (a specific trace ID)
           ```

           Useful for timeouts, retries, slow paths, and cross-service behavior.

        6. **Incidents.**

           ```
           search_datadog_incidents (by title, team, date range)
           get_datadog_incident     (full detail for a specific incident)
           ```

           If the target looks defensive, search for incidents around the time it was added. An incident whose timeline includes "added defensive check for X" is near-direct evidence.

        ## What good evidence looks like here

        - A monitor whose query and threshold match the constraint the code enforces (code clamps to 100; monitor alerts when requests exceed 100/min)
        - A dashboard created by the target's author, with widgets that correspond to what the code measures or guards against
        - A metric showing a production spike immediately before the code was merged, and stable values after
        - An incident record referencing the target code, the same symbols, or the same error strings
        - Logs showing a specific error pattern the defensive code would prevent, timestamped in the window before the change

        ## Common pitfalls

        - **Correlation is not causation.** A spike before a PR and stabilization after is suggestive, not definitive. Other changes may have landed in the same window. Check neighboring PRs.
        - **Overfitting to the chart you found.** Datadog visualizations are *made* by humans and reflect that human's framing. A chart named "retry success rate" is evidence the team cared about retry success, not that it's why a specific line of code exists.
        - **Vanished telemetry.** Metrics can be renamed, deleted, or have short retention. If you can't find data from the relevant window, that's a gap, not a null result.
        - **Noise at scale.** Searching logs for a common string returns thousands of matches. Narrow by service, tag, and time aggressively. Use `analyze_datadog_logs` to aggregate rather than dumping raw logs.
        - **Instrumented != caused.** A metric's existence tells you someone cared enough to measure something, not that the code was added *because* of it. Cross-reference with commit/PR dates.

        ## What to return

        For each relevant item:
        - Type (dashboard / monitor / metric / log pattern / trace / incident / notebook)
        - Title or name
        - Link or identifier (dashboard ID, monitor ID, metric name, incident ID)
        - Owner/author and created/modified date
        - The specific condition, query, or quote that bears on the question (verbatim where possible)
        - Relevance: what this suggests about the target code, and how strong the connection is
      '';

      ".agents/skills/why/references/sources/incident-postmortem.md".text = ''
        # Incident & Postmortem Context

        Not a separate source, a **cross-cutting angle**. Incidents often motivate defensive code ("we added this check after the X outage"), so if the target looks defensive (null checks, retry logic, timeout handling, rate limiting, feature flags), specifically hunt for incident history across every available source:

        - **Notion**: search for postmortems mentioning the target file, feature, or error string
        - **Linear**: look for tickets labeled `incident`, `sev-*`, `postmortem-action-item`, `reliability`
        - **Slack**: search `#sev-*` and `#incident-*` channels around the dates the target code was added
        - **Git**: commits with messages like "fix for incident", "add defensive check", "revert" followed by "re-apply with..." are strong signals
        - **Datadog**: `search_datadog_incidents` for formal incident records with timelines; dashboards and monitors created as postmortem action items
        - **Sentry**: issues whose first-seen/last-seen window aligns with the target's PR ship date; stack traces through the target
        - **Databricks**: product-analytics events that classify an error condition (client-reported failures, user-visible retry events, etc.) often spike during an incident window. A drop in that event count after the target PR ships is circumstantial support that the target code resolved the user-visible symptom, even when Datadog/Sentry signal is noisy.

        If you find an incident link, fetch the full postmortem. Postmortems typically have an "Action Items" section that ties directly to code changes. When multiple sources corroborate (a Datadog incident ID appears in a Linear ticket, which appears in a Notion postmortem, which appears in a Slack thread that links to the target PR, and the Databricks error-event count drops after the fix), the evidence is especially strong.

        Worth spending time on when the code's defensive character makes an incident-driven origin plausible. Skip it for code that doesn't look defensive.
      '';

      ".agents/skills/why/references/sources/linear.md".text = ''
        # Linear Tickets

        ## What this source contains

        - Issues describing features, bugs, and their motivation
        - Project docs attached to issues (often PRDs or specs)
        - Parent/sub-issue relationships (broader initiative → specific tickets)
        - Comments on issues (clarifications, scope changes, "why we're doing this" rationale)
        - Labels (e.g., `compliance`, `customer-request`, `perf`) that signal the type of motivation
        - Status updates that explain scope changes
        - Attachments and linked GitHub PRs

        Linear is where the product/business context often lives: the "we're doing this because customer X asked" or "this is for the Q3 compliance initiative" layer.

        ## How to search it

        Use the Linear MCP.

        1. **Start with linked tickets.** If the seed commits or PRs reference ticket IDs (e.g., `ENG-1234`, `[BUG-567]`), fetch those first with `get_issue`. Read the full issue including comments.
        2. **List related issues by keyword.** Use `list_issues` with text search for the feature name, key symbol, or business term. Try multiple phrasings.
        3. **Walk the issue tree.** If you land on a sub-issue, fetch its parent. Sub-issues are tactical; parents often carry the "why."
        4. **Read project docs.** If the issue belongs to a project, use `get_project` and check attached docs. Project-level documents are where specs and rationale are most often captured.
        5. **Check labels and milestones.** Labels hint at the category of motivation (customer-request, incident-followup, compliance). Milestones tie work to deadlines, which often reveal motivation.

        ## What good evidence looks like here

        - An issue description stating the business problem: "Customer Acme needs X because of their SOC2 audit"
        - A comment recording a decision: "We decided to go with approach B because approach A would require touching the billing service"
        - A parent issue titled like an initiative: "Q3 Enterprise Readiness" or "Reduce Payment Failures"
        - An attached PRD or spec
        - Labels like `customer:acme`, `incident-followup`, `compliance`, `perf-regression`

        ## Common pitfalls

        - **Scope drift.** The ticket the PR references may have been closed and reopened with a different scope. Read the whole history.
        - **Mechanical templates.** Some teams require "Why" sections but fill them with boilerplate. Generic text ("improve user experience") is probably not a real answer.
        - **Stale tickets.** Old tickets often reflect a version of the plan that changed. Check dates and cross-reference with the code's ship date.
        - **Closed-as-duplicate chains.** Follow the duplicate-of relationships back to the canonical ticket.
        - **Private workspace content.** If you can't access an issue, note that as a gap rather than guessing.

        ## What to return

        For each relevant ticket:
        - Ticket ID and title
        - The problem/motivation quoted from the description or comments (not paraphrased; the synthesizer needs the exact text to cite)
        - Labels, parent issue, project
        - Author, created date, closed date
        - Link to the ticket if available
      '';

      ".agents/skills/why/references/sources/notion.md".text = ''
        # Notion Docs

        ## What this source contains

        - PRDs (product requirement documents)
        - Technical specs and RFCs
        - Architectural decision records (ADRs)
        - Meeting notes from design reviews
        - Team pages with domain context
        - Postmortems from incidents
        - Runbooks that may explain defensive code
        - Strategy documents that set priorities

        Notion is where "why" often lives in long-form before it becomes code. A significant feature usually has a doc.

        ## How to search it

        Use the Notion MCP.

        1. **Keyword searches with `notion-search`.** Try:
           - The feature name
           - Key symbols / class names from the target code
           - Author handles (design docs are often authored before the code lands)
           - Error strings or user-visible terms
           - Time-bounded queries if you know when the code shipped
        2. **Fetch candidate pages with `notion-fetch`.** Read the full content, not the preview; rationale is often buried mid-document.
        3. **Follow backlinks and child pages.** Design docs often have sub-pages for alternatives considered, appendices, or implementation notes.
        4. **Check related databases.** `notion-query-data-sources` and `notion-query-meeting-notes` can surface meeting notes that discussed the decision.
        5. **Search author-specific spaces.** If the PR author has a personal notebook (common at some companies), it may hold exploratory thinking that preceded the code.

        ## What good evidence looks like here

        - A PRD with a "Problem statement" or "Motivation" section that matches the target code's purpose
        - An "Alternatives considered" or "Rejected approaches" section
        - A postmortem that names the target code as the fix for a specific incident
        - Meeting notes that record "we decided X because Y" and tie to the same author/date range as the PR
        - An ADR template filled out non-trivially (status, context, decision, consequences)

        ## Common pitfalls

        - **Outdated docs.** Specs are often written before implementation and not updated; the doc may describe a plan that changed. Cross-check against the actual PR.
        - **Doc vs. reality drift.** A spec may say "we'll do X" but the code actually does Y. Flag the divergence; the synthesizer will surface the contradiction.
        - **Boilerplate templates.** Some orgs require a "Why" section that gets filled with fluff. Look for specificity.
        - **Unlinked docs.** The most relevant doc may not be linked from anywhere. Broad keyword searches help.
        - **Multiple drafts.** If a topic has multiple docs, find the one that was finalized or most recently updated. Check dates.
        - **Access-restricted pages.** If you can't access a page, note it as a gap.

        ## What to return

        For each relevant doc:
        - Title and URL
        - Authors and last-updated date
        - The motivation text (verbatim quote), with page/section location
        - Relevant linked pages (so the synthesizer can cite them)
        - Whether the doc was finalized or draft
      '';

      ".agents/skills/why/references/sources/sentry.md".text = ''
        # Sentry Error History

        ## What this source contains

        Sentry is the archive of things that went wrong. For defensive, corrective, or error-handling code, it often holds the direct motivation: the specific exceptions, stack traces, and frequencies that pushed someone to add a check, catch, retry, or fallback.

        - **Issues.** Grouped errors with counts, first/last seen timestamps, affected releases, and comments
        - **Events.** Individual error instances within an issue (stack traces, tags, user context)
        - **Releases.** Deployment records with associated issues (useful for "which version fixed this?")
        - **Replays.** Session recordings of user-facing errors (if enabled)
        - **Profiles.** Performance profiling data (less useful for "why"; more for "how slow")
        - **Issue comments & assignments.** Sometimes contain engineer notes on root cause

        The most valuable thing Sentry provides is **temporal correlation**: "issue X was created 2024-01-02, peaked at 500 events/day, stopped appearing after release v2.14.0 on 2024-01-15, the release that shipped the defensive check."

        ## How to search it

        Use the Sentry MCP.

        1. **Orient.** If you don't know the project slug and organization:

           ```
           find_organizations
           find_projects
           ```

        2. **Search for issues related to the target.**

           ```
           search_issues (natural language, e.g., "errors in PaymentService timeout", "unhandled exceptions in uploadFile")
           ```

           Good query components: exception class names the target handles, the function or class name of the target, error message strings the target checks for, the file path of the target.

        3. **Narrow by release and time window.**

           ```
           search_issue_events (filter by release, time, environment, trace ID, tags)
           get_issue_tag_values (for an issue, see distribution across versions, users, environments)
           ```

           For a suspected issue, check:
           - **First seen.** When did the error start appearing?
           - **Last seen.** When did it stop? Does it line up with the target's ship date?
           - **Affected releases.** Which versions saw it? Which was the fix?
           - **Frequency trajectory.** Did it spike, then get resolved?

        4. **Pull the full event for context.**

           ```
           get_sentry_resource (pass a Sentry URL or type+ID)
           ```

           Does the stack trace pass through the target code? Do the tags and breadcrumbs match the conditions the target defends against?

        5. **Check releases that landed near the target.**

           ```
           find_releases (around the commit date of the target)
           ```

           Cross-reference release version with the PR's merge date.

        6. **Use Seer sparingly.**

           ```
           analyze_issue_with_seer
           ```

           Seer produces AI root-cause analyses. Useful as a hypothesis generator, but treat them as inference, not authoritative. The actual events and stack traces are the primary evidence; Seer's narrative is secondary.

        ## What good evidence looks like here

        - An issue whose **first seen** is shortly before the target's PR and **last seen** shortly after, suggesting the target addressed this error
        - Stack traces that pass through or land on the target function, showing the exact failure mode being defended against
        - A comment on the issue from the PR author describing the fix
        - The target's PR description or commit message referencing a Sentry issue URL or ID
        - An issue with high event counts that stops after the release containing the target

        ## Common pitfalls

        - **Grouping drift.** Sentry groups errors by fingerprint. Refactors or renames can track the "same" error under a new issue ID. If an issue ends abruptly, the error may have just been regrouped. Check for new issues immediately after.
        - **Release correlation is noisy.** A release contains many commits. An issue stopping at v2.14.0 doesn't prove the target fixed it; another change in the same release might have. Cross-reference with the target's exact commit.
        - **Silent fixes.** Sometimes the error stops because upstream changed, not because of the defensive code. The correlation suggests the fix; it doesn't prove authorship.
        - **Resolved != fixed.** Issues can be marked "resolved" manually without any code change. Treat `resolved` as a human marker, not evidence that code fixed it.
        - **Seer hallucinations.** Seer can generate confident-sounding explanations that aren't right. Fall back to the actual events, stack traces, and timestamps when making claims.
        - **Sampling.** Some projects sample events aggressively. A low event count may just mean high sampling, not a rare error. If in doubt, note the gap.

        ## What to return

        For each relevant issue:
        - Issue ID and title
        - Project and organization
        - First seen / last seen timestamps
        - Event count (and sampling rate if known)
        - Affected releases
        - A representative stack trace snippet showing relevance to the target (verbatim excerpt, not summary)
        - First/last-seen correlation with the target's ship date
        - Link to the issue
        - Any author comments or resolution notes
      '';

      ".agents/skills/why/references/sources/slack.md".text = ''
        # Slack Conversations

        ## What this source contains

        - Real-time discussions of problems and decisions
        - Incident channels where fire-drill decisions were made
        - Design discussion threads where tradeoffs were debated
        - Questions answered by senior engineers that didn't make it into docs
        - Post-merge discussions that explain why something was revisited
        - DMs (usually not searchable, scope accordingly)

        Slack is frequently where the *real* decisions got made, especially for smaller changes that didn't warrant a doc. It's also the most ephemeral source: threads get deleted, channels get archived, and search quality degrades over time.

        ## How to search it

        Slack MCP tools vary. Check which Slack MCP is available and inspect its tool schema first. It may require `mcp_auth`. If authentication fails, stop and report the gap.

        1. **Author-bounded search.** Messages from the PR author around the PR merge date. Limits scope dramatically and often hits gold.
        2. **Keyword search for the feature name and key symbols.** Include misspellings and casual phrasings.
        3. **PR URL search.** Slack often links PRs when they're reviewed or discussed. Search for the PR URL (or just `/pull/<number>`).
        4. **Error string search.** If the code handles a specific error, search for the error string. Incident threads often surface.
        5. **Channel-scoped search.** Narrow to likely channels:
           - `#eng-*`. Engineering discussions
           - `#proj-*`. Project channels
           - `#incident-*` / `#sev-*`. Incident channels
           - Team-specific channels for the owning team
           - Design review channels
        6. **Thread traversal.** When you find a relevant message, fetch the whole thread. The decision often lives in the replies.

        ## What good evidence looks like here

        - A thread where tradeoffs were explicitly debated ("I was going to use A but B is better because...")
        - An incident channel message describing the bug the code prevents
        - A question from a reviewer and an authoritative answer from the author or lead
        - A reference to a meeting where a decision was made
        - A message from a product manager or customer-facing engineer explaining a customer ask

        ## Common pitfalls

        - **Channel archaeology limits.** Very old messages may be gone due to retention policies. If you can't find anything before a certain date, note the retention cliff.
        - **Unsearched DMs.** Many decisions happen in DMs that aren't searchable. You'll miss them; that's a known limitation.
        - **Speculative jokes as "decisions."** Slack is casual. "Lol just do the thing" isn't a decision, even if it preceded the commit. Look for considered discussion.
        - **Context collapse in single messages.** Without the thread, a single message often reads differently than in context. Always fetch threads.
        - **Auth failures.** If the MCP isn't authenticated, stop. Don't make up findings. Report that Slack wasn't searchable.

        ## What to return

        For each relevant thread:
        - Channel name
        - Permalink or thread ID
        - Participants
        - Date range of the discussion
        - The key quotes (verbatim) with attribution
        - Context: what thread/incident/discussion this was part of
      '';

      ".agents/skills/why/references/synthesizer-prompt.md".text = ''
        # Synthesizer Prompt Template

        Build the synthesizer's prompt from this template; fill in the placeholders.

        ---

        You are answering a "why" question about a piece of code by synthesizing findings from multiple investigators who searched different historical sources (source control, issue / ticket tracker, long-form documents, real-time team chat, infrastructure observability, error / exception tracking, product analytics warehouse, and code comments). Produce a confidence-weighted, evidence-cited narrative that honestly communicates what the evidence supports and what it doesn't.

        ## The Question

        > {QUESTION}

        ## The Code Anchor

        **Target files:** {FILES_WITH_LINE_RANGES}

        **Key symbols:** {SYMBOLS}

        ## Investigator Findings

        {ALL_INVESTIGATOR_FINDINGS}

        ## Sources That Weren't Searched

        {SKIPPED_SOURCES_WITH_REASONS}

        ## Epistemics Framework

        You MUST follow the framework in `references/epistemics.md`. Read it in full before writing the output. The key rules:

        1. Every claim sits in one of these tiers: **Direct**, **Supported**, **Inferred**, **Speculative**, **Unknown**. The tier determines what section the claim goes in and how it's phrased.
        2. Every Direct/Supported claim must have a citation (PR #, ticket ID, doc URL, chat permalink, commit hash, or file:line).
        3. Inferred and Speculative claims must use hedged language ("appears to", "likely", "suggests", "one possibility is").
        4. Never cite code as evidence for its own intent.
        5. Gaps in the evidence must be documented. Don't fill them with plausible-sounding guesses.
        6. If the user's question embedded a hypothesis, treat it as a candidate, not a conclusion. Check the evidence independently.

        ## Instructions

        1. **Read all investigator findings.** They gathered raw evidence, not conclusions. You weigh it.
        2. **Reconcile overlapping findings.** Multiple investigators may have cited the same PR, ticket, or doc. Merge into a single, authoritative reference.
        3. **Identify contradictions.** If two items of evidence disagree, don't pick one. Surface both.
        4. **Calibrate confidence.** For each claim, identify the evidence and the tier. State Direct claims plainly with a citation. Hedge Inferred claims and explain the inference. Mark Speculative claims explicitly. Put claims with no evidence in the gaps section.
        5. **Verify citations by spot-checking.** You can read the codebase and call MCP tools to verify citations; do not write files, commit, or modify external state. If you're uncertain a cited item exists or says what's claimed, check it. Don't propagate errors.
        6. **Don't overreach.** The user will act on your output. Better to leave an open question open than to fill it with a confident-sounding guess.

        ## Output Format

        Write the output for the user. Use this exact structure:

        ---

        ### The Question

        Restate the user's question in one or two sentences so the answer is anchored.

        ### The Code in Question

        File paths, line ranges, key symbols. Two or three lines to orient a reader who lands here cold.

        ### What We Found

        **Claims with direct evidence**, one per bullet. Quote or paraphrase the source and cite precisely. Format each finding like:

        - **[Direct]** {Claim}. Source: [PR #123](url) / ticket ID / file:line. {Brief quote or paraphrase.}
        - **[Supported]** {Claim}. Evidence: {list of items and what each contributes}.

        Use `[Direct]` for single-source, explicit evidence. Use `[Supported]` when multiple indirect items converge on a conclusion.

        ### What We Can Reasonably Infer

        **Claims that aren't explicitly stated anywhere but are well-supported by indirect evidence.** Make the inference chain visible: "Given A and B, it's likely that C." Use hedged language ("appears to", "likely", "suggests", "is consistent with"). Format:

        - **[Inferred]** {Hedged claim}. Reasoning: {the specific evidence and the inference step}.

        If there's nothing to infer, skip this section.

        ### Competing Hypotheses

        **If the evidence fits multiple stories, present them.** Don't force a winner when the record doesn't support one. For each hypothesis:

        - **Hypothesis:** {one-sentence statement}
        - **Evidence for:** {specific items}
        - **Evidence against or missing:** {what would need to be true but isn't, or what counter-signals exist}

        Skip this section if there's a single clear answer.

        ### What We Don't Know

        **Explicit gaps.** Things the user asked that the evidence didn't answer. Sources searched that came up empty. Sources that weren't searchable at all, such as a missing real-time team chat MCP.

        Be specific. "We searched the issue tracker for [query1], [query2], [query3] and found no issue discussing the rate-limit threshold" is useful. "We don't know why" is not. Include:

        - Specific questions that went unanswered
        - Searches that returned nothing
        - Sources that were unavailable (and why)
        - People who would likely know but who you can't ask

        ### Sources Consulted

        Bulleted list of what was actually searched, so the user can judge coverage and redirect. Format:

        - **Source control history**: {file paths}, {number of commits reviewed}, PRs #{numbers}, and code comments searched. Or "Not searched. No repository history or authenticated hosting integration was available."
        - **Issue / ticket tracker**: {ticket IDs and keyword searches}. Or "Not searched. No matching MCP available in this environment."
        - **Long-form documents**: {page titles and search queries}. Or "Not searched. No matching MCP available in this environment."
        - **Real-time team chat**: {channels searched, date ranges, queries}. Or "Not searched. No matching MCP available in this environment."
        - **Infrastructure observability**: {dashboards, monitors, metrics, logs, traces, or incidents searched}. Or "Not searched. No matching MCP available in this environment."
        - **Error / exception tracking**: {issues, events, or releases searched}. Or "Not searched. No matching MCP available in this environment."
        - **Product analytics warehouse**: {fully-qualified tables queried, the time windows, and the numeric summaries (counts, percentiles, first/last-seen timestamps) that bore on the question}. Or "Not searched. No matching MCP available in this environment."

        ### Confidence Summary

        One or two sentences summarizing your overall confidence. E.g.:

        > "The core rationale (A) is well-supported by direct PR and ticket evidence. The specific threshold value (100) is inferred from the surrounding context but not explicitly documented. The question of whether this was driven by a customer request could not be answered. No relevant issue tracker or long-form doc content surfaced, and real-time team chat search was unavailable."

        ---

        ## Quality Check Before Returning

        Before finalizing, review your output against this checklist:

        1. Does every claim in "What We Found" have a citation? If not, add one or move the claim to "Inferred" or "Hypotheses."
        2. Is the phrasing tier-appropriate? (Direct claims can use "because"; Inferred claims cannot.)
        3. Did you surface any contradictions you noticed, or did you quietly pick one?
        4. Does the "What We Don't Know" section exist and name specific gaps? If it's empty or missing, be suspicious. Historical investigations almost always have gaps.
        5. If the user embedded a hypothesis in their question, did you check it against the evidence rather than rubber-stamping it?
        6. Did you cite any code as evidence for its own intent? Remove those. Code is mechanics, not motivation.
        7. Is the overall tone calibrated? A confident-sounding answer with weak evidence is the exact failure mode this skill exists to prevent.

        If any item fails, revise before returning.

        ## A Final Note

        The value of this output comes from its honesty, not its authority. A reader who takes your answer to the original author, an engineering lead, or a product manager should be well-positioned to ask the right follow-up questions. Be clear about what's known, what's inferred, and what's missing. Don't optimize for looking decisive. Optimize for being useful.
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

        Use:

        ```text
        <scope>: <description>
        ```

        The scope is the area of the codebase being changed, such as a module, component, package, directory, command, feature area, or subsystem. It is not a conventional-commit type like `feat`, `fix`, `refactor`, `chore`, `docs`, or `test` unless that is truly the name of the changed area.

        ## Style

        - Capture the highest-level intent of the change.
        - Prefer broad architectural or product impact over incidental mechanical edits, renamed symbols, generated files, formatting, or whichever patch hunk appears first.
        - Keep it concise and specific.
        - Use imperative or concise present-tense wording when natural.
        - Avoid trailing punctuation.
        - Do not include bullets, Markdown fences, explanation, alternatives, quotes, or prefixes like `Commit message:`.
      '';

      ".agents/skills/wrtcmtmsg/agents/openai.yaml".text = ''
        interface:
          display_name: "Write Commit Message"
          short_description: "Write concise scoped VCS commit subjects"
          default_prompt: "Use $wrtcmtmsg to write a one-line commit message for my uncommitted changes."

        policy:
          allow_implicit_invocation: false
      '';
    };
  };
}
