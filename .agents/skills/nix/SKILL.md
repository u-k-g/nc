---
name: nix
description: >
  Activate when editing *.nix, flakes, NixOS, Pi deploy, linux-builder, or Nix CLI.
---

# Nix

Reference for structure and style: `git@github.com:RGBCube/ncc.git` (local clone `01-projects/02-clones/ncc` if present). Prefer concrete ncc patterns over guesses. Do not copy workstation tooling (`nh`, `dix`, `nom`, desktop modules) onto the drone.

Pi appliance policy lives in `AGENTS.md`. This skill does not repeat it. Full-system Darwin uses the project `darwin.linux-builder` VM only for that `nix build`. x86 Linux uses binfmt/`extra-platforms`. The Pi is never a builder.

## CLI

- New `nix` CLI only: `nix build`, `nix copy`, `nix profile` / `nix build --profile`. Never `nix-*` (`nix-build`, `nix-env`, `nix-store` except image first-boot `nix-store --load-db`).
- Never `nh` or `nixos-rebuild`.
- `--builders`, not `--store`, for remote builds.
- Long flags in committed scripts.
- Never `builtins.getFlake`. Use flake refs on the CLI.
- Never `find /nix/store`. `nix flake archive --json` once, then use literal paths.

## Style

- No `rec`. No `--impure`. No `builtins.getEnv`.
- No `builtins.` in modules; use `lib`.
- `let inherit (lib.lists) head;` with full submodule paths. `lib.lists.singleton` over a one-item list.
- Dendritic flake-parts: `*.mod.nix` auto-discovery. One concern per file. Packages that are their own tool get their own module.
- `${lib.getExe pkgs.foo}` (or `getExe'`) over bare command names.
- `"${path}"` when the derivation context must survive. Never `toString` for those paths.
- `pkgs.callPackage ({ stdenv, writeText }: ...) { }` for inline packages.
- `/* lang */` before multiline code strings.
- `mkIf` on the individual option, not the whole attrset, when that is enough.
- Prefer `<|` when the parenthesized expr is the final argument (not `if`/`let`/lambda).
- Empty line between unrelated options.

Do not invent extra deploy wrappers. The deployable is a store path.
