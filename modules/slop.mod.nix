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

          ".agents/skills/correct/SKILL.md".text = ''
            ---
            name: correct
            description: "Find the mistakes agents keep repeating in this repo and make each one impossible. Try architecture first, then types, then a lint whose error names the fix, then a test, and write docs last. Prove each check fails on a real past mistake. Repeat this each time the operator corrects you. Use for /correct."
            ---

            # Correct

            The operator keeps correcting agents in this repo for the same mistakes. Change the repo so the next agent can't make them.

            Assume every contributor is an agent that sees only the files it opened, copies the nearest example, and takes the shortest path that compiles. Design the repo so a change that looks right from one file is right for the whole repo.

            ## Find the mistake classes

            First, read recent commits, reverts, review comments, agent instruction files, and comments that explain workarounds. Group the mistakes into classes. A class counts once it has happened twice.

            ## Fix each class at the highest level that works

            1. **Eliminate it with architecture.** Give each piece of state one owner and each task one supported way. Hide internals so the wrong import fails. Replace hand-synced lists with one source of truth. Delete old ways and dead code an agent would copy.
            2. **Enforce it with types so the bad state can't be written.** If bad code still compiles, add a lint or CI check whose error names the file, type, or function to use instead. If the pattern is already common, fail only when a change adds more.
            3. **Test the behavior.** Fix or delete any test that still passes when the behavior it checks breaks, or that fails when only the internals change.
            4. **Write docs or agent rules last, only for judgment calls.** Nothing fails when an agent skips them.

            ## Fix and prove

            Then fix the most frequent classes now, one commit each. Prove each new check fails on a real past mistake. Run the same command locally and in CI. Exceptions go on the offending line with a reason, an expiry date, and a human's approval.

            ## Keep the rule table

            Last, keep a table in the agent instruction file that pairs each rule with what enforces it. When the operator corrects you, fix the mistake and add the rule. If the rule was already there and nothing enforces it, that's a repeat, so fix it at the highest level in the same change. Drop a rule once its mistake can't happen.

            **Reply:** each class with its evidence, the level you picked, and why a higher level didn't work.
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

          ".agents/skills/how/SKILL.md".text = ''
            ---
            name: how
            description: "Use for \"how does X work\", code walkthroughs before changing something, and placement / ownership / layering questions (\"where should this live\", \"which package owns this\", \"is this the right layer\"). Explains subsystem architecture, runtime flow, onboarding mental models. Use why for motivation."
            ---

            # How

            Explore the codebase to answer "how does X work?" questions. Produce architectural explanations at the level of a senior engineer onboarding onto a subsystem, enough to build a working mental model, not so much that it reads like annotated source code.

            Every spawn is a Task subagent with `subagent_type: generalPurpose` and `readonly: true`. Explorers use the `how explorer` line in the pstack settings file (`~/.cursor/rules/pstack-models.mdc` in Cursor, `~/.claude/rules/pstack-models.md` in Claude Code, `~/.agents/pstack-models.md` in other harnesses) (default `grok-4.7-xhigh-fast`), and every explainer uses the `how explainer` line (default `claude-opus-5-5-xhigh`). Set `model` to that line's value, or to the default if the file or the line is missing. Leave `model` unset when the value is `auto` or `inherit-parent`. If your subagent tool rejects a slug, use the default and say so. If it rejects the default, use the closest valid slug of the same family from its error message or your harness's model list.

            ## 1. Assess complexity

            If the scope is ambiguous, state your interpretation and explore. The user can redirect.

            - **Simple** (a single module, a small utility, a narrow question such as "how does function X work"): no explorers. Spawn one explainer that explores and explains in one pass, built from `references/explainer-prompt.md` without the explorer-findings section. Go to step 4.
            - **Complex** (a subsystem spanning multiple files or services, a cross-cutting feature, a full architectural overview): go to step 2.

            When in doubt, take the simple path.

            **Other harnesses.** The spawns in this skill use Cursor's `Task` tool. In another harness, use its subagent tool: `Agent` in Claude Code (`subagent_type: general-purpose`), `task` in OpenCode (`subagent_type: general`), `spawn_agent` in Codex. Keep the prompt and the model. Drop parameters your tool doesn't have. If your harness has no subagent tool, as in Pi without an extension, run each role yourself, one after another.

            ## 2. Explore (complex only)

            Decompose the question into 2 to 4 angles, each a distinct slice of the subsystem. Spawn all explorers in a single message, each with `references/explorer-prompt.md` and its angle filled in.

            ## 3. Synthesize (complex only)

            Once all explorers have returned, spawn one explainer with `references/explainer-prompt.md` and every explorer's findings filled in.

            ## 4. Present

            Present the explainer's output. Light edits for clarity or context from the conversation are fine. Do not substantially rewrite it.

            ## Output format

            The explanation uses the sections defined in `references/explainer-prompt.md`, dropping any that do not apply: Overview, Key Concepts, How It Works, Where Things Live, Gotchas.
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

            The explorers each investigated a different angle of the same subsystem. Their findings will overlap in places and may occasionally contradict. Reconcile them. Merge overlapping descriptions, resolve contradictions by checking the code yourself, and combine the separate slices into a unified picture.

            Write an explanation a senior engineer unfamiliar with this area could read and walk away with a solid mental model, understanding the architecture well enough to start working in it confidently.

            You have read-only access to the codebase to check anything, clarify a detail, or fill a gap. Use Read, Grep, and Glob as needed. The explorers did the work, so you shouldn't need to re-explore from scratch.

            ## Output Format

            Use this structure, adapted to what makes sense for the question. Not every section is needed for every question.

            ### Overview
            1-2 paragraphs. What is this thing, what does it do, why does it exist. Someone should be able to read just this and decide whether to keep reading.

            ### Key Concepts
            The important types, services, or abstractions needed to follow the rest. Brief definitions, not exhaustive.

            ### How It Works
            The core of the explanation, and the longest section. Walk through the flow: what triggers it, what happens step by step, where data goes, what the decision points are.

            Use prose, not pseudocode. Reference specific files and functions so the reader knows where to look, but don't dump large code blocks unless a snippet is essential to a point.

            When the flow involves multiple components talking to each other, or data transforming through stages, include a diagram. Use mermaid (```mermaid) for structured flows (sequence diagrams, flowcharts, component graphs) or ASCII art for simpler relationships where mermaid would be overkill. Use your judgment. A diagram should clarify, not decorate. If prose covers the flow, skip the diagram.

            ### Where Things Live
            A brief file/directory map. Just the ones someone would need to start working here.

            ### Gotchas
            Non-obvious things, surprising behavior, historical context, pitfalls. Skip this section if there's nothing worth calling out.

            ## Communication Style

            - Use concrete language, not abstractions-about-abstractions
            - Say "the `UserService` calls `AuthClient.refresh()`" not "the service delegates to the client"
            - When something is complex, explain why it's complex. Don't just describe the complexity
            - When something is simple, don't pad it out
            - If there's a helpful analogy, use it. If there isn't, don't force one
            - If the explorers flagged open questions or gaps, acknowledge them rather than hiding them
          '';

          ".agents/skills/how/references/explorer-prompt.md".text = ''
            # Explorer Prompt Template

            Build each explorer subagent's prompt from this template. Fill in the placeholders.

            ---

            Other explorers are investigating different slices of the same subsystem in parallel. Don't try to cover everything. Focus on your assigned angle and go deep.

            ## Question

            > {QUESTION}

            ## Your Exploration Angle

            {EXPLORATION_ANGLE}

            ## Output

            ### Components Found
            The key types, services, classes, and abstractions. For each: name, file path, and a one-sentence description of what it does.

            ### Flow
            The execution flow step by step. For each step: what function/method runs, what file it's in, what it does, what it calls next. Include the data that flows between steps.

            ### Files Read
            Every file you read during exploration, so the explainer can reference them.

            ### Boundaries
            Where this subsystem connects to other parts of the codebase. The inputs and outputs.

            ### Non-Obvious Things
            Anything surprising, historically motivated, or easy to get wrong. Things that look like they should work one way but work another.

            ### Open Questions
            Anything you couldn't fully trace or understand. Be honest about gaps.
          '';

          ".agents/skills/interrogate/SKILL.md".text = ''
            ---
            name: interrogate
            description: "Use for \"interrogate\", \"adversarial review\", \"multi-model review\", \"challenge this\", \"stress test this code\", \"find blind spots\", or \"tear this apart\". Multiple LLM reviewers challenge changes from independent angles."
            ---

            # Interrogate

            Spawn one reviewer per configured model to adversarially review code changes. The adversarial signal comes from model diversity, not assigned personas. The deliverable is a synthesized verdict. Do NOT auto-apply changes.

            ## Step 1, Scope

            Identify what to review from context:

            - If the user points at specific files or a diff, use that.
            - If on a feature branch, run `git diff main...HEAD` (or the appropriate base branch) for the full changeset.
            - If the user's message references recent work, gather the relevant files.

            Package the diff or file contents with any surrounding context files the reviewers need to understand the code.

            ## Step 2, Intent

            Before spawning reviewers, state the intent in one clear paragraph from the user's message, commit messages, the PR description if one exists, and the code. If you're unsure about the intent, ask the user before proceeding.

            ## Step 3, Spawn Reviewers

            Launch all reviewers in a single message with the Task tool, one per entry on the `interrogate reviewers` line in the pstack settings file (`~/.cursor/rules/pstack-models.mdc` in Cursor, `~/.claude/rules/pstack-models.md` in Claude Code, `~/.agents/pstack-models.md` in other harnesses), labeled Reviewer A, B, and so on to match the entry count. If the file or that line is missing, use the table defaults.

            **Other harnesses.** The spawns in this skill use Cursor's `Task` tool. In another harness, use its subagent tool: `Agent` in Claude Code (`subagent_type: general-purpose`), `task` in OpenCode (`subagent_type: general`), `spawn_agent` in Codex. Keep the prompt and the model. Drop parameters your tool doesn't have. If your harness has no subagent tool, as in Pi without an extension, run each reviewer yourself, one after another.

            | Subagent | Default model |
            |----------|---------------|
            | Reviewer A | `claude-opus-5-5-xhigh` |
            | Reviewer B | `grok-4.7-xhigh-fast` |

            Each reviewer gets `subagent_type: generalPurpose`, `readonly: true`, and `model` set to its configured entry, or its table default when there is no configured line. Omit `model` for an `auto` or `inherit-parent` entry, so that reviewer runs on the parent model.

            If your subagent tool rejects a configured entry, run that reviewer on its family's table default and say so. Families go by prefix: `claude-*`, and `grok-*` with `cursor-grok-*` and `composer-*`. A refused `composer-*` entry runs on Reviewer B's default. With no family match, use Reviewer A's default. If it rejects a table default, spawn with the closest equivalent from the valid slugs in its error message or your harness's model list (prefer the same family and reasoning tier), and open a separate PR to update the default table. Do not block the review on the slug issue. Never treat an alias entry as a rejected slug or apply either fallback to it.

            Read `references/reviewer-prompt.md` and fill in the same template for every reviewer with the stated intent, the diff or file contents, the rubric from `references/rubric.md`, and the code-quality lens from `references/code-quality-review.md`.

            ## Step 4, Synthesize

            As results come back, build a unified picture. Parse every reviewer's findings. Merge findings that describe the same issue differently, and note which models raised each one. Findings two or more models raised independently are the highest signal. Read a lone model's finding, but weight it accordingly. Note disagreements. If one model flags something and another explicitly says the opposite, that is context for the verdict.

            ## Step 5, Lead Judgment

            You are the lead reviewer, a pragmatic senior engineer, not a neutral aggregator. Read `references/lead-judgment.md` for the full framework. Put every finding in one of four buckets, with the model(s) that raised it and a one-line rationale.

            - **Act on**. Real issues affecting correctness, security, or maintainability given the actual goals. They would block a real PR.
            - **Consider**. Legitimate, but you're not sure they outweigh the cost of addressing them now. Worth the user's attention.
            - **Noted**. Technically valid but not actionable. Context-dependent, premature optimization, or low-impact at this stage.
            - **Dismissed**. Wrong, nitpicky, or missing context, with a brief reason.

            ## Output Format

            ### Intent
            > [The stated intent paragraph from Step 2]

            ### Reviewers
            - Reviewer [label]: [model name], [N findings] (one bullet per reviewer)

            ### Act On
            [Each: description, which models raised it, why it matters.]

            ### Consider
            [Each: description, which models raised it, the tradeoff.]

            ### Noted
            [Brief list.]

            ### Dismissed
            [Each with a brief rationale.]

            ### Agreement Map
            [Where models agreed and diverged, and what that pattern tells us.]
          '';

          ".agents/skills/interrogate/references/code-quality-review.md".text = ''
            # Code Quality Review

            Each reviewer applies this code-quality lens in addition to the rubric. It is a strict standard focused on implementation quality, maintainability, abstraction quality, and codebase health.

            Above all, be ambitious about code structure. Do not merely identify local cleanup. Actively search for "code judo" moves, restructurings that preserve behavior while making the implementation dramatically simpler, smaller, more direct, and more elegant.

            ## Core Prompt

            Start from this baseline:

            > Perform a deep code quality audit of the current branch's changes.
            > Rethink how to structure / implement the changes to meaningfully improve code quality without impacting behavior.
            > Work to improve abstractions, modularity, reduce Spaghetti code, improve succinctness and legibility.
            > Be ambitious, if there is a clear path to improving the implementation that involves restructuring some of the codebase, go for it.
            > Be extremely thorough and rigorous. Measure twice, cut once.

            ## Dimensions

            Each dimension is stated once. Apply the ones that are relevant.

            0. **Be ambitious about structural simplification.** Do not stop at "this could be a bit cleaner." Look for reframings that make whole branches, helpers, modes, conditionals, or layers disappear. Assume a "code judo" move is often available. It uses the existing architecture more effectively and makes the change dramatically simpler. If you can delete complexity rather than rearrange it, push hard for that.

            1. **Do not let a PR push a file from under 1k lines to over 1k lines without a very strong reason.** Treat this as a strong smell. Prefer extracting helpers, subcomponents, or modules. If the diff crosses that threshold, ask whether the code should be decomposed first. Waive only for a compelling structural reason where the resulting file stays clearly organized.

            2. **Do not allow spaghetti growth in existing code.** Be suspicious of new ad-hoc conditionals, scattered special cases, or one-off branches inserted into unrelated flows. Treat "weird if statements in random places" as a design problem, not a style nit. Prefer pushing the logic into a dedicated helper, state machine, or module instead of tangling an existing path.

            3. **Bias toward cleaning the design, not just accepting working code.** If behavior can stay the same while the structure becomes meaningfully cleaner, push for the cleaner version. Prefer simplifications that remove moving pieces over refactors that spread the same complexity around.

            4. **Prefer direct, boring, maintainable code over hacky or magical code.** Treat brittle, ad-hoc, or "magic" behavior as a problem. Be skeptical of generic mechanisms that hide simple data-shape assumptions. Flag thin abstractions, identity wrappers, or pass-through helpers that add indirection without buying clarity.

            5. **Push on type and boundary cleanliness when it affects maintainability.** Question unnecessary optionality, `unknown`, `any`, or cast-heavy code when a clearer type boundary could exist. Prefer explicit typed models over loosely-shaped ad-hoc objects. If a branch leans on a silent fallback to paper over an unclear invariant, ask whether the boundary should be made explicit.

            6. **Keep logic in the canonical layer and reuse existing helpers.** Call out feature logic leaking into shared paths or implementation details leaking through APIs. Prefer existing canonical utilities over bespoke one-offs. Push code toward the right package, service, or module instead of normalizing drift.

            7. **Treat unnecessary sequential orchestration and non-atomic updates as design smells when the cleaner structure is obvious.** If independent work is serialized for no reason, ask whether it should run in parallel. If related updates can leave state half-applied, push for a more atomic structure. Do not over-index on micro-optimizations, but do flag avoidable orchestration complexity that makes the code more brittle.

            ## Output Expectations

            Prioritize structural code-quality regressions and missed simplifications first, then spaghetti and branching complexity, then boundary, type, and file-size concerns, then smaller modularity and legibility issues.

            ## Approval Bar

            Do not approve merely because behavior seems correct. Treat these as presumptive blockers unless the author can justify them: the PR keeps a lot of incidental complexity when a code-judo move would delete it. Pushes a file from below 1000 lines to above 1000 lines. Adds ad-hoc branching that tangles an existing flow. Scatters feature checks across shared code. Adds an unnecessary abstraction, wrapper, or cast-heavy contract, or duplicates an existing helper or puts logic in the wrong layer when there is a clear canonical home. If those conditions are not met, leave explicit, actionable feedback and push for a cleaner decomposition.

            ## Review Tone

            Be direct, serious, and demanding about quality. Do not be rude, but do not soften major maintainability issues into mild suggestions. If the code is making the codebase messier, say so. If the implementation missed an obvious dramatic simplification, say that too. Do not be satisfied with "maybe rename this" when the real issue is structural.
          '';

          ".agents/skills/interrogate/references/lead-judgment.md".text = ''
            # Lead Judgment Framework

            ## Filtering Principles

            ### Nitpick Gravity

            Reviewers, especially adversarial ones, tend to fill their review. If they don't find critical issues, they'll inflate nits to fill the space. If a reviewer's findings are all nits and style preferences, the code is probably fine. Say so.

            ### Hypothetical vs. Actual

            "What if someone passes null here?" is only a finding if the caller can actually pass null. Trace the call site. If the input is validated upstream or the type system prevents it, dismiss the finding. Reviewers working from a diff can't always see the full call chain. You can.

            ### Premature Abstraction Warnings

            Reviewers often suggest extracting functions, adding interfaces, or creating abstractions. Does this code need to change in a second way? If not, the abstraction is premature. Simple inline code that works beats a clean abstraction that's overkill for the current scope.

            ### "I Would Have Done It Differently"

            This is the most common false positive in code review. A finding that amounts to "I prefer a different approach" is not a bug, not a design flaw, and not actionable unless the reviewer shows a concrete problem with the current approach. Dismiss these, and say why.

            ### Missing Context Signals

            Watch for findings that reveal the reviewer didn't understand the context:
            - Suggesting changes to code the author didn't write or modify
            - Flagging patterns that are consistent with the rest of the codebase (the reviewer just doesn't know that)
            - Recommending approaches that conflict with constraints you know about

            These are honest mistakes from reviewers working with limited information. Dismiss them gracefully.

            ## When Reviewers Are Right

            Don't dismiss findings just because they're uncomfortable. The whole point of adversarial review is to catch things you'd miss. Signs a finding deserves attention:

            - Multiple models flag the same issue independently (consensus signal)
            - The finding identifies a concrete execution path, not a hypothetical
            - The finding reveals a gap in your mental model of the code
            - You read the finding and think "...yeah, actually"

            Be especially careful about dismissing security findings and correctness bugs. These deserve more scrutiny even when they come from a single model.
          '';

          ".agents/skills/interrogate/references/reviewer-prompt.md".text = ''
            # Reviewer Prompt Template

            Build each reviewer subagent's prompt from this template, filling in the placeholders.

            ---

            You are an adversarial code reviewer. Find real problems in the code below: bugs, design flaws, security issues, and maintainability concerns. You are not here to be helpful or encouraging. You are here to stress-test.

            ## Intent

            The author's stated intent for this change:

            > {INTENT}

            Review whether the code achieves this intent well. Do NOT question the intent itself. Assume the goal is correct and challenge the execution.

            ## Code Under Review

            {DIFF_OR_FILES}

            ## Review Rubric

            {RUBRIC_CONTENTS}

            ## Code Quality Lens

            {CODE_QUALITY_CONTENTS}

            ## Instructions

            Review the code through every lens in the rubric and the code-quality lens above that you find relevant. Do not force lenses that don't apply. A simple bug fix does not need paragraphs about architectural integrity.

            For each finding, provide:

            1. **Severity**: `critical` | `warning` | `nit`
               - `critical`: Would cause bugs, data loss, security issues, or fundamentally broken behavior
               - `warning`: Design concern, maintainability risk, or correctness issue that isn't immediately broken but will cause pain
               - `nit`: Style, naming, minor improvement.
            2. **Finding**: What the problem is, in concrete terms. Reference specific lines/functions.
            3. **Evidence**: Why you believe this is a problem. Show your reasoning. Don't just assert.
            4. **Suggestion** (optional): What you'd do instead, only if you have a concrete alternative.

            A good finding references specific code, not vague concerns ("this could be better"). It distinguishes between "this is broken" and "I would have done this differently". It considers the stated intent. A finding that ignores the context of what's being built is a bad finding.

            Do not restate what the code does without identifying a problem. Do not praise the code. If you find nothing wrong, say "no findings" and stop. An empty review is a valid outcome.

            ## Output

            Return your findings as a structured list:

            ```
            ## Findings

            ### 1. [Severity] Short title
            **Location**: file:line or function name
            **Finding**: What's wrong
            **Evidence**: Why this matters
            **Suggestion**: (optional) What to do instead

            ### 2. [Severity] Short title
            ...
            ```
          '';

          ".agents/skills/interrogate/references/rubric.md".text = ''
            # Review Rubric

            Review through whichever lenses are relevant. Not every lens applies to every change.

            ## Correctness

            Does the code actually do what the intent says it should?

            - Edge cases: empty inputs, nil/undefined, boundary values, concurrent access
            - Error handling: are errors caught, propagated, or silently swallowed?
            - Off-by-one, type coercion, integer overflow, string encoding
            - State management: race conditions, stale closures, dangling references
            - Do both the happy path and the sad path work?
            - Idempotency: what happens if this operation runs twice, or if a previous run crashed halfway? If the answer is "it depends on what state was left behind," a reconciliation step is missing.
            - Concurrency: if multiple actors can touch the same mutable state (files, branches, shared data), is access serialized structurally (locks, sequential phases, exclusive ownership), or by conventions that won't hold?

            When you find a potential bug, trace the execution path. Don't just flag "this could be nil". Show the call chain that makes it nil.

            ## Root Causes vs. Symptoms

            Is the code fixing the actual problem or papering over a symptom?

            Answering this often requires looking beyond the changed files. Read the surrounding code (callers, callees, type definitions, sibling modules) and understand the architecture the change lives in. Use the tools available to you (Read, Grep, Glob) to follow the call chain, read the types, and understand why the code exists before judging whether the change addresses the right layer.

            - Guard clauses that mask a deeper invariant violation
            - Retry logic that hides a broken contract
            - Type casts that silence a modeling error
            - A workaround: why is it needed? What would a proper fix look like?
            - A fix in module A that should really be a fix in module B's contract
            - Instructions where structure would be better: if the fix is a comment saying "don't do X" or a convention someone has to remember, ask whether it could instead be a type constraint, a lint rule, or a runtime check that makes the wrong thing impossible

            ## Structural Integrity

            Does the code fit well into the system it's part of?

            - Boundary discipline: is validation at system boundaries, or scattered through business logic? Validate data once where it enters the system, then trust it internally.
            - Abstraction level: is the code mixing high-level orchestration with low-level detail?
            - Coupling: does this change introduce dependencies that will make future changes harder?
            - Data model fit: do the data structures match the actual access patterns?
            - Bolted-on vs. integrated: if the new requirement had been known from the start, would the code look like this, or does the change feel patched onto the existing design?
            - Legacy dual-paths: does the change introduce a new API while keeping the old one alive? If there are no external consumers, migrate callers and delete the old path in the same wave. Don't leave compatibility layers that will become permanent.

            Don't penalize simple code for lacking abstraction. Premature abstraction is worse than duplication.

            ## Verification

            Can you tell that this code works from reading it?

            - Are there tests? Do they test behavior or implementation details?
            - Are there assertions/invariants that would catch regressions?
            - If this is a bug fix: is there a test for the bug?
            - If this touches an integration boundary: is the full path tested?
            - Check the real thing, not a proxy. If the code checks liveness via file mtime or cached state instead of reading the actual value, that's a verification gap.
            - For delegated or async work: does the code verify actual output artifacts, or does it trust self-reports and summaries?

            ## Complexity Budget

            Is the complexity justified by what the code accomplishes?

            - Code that could be simpler without losing correctness or clarity
            - Abstractions that serve only one call site
            - Configuration or parameterization for cases that don't exist yet
            - Dead code, unused imports, vestigial parameters
            - Over-engineering: "just in case" code paths with no current callers
            - Obsolete compatibility paths kept alive for transitional stability that's no longer needed. If the migration is done, delete the scaffolding
            - Does the user experience justify the complexity? Every feature, control, and option should earn its place. Half-finished features are worse than missing ones.

            Simpler is better unless simpler is wrong.

            ## Security

            For each security finding, trace the input path through the code and show it.

            - User input flowing to dangerous sinks (SQL, shell, eval, innerHTML) without sanitization
            - Authentication/authorization gaps in new endpoints
            - Secrets in code, logs, or error messages
            - TOCTOU (time-of-check-time-of-use) in security-critical paths
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

          ".agents/skills/principle-boundary-discipline/SKILL.md".text = ''
            ---
            name: principle-boundary-discipline
            description: "Apply when wiring validation, error handling, or framework adapters. Concentrate guards at system boundaries (CLI, config, network, external APIs); trust internal types and keep business logic in pure functions."
            ---

            # Boundary Discipline

            Place validation, type narrowing, and error handling at system boundaries. Trust internal code unconditionally. Business logic lives in pure functions. The shell is thin and mechanical.

            **Why:** Scattered validation is noisy, redundant, and gives a false sense of safety. Keep logic out of framework wiring so it can be tested without the framework.

            **The pattern:**
            - **At boundaries** (CLI args, config files, external APIs, network protocols): validate, return errors, handle defensively.
            - **Inside the system:** typed data, error propagation, no re-validation. Trust the types.
            - **Across the boundary.** Expose domain concepts, not the boundary's private representation. Keep general-purpose mechanism inside and special-purpose policy at the edge.

            **Applications:**

            Validation and error handling:
            - Validate config at parse time (the boundary), not inside business logic
            - Parse raw data into domain types at the boundary
            - Do not re-export transport, storage, framework, or wire types through the public surface
            - No redundant nil checks deep in call chains if the boundary already validated

            Code organization:
            - Business logic in pure functions with no framework dependencies
            - Parse functions: pure transforms from raw bytes to typed state
            - Prompt construction: structured state in, string out
            - Scoring and assessment: pure transforms from state to results

            **The tests:**
            - "Is this data crossing a system boundary right now?" If not, validation is redundant.
            - "Can this be a pure function that the shell just calls?" If yes, extract it.
          '';

          ".agents/skills/principle-build-the-lever/SKILL.md".text = ''
            ---
            name: principle-build-the-lever
            description: "Apply to any non-trivial work, not just bulk work: edits, migrations, analyses, checks. Build the tool that does it or proves it (codemod, script, generator, or a skill your subagents follow) instead of working by hand. The tool is the artifact a reviewer can rerun."
            ---
            # Build the Lever

            When the work isn't trivial, build the tool that does it instead of doing it by hand.

            A codemod, generator, or script does the work the same way every time and reruns for free. The tool is one artifact a reviewer can read and rerun to check the work. Hand-done changes can only be re-verified by redoing them. A deterministic script turns "trust me" into "run this".

            Default to building the lever. Skip it only when the task is trivial, a couple of obvious edits you can see at a glance.

            - Do the first unit by hand to learn the recipe, then build the tool. Prove it by rerunning it on that unit and diffing against your hand-done version. Make the lever safe to rerun.
            - Codemod or script for edits, generator for repetitive files, a dump-to-sqlite query for analysis, a rerunnable check for verification.
            - A deterministic lever beats fan-out. If the tool can process every unit in one pass, run it yourself. Don't fan out delegates to hand-apply what a script can do.
            - When you fan work out to subagents, write the lever as a skill they all read: the recipe, the verification contract, and the do-not-touch fences in one artifact. Keep it outside the delegates' write scope so they can't quietly edit the contract.
            - Applying this principle produces a file. If you cited it and there is no codemod, script, generator, or delegate skill in the diff, you didn't apply it.
            - Commit the lever when the work outlives the session.

            The bar is triviality, not repetition. A one-off still earns a lever when the lever is what makes the work checkable. Per the [Laziness Protocol](../principle-laziness-protocol/SKILL.md), build the smallest script that does or proves the job, never a framework.

            Distinct from [Encode Lessons in Structure](../principle-encode-lessons-in-structure/SKILL.md), which makes a recurring instruction a durable guardrail. This is throughput and reviewability on the work in front of you. For scripting the verification itself, see [Prove It Works](../principle-prove-it-works/SKILL.md).
          '';

          ".agents/skills/principle-encode-lessons-in-structure/SKILL.md".text = ''
            ---
            name: principle-encode-lessons-in-structure
            description: "Apply when you catch yourself writing the same instruction a second time, or notice a recurring correction. Encode the rule as a lint, metadata flag, runtime check, or script instead of more text."
            ---

            # Encode Lessons in Structure

            If the lesson needs judgment and cannot be encoded, make the instruction more prominent and add an example of the failure mode.

            **Corollary:** If the fix is structural, only use the structural fix. The instruction is the symptom.
          '';

          ".agents/skills/principle-fix-root-causes/SKILL.md".text = ''
            ---
            name: principle-fix-root-causes
            description: "Apply when debugging. Trace each symptom back to the first place the system went wrong and fix it there. A guard is a fix only when the state it handles is legitimate."
            ---

            # Fix Root Causes

            When debugging, fix the fault, not the place where it surfaced. The symptom is where a wrong state became visible. The root cause is the first place the system did something it should not do, or failed to handle a state it should handle.

            **Why:** A symptom fix hides the evidence and leaves the fault free to surface somewhere else. Each one makes the system harder to reason about, because the code now carries a workaround for a bug that nobody named.

            **Pattern:**
            - Reproduce first.
            - Ask "why" at each step until the answer is a wrong decision in the code, not a consequence of an earlier one.
            - When stuck, instrument. Read the actual error and the actual state. Do not guess.
            - Ask whether the state that triggered the symptom is legitimate. If the system may be in that state, the code that broke on it is the root cause, and handling the state there is the fix. If the state should never exist, a check where it broke hides the bug. Find what produced the state. Guards, retries, swallowed errors, clamped values, and discarded state are the usual ways to hide a bug.
            - When something fails only after a restart, suspect persisted state first: config files, caches, lock files, serialized state.
            - Check for the pattern, not just the instance. Find every place with the same fault and fix them all.
            - If a workaround needs a paragraph-long comment to justify it, the code is wrong. Fix the code, not the comment.
            - If the deciding fact took a deep dig to find, propose the cheap, always-on signal that would have shown it at first look.
          '';

          ".agents/skills/principle-foundational-thinking/SKILL.md".text = ''
            ---
            name: principle-foundational-thinking
            description: "Apply before writing logic: choosing core types and data structures, sequencing scaffold-vs-feature work, asking what concurrent actors share. Get the data structures right so downstream code becomes obvious."
            ---

            # Foundational Thinking

            **Structural decisions** protect option value. **Code-level decisions** protect simplicity.

            **Data structures first.** Get the data shape right before writing logic. Define core types early, trace every access pattern, and choose structures that match the dominant paths.

            At code level, DRY the structure, not every line. Types and data models should converge. Three similar statements still beat a premature abstraction. Prefer explicit over clever. Test behavior and edge cases, not line counts.

            **Concurrency corollary.** Before sharing state between actors, ask "what happens if another actor modifies this concurrently?" If not "nothing", isolate.

            **Scaffold first.** If something helps every later phase, do it first. Ask "does every subsequent phase benefit from this existing?" CI, linting, test infrastructure, and shared types are scaffold. Sequence for option value: setup before features, tests before fixes. Keep commits small and single-purpose.

            Each increment should land a coherent abstraction or deepen one that exists. Do not spread a new capability across callers as special-case coordination.

            Subtraction comes before scaffolding. Remove dead code first, then lay foundations.
          '';

          ".agents/skills/principle-guard-the-context-window/SKILL.md".text = ''
            ---
            name: principle-guard-the-context-window
            description: "Apply when context is filling up: large outputs, long files, repeated reads, fan-out planning. Route bulk to subagents; keep summaries in the main thread, not raw payloads."
            ---

            # Guard the Context Window

            **Why:** Context overflow degrades reasoning quality, creates compression artifacts, and halts progress.

            **Pattern:**
            - **Size phases and cap scope.** Limit files per phase, set turn budgets, account for mechanism costs.
          '';

          ".agents/skills/principle-laziness-protocol/SKILL.md".text = ''
            ---
            name: principle-laziness-protocol
            description: "Apply when refactoring, evaluating diff size, or tempted to add abstractions, layers, or signal threading. Bias toward deletion and the smallest change that solves the problem."
            ---

            # Laziness Protocol

            - **Consolidate decisions.** Do not repeat the same choice in several places. Put it behind one source of truth and pass the result as a simple flag.
            - **Minimize the diff.** Make the smallest change that solves the problem. Fewer lines beat "elegant" boilerplate.
          '';

          ".agents/skills/principle-minimize-reader-load/SKILL.md".text = ''
            ---
            name: principle-minimize-reader-load
            description: "Apply when reviewing or shaping code that's hard to trace. Count layers between question and answer, and hidden state in the reader's head; collapse one-caller wrappers and shrink mutable scope."
            ---

            # Minimize Reader Load

            Maintainability is the work a reader must do to understand code. Track two axes: **layers to trace** (indirections between the question and the answer) and **state to hold** (hidden or mutable context the reader must keep in their head). LOC, cyclomatic complexity, and "clean architecture" are proxies. Reader load is the thing that matters. The two axes are independent. A flat file with 50 globals can be as hard to reason about as a 6-layer adapter stack. Guard both. This is the human analog of [Guard the Context Window](../principle-guard-the-context-window/SKILL.md). Working memory is finite for readers too.

            - **Collapse layers** that cost more than they save: wrappers with one caller, adapters with no second implementation, speculative indirection that was never needed. Inline them.
            - **Make adjacent layers change the abstraction.** A layer that repeats the same methods and arguments adds reader load without compression. Collapse pass-through layers.
            - **Demand interface compression.** A broad interface that hides little complexity makes readers learn both the surface and the implementation. Prefer boundaries that hide meaningful decisions.
            - **Shrink state scope:** prefer pure functions (returns over mutations), locals over fields, fields over module state, and module state over globals. Derive instead of sync.
            - **Name the invariant at the boundary,** not in every consumer, so the reader learns it once.
            - Before adding a layer or a piece of state, ask: does it reduce reader load elsewhere by at least as much?

            **The test:** can a new reader answer "where does X come from?" and "what can change X?" in under 30 seconds? If not, cut layers or cut state.
          '';

          ".agents/skills/principle-prove-it-works/SKILL.md".text = ''
            ---
            name: principle-prove-it-works
            description: "Apply after completing a task, before declaring done. Verify against the real artifact (run the feature, read the actual value, inspect the diff), not a proxy, self-report, or 'it compiles.'"
            ---

            # Prove It Works

            Verify every task output by checking the real thing directly. Do not infer from proxies, self-reports, or "it compiles."

            **Why:** Unverified work has unknown correctness. Indirect verification (file mtimes, output freshness, agent self-reports, cached screenshots) feels cheaper than direct observation. Acting on a wrong inference costs far more than checking the source.

            Check the real thing, not a proxy:
            - Check process liveness directly, not indirectly through derived state
            - Read the actual value, not a cached or derived representation
            - When verification fails, suspect the observation method before suspecting the system

            ## Script the check when you can

            The strongest proof is a deterministic script that re-runs the same comparison, not a one-time eyeball. Write the script, run it, and keep its output as an artifact a reviewer can re-run instead of trusting your word.

            Keep the artifact visible for the human. Commit it only for large or complex work where the trail has to be auditable later, like a big port or migration (the **show-me-your-work** skill).
          '';

          ".agents/skills/principle-sequence-verifiable-units/SKILL.md".text = ''
            ---
            name: principle-sequence-verifiable-units
            description: "Apply to multi-step work (sweeps, migrations, runs of similar edits) and to how you stack commits and PRs. Break work into small units that each end in a verifiable state, check each before the next, and order delivery so the sequence proves itself to a reviewer."
            ---

            # Sequence work into verifiable units

            Order work as a sequence of small units, each ending in a state you can check, and don't advance until the current one is green.

            **Why:** A break caught at the unit that caused it is cheap to localize. A break caught after a batch is buried, and you have already built further on a broken base. Sequencing those same units into a delivery a reviewer can replay turns "trust me" into "watch it go red, then green."

            **Execution.** In a sweep, migration, or any run of similar edits, verify each change before starting the next. Each unit is a before/after bracket: known-good state, one change, run the check, then proceed. Rebase onto clean trunk first so every check measures against the real baseline. When a lever does the edits, the per-unit check is nearly free. Run it anyway.

            **Delivery.** Stack commits and PRs in the order that proves the work. The canonical shape is the failing test first, then the fix on top. Other story orders are a subtraction before the reshape, a baseline capture before the treatment, the scaffold before the feature. Each commit lands on its own and the sequence reads as an argument.

            The sequencing complement to the **prove-it-works** principle skill, which keeps each check real, and the **build-the-lever** principle skill, which makes the per-unit check cheap.
          '';

          ".agents/skills/principle-subtract-before-you-add/SKILL.md".text = ''
            ---
            name: principle-subtract-before-you-add
            description: "Apply when sequencing an addition, refactor, or rewrite. Remove dead code, redundant validators, and stub references first, then build on the simpler base."
            ---

            # Subtract Before You Add

            When evolving a system, remove complexity first, then build. Default to subtraction.

            Make simplification a continual investment. Leave the design slightly simpler and more capable behind the same or smaller surface than you found it.

            - Sequence removal before construction
            - Cut before you polish (get to the minimum before investing in quality)
            - Design for observed usage, not speculative edge cases
            - No speculative validators, parsers, or guards beyond what the spec demands
            - Simplify prompts (remove redundant instructions, excessive templates)
            - When a reference has no novel content, delete it rather than leaving a stub
          '';

          ".agents/skills/show-me-your-work/SKILL.md".text = ''
            ---
            name: show-me-your-work
            description: "Keep a reviewable decision trail for long-running or unattended work: a TSV log with one row per decision (what, why, evidence, result). Local by default; commit it when a reviewer needs the trail to trust the result. Use for /show-me-your-work, autonomous or multi-phase runs, or work a human reviews after stepping away."
            ---

            # Show me your work

            Keep one canonical log.

            ## The format

            A single TSV file, one row per decision. Cells stay single-line. Evidence is a pointer, not prose.

            Copy `references/decision-log-template.tsv` (the header row) to start a clean log. Columns:

            - **ts.** ISO8601 timestamp.
            - **phase.** The phase or workstream.
            - **decision.** What was chosen or done, one line.
            - **why.** The reason in plain words. If a principle drove it, say it plainly, not as a jargon tag.
            - **evidence.** A link or path that proves it: commit SHA, PR number, `file:line`, or an artifact, trace, or screenshot path. Never a paragraph.
            - **result.** The outcome or predicate state: `tests green`, `reverted`, `pixel-diff 0`, `INCONCLUSIVE`, `open`.

            An example, plain-spoken so a reviewer reads it at a glance.

            ```
            ts	phase	decision	why	evidence	result
            2026-05-24T09:02:00Z	frame	counted the work first, about 100 components and roughly 75 hours	wanted to know the size before starting a long run	commit 3a9f1c2	found 5 things to sort out before starting
            2026-05-24T09:40:00Z	harness	took screenshots of the old version before changing anything	so we can compare old against new and catch any visual change	scripts/snapshot.sh, baseline/	saved 120 reference screenshots
            2026-05-24T11:15:00Z	widget	moved the widget styles over without changing how it looks	keep the change small and the result identical	commit 7c21e0a, pixel-diff 0	looks identical, tests pass
            2026-05-24T12:30:00Z	widget	threw out a helper's work because its screenshots were blank	checked the real files instead of trusting its summary	worktree reset	reverted, tightened the instructions for next time
            ```

            ## Logging a row

            Write each entry the way you'd tell a teammate what you did. Plain words, concrete actions, no AI speak or abstract jargon (the AGENTS.md writing rules apply to log text too).

            Use the helper `scripts/log.sh <logfile> <phase> <decision> <why> <evidence> <result>`. It stamps `ts`, writes the header on first use, strips stray tabs/newlines, and prefixes any cell starting with `=`, `+`, `-`, or `@` with a single quote. A bare `printf` appending a row works too, but mind those same bytes if cells come from generated or user-supplied text.

            Log decision points and checkpoints, not every action: a fork chosen, a unit completed with its verification result, a pivot or revert with its trigger, a blocker surfaced, a gate fixed. For loop runs, one row per iteration. Skip the trivial and self-evident.

            A run is one agent conversation, including its later turns and any summary of it. A pickup, a replacement agent, or a new chat starts a new run. When a run adds to a log that already has rows, its first row has phase `start`, and so does its first row after another run's `start` row. So a run that comes back to a log in a later turn first reads the log's last rows to see whether another run wrote since. A `start` row names the `ts` range of the rows before it that this run did not write, and its evidence names this run, such as its agent id. Use phase `start` for nothing else.

            ## Where it lives

            By default the log is a working artifact, not committed. Keep it at `decisions.tsv` in the work dir, or `.audit/<task-slug>.tsv` when several efforts run at once, and leave it out of git.

            Commit it only when the work is ambitious enough that a reviewer needs the trail to trust the result.

            ## Rules

            - Append-only. A wrong call gets a new row that supersedes it. Never edit or delete history.
            - Prefer evidence produced by committed scripts over hand-made one-offs (the **encode-lessons-in-structure** principle skill).

            ## Audit the log against the transcript

            At the end of the run, before handing back, check the log told the truth. Read this run's transcript from the active workspace's session directory: in Cursor, the `agent-transcripts/` directory the system prompt names. In Claude Code, `~/.claude/projects/<slug>/` (the workspace path with every character that isn't a letter or digit turned into "-"). In Pi, `~/.pi/agent/sessions/--<slug>--/`. In Codex, the `~/.codex/sessions/` file whose first line has `payload.cwd` equal to the workspace path. Don't glob across every project's directory. That reads unrelated private chats. Walk this run's rows against what actually happened. Each stretch of them begins at one of this run's `start` rows, or at the first row if this run created the log, and ends at the next `start` row of another run:

            - Check that every row maps to a real decision or action.
            - Check that each row's evidence resolves and shows what the row claims.
            - A fork, pivot, or abandoned approach that shaped the work but isn't logged is a gap. Add it.

            Correct the log, not the story. The audit never edits or removes a row, even an invented one. When a row records neither a real decision nor a real action, or its claim or evidence is wrong, add a row that supersedes it with what actually happened and a pointer that resolves. This audit does not check rows outside this run's stretches. If this run's own work shows one of them is wrong, supersede it like any wrong call.

            ## Cross-model review of the trail

            Before handing back, spawn a subagent on a different model family from the one that did the work. Self-review is not a substitute. The subagent reads the audit trail and the run's transcript, then flags what the user should pay attention to. Not a redo of the work, a scan for what's suboptimal or risky.

            - Decisions logged with weak or absent evidence.
            - Verification steps skipped or claimed without proof in the transcript.
            - Choices that look risky in hindsight (premature, scope-creeping, papering over a symptom).
            - Gaps the user would otherwise miss on a casual skim.

            Every reply for a run that produced a trail ends with an "Attention" section. Lead with the reviewer's model on its own line (`reviewed by <model>`), then list each flag pointing to specific rows or moments. "No flags" is a valid value. The model name is not.

            ## Reviewing the trail

            Read top to bottom, follow the evidence pointers, spot-check. GitHub renders a committed TSV as a table. `column -s$'\t' -t decisions.tsv` renders it in a terminal.

            ## Composing this skill

            Other skills route their audit trail here instead of inventing one. Reference it by name and let it own the format. Don't restate the columns.
          '';

          ".agents/skills/show-me-your-work/references/decision-log-template.tsv".text = ''
            ts	phase	decision	why	evidence	result
          '';

          ".agents/skills/show-me-your-work/scripts/log.sh".text = ''
            #!/usr/bin/env bash
            # Append a well-formed row to a show-me-your-work decision log (TSV).
            # Usage: log.sh <logfile> <phase> <decision> <why> <evidence> <result>
            set -euo pipefail

            if [ "$#" -ne 6 ]; then
            	printf 'usage: log.sh <logfile> <phase> <decision> <why> <evidence> <result>\n' >&2
            	exit 1
            fi

            logfile="$1"
            shift

            logdir="$(dirname "$logfile")"
            if [ -n "$logdir" ] && [ "$logdir" != "." ] && [ ! -d "$logdir" ]; then
            	mkdir -p "$logdir"
            fi

            # Use `>>` here, never `>`. A network mount can fail this test for a log
            # that exists. Then the cost is one stray header line, not the rows.
            if [ ! -s "$logfile" ]; then
            	printf 'ts\tphase\tdecision\twhy\tevidence\tresult\n' >> "$logfile"
            fi

            ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
            # Strip tabs/newlines/CR so cells stay on one line, and prefix any cell
            # whose first char a spreadsheet would parse as a formula (=, +, -, @)
            # with a single quote. The skill expects this log to be read in
            # spreadsheets, so attacker-controlled evidence (PR titles, filenames,
            # generated text) must not become formula execution when a reviewer
            # opens the file.
            clean() {
            	local v
            	v=$(printf '%s' "$1" | tr '\t\n\r' '   ')
            	case "$v" in
            		=*|+*|-*|@*) printf "'%s" "$v" ;;
            		*) printf '%s' "$v" ;;
            	esac
            }
            printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
            	"$ts" "$(clean "$1")" "$(clean "$2")" "$(clean "$3")" "$(clean "$4")" "$(clean "$5")" \
            	>> "$logfile"
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
