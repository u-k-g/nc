{ inputs, ... }:
{
  perSystem = { pkgs, ... }:
  let
    # The upstream lockfile is lockfileVersion 9.0, which pnpm 11 and 12 both
    # read and write; edge keeps this in step with the interactive pnpm.
    edgePnpm = inputs.edge.legacyPackages.${pkgs.stdenv.hostPlatform.system}.pnpm;
  in
  {
    packages.hermes-desktop-web = pkgs.callPackage (
      {
        stdenv,
        nodejs,
        pnpmConfigHook,
        fetchPnpmDeps,
      }:
      stdenv.mkDerivation (final: {
        pname = "hermes-desktop-web";
        version = "0.0.0-${inputs.hermes-desktop-web.shortRev}";
        src = inputs.hermes-desktop-web;
        nativeBuildInputs = [
          nodejs
          edgePnpm
          pnpmConfigHook
        ];
        pnpmDeps = fetchPnpmDeps {
          inherit (final) pname version src;
          pnpm = edgePnpm;
          fetcherVersion = 4;
          hash = "sha256-VKzMEcusCX0TOBQrN/TmKKqc59nbcDgSs8FgJORZtWE=";
        };
        buildPhase = /* bash */ ''
          runHook preBuild
          pnpm typecheck
          pnpm --filter @hermes-web/web test
          pnpm build
          runHook postBuild
        '';
        installPhase = /* bash */ ''
          runHook preInstall
          mkdir -p "$out/share/hermes-desktop-web"
          cp -r apps/web/dist "$out/share/hermes-desktop-web/dist"
          cp -r apps/proxy/src "$out/share/hermes-desktop-web/proxy"
          runHook postInstall
        '';
      })
    ) { };
  };
}
