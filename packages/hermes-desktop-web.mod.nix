{ inputs, ... }:
{
  perSystem = { pkgs, ... }: {
    packages.hermes-desktop-web = pkgs.callPackage (
      {
        stdenv,
        nodejs,
        pnpm_11,
        pnpmConfigHook,
        fetchPnpmDeps,
        writeText,
      }:
      stdenv.mkDerivation (final: {
        pname = "hermes-desktop-web";
        version = "0.0.0-f1ae2bb";
        src = inputs.hermes-desktop-web;
        nativeBuildInputs = [
          nodejs
          pnpm_11
          pnpmConfigHook
        ];
        pnpmDeps = fetchPnpmDeps {
          inherit (final) pname version src;
          pnpm = pnpm_11;
          fetcherVersion = 4;
          hash = "sha256-VKzMEcusCX0TOBQrN/TmKKqc59nbcDgSs8FgJORZtWE=";
        };
        # Seed the single local gateway before the desktop stores initialize.
        postPatch = /* bash */ ''
          cp ${
            writeText "hermes-web-main.tsx" /* typescript */ ''
              import { installContextMenuInterceptor } from './context-menu-interceptor';
              import { installWebBridge } from './bridge/adapter';
              import { loadRegistry, saveRegistry, defaultMockConnection } from './bridge/registry';
              import './web.css';

              async function start() {
                const response = await fetch('/api/proxy/meta');
                if (!response.ok) throw new Error('Cannot load Hermes connection settings');
                const { defaultGatewayUrl } = await response.json();
                const registry = loadRegistry();
                if (registry.connections.length === 1 && registry.connections[0].url === defaultMockConnection().url) {
                  registry.connections[0] = {
                    id: 'local', label: 'Manara', kind: 'remote',
                    url: defaultGatewayUrl, authMode: 'oauth', token: "",
                  };
                  saveRegistry(registry);
                }
                installContextMenuInterceptor();
                installWebBridge();
                await import('../../../vendor/hermes-desktop/src/main');
              }
              start().catch((error) => {
                document.body.textContent = 'Hermes could not start. Reload to retry.';
                console.error(error);
              });
            ''
          } apps/web/src/main.tsx
        '';
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
