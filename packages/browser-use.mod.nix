{ inputs, ... }:

{
  perSystem =
    { lib, pkgs, ... }:
    let
      inherit (lib.attrsets) optionalAttrs;
    in
    {
      packages = optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        browser-use = pkgs.callPackage (
          {
            callPackage,
            lib,
            python312,
            runCommand,
            ...
          }:
          let
            inherit (lib.fixedPoints) composeManyExtensions;
            inherit (inputs.hermes-agent.inputs) uv2nix pyproject-nix pyproject-build-systems;
            workspace = uv2nix.lib.workspace.loadWorkspace {
              workspaceRoot = ./browser-use;
            };
            pythonSet =
              (callPackage pyproject-nix.build.packages {
                python = python312;
              }).overrideScope
              <| composeManyExtensions [
                pyproject-build-systems.overlays.default
                (workspace.mkPyprojectOverlay { sourcePreference = "wheel"; })
              ];
            virtualEnv = pythonSet.mkVirtualEnv "browser-use-0.13.10-env" { browser-use = [ ]; };
          in
          # Export only the CLI entrypoints, keeping its interpreter and
          # dependency commands out of the user's general-purpose PATH.
          runCommand "browser-use-0.13.10" { meta.mainProgram = "browser-use"; } ''
            mkdir -p "$out/bin"
            for command in browser browser-use browser-use-tui browseruse bu; do
              ln -s "${virtualEnv}/bin/$command" "$out/bin/$command"
            done
          ''
        ) { };
      };
    };
}
