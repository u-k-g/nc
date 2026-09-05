{ inputs, ... }:
{
  perSystem = { pkgs, ... }: {
    packages.hermes-desktop-web =
      pkgs.callPackage
        (
          {
            stdenv,
            nodejs,
            pnpm_11,
            pnpmConfigHook,
            fetchPnpmDeps,
            writeText,
            mobileAssets,
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
              cp ${mobileAssets}/mobile.css apps/web/src/mobile.css
              cp ${mobileAssets}/sw.js ${mobileAssets}/manifest.webmanifest ${mobileAssets}/*.png vendor/hermes-desktop/public/
              substituteInPlace apps/proxy/src/main.ts \
                --replace-fail "'.json': 'application/json; charset=utf-8'," "'.json': 'application/json; charset=utf-8', '.webmanifest': 'application/manifest+json'," \
                --replace-fail "ext === '.html' ? 'no-store' : 'public, max-age=31536000, immutable'" \
                  "ext === '.html' ? 'no-store' : (url.pathname.startsWith('/assets/') ? 'public, max-age=31536000, immutable' : 'no-cache')"
              substituteInPlace apps/web/index.html \
                --replace-fail 'width=device-width, initial-scale=1.0' 'width=device-width, initial-scale=1.0, viewport-fit=cover, interactive-widget=resizes-content' \
                --replace-fail '<title>Hermes</title>' '<link rel="manifest" href="/manifest.webmanifest" /><title>Hermes</title>'
              substituteInPlace vendor/hermes-desktop/src/app/contrib/controller.tsx \
                --replace-fail '<div className="relative flex h-[34px]' '<div data-hermes-titlebar="" className="relative flex h-[34px]'
              substituteInPlace vendor/hermes-desktop/src/app/shell/titlebar-controls.tsx \
                --replace-fail 'data-tour={tool.tour}' 'data-hermes-tool={tool.id} data-tour={tool.tour}'
              cp ${
                writeText "hermes-web-main.tsx" /* typescript */ ''
                  import { installContextMenuInterceptor } from './context-menu-interceptor';
                  import { installWebBridge } from './bridge/adapter';
                  import { loadRegistry, saveRegistry, defaultMockConnection } from './bridge/registry';
                  import './web.css';
                  import './mobile.css';

                  // Register after rendering; never reload an active chat for updates.
                  function registerPwa() {
                    if ('serviceWorker' in navigator) {
                      navigator.serviceWorker.register('/sw.js', { updateViaCache: 'none' }).catch(console.error);
                    }
                  }
                  if (document.readyState === 'complete') registerPwa();
                  else window.addEventListener('load', registerPwa, { once: true });

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
        )
        {
          mobileAssets = pkgs.callPackage ./hermes-desktop-web/mobile.nix {
            src = inputs.hermes-desktop-web;
          };
        };
  };
}
