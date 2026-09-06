{ runCommand, writeText }:
runCommand "hermes-submission-lifecycle" { } /* bash */ ''
  mkdir -p "$out"
  cp ${
    writeText "composer-ownership.test.ts" /* typescript */ ''
      import { act, cleanup, renderHook } from '@testing-library/react';
      import { afterEach, beforeEach, expect, it, vi } from 'vitest';
      import { useComposerSubmit } from '@/app/chat/composer/hooks/use-composer-submit';
      import { listSubmissions } from '@/lib/submission-journal';
      vi.mock('@/components/pane-shell/pane-visibility', () => ({ usePaneVisible: () => true }));
      vi.mock('@/lib/chat-runtime', () => ({ SLASH_COMMAND_RE: /^\// }));
      vi.mock('@/lib/haptics', () => ({ triggerHaptic: vi.fn() }));
      vi.mock('@/store/clarify', () => ({ hasClarifyRequest: () => false, skipClarifyRequest: vi.fn() }));
      vi.mock('@/store/composer-input-history', () => ({ resetBrowseState: vi.fn() }));
      vi.mock('@/store/mcp-setup', () => ({ hasMcpSetupRequest: () => false, skipMcpSetupRequest: vi.fn() }));
      vi.mock('@/store/prompts', () => ({ hasBlockingPromptRequest: () => false }));
      vi.mock('@/app/chat/composer/composer-utils', () => ({ cloneAttachments: (items: unknown[]) => [...items] }));
      vi.mock('@/app/chat/composer/focus', () => ({ onComposerSubmitRequest: () => () => {} }));
      vi.mock('@/app/chat/composer/path-refs', () => ({ pathifyRefs: (text: string) => text }));
      vi.mock('@/app/chat/composer/rich-editor', () => ({ composerPlainText: (node: HTMLElement) => node.textContent }));
      vi.mock('@/app/chat/composer/scope', () => ({ useComposerScope: () => ({ target: 'main', attachments: { clear: vi.fn() } }), useComposerSurfaceId: () => 'main' }));
      beforeEach(() => localStorage.clear());
      afterEach(() => { cleanup(); vi.restoreAllMocks(); });
      function harness() {
        let resolve!: (accepted: boolean) => void;
        const reply = new Promise<boolean>(done => { resolve = done; });
        const draftRef = { current: 'original text' }; const scope = { current: 'a' as string | null };
        const clearDraft = vi.fn(() => { draftRef.current = '''; });
        const loadIntoComposer = vi.fn(); const stashAt = vi.fn();
        const onSubmit = vi.fn(() => reply); const onSteer = vi.fn(() => reply);
        const args = { activeQueueSessionKey: 'a', activeQueueSessionKeyRef: scope, attachments: [], busy: false, compacting: false, clearDraft, disabled: false, draftRef, drainNextQueued: async () => false, editorRef: { current: null }, exitQueuedEdit: () => false, focusInput: vi.fn(), inputDisabled: false, loadIntoComposer, onCancel: vi.fn(), onSteer, onSubmit, queueCurrentDraft: () => false, queueEdit: null, queuedPrompts: [], sessionId: 'a', setComposerText: vi.fn(), stashAt };
        const hook = renderHook(() => useComposerSubmit(args));
        return { ...hook, args, draftRef, scope, clearDraft, loadIntoComposer, stashAt, onSubmit, onSteer, resolve };
      }
      it.each([true, false])('late acknowledgement=%s cannot overwrite a different session or its draft', async accepted => {
        const h = harness(); act(() => h.result.current.submitDraft());
        expect(h.onSubmit).toHaveBeenCalledTimes(1);
        h.scope.current = 'b'; h.draftRef.current = 'new draft in B';
        h.stashAt.mockClear(); h.clearDraft.mockClear();
        await act(async () => { h.resolve(accepted); });
        expect(h.draftRef.current).toBe('new draft in B');
        expect(h.loadIntoComposer).not.toHaveBeenCalled(); expect(h.stashAt).not.toHaveBeenCalled(); expect(h.clearDraft).not.toHaveBeenCalled();
        if (!accepted) expect(listSubmissions()[0]).toMatchObject({ scope: 'a', text: 'original text', state: 'unconfirmed' });
      });
      it('late acknowledgement cannot erase a newer draft in the same session, even after switching away and back', async () => {
        const h = harness(); act(() => h.result.current.submitDraft());
        h.scope.current = 'b'; h.rerender(); h.scope.current = 'a'; h.draftRef.current = 'newer words'; h.rerender();
        h.stashAt.mockClear(); await act(async () => { h.resolve(true); });
        expect(h.draftRef.current).toBe('newer words'); expect(h.stashAt).not.toHaveBeenCalled();
      });
      it('synchronous submit exceptions retain recovery text', async () => {
        const h = harness(); h.onSubmit.mockImplementation(() => { throw Error('offline'); });
        await act(async () => { h.result.current.submitDraft(); });
        expect(listSubmissions()[0]).toMatchObject({ text: 'original text', state: 'unconfirmed' });
      });
      it('failed steering retains text without converting it into another agent command', async () => {
        const h = harness(); act(() => h.result.current.steerDraft());
        h.scope.current = 'b'; h.draftRef.current = 'different session';
        await act(async () => { h.resolve(false); });
        expect(h.onSubmit).not.toHaveBeenCalled(); expect(h.onSteer).toHaveBeenCalledTimes(1);
        expect(h.draftRef.current).toBe('different session'); expect(listSubmissions()[0].state).toBe('unconfirmed');
      });
      it('quota failure leaves the editor intact and sends nothing', async () => {
        const h = harness(); vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => { throw Error('quota'); }); vi.spyOn(window, 'alert').mockImplementation(() => {});
        await act(async () => { h.result.current.submitDraft(); });
        expect(h.draftRef.current).toBe('original text'); expect(h.onSubmit).not.toHaveBeenCalled(); expect(h.clearDraft).not.toHaveBeenCalled();
      });
    ''
  } "$out/composer-ownership.test.ts"
  cp ${
    writeText "patch-lifecycle.mjs" /* javascript */ ''
      import fs from "node:fs";
      const patches = [
        [
      "vendor/hermes-desktop/src/app/chat/composer/hooks/use-composer-submit.ts",
      "import { clearSessionDraft, type ComposerAttachment } from '@/store/composer'",
      `import { type ComposerAttachment } from '@/store/composer'
      import { runSubmission } from '@/lib/submission-journal'`
        ],
        [
      "vendor/hermes-desktop/src/app/chat/composer/hooks/use-composer-submit.ts",
      "import { enqueueQueuedPrompt, type QueuedPromptEntry } from '@/store/composer-queue'",
      "import { type QueuedPromptEntry } from '@/store/composer-queue'"
        ],
        [
      "vendor/hermes-desktop/src/app/chat/composer/hooks/use-composer-submit.ts",
      `  // Shared send primitive: fire onSubmit, and if the gateway rejects (accepted
        // === false) or throws, re-load + re-stash the draft so the words survive.
        const dispatchSubmit = (text: string, attachments?: ComposerAttachment[], displayKind?: 'hidden') => {
          const submittedScope = activeQueueSessionKeyRef.current
          const submittedAttachments = attachments ?? []

          const restore = () => {
            loadIntoComposer(text, submittedAttachments)
            // Use the scope captured at dispatch, not whatever session is focused
            // now — the gateway can reject well after the user has switched away,
            // and re-stashing into the currently-focused session would overwrite
            // its draft with the rejected text from a different session (#54527).
            stashAt(submittedScope, text, submittedAttachments)
          }

          void Promise.resolve(
            attachments
              ? onSubmit(text, { attachments, composerScope: submittedScope, ...(displayKind ? { displayKind } : {}) })
              : onSubmit(text, { composerScope: submittedScope, ...(displayKind ? { displayKind } : {}) })
          )
            .then(accepted => void (accepted === false ? restore() : clearSessionDraft(submittedScope)))
            .catch(restore)
        }
      `,
      `  // Each send owns a recovery record, never the editor of a later session.
        const dispatchSubmit = (text: string, attachments?: ComposerAttachment[], displayKind?: 'hidden', consumeDraft = false) => {
          const submittedScope = activeQueueSessionKeyRef.current
          void runSubmission(
            { scope: submittedScope, text, attachmentCount: attachments?.length ?? 0 },
            () => onSubmit(text, { attachments, composerScope: submittedScope, ...(displayKind ? { displayKind } : {}) }),
            () => {
              if (consumeDraft) { clearDraft(); scope.attachments.clear(); stashAt(submittedScope, ''', []) }
            }
          ).catch(() => window.alert('Could not save the submission locally. Nothing was sent; your draft is still here.'))
        }
      `
        ],
        [
      "vendor/hermes-desktop/src/app/chat/composer/hooks/use-composer-submit.ts",
      `        clearDraft()
              dispatchSubmit(text)`,
      "        dispatchSubmit(text, undefined, undefined, true)"
        ],
        [
      "vendor/hermes-desktop/src/app/chat/composer/hooks/use-composer-submit.ts",
      `      clearDraft()
            scope.attachments.clear()
            dispatchSubmit(text, submittedAttachments)`,
      "      dispatchSubmit(text, submittedAttachments, undefined, true)"
        ],
        [
      "vendor/hermes-desktop/src/app/chat/composer/hooks/use-composer-submit.ts",
      `    clearDraft()

          void Promise.resolve(onSteer(text)).then(accepted => {
            if (!accepted && activeQueueSessionKey) {
              enqueueQueuedPrompt(activeQueueSessionKey, { text, attachments: [] })
            }
          })`,
      `    const submittedScope = activeQueueSessionKeyRef.current
          void runSubmission(
            { scope: submittedScope, text, attachmentCount: 0 },
            () => onSteer(text),
            () => { clearDraft(); stashAt(submittedScope, ''', []) }
          ).catch(() => window.alert('Could not save the correction locally. Nothing was sent; your draft is still here.'))`
        ],
        [
      "vendor/hermes-desktop/src/app/chat/composer/index.tsx",
      "import { ComposerPrimitive } from '@assistant-ui/react'",
      `import { SubmissionRecovery } from '@/lib/submission-recovery'
      import { ComposerPrimitive } from '@assistant-ui/react'`
        ],
        [
      "vendor/hermes-desktop/src/app/chat/composer/index.tsx",
      "            {isHelpHint && <HelpHint />}",
      `            <SubmissionRecovery />
                  {isHelpHint && <HelpHint />}`
        ],
        [
      "vendor/hermes-desktop/src/app/session/hooks/use-prompt-actions/submit.ts",
      `            },
                  // A starved backend loop (#55578 symptom d) rejects the submit even
                  // though the stored session is fine — recover it like a dead id
                  // instead of erroring out and losing the session binding.
                  { alsoTimeout: true }`,
      "            } // Timeout is ambiguous: never resume and replay a prompt."
        ],
        [
      "vendor/hermes-desktop/src/app/session/hooks/use-prompt-actions/index.ts",
      `        const { result } = await withSessionNotFoundResume(sessionId, selectedStoredSessionIdRef.current, send, {
                requestGateway,
                onRecovered: recoveredId => {`,
      `        const ownerStoredId = selectedStoredSessionIdRef.current
              const { result } = await withSessionNotFoundResume(sessionId, ownerStoredId, send, {
                requestGateway,
                driftReason: () => activeSessionIdRef.current !== sessionId || selectedStoredSessionIdRef.current !== ownerStoredId ? 'redirect owner retired' : null,
                onRecovered: recoveredId => {`
        ],
        [
      "vendor/hermes-desktop/src/app/chat/composer/hooks/use-composer-queue.ts",
      "import { useStore } from '@nanostores/react'",
      `import { runSubmission } from '@/lib/submission-journal'
      import { useStore } from '@nanostores/react'`
        ],
        [
      "vendor/hermes-desktop/src/app/chat/composer/hooks/use-composer-queue.ts",
      `const accepted = await Promise.resolve(
                onSubmit(entry.text, {
                  attachments: entry.attachments,
                  ...(entry.displayText ? { displayText: entry.displayText } : {}),
                  fromQueue: true,
                  sessionId: drainRuntimeSessionId,
                  storedSessionId: drainQueueSessionKey
                })
              )`,
      `const accepted = await runSubmission(
                  { scope: drainQueueSessionKey, text: entry.text, attachmentCount: entry.attachments.length, queueId: entry.id },
                () => onSubmit(entry.text, {
                  attachments: entry.attachments,
                  ...(entry.displayText ? { displayText: entry.displayText } : {}),
                  fromQueue: true,
                  sessionId: drainRuntimeSessionId,
                  storedSessionId: drainQueueSessionKey
                }),
                  () => { parkQueuedPrompts(drainQueueSessionKey); removeQueuedPrompt(drainQueueSessionKey, entry.id) }
                )`
        ],
        [
      "vendor/hermes-desktop/src/app/chat/composer/hooks/use-composer-queue.ts",
      "  getQueuedPrompts,",
      `  getQueuedPrompts,
        parkQueuedPrompts,`
        ],
        [
      "vendor/hermes-desktop/src/app/session/hooks/use-background-queue-drain.ts",
      "import { useStore } from '@nanostores/react'",
      `import { runSubmission } from '@/lib/submission-journal'
      import { useStore } from '@nanostores/react'`
        ],
        [
      "vendor/hermes-desktop/src/app/session/hooks/use-background-queue-drain.ts",
      `const accepted = await Promise.resolve(
                  submitTextRef.current(liveEntry.text, {
                    attachments: liveEntry.attachments,
                    fromQueue: true,
                    sessionId: runtimeSessionId,
                    storedSessionId: sessionKey
                  })
                )`,
      `const accepted = await runSubmission(
                  { scope: sessionKey, text: liveEntry.text, attachmentCount: liveEntry.attachments.length, queueId: liveEntry.id },
                  () => submitTextRef.current(liveEntry.text, {
                    attachments: liveEntry.attachments,
                    fromQueue: true,
                    sessionId: runtimeSessionId,
                    storedSessionId: sessionKey
                  }),
                  () => { parkQueuedPrompts(sessionKey); removeQueuedPrompt(sessionKey, liveEntry.id) }
                )`
        ],
        [
      "vendor/hermes-desktop/src/app/session/hooks/use-background-queue-drain.ts",
      "  getQueuedPrompts,",
      `  getQueuedPrompts,
        parkQueuedPrompts,`
        ],
        [
      "vendor/hermes-desktop/src/app/session/hooks/use-background-queue-drain.ts",
      "  shouldAutoDrain",
      `  shouldAutoDrain,
        unparkQueuedPrompts`
        ],
        [
      "vendor/hermes-desktop/src/app/session/hooks/use-background-queue-drain.ts",
      "          resetBrowseState(runtimeSessionId)",
      `          resetBrowseState(runtimeSessionId)
                unparkQueuedPrompts(sessionKey)`
        ],
        [
      "vendor/hermes-desktop/src/store/composer-queue.ts",
      "atom<Record<string, true>>({})",
      "atom<Record<string, true>>(Object.fromEntries(Object.keys($queuedPromptsBySession.get()).map(key => [key, true as const])))"
        ],
        [
      "vendor/hermes-desktop/src/app/chat/composer/hooks/use-composer-queue.ts",
      "      const accepted = await Promise.resolve(onSteer(entry.text))",
      `      const accepted = await runSubmission(
              { scope: activeQueueSessionKey, text: entry.text, attachmentCount: 0, queueId: entry.id },
              () => onSteer(entry.text),
              () => { parkQueuedPrompts(activeQueueSessionKey); removeQueuedPrompt(activeQueueSessionKey, entry.id) }
            )`
        ],
        [
      "vendor/hermes-desktop/src/app/chat/composer/hooks/use-composer-voice.ts",
      "import { useStore } from '@nanostores/react'",
      `import { runSubmission } from '@/lib/submission-journal'
      import { useStore } from '@nanostores/react'`
        ],
        [
      "vendor/hermes-desktop/src/app/chat/composer/hooks/use-composer-voice.ts",
      `    clearDraft()
          await onSubmit(text)`,
      `    await runSubmission(
            { scope: sessionId ?? null, text, attachmentCount: 0 },
            () => onSubmit(text),
            clearDraft
          )`
        ],
        [
      "vendor/hermes-desktop/src/app/chat/composer/index.tsx",
      "  const onSubmit = useCallback<ChatBarProps['onSubmit']>(",
      `  const submitViewRef = useRef({ key: queueSessionKey || sessionId || null })
        const submitViewKey = queueSessionKey || sessionId || null
        if (submitViewRef.current.key !== submitViewKey) submitViewRef.current = { key: submitViewKey }
        const onSubmit = useCallback<ChatBarProps['onSubmit']>(`
        ],
        [
      "vendor/hermes-desktop/src/app/chat/composer/index.tsx",
      "      const draft = await runComposerMiddleware({ text: value, attachments: options?.attachments })",
      `      const owner = submitViewRef.current
            const draft = await runComposerMiddleware({ text: value, attachments: options?.attachments })
            if (!options?.fromQueue && submitViewRef.current !== owner) return false`
        ],
        [
      "vendor/hermes-shared/src/json-rpc-gateway.ts",
      `    this.socket = socket
          this.stopHeartbeat()`,
      `    this.socket = socket
          this.replayInFlight = false
          this.replayHold = null
          this.stopHeartbeat()`
        ],
        [
      "vendor/hermes-shared/src/json-rpc-gateway.ts",
      `    this.replayInFlight = true
      `,
      `    const owner = this.socket
          this.replayInFlight = true
      `
        ],
        [
      "vendor/hermes-shared/src/json-rpc-gateway.ts",
      "      for (const result of results) {",
      `      if (this.socket !== owner || this.replayHold !== hold) return

            for (const result of results) {`
        ],
        [
      "vendor/hermes-shared/src/json-rpc-gateway.ts",
      `      this.flushReplayHold()
            this.replayInFlight = false`,
      `      // A retired replay must not flush or unlock its replacement's buffer.
            if (this.socket === owner && this.replayHold === hold) {
              this.flushReplayHold()
              this.replayInFlight = false
            }`
        ],
        [
      "vendor/hermes-shared/src/json-rpc-gateway.ts",
      `    if (this.replayEpoch !== null) {
            this.lastSeenSeq.clear()
          }`,
      `    if (this.replayEpoch !== null) {
            this.lastSeenSeq.clear()
            this.replayHold = null
            this.replayInFlight = false
          }`
        ],
        [
      "vendor/hermes-shared/src/json-rpc-gateway.ts",
      `      this.recordSeq(frame.params)
            this.dispatchEvent(frame.params)`,
      "      this.dispatchIfNewer(frame.params)"
        ],
        [
      "vendor/hermes-shared/src/json-rpc-gateway.ts",
      `      for (const result of results) {
      `,
      `      for (const result of results) {
              if (this.replayHold !== hold) return
      `
        ]
      ];
      for (const [path, before, after] of patches) {
        const source = fs.readFileSync(path, "utf8");
        if (!source.includes(before) || source.indexOf(before) !== source.lastIndexOf(before)) throw new Error("Review upstream lifecycle patch: " + path + " " + before.slice(0, 70));
        fs.writeFileSync(path, source.replace(before, after));
      }
    ''
  } "$out/patch-lifecycle.mjs"
  cp ${
    writeText "submission-journal.ts" /* typescript */ ''
      // Recovery data is local to this browser. It is never an outbound command queue.
      export type SubmissionState = 'saved' | 'sending' | 'unconfirmed' | 'acknowledged';
      export interface Submission {
        id: string; scope: string | null; text: string; attachmentCount: number;
        state: SubmissionState; createdAt: number; queueId?: string;
      }
      const prefix = 'hermes.nc.submission.v1.';
      const changed = 'hermes:nc-submissions';
      const active = new Set<string>();
      export function subscribeSubmissions(listener: () => void) {
        const storage = (event: StorageEvent) => { if (!event.key || event.key.startsWith(prefix)) listener(); };
        window.addEventListener(changed, listener);
        window.addEventListener('storage', storage);
        return () => { window.removeEventListener(changed, listener); window.removeEventListener('storage', storage); };
      }
      function publish() { window.dispatchEvent(new Event(changed)); }
      export function listSubmissions(): Submission[] {
        const entries: Submission[] = [];
        for (let i = 0; i < localStorage.length; i++) {
          const key = localStorage.key(i);
          if (!key?.startsWith(prefix)) continue;
          try {
            const item = JSON.parse(localStorage.getItem(key) ?? 'null') as Submission;
            if (!item || typeof item.id !== 'string' || key !== prefix + item.id || typeof item.text !== 'string' ||
                !(item.scope === null || typeof item.scope === 'string') || !Number.isFinite(item.createdAt) ||
                !['saved', 'sending', 'unconfirmed', 'acknowledged'].includes(item.state)) continue;
            // A reload (or another tab) cannot establish whether a send was delivered.
            entries.push(item.state === 'sending' && !active.has(item.id) ? { ...item, state: 'unconfirmed' } : item);
          } catch { /* Keep corrupt records untouched; never turn them into commands. */ }
        }
        return entries.sort((a, b) => a.createdAt - b.createdAt);
      }
      function write(item: Submission) {
        localStorage.setItem(prefix + item.id, JSON.stringify(item));
        publish();
      }
      export function discardSubmission(id: string) {
        localStorage.removeItem(prefix + id); publish();
      }
      export function beginSubmission(input: Pick<Submission, 'scope' | 'text' | 'attachmentCount' | 'queueId'>): Submission {
        const item: Submission = { ...input, id: crypto.randomUUID(), createdAt: Date.now(), state: 'saved' };
        // Must succeed before clearing the editor or calling the gateway.
        write(item);
        return item;
      }
      export function transitionSubmission(item: Submission, state: SubmissionState) {
        const allowed: Record<SubmissionState, SubmissionState[]> = {
          saved: ['sending'], sending: ['unconfirmed', 'acknowledged'], unconfirmed: [], acknowledged: []
        };
        if (!allowed[item.state].includes(state)) throw new Error('Invalid submission transition');
        const next = { ...item, state };
        write(next);
        Object.assign(item, next);
      }
      export async function runSubmission(
        input: Pick<Submission, 'scope' | 'text' | 'attachmentCount' | 'queueId'>,
        send: () => unknown | Promise<unknown>,
        beforeSend: () => void = () => {}
      ): Promise<boolean> {
        // Covers a crash between saving recovery data and removing a queue entry.
        if (input.queueId && listSubmissions().some(item => item.queueId === input.queueId)) return false;
        const item = beginSubmission(input);
        active.add(item.id);
        try {
          transitionSubmission(item, 'sending');
          beforeSend();
          const accepted = await send();
          // Upstream callbacks use void for successfully handled local commands.
          if (accepted === false) {
            transitionSubmission(item, 'unconfirmed');
            return false;
          }
          transitionSubmission(item, 'acknowledged');
          // Acknowledgement and pruning are separate: a failed deletion is harmless.
          try { discardSubmission(item.id); } catch { /* An acknowledged record is never replayed. */ }
          return true;
        } catch {
          if (item.state === 'sending') {
            try { transitionSubmission(item, 'unconfirmed'); } catch { /* Retain the durable sending record. */ }
          }
          return false;
        } finally {
          active.delete(item.id); publish();
        }
      }
    ''
  } "$out/submission-journal.ts"
  cp ${
    writeText "submission-lifecycle.test.ts" /* typescript */ ''
      import { afterEach, beforeEach, expect, it, vi } from 'vitest';
      import { beginSubmission, listSubmissions, runSubmission, transitionSubmission } from '@/lib/submission-journal';
      import { JsonRpcGatewayClient } from '@hermes/shared';
      const deferred = <T>() => { let resolve!: (value: T) => void; const promise = new Promise<T>(done => { resolve = done; }); return { promise, resolve }; };
      beforeEach(() => localStorage.clear());
      afterEach(() => vi.restoreAllMocks());
      const input = { scope: 'session-a', text: 'keep these words', attachmentCount: 0 };
      it('persists before clearing the editor or contacting Hermes; acknowledgement prunes only its own record', async () => {
        const reply = deferred<boolean>();
        const send = vi.fn(() => { expect(listSubmissions()[0].state).toBe('sending'); return reply.promise; });
        const pending = runSubmission(input, send);
        const newer = beginSubmission({ ...input, text: 'a newer draft' });
        reply.resolve(true); expect(await pending).toBe(true);
        expect(listSubmissions()).toEqual([newer]);
      });
      it.each(['rejection', 'throw', 'false'])('retains text on %s without another attempt', async failure => {
        const send = vi.fn(() => { if (failure === 'throw') throw Error('closed'); return failure === 'false' ? false : Promise.reject(Error('timeout')); });
        expect(await runSubmission(input, send)).toBe(false);
        expect(send).toHaveBeenCalledTimes(1);
        expect(listSubmissions()[0]).toMatchObject({ text: input.text, state: 'unconfirmed', scope: 'session-a' });
      });
      it('does not clear or send if durable storage fails', async () => {
        vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => { throw Error('quota'); });
        const send = vi.fn(), clear = vi.fn();
        await expect(runSubmission(input, send, clear)).rejects.toThrow('quota');
        expect(send).not.toHaveBeenCalled(); expect(clear).not.toHaveBeenCalled();
      });
      it('restored in-flight records are unconfirmed, never replayed', () => {
        const item = beginSubmission(input); transitionSubmission(item, 'sending');
        expect(listSubmissions()[0].state).toBe('unconfirmed');
      });
      it('never retries a queue entry after a crash between journaling and dequeueing', async () => {
        beginSubmission({ ...input, queueId: 'queued-1' });
        const send = vi.fn();
        expect(await runSubmission({ ...input, queueId: 'queued-1' }, send)).toBe(false);
        expect(send).not.toHaveBeenCalled();
      });
      it('does not change an acknowledged entry back into a pending command', () => {
        const item = beginSubmission(input); transitionSubmission(item, 'sending'); transitionSubmission(item, 'acknowledged');
        expect(() => transitionSubmission(item, 'sending')).toThrow('Invalid submission transition');
      });
      it('retains acknowledgement if pruning fails', async () => {
        vi.spyOn(Storage.prototype, 'removeItem').mockImplementation(() => { throw Error('storage unavailable'); });
        expect(await runSubmission(input, () => true)).toBe(true);
        expect(listSubmissions()[0].state).toBe('acknowledged');
      });
      class Socket extends EventTarget {
        readyState = 0; sent: { id: string; method: string }[] = [];
        send(data: string) { this.sent.push(JSON.parse(data)); }
        open() { this.readyState = 1; this.dispatchEvent(new Event('open')); }
        close() { this.readyState = 3; this.dispatchEvent(new CloseEvent('close')); }
        frame(value: unknown) { this.dispatchEvent(new MessageEvent('message', { data: JSON.stringify(value) })); }
        event(seq: number, session_id = 'a') { this.frame({ method: 'event', params: { type: 'message.delta', session_id, seq, payload: { delta: String(seq) } } }); }
      }
      function gateway() {
        const sockets: Socket[] = [];
        const client = new JsonRpcGatewayClient({ socketFactory: () => { const socket = new Socket(); sockets.push(socket); return socket as unknown as WebSocket; }, heartbeatIntervalMs: 0 });
        const open = () => { const pending = client.connect('ws://test'); sockets.at(-1)!.open(); return pending; };
        return { client, sockets, open };
      }
      it('a retired replay cannot deliver old deltas or flush the replacement replay buffer', async () => {
        const { client, sockets, open } = gateway(); const events: unknown[] = [];
        client.onEvent(event => events.push(event));
        await open(); sockets[0].event(1); client.close(); await open();
        const old = sockets[1]; const request = old.sent[0];
        // Resolve old RPC, then retire its owner before the replay continuation runs.
        old.frame({ id: request.id, result: { events: [{ type: 'message.delta', session_id: 'a', seq: 2 }] } });
        client.close(); const connecting = open(); const fresh = sockets[2]; fresh.event(4);
        await connecting; await Promise.resolve(); await Promise.resolve();
        expect(events).toHaveLength(1);
        expect(fresh.sent[0].method).toBe('session.events.since');
        old.event(99);
        fresh.frame({ id: fresh.sent[0].id, result: { events: [{ type: 'message.delta', session_id: 'a', seq: 3 }] } });
        await new Promise(resolve => setTimeout(resolve, 0));
        expect(events.map(event => (event as { seq: number }).seq)).toEqual([1, 3, 4]);
        client.close();
      });
      it('deduplicates live deltas independently per session', async () => {
        const { client, sockets, open } = gateway(); const events: unknown[] = []; client.onEvent(event => events.push(event));
        await open(); sockets[0].event(2, 'a'); sockets[0].event(2, 'a'); sockets[0].event(1, 'a'); sockets[0].event(2, 'b');
        expect(events).toHaveLength(2); client.close();
      });
      it('disconnect rejects a command once and reconnect sends no command replay', async () => {
        const { client, sockets, open } = gateway(); await open();
        const result = expect(client.request('prompt.submit', { text: 'one command' })).rejects.toThrow();
        client.close(); await result; await open();
        expect(sockets[0].sent.filter(item => item.method === 'prompt.submit')).toHaveLength(1);
        expect(sockets[1].sent).toHaveLength(0); client.close();
      });
      it('a new backend epoch retires pending replay work', async () => {
        const { client, sockets, open } = gateway(); const events: string[] = []; client.onEvent(event => { if (event.type === 'message.delta') events.push(String((event as { seq?: number }).seq)); });
        await open(); sockets[0].frame({ method: 'event', params: { type: 'gateway.ready', payload: { replay_epoch: 'old' } } }); sockets[0].event(40);
        client.close(); await open(); const socket = sockets[1];
        socket.frame({ method: 'event', params: { type: 'gateway.ready', payload: { replay_epoch: 'new' } } }); socket.event(1);
        socket.frame({ id: socket.sent[0].id, result: { epoch: 'old', events: [{ type: 'message.delta', session_id: 'a', seq: 41 }] } });
        await new Promise(resolve => setTimeout(resolve, 0));
        expect(events).toEqual(['40', '1']); expect(client.getSeqWatermarks()).toEqual({ a: 1 }); client.close();
      });
    ''
  } "$out/submission-lifecycle.test.ts"
  cp ${
    writeText "submission-recovery.tsx" /* typescript */ ''
      import { useEffect, useState } from 'react';
      import { discardSubmission, listSubmissions, subscribeSubmissions, type Submission } from '@/lib/submission-journal';

      export function SubmissionRecovery() {
        const [items, setItems] = useState<Submission[]>([]);
        const [error, setError] = useState(''');
        useEffect(() => {
          const refresh = () => { try { setItems(listSubmissions().filter(item => item.state !== 'acknowledged')); } catch { setError('Local recovery storage is unavailable.'); } };
          const off = subscribeSubmissions(refresh); refresh(); return off;
        }, []);
        if (!items.length && !error) return null;
        return <details className="relative z-4 pointer-events-auto mx-3 my-2 rounded-lg border border-current/20 bg-(--dt-input) p-3 text-sm" data-submission-recovery onPointerDown={event => event.stopPropagation()}>
          <summary className="cursor-pointer" aria-live="polite">{items.length} locally saved submission{items.length === 1 ? ''' : 's'}{error && ' — storage unavailable'}</summary>
          <div className="max-h-60 overflow-auto">
            {error && <p role="alert">{error}</p>}
            {items.map(item => <div key={item.id} className="mt-3 space-y-2">
              <p role="status">{item.state === 'sending' ? 'Saved locally; awaiting acknowledgement.' : item.state === 'saved' ? 'Saved locally; not sent.' : 'Delivery unconfirmed. Check the conversation before sending again.'}</p>
              <p className="break-all text-xs opacity-70">{item.scope ?? 'New conversation'} · {new Date(item.createdAt).toLocaleString()}</p>
              <textarea aria-label="Saved submission text" readOnly value={item.text} className="w-full rounded border border-current/20 bg-transparent p-2" />
              {item.attachmentCount > 0 && <p>Attachments are not saved here. Reattach them if you resend.</p>}
              <div className="flex gap-3">
                <button type="button" className="min-h-11 px-2 underline" onClick={() => { void navigator.clipboard.writeText(item.text).catch(() => setError('Copy failed. Select the saved text to copy it.')); }}>Copy text</button>
                {item.state !== 'sending' && <button type="button" className="min-h-11 px-2 underline" onClick={() => { if (window.confirm('Discard this local recovery copy?')) { try { discardSubmission(item.id); } catch { setError('Could not remove the recovery copy.'); } } }}>Discard copy</button>}
              </div>
            </div>)}
          </div>
        </details>;
      }
    ''
  } "$out/submission-recovery.tsx"
''
