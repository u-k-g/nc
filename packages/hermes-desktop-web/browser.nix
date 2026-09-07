{ runCommand, writeText }:
# Patterns reviewed in macro-inc/macro at 197e8159873511ae2731c8195b223facec4be767:
# apps/web/src/components/app/useAppSquishHandlers.ts
# apps/web/src/lib/core/component/AI/component/input/ChatInput.tsx
# Independently implemented for the Hermes browser build.
runCommand "hermes-browser-interactions" { } /* bash */ ''
  mkdir -p "$out"
  cp ${
    writeText "patch-titlebar-palette.mjs" /* javascript */ ''
      import fs from 'node:fs';
      const base = 'vendor/hermes-desktop/src/';
      function patch(file, before, after) {
        const path = base + file;
        const source = fs.readFileSync(path, 'utf8');
        if (source.split(before).length !== 2) throw Error(`Review titlebar palette patch: ''${file}`);
        fs.writeFileSync(path, source.replace(before, after));
      }
      patch('app/shell/titlebar-controls.tsx',
        "import { $hapticsMuted, toggleHapticsMuted } from '@/store/haptics'",
        "import { $hapticsMuted, toggleHapticsMuted } from '@/store/haptics'\nimport { openCommandPalette } from '@/store/command-palette'");
      patch('app/shell/titlebar-controls.tsx',
        '  const systemTools: TitlebarTool[] = [',
        `  const systemTools: TitlebarTool[] = [
          {
            actionId: 'nav.commandPalette',
            icon: <TitlebarIcon name="search" />,
            id: 'command-palette',
            label: t.commandCenter.paletteTitle,
            onSelect: () => {
              triggerHaptic('open')
              openCommandPalette()
            }
          },`);
      // Reserve room for the extra pinned button on desktop as well as mobile.
      patch('app/contrib/wiring.tsx', 'const SYSTEM_TOOL_COUNT = 5', 'const SYSTEM_TOOL_COUNT = 6');
      patch('app/contrib/controller.tsx',
        'Five static cluster buttons: four systemTools', 'Six static cluster buttons: five systemTools');
      patch('app/contrib/controller.tsx',
        '+ 5 * var(--titlebar-control-size, 24px)', '+ 6 * var(--titlebar-control-size, 24px)');
    ''
  } "$out/patch-titlebar-palette.mjs"
  cp ${
    writeText "patch-external-links.mjs" /* javascript */ ''
      import fs from 'node:fs';
      const base = 'vendor/hermes-desktop/src/';
      function patch(file, before, after, count = 1) {
        const path = base + file;
        const source = fs.readFileSync(path, 'utf8');
        if (source.split(before).length !== count + 1) throw Error(`Review external-browser patch: ''${file}`);
        fs.writeFileSync(path, source.replaceAll(before, after));
      }
      // Managed preference: every click path reads the same value, including
      // callers that explicitly pass native:false. No stale local preference
      // can send links back into a webview after an update or reload.
      patch('lib/external-link.tsx',
        'export function openLink(href: string, options: { native?: boolean } = {}): void {',
        `export const IN_APP_BROWSER_ENABLED = false
      export function openLink(href: string, options: { native?: boolean } = {}): void {`);
      patch('lib/external-link.tsx',
        'if (options.native || hudForcesNativeLinks() ||',
        'if (!IN_APP_BROWSER_ENABLED || options.native || hudForcesNativeLinks() ||');
      patch('app/context-menu/app-context-menu.tsx',
        'import { hostPathLabel, hudForcesNativeLinks, normalizeExternalUrl, openExternalLink }',
        'import { hostPathLabel, hudForcesNativeLinks, IN_APP_BROWSER_ENABLED, normalizeExternalUrl, openExternalLink }');
      patch('app/context-menu/app-context-menu.tsx',
        'const openInApp = !hudForcesNativeLinks()',
        'const openInApp = IN_APP_BROWSER_ENABLED && !hudForcesNativeLinks()', 2);
      // URL attachment clicks must open synchronously in the user gesture,
      // before the async local-file resolver can lose popup permission.
      patch('components/chat/preview-attachment.tsx',
        "import { Download, MonitorPlay } from '@/lib/icons'",
        "import { Download, MonitorPlay } from '@/lib/icons'\nimport { openLink } from '@/lib/external-link'");
      patch('components/chat/preview-attachment.tsx',
        '  async function togglePreview() {',
        `  async function togglePreview() {
          if (new RegExp('^https?://', 'i').test(target)) {
            openLink(target)
            return
          }`);
      patch('app/settings/appearance-settings.tsx',
        '          <ListRow\n            action={<LanguageSwitcher />}',
        `          <ListRow
                  title="Open web links in"
                  description="Web links always open in a normal browser tab. In-app browsing is never used for links."
                  action={<span className="text-sm text-muted-foreground">External browser</span>}
                />
                <ListRow
                  action={<LanguageSwitcher />}`);
    ''
  } "$out/patch-external-links.mjs"
  cp ${
    writeText "external-browser.test.ts" /* typescript */ ''
      import { createElement as h } from 'react';
      import { cleanup, fireEvent, render, screen } from '@testing-library/react';
      import { afterEach, beforeEach, expect, it, vi } from 'vitest';
      import { ExternalLink, IN_APP_BROWSER_ENABLED, openLink } from '@/lib/external-link';
      const original = window.hermesDesktop;
      const openExternal = vi.fn();
      beforeEach(() => {
        openExternal.mockReset();
        window.hermesDesktop = { openExternal } as unknown as Window['hermesDesktop'];
      });
      afterEach(() => { cleanup(); window.hermesDesktop = original; });
      it.each([{}, { native: false }, { native: true }])('always routes links externally with options %j', options => {
        expect(IN_APP_BROWSER_ENABLED).toBe(false);
        openLink('https://example.com/docs', options);
        expect(openExternal).toHaveBeenCalledExactlyOnceWith('https://example.com/docs');
      });
      it('handles ordinary, modified and middle clicks synchronously', () => {
        render(h(ExternalLink, { href: 'https://example.com/docs' }, 'Documentation'));
        const link = screen.getByRole('link', { name: 'Documentation' });
        fireEvent.click(link);
        fireEvent.click(link, { ctrlKey: true });
        fireEvent.click(link, { metaKey: true });
        fireEvent(link, new MouseEvent('auxclick', { button: 1, bubbles: true, cancelable: true }));
        expect(openExternal).toHaveBeenCalledTimes(4);
        expect(openExternal.mock.calls.every(([url]) => url === 'https://example.com/docs')).toBe(true);
      });
    ''
  } "$out/external-browser.test.ts"
  cp ${
    writeText "mobile-viewport.ts" /* typescript */ ''
      // Resize the mobile shell without putting keyboard animation into React state.
      export function installMobileViewport() {
        const media = window.matchMedia('(max-width: 767px) and (pointer: coarse)');
        const viewport = window.visualViewport;
        const root = document.documentElement;
        let frame: number | null = null;
        let disposed = false;
        const update = () => {
          frame = null;
          if (!media.matches) {
            root.style.removeProperty('--hermes-viewport-height');
            return;
          }
          // Pinch zoom changes the visual viewport too; do not reflow the app for it.
          if (viewport && viewport.scale !== 1) return;
          const height = viewport?.height ?? window.innerHeight;
          if (!Number.isFinite(height) || height <= 0) return;
          const value = Math.round(height) + 'px';
          if (root.style.getPropertyValue('--hermes-viewport-height') !== value) {
            root.style.setProperty('--hermes-viewport-height', value);
          }
        };
        const schedule = () => {
          if (!disposed && !document.hidden && frame === null) frame = window.requestAnimationFrame(update);
        };
        const onVisibility = () => {
          if (document.hidden && frame !== null) {
            window.cancelAnimationFrame(frame);
            frame = null;
          } else schedule();
        };
        window.addEventListener('resize', schedule, { passive: true });
        window.addEventListener('pageshow', schedule);
        viewport?.addEventListener('resize', schedule, { passive: true });
        media.addEventListener('change', schedule);
        document.addEventListener('visibilitychange', onVisibility);
        schedule();
        return () => {
          disposed = true;
          if (frame !== null) window.cancelAnimationFrame(frame);
          window.removeEventListener('resize', schedule);
          window.removeEventListener('pageshow', schedule);
          viewport?.removeEventListener('resize', schedule);
          media.removeEventListener('change', schedule);
          document.removeEventListener('visibilitychange', onVisibility);
          root.style.removeProperty('--hermes-viewport-height');
        };
      }
    ''
  } "$out/mobile-viewport.ts"
  cp ${
    writeText "mobile-viewport.test.ts" /* typescript */ ''
      import { afterEach, beforeEach, expect, it, vi } from 'vitest';
      import { installMobileViewport } from './mobile-viewport';

      let media: EventTarget & { matches: boolean };
      let viewport: EventTarget & { height: number; scale: number };
      let frames: Map<number, FrameRequestCallback>;
      let cleanup: () => void;
      let hidden: boolean;
      const height = () => document.documentElement.style.getPropertyValue('--hermes-viewport-height');
      const flush = () => {
        const pending = [...frames.values()]; frames.clear();
        pending.forEach(callback => callback(0));
      };
      beforeEach(() => {
        frames = new Map(); hidden = false; let id = 0;
        media = Object.assign(new EventTarget(), { matches: true });
        viewport = Object.assign(new EventTarget(), { height: 844, scale: 1 });
        vi.stubGlobal('matchMedia', () => media);
        vi.stubGlobal('visualViewport', viewport);
        vi.stubGlobal('requestAnimationFrame', (callback: FrameRequestCallback) => { frames.set(++id, callback); return id; });
        vi.stubGlobal('cancelAnimationFrame', (id: number) => frames.delete(id));
        vi.spyOn(document, 'hidden', 'get').mockImplementation(() => hidden);
        cleanup = installMobileViewport(); flush();
      });
      afterEach(() => { cleanup(); vi.restoreAllMocks(); vi.unstubAllGlobals(); });
      it('fits the keyboard viewport and coalesces resize events into one frame', () => {
        expect(height()).toBe('844px'); viewport.height = 430;
        for (let i = 0; i < 20; i++) viewport.dispatchEvent(new Event('resize'));
        expect(frames.size).toBe(1); expect(height()).toBe('844px');
        flush(); expect(height()).toBe('430px');
        viewport.height = 844; window.dispatchEvent(new Event('resize')); flush();
        expect(height()).toBe('844px');
      });
      it('preserves pinch zoom and restores native desktop sizing', () => {
        viewport.scale = 2; viewport.height = 422;
        viewport.dispatchEvent(new Event('resize')); flush(); expect(height()).toBe('844px');
        media.matches = false; media.dispatchEvent(new Event('change')); flush(); expect(height()).toBe("");
      });
      it('cancels hidden work, recovers on return, and removes listeners on disposal', () => {
        viewport.height = 430; viewport.dispatchEvent(new Event('resize'));
        hidden = true; document.dispatchEvent(new Event('visibilitychange')); expect(frames.size).toBe(0);
        viewport.dispatchEvent(new Event('resize')); expect(frames.size).toBe(0);
        hidden = false; document.dispatchEvent(new Event('visibilitychange')); flush(); expect(height()).toBe('430px');
        cleanup(); viewport.dispatchEvent(new Event('resize')); window.dispatchEvent(new Event('pageshow'));
        expect(frames.size).toBe(0); expect(height()).toBe("");
      });
      it('ignores transient zero heights', () => {
        viewport.height = 0; viewport.dispatchEvent(new Event('resize')); flush(); expect(height()).toBe('844px');
      });
    ''
  } "$out/mobile-viewport.test.ts"
  cp ${
    writeText "patch-composer-focus.mjs" /* javascript */ ''
      import fs from 'node:fs';
      const path = 'vendor/hermes-desktop/src/app/chat/composer/hooks/use-composer-draft.ts';
      const source = fs.readFileSync(path, 'utf8');
      const before = `  useEffect(() => {
          if (!inputDisabled) {
            focusInput()
          }
        }, [focusInput, focusKey, focusRequestId, inputDisabled])`;
      const after = `  const consumedFocusRequest = useRef(focusRequestId)
        useEffect(() => {
          if (inputDisabled) return
          const explicit = consumedFocusRequest.current !== focusRequestId
          consumedFocusRequest.current = focusRequestId
          // Opening a chat or recovering the connection must not summon the phone keyboard.
          // Taps, keyboard shortcuts and explicit insert/focus requests still work.
          if (explicit || !window.matchMedia('(pointer: coarse)').matches) focusInput()
        }, [focusInput, focusKey, focusRequestId, inputDisabled])`;
        if (!source.includes(before)) throw new Error('Upstream composer focus changed; review browser patch');
        fs.writeFileSync(path, source.replace(before, after));
    ''
  } "$out/patch-composer-focus.mjs"
''
