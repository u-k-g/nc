{
  runCommand,
  writeText,
  imagemagick,
  lib,
  src,
  background ? "#f7f7f7",
}:

runCommand "hermes-mobile-assets" { nativeBuildInputs = lib.lists.singleton imagemagick; } /* bash */ ''
  mkdir -p "$out"
  magick ${src}/vendor/hermes-desktop/assets/icon.png -resize 192x192 "$out/pwa-192.png"
  magick ${src}/vendor/hermes-desktop/assets/icon.png -resize 512x512 "$out/pwa-512.png"
  magick ${src}/vendor/hermes-desktop/assets/icon.png -resize 320x320 -background '${background}' -gravity center -extent 512x512 "$out/pwa-maskable.png"
  cp ${
    writeText "manifest.webmanifest" /* json */ ''
      {
        "id": "/", "name": "Hermes · Manara", "short_name": "Hermes",
        "start_url": "/", "scope": "/", "display": "standalone",
        "background_color": "${background}", "theme_color": "${background}",
        "icons": [
          { "src": "/pwa-192.png", "sizes": "192x192", "type": "image/png", "purpose": "any" },
          { "src": "/pwa-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any" },
          { "src": "/pwa-maskable.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable" }
        ]
      }
    ''
  } "$out/manifest.webmanifest"
  cp ${
    writeText "mobile.css" /* css */ ''
      @media (max-width: 767px) and (pointer: coarse) {
        html, body { overscroll-behavior: none; }
        :root, body, #root, [data-contrib-shell], [data-slot="sidebar-wrapper"] {
          height: var(--hermes-viewport-height, 100dvh) !important;
          min-height: 0;
        }
        [data-contrib-shell] {
          padding-top: env(safe-area-inset-top);
          padding-left: env(safe-area-inset-left);
          padding-right: env(safe-area-inset-right);
          --titlebar-control-size: 44px;
          --titlebar-control-height: 44px;
          --titlebar-controls-top: calc(4px + env(safe-area-inset-top)) !important;
        }
        [data-hermes-titlebar] { height: 52px; }
        [data-hermes-tool="flip-panes"], [data-hermes-tool="layout"], [data-hermes-tool="hud"] {
          display: none;
        }
        [data-size="icon-titlebar"] { width: 44px; height: 44px; }
        [data-size="icon-titlebar"] .codicon { font-size: 19px !important; }
        [data-slot="composer-dock"] {
          padding-bottom: calc(var(--composer-shell-pad-block-end, 0px) + env(safe-area-inset-bottom)) !important;
        }
        [data-slot="composer-surface"] > * { min-width: 0; }
        [data-slot="composer-fade"] > .grid:has(> [class*="grid-area:input"]) {
          grid-template-columns: auto minmax(0, 1fr);
          grid-template-areas: "input input" "menu controls";
          gap: 8px;
        }
        [data-slot="composer-fade"] [class*="grid-area:controls"],
        [data-slot="composer-fade"] [class*="grid-area:menu"] { flex-wrap: wrap; }
        [data-slot="composer-root"] button {
          min-width: 44px;
          min-height: 44px;
          touch-action: manipulation;
        }
        input, textarea, [contenteditable="true"] { font-size: 16px !important; }
        [data-slot="statusbar"] { padding-bottom: env(safe-area-inset-bottom); }
        [data-slot="statusbar"] > div { overflow-x: auto !important; scrollbar-width: none; }
        [data-slot="dialog-content"] { max-height: 90dvh; overflow-y: auto; }
      }
    ''
  } "$out/mobile.css"
  cp ${
    writeText "sw.js" /* javascript */ ''
      // Cache public, fingerprinted build assets only. Navigation stays fresh.
      const CACHE = 'hermes-ui-assets-v1';
      const LIMIT = 160;
      self.addEventListener('activate', event => {
        event.waitUntil((async () => {
          for (const key of await caches.keys()) {
            if (key.startsWith('hermes-ui-assets-') && key !== CACHE) await caches.delete(key);
          }
          await self.clients.claim();
        })());
      });
      self.addEventListener('fetch', event => {
        const request = event.request;
        const url = new URL(request.url);
        if (request.method !== 'GET' || url.origin !== self.location.origin || url.search) return;
        if (/^\/assets\/[^/]+-[\w-]{8,}\.(js|css|woff2?|png|svg|webp)$/.test(url.pathname)) {
          event.respondWith((async () => {
            const cache = await caches.open(CACHE);
            const hit = await cache.match(request);
            if (hit) return hit;
            const response = await fetch(request);
            // Missing assets can return the upstream SPA fallback, never cache that.
            if (response.ok && !response.redirected && !response.headers.get('content-type')?.includes('text/html')) {
              await cache.put(request, response.clone());
              const keys = await cache.keys();
              for (const key of keys.slice(0, Math.max(0, keys.length - LIMIT))) await cache.delete(key);
            }
            return response;
          })());
        } else if (request.mode === 'navigate' && (url.pathname === '/' || url.pathname === '/index.html')) {
          event.respondWith(fetch(request).catch(() => new Response(
            '<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><title>Hermes offline</title><style>body{font:18px system-ui;padding:2rem;max-width:30rem;margin:auto}button{font:inherit;padding:12px 24px}</style><h1>Cannot reach Manara</h1><p>Check your connection and turn on Tailscale, then try again.</p><button onclick="location.reload()">Try again</button>',
            { headers: { 'Content-Type': 'text/html; charset=utf-8' } }
          )));
        }
      });
    ''
  } "$out/sw.js"
''
