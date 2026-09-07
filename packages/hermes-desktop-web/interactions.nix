{ runCommand, writeText }:
runCommand "hermes-interactions" { } /* bash */ ''
  mkdir -p "$out"
  cp ${
    writeText "interaction-feedback.ts" /* typescript */ ''
      import { useCallback, useLayoutEffect, useRef, useState } from 'react';

      // The busy signal, not the RPC response, confirms that a run has stopped.
      // Every invocation belongs to one pane/session generation; late replies
      // must never clear or replace feedback for another run.
      export function useStopFeedback(scope: string | null, busy: boolean, action: () => void | Promise<void>) {
        const [feedback, setFeedback] = useState<{ scope: string | null; text: string; retryable: boolean } | null>(null);
        const actionRef = useRef(action);
        actionRef.current = action;
        const owner = useRef({ scope, busy, generation: 0, pending: false });
        const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
        useLayoutEffect(() => {
          owner.current = { scope, busy, generation: owner.current.generation + 1, pending: false };
          clearTimeout(timer.current);
          setFeedback(null);
          return () => {
            owner.current.generation++;
            clearTimeout(timer.current);
          };
        }, [scope, busy]);
        const cancel = useCallback(async () => {
          const current = owner.current;
          if (!current.busy || current.pending) return;
          current.pending = true;
          const generation = ++current.generation;
          const owns = () => owner.current === current && current.generation === generation;
          setFeedback({ scope: current.scope, text: 'Stopping…', retryable: false });
          clearTimeout(timer.current);
          timer.current = setTimeout(() => {
            if (!owns()) return;
            current.pending = false;
            setFeedback({ scope: current.scope, text: 'Stop requested; still waiting for the run to end.', retryable: true });
          }, 8000);
          try {
            await actionRef.current();
          } catch {
            if (!owns()) return;
            clearTimeout(timer.current);
            current.pending = false;
            setFeedback({ scope: current.scope, text: 'Could not confirm the stop. Check your connection and try again.', retryable: true });
          }
        }, []);
        const visible = feedback?.scope === scope && busy ? feedback : null;
        return { cancel, status: visible?.text ?? null, retryable: visible?.retryable ?? false };
      }
    ''
  } "$out/interaction-feedback.ts"
  cp ${
    writeText "interaction-motion.tsx" /* typescript */ ''
      import { MotionConfig, motion } from 'motion/react';
      import { useState, useSyncExternalStore, type ReactNode } from 'react';

      const query = '(prefers-reduced-motion: reduce)';
      const readMotionPreference = () => window.matchMedia?.(query).matches ?? false;
      function subscribeMotionPreference(listener: () => void) {
        const media = window.matchMedia?.(query);
        media?.addEventListener('change', listener);
        return () => media?.removeEventListener('change', listener);
      }
      // Motion's hook snapshots the preference at mount in the pinned version.
      // Subscribe explicitly so changing the OS preference takes effect live.
      export function useInteractionReducedMotion() {
        return useSyncExternalStore(subscribeMotionPreference, readMotionPreference, () => true);
      }
      export function InteractionMotion({ children }: { children: ReactNode }) {
        const reduced = useInteractionReducedMotion();
        return <MotionConfig reducedMotion={reduced ? 'always' : 'never'}>{children}</MotionConfig>;
      }

      // One spring for disclosures. Re-targeting animate preserves the current
      // position and velocity, including reversals before the previous settle.
      export function InteractionDisclosure({ open, id, children }: { open: boolean; id: string; children: ReactNode }) {
        const reduced = useInteractionReducedMotion();
        const [visited, setVisited] = useState(open);
        if (open && !visited) setVisited(true);
        return <motion.div
          id={id}
          data-interaction-disclosure=""
          aria-hidden={!open}
          inert={!open}
          initial={false}
          animate={{ height: open ? 'auto' : 0, opacity: open ? 1 : 0 }}
          transition={reduced ? { duration: 0 } : { type: 'spring', stiffness: 420, damping: 40, mass: 0.8 }}
          style={{ overflow: 'clip' }}
        >
          <div className="flex min-w-0 flex-col gap-(--conversation-turn-gap)">{visited && children}</div>
        </motion.div>;
      }
    ''
  } "$out/interaction-motion.tsx"
  cp ${
    writeText "interaction.css" /* css */ ''
      :root {
        --interaction-fast: 100ms;
        --interaction-settle: 220ms;
        --interaction-ease: cubic-bezier(.2, .8, .2, 1);
      }
      /* Feedback changes paint, never button geometry or pointer hit areas. */
      :where(button, [role="button"], [role="tab"], [role="switch"], summary) {
        -webkit-tap-highlight-color: transparent;
        transition-property: background-color, color, border-color, box-shadow, opacity;
        transition-duration: var(--interaction-fast);
        transition-timing-function: var(--interaction-ease);
      }
      :where(button, [role="button"], [role="tab"], [role="switch"], summary):active:not(:disabled):not([aria-disabled="true"]) {
        box-shadow: inset 0 0 0 999px color-mix(in srgb, currentColor 10%, transparent);
        transition-duration: 0ms;
      }
      :where(button, [role="button"], [role="tab"], [role="switch"], summary):focus-visible {
        outline: 2px solid var(--ui-blue, currentColor);
        outline-offset: 2px;
      }
      [data-slot="aui_completed-run"] button > svg {
        transition: transform var(--interaction-fast) var(--interaction-ease);
      }
      [data-slot="sheet-content"], [data-slot="sheet-overlay"],
      [data-slot="dialog-content"], [data-slot="dialog-overlay"] {
        animation-duration: var(--interaction-settle);
        animation-timing-function: var(--interaction-ease);
      }
      [data-slot="aui_response-loading"], [data-slot="aui_turn-activity"] {
        min-height: 1.5em;
      }
      [data-interaction-status] {
        min-height: 1.5em;
        font-size: .75rem;
        line-height: 1.5;
      }
      @media (prefers-reduced-motion: reduce) {
        *, *::before, *::after {
          animation-duration: 0.01ms !important;
          animation-iteration-count: 1 !important;
          transition-duration: 0ms !important;
          scroll-behavior: auto !important;
        }
      }
    ''
  } "$out/interaction.css"
  cp ${
    writeText "patch-interactions.mjs" /* javascript */ ''
      import fs from 'node:fs';
      const base = 'vendor/hermes-desktop/src/';
      function patch(file, before, after) {
        const source = fs.readFileSync(base + file, 'utf8');
        if (source.split(before).length !== 2) throw Error(`Review interaction patch: ''${file}: ''${before}`);
        fs.writeFileSync(base + file, source.replace(before, after));
      }
      patch('app/chat/composer/index.tsx',
        "import { SubmissionRecovery } from '@/lib/submission-recovery'",
        "import { SubmissionRecovery } from '@/lib/submission-recovery'\nimport { useStopFeedback } from '@/lib/interaction-feedback'");
      patch('app/chat/composer/index.tsx',
        `  const haltRun = useCallback(() => {
          parkQueuedPrompts(activeQueueSessionKeyRef.current)

          return onCancel()
        }, [activeQueueSessionKeyRef, onCancel])`,
        `  const { cancel: haltRun, status: stopStatus, retryable: stopRetryable } = useStopFeedback(activeQueueSessionKey, busy, () => {
          parkQueuedPrompts(activeQueueSessionKeyRef.current)
          return onCancel()
        })`);
      patch('app/chat/composer/index.tsx', '<SubmissionRecovery />',
        `<SubmissionRecovery scope={activeQueueSessionKey} stopStatus={stopStatus} onRetryStop={stopRetryable ? haltRun : undefined} />`);
      patch('components/assistant-ui/thread/status.tsx',
        "import { cn } from '@/lib/utils'",
        "import { cn } from '@/lib/utils'\nimport { $bufferedOutput } from '@/lib/buffered-output'");
      patch('components/assistant-ui/thread/status.tsx',
        "      {hint && <HintText>{hint}</HintText>}\n      <ActivityTimerText seconds={elapsed} />\n    </StatusRow>\n  )\n}\n\n// Parked-background",
        "      <HintText>{hint || t.assistant.thread.loadingResponse}</HintText>\n      <ActivityTimerText seconds={elapsed} />\n    </StatusRow>\n  )\n}\n\n// Parked-background");
      patch('components/assistant-ui/thread/status.tsx',
        'export const TurnActivityIndicator: FC = () => {',
        'export const TurnActivityIndicator: FC = () => {\n  const buffered = useStore($bufferedOutput)');
      patch('components/assistant-ui/thread/status.tsx',
        '(Boolean(hint) || quietSince !== undefined)',
        '(buffered || Boolean(hint) || quietSince !== undefined)');
      patch('components/assistant-ui/thread/status.tsx',
        "      {hint && <HintText>{hint}</HintText>}\n      <ActivityTimerText seconds={elapsed} />",
        "      <HintText>{hint || (buffered ? 'Working · text appears when ready' : 'Hermes is working')}</HintText>\n      <ActivityTimerText seconds={elapsed} />");
      patch('components/ui/button.tsx', 'shadow-none transition-all duration-100',
        'shadow-none transition-colors duration-100');
      patch('components/ui/tabs.tsx', 'whitespace-nowrap transition-all outline-none',
        'whitespace-nowrap transition-colors duration-100 outline-none');
      patch('main.tsx', "import { StrictMode } from 'react'",
        "import { StrictMode } from 'react'\nimport { InteractionMotion } from './lib/interaction-motion'");
      patch('main.tsx', '<RootTooltipProvider>', '<RootTooltipProvider>\n                  <InteractionMotion>');
      patch('main.tsx', '</RootTooltipProvider>', '</InteractionMotion>\n                </RootTooltipProvider>');
      patch('components/ui/sheet.tsx', "import { Dialog as SheetPrimitive } from 'radix-ui'",
        "import { AnimatePresence, motion } from 'motion/react'\nimport { useInteractionReducedMotion } from '@/lib/interaction-motion'\nimport { Dialog as SheetPrimitive } from 'radix-ui'");
      patch('components/ui/sheet.tsx',
        `function Sheet({ ...props }: React.ComponentProps<typeof SheetPrimitive.Root>) {
        return <SheetPrimitive.Root data-slot="sheet" {...props} />
      }`,
        `const SheetOpen = React.createContext(false)
      function Sheet({ open: controlledOpen, defaultOpen = false, onOpenChange, ...props }: React.ComponentProps<typeof SheetPrimitive.Root>) {
        const [localOpen, setLocalOpen] = React.useState(defaultOpen)
        const open = controlledOpen ?? localOpen
        return <SheetOpen.Provider value={open}>
          <SheetPrimitive.Root {...props} open={open} onOpenChange={value => {
            setLocalOpen(value)
            onOpenChange?.(value)
          }} />
        </SheetOpen.Provider>
      }`);
      patch('components/ui/sheet.tsx',
        'bg-black/22 backdrop-blur-[0.125rem] data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:animate-in data-[state=open]:fade-in-0',
        'bg-black/22 backdrop-blur-[0.125rem]');
      patch('components/ui/sheet.tsx',
        `  const { t } = useI18n()

        return (
          <SheetPortal>
            <SheetOverlay />
            <SheetPrimitive.Content`,
        `  const { t } = useI18n()
        const open = React.useContext(SheetOpen)
        const reduced = useInteractionReducedMotion()
        const offset = side === 'left' ? { x: '-100%', y: 0 } : side === 'right' ? { x: '100%', y: 0 }
          : side === 'top' ? { x: 0, y: '-100%' } : { x: 0, y: '100%' }
        const transition = reduced ? { duration: 0 } : { type: 'spring' as const, stiffness: 420, damping: 40, mass: 0.8 }

        return (
          <SheetPortal forceMount>
            <AnimatePresence initial={false}>
            {open && <SheetOverlay key="overlay" forceMount asChild>
              <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={reduced ? { duration: 0 } : { duration: 0.12 }} />
            </SheetOverlay>}
            {open && <SheetPrimitive.Content key="content" forceMount asChild`);
      patch('components/ui/sheet.tsx',
        'shadow-md transition ease-in-out data-[state=closed]:animate-out data-[state=closed]:duration-300 data-[state=open]:animate-in data-[state=open]:duration-500',
        'shadow-md');
      for (const side of ['right', 'left', 'top', 'bottom']) {
        patch('components/ui/sheet.tsx', ` data-[state=closed]:slide-out-to-''${side} data-[state=open]:slide-in-from-''${side}`, ''');
      }
      patch('components/ui/sheet.tsx',
        `      >
              {children}
              {showCloseButton`,
        `      >
              <motion.div initial={reduced ? false : offset} animate={{ x: 0, y: 0 }} exit={reduced ? { x: 0, y: 0 } : offset} transition={transition}>
              {children}
              {showCloseButton`);
      patch('components/ui/sheet.tsx',
        `      </SheetPrimitive.Content>
          </SheetPortal>`,
        `      </motion.div>
            </SheetPrimitive.Content>}
            </AnimatePresence>
          </SheetPortal>`);
    ''
  } "$out/patch-interactions.mjs"
  cp ${
    writeText "interaction-feedback.test.ts" /* typescript */ ''
      import { act, cleanup, renderHook } from '@testing-library/react';
      import { afterEach, expect, it, vi } from 'vitest';
      import { useStopFeedback } from '@/lib/interaction-feedback';
      afterEach(() => { cleanup(); vi.useRealTimers(); });
      const deferred = () => {
        let resolve!: () => void;
        let reject!: (error: Error) => void;
        const promise = new Promise<void>((yes, no) => { resolve = yes; reject = no; });
        return { promise, resolve, reject };
      };
      it('acknowledges immediately, coalesces repeated stops, and waits for busy to clear', async () => {
        const reply = deferred(); const action = vi.fn(() => reply.promise);
        const h = renderHook(({ busy }) => useStopFeedback('a', busy, action), { initialProps: { busy: true } });
        act(() => { void h.result.current.cancel(); void h.result.current.cancel(); });
        expect(h.result.current.status).toBe('Stopping…'); expect(action).toHaveBeenCalledTimes(1);
        await act(async () => reply.resolve());
        expect(h.result.current.status).toBe('Stopping…');
        h.rerender({ busy: false }); expect(h.result.current.status).toBeNull();
      });
      it('ignores late rejection from another session, including a switch away and back', async () => {
        const old = deferred(); const next = deferred(); const action = vi.fn().mockReturnValueOnce(old.promise).mockReturnValue(next.promise);
        const h = renderHook(({ scope }) => useStopFeedback(scope, true, action), { initialProps: { scope: 'a' } });
        act(() => { void h.result.current.cancel(); });
        h.rerender({ scope: 'b' }); h.rerender({ scope: 'a' });
        act(() => { void h.result.current.cancel(); });
        await act(async () => old.reject(Error('old failure')));
        expect(h.result.current.status).toBe('Stopping…'); expect(h.result.current.retryable).toBe(false);
        await act(async () => next.resolve());
      });
      it('offers retry after an honest timeout and does not claim the run stopped', () => {
        vi.useFakeTimers(); const action = vi.fn(() => new Promise<void>(() => {}));
        const h = renderHook(() => useStopFeedback('a', true, action));
        act(() => { void h.result.current.cancel(); vi.advanceTimersByTime(8000); });
        expect(h.result.current.status).toContain('still waiting'); expect(h.result.current.retryable).toBe(true);
        act(() => { void h.result.current.cancel(); }); expect(action).toHaveBeenCalledTimes(2);
        expect(h.result.current.status).toBe('Stopping…');
      });
      it('catches synchronous failures and permits retry', async () => {
        const h = renderHook(() => useStopFeedback('a', true, () => { throw Error('offline'); }));
        await act(async () => { await h.result.current.cancel(); });
        expect(h.result.current.status).toContain('Check your connection'); expect(h.result.current.retryable).toBe(true);
      });
    ''
  } "$out/interaction-feedback.test.ts"
  cp ${
    writeText "interaction-recovery.test.ts" /* typescript */ ''
      import { createElement as h } from 'react';
      import { act, cleanup, fireEvent, render, screen } from '@testing-library/react';
      import { afterEach, beforeEach, expect, it, vi } from 'vitest';
      import { SubmissionRecovery } from '@/lib/submission-recovery';
      import { runSubmission } from '@/lib/submission-journal';
      beforeEach(() => localStorage.clear());
      afterEach(() => { cleanup(); vi.restoreAllMocks(); vi.unstubAllGlobals(); });
      it('shows delivery state outside the closed recovery panel and only for its owning session', async () => {
        let resolve!: (accepted: boolean) => void;
        const reply = new Promise<boolean>(done => { resolve = done; });
        const view = render(h(SubmissionRecovery, { scope: 'a' }));
        let pending!: Promise<boolean>;
        act(() => { pending = runSubmission({ scope: 'a', text: 'Keep these words', attachmentCount: 0 }, () => reply); });
        const status = view.container.querySelector('[data-interaction-status]')!;
        expect(status.textContent).toContain('sending');
        expect(view.container.querySelector('details')?.open).toBe(false);
        view.rerender(h(SubmissionRecovery, { scope: 'b' }));
        expect(status.textContent).toBe(''');
        await act(async () => { resolve(false); await pending; });
        expect(status.textContent).toBe(''');
        view.rerender(h(SubmissionRecovery, { scope: 'a' }));
        expect(status.textContent).toContain('Check the conversation before resending');
      });
      it('confirms copying only after the clipboard write succeeds', async () => {
        await runSubmission({ scope: 'a', text: 'Recovered text', attachmentCount: 0 }, () => false);
        const writeText = vi.fn().mockResolvedValue(undefined);
        vi.stubGlobal('navigator', { clipboard: { writeText } });
        render(h(SubmissionRecovery, { scope: 'a' }));
        fireEvent.click(screen.getByText('1 locally saved submission'));
        await act(async () => { fireEvent.click(screen.getByRole('button', { name: 'Copy text' })); });
        expect(writeText).toHaveBeenCalledWith('Recovered text');
        expect(screen.getByRole('button', { name: 'Copied' })).toBeTruthy();
      });
    ''
  } "$out/interaction-recovery.test.ts"
''
