---
name: nushell
description: >
  Activate when editing *.nu, writeNu/writeNuBin, or replacing bash orchestration.
---

# Nushell

Glue language for copy/activate/JSON/tables wrapping `nix` and `systemd`. Not for long-lived owners of hardware or safety state (those stay Rust/C++).

Pi appliance policy lives in `AGENTS.md`. Nix CLI/style lives in the `nix` skill.

## Style

- Typed `def`s. Fail with `error make { msg: ... }`.
- Structured data: `open`, `from json`, `to json`. Not `jq`/`awk`/`sed` pipelines.
- Small modules (`use foo.nu *`), not one thousand-line script.
- `run-external` / captured status for other programs. `${lib.getExe pkgs.foo}` when the script is generated from Nix.
- Prefer `pkgs.writers.writeNuBin` with `/* nu */` for short Nix-owned scripts. Keep non-trivial programs as `*.nu` files on disk (inspectable).
- Long flags in committed scripts.
- Do not rewrite `vigil-status`, inhibit, or mission-controller into Nu.
