{ inputs, ... }:
{
  perSystem = { pkgs, ... }:
  let
    # The upstream lockfile is lockfileVersion 9.0, which pnpm 11 and 12 both
    # read and write; edge keeps this in step with the interactive pnpm.
    # nixpkgs' pnpm hooks predate pnpm 12's supply-chain verification pass and
    # pass an empty --registry to it, so the hooks come from edge as well.
    edgePkgs = inputs.edge.legacyPackages.${pkgs.stdenv.hostPlatform.system};
    edgePnpm = edgePkgs.pnpm;
  in
  {
    packages.hermes-desktop-web = pkgs.callPackage (
      {
        stdenv,
        nodejs,
      }:
      stdenv.mkDerivation (final: {
        pname = "hermes-desktop-web";
        version = "0.0.0-${inputs.hermes-desktop-web.shortRev}";
        src = inputs.hermes-desktop-web;
        nativeBuildInputs = [
          nodejs
          edgePnpm
          edgePkgs.pnpmConfigHook
        ];
        pnpmDeps = edgePkgs.fetchPnpmDeps {
          inherit (final) pname version src;
          pnpm = edgePnpm;
          fetcherVersion = 5;
          hash = "sha256-BkuwGcHF9uMeJg0rXxMaElpF5z76Wu/yu3NOcCrRBzA=";
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
