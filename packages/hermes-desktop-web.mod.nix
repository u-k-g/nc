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
            browserAssets,
            lib,
            theme ? null,
            themeAssets ? null,
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
            postPatch =
              /* bash */ ''
                cp ${mobileAssets}/mobile.css apps/web/src/mobile.css
                cp ${browserAssets}/mobile-viewport*.ts apps/web/src/
                node ${browserAssets}/patch-composer-focus.mjs
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
                      import { installMobileViewport } from './mobile-viewport';

                      const disposeViewport = installMobileViewport();
                      if (import.meta.hot) import.meta.hot.dispose(disposeViewport);

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
              ''
              + lib.strings.optionalString (theme != null) /* bash */ ''
                cp ${themeAssets}/themenix.ts vendor/hermes-desktop/src/themes/themenix.ts
                cp ${themeAssets}/themenix.css ${themeAssets}/*.woff2 apps/web/src/
                sed -i "1i import './themenix.css';" apps/web/src/main.tsx
                sed -i "1i import { themenixTheme } from './themenix';" vendor/hermes-desktop/src/themes/presets.ts
                substituteInPlace vendor/hermes-desktop/src/themes/presets.ts \
                  --replace-fail 'nous: nousTheme,' 'nc: themenixTheme, nous: nousTheme,' \
                  --replace-fail "DEFAULT_SKIN_NAME = 'nous'" "DEFAULT_SKIN_NAME = 'nc'"
                substituteInPlace vendor/hermes-desktop/src/themes/context.tsx \
                  --replace-fail 'name && resolveTheme(name) && !RETIRED_SKINS.has(name) ? name : DEFAULT_SKIN_NAME' "'nc'" \
                  --replace-fail "value === 'light' || value === 'dark' || value === 'system' ? value : 'system'" "'${
                    if theme.isDark then "dark" else "light"
                  }'" \
                  --replace-fail 'listAllThemes().map' "listAllThemes().filter(theme => theme.name === 'nc').map" \
                  --replace-fail 'setModeState(next)' 'setModeState(normalizeMode(next))' \
                  --replace-fail 'modePref.assign(liveProfile(), next)' 'modePref.assign(liveProfile(), normalizeMode(next))' \
                  --replace-fail 'setPreview(resolveTheme(name) ? { name, mode: previewMode } : null)' 'setPreview(null)' \
                  --replace-fail '(accentOverride === null ? activeTheme : retintTheme(activeTheme, accentOverride))' 'activeTheme' \
                  --replace-fail "'--ui-success': harmonize('#10b981', midground, 0.25)," \
                    "'--ui-success': '#${theme.base0B}', '--ui-red': '#${theme.base08}', '--ui-orange': '#${theme.base09}', '--ui-yellow': '#${theme.base0A}', '--ui-green': '#${theme.base0B}', '--ui-cyan': '#${theme.base0C}', '--ui-blue': '#${theme.base0D}', '--ui-purple': '#${theme.base0E}',"
                substituteInPlace apps/web/index.html \
                  --replace-fail '<meta name="theme-color" content="#0a0a0a" />' '<meta name="theme-color" content="#${theme.base00}" />'
                # Insert before the upstream pre-paint script reads cached colors.
                sed -i '/<title>Hermes<\/title>/r ${themeAssets}/boot.html' apps/web/index.html
                node --input-type=module <<'JS'
                import fs from 'node:fs';
                const path = 'vendor/hermes-desktop/src/app/settings/appearance-settings.tsx';
                const source = fs.readFileSync(path, 'utf8');
                const start = source.indexOf('          <ListRow\n            below={');
                const end = source.indexOf('\n          <ListRow', start + 1);
                if (start < 0 || end < 0 || !source.slice(start, end).includes('APPEARANCE_SETTING_IDS.theme')) {
                  throw new Error('Upstream appearance settings changed; review the managed-theme patch');
                }
                fs.writeFileSync(path, source.slice(0, start) + `
                          <ListRow
                            title="nc"
                            description="Follows Manara's system theme."
                            id={appearanceSettingElementId(APPEARANCE_SETTING_IDS.theme)}
                            below={<div className="mt-3 max-w-xs"><ThemePreview mode={resolvedMode} name="nc" /></div>}
                            wide
                          />
                ` + source.slice(end));
                JS
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
          browserAssets = pkgs.callPackage ./hermes-desktop-web/browser.nix { };
        };
  };
}
