{ runCommand, writeText }:
# Patterns reviewed in macro-inc/macro at 197e8159873511ae2731c8195b223facec4be767:
# apps/web/src/components/app/useAppSquishHandlers.ts
# apps/web/src/lib/core/component/AI/component/input/ChatInput.tsx
# Independently implemented for the Hermes browser build.
runCommand "hermes-browser-interactions" { } /* bash */ ''
  mkdir -p "$out"
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
