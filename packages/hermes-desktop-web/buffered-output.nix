{ runCommand, writeText }:
runCommand "hermes-buffered-output" { } /* bash */ ''
  mkdir -p "$out"
  cp ${
    writeText "buffered-output.test.ts" /* typescript */ ''
      import { createElement as h } from "react";
      import { atom } from "nanostores";
      import {
        act,
        cleanup,
        fireEvent,
        render,
        renderHook,
        screen,
      } from "@testing-library/react";
      import { afterEach, expect, it, vi } from "vitest";
      import type { ChatMessage } from "@/lib/chat-messages";
      vi.mock("@/app/settings/primitives", () => ({
        ToggleRow: ({
          checked,
          label,
          onChange,
        }: {
          checked: boolean;
          label: string;
          onChange: (value: boolean) => void;
        }) =>
          h("input", {
            type: "checkbox",
            checked,
            "aria-label": label,
            onChange: (event: { target: { checked: boolean } }) =>
              onChange(event.target.checked),
          }),
      }));
      let visible = true;
      vi.mock("@/components/pane-shell/pane-visibility", () => ({
        usePaneVisible: () => visible,
      }));
      import {
        $bufferedOutput,
        BufferedOutputSetting,
        createTranscriptBuffer,
        useBufferedMessages,
      } from "@/lib/buffered-output";
      afterEach(() => {
        cleanup();
        visible = true;
        $bufferedOutput.set(true);
      });
      const user: ChatMessage = {
        id: "u",
        role: "user",
        parts: [{ type: "text", text: "Question" }],
      };
      const delta = (text: string): ChatMessage => ({
        id: "a",
        role: "assistant",
        pending: true,
        parts: [{ type: "text", text }],
      });
      const final: ChatMessage = {
        ...delta("Final answer"),
        pending: false,
        completedAt: 123,
      };
      function view() {
        return {
          $messages: atom<ChatMessage[]>([user]),
          $busy: atom(false),
          $runtimeId: atom<string | null>("a"),
          $storedId: atom<string | null>("a"),
        };
      }
      it("defaults on and persists the setting when switched off", () => {
        expect($bufferedOutput.get()).toBe(true);
        render(h(BufferedOutputSetting));
        fireEvent.click(screen.getByRole("checkbox"));
        expect($bufferedOutput.get()).toBe(false);
        expect(localStorage.getItem("hermes.desktop.bufferedOutput")).toBe("false");
      });
      it("buffers token deltas but publishes completed commentary before the run ends", () => {
        const select = createTranscriptBuffer();
        const initial = [user];
        select(initial, false, true, "a");
        for (let i = 0; i < 100; i++)
          expect(select([user, delta(String(i))], true, true, "a")).toBe(initial);
        expect(
          select(
            [user, { ...delta("Commentary"), pending: false, interim: true }],
            true,
            true,
            "a",
          ),
        ).toEqual([user, { ...delta("Commentary"), pending: false, interim: true }]);
        const complete = [user, final];
        expect(select(complete, false, true, "a")).toBe(complete);
      });
      it("keeps user steering and system notices live and reveals errors immediately", () => {
        const select = createTranscriptBuffer();
        select([user], false, true, "a");
        const steer = { ...user, id: "steer" };
        const system: ChatMessage = { id: "notice", role: "system", parts: [] };
        expect(
          select([user, delta("partial"), steer, system], true, true, "a"),
        ).toEqual([user, steer, system]);
        const error = { ...delta("partial"), error: "Disconnected" };
        expect(select([user, error], true, true, "a")).toEqual([user, error]);
        expect(select([user, delta("partial")], false, true, "a")).toHaveLength(2);
      });
      it("opening a running session hides partial output while preserving history; switching sessions clears the buffer", () => {
        const select = createTranscriptBuffer();
        const earlier = { ...final, id: "old" };
        expect(select([earlier, user, delta("private A")], true, true, "a")).toEqual([
          earlier,
          user,
        ]);
        const other = { ...user, id: "other" };
        expect(select([other, delta("private B")], true, true, "b")).toEqual([other]);
      });
      it("preserves the complete work of previous runs while the next run is buffered", () => {
        const select = createTranscriptBuffer();
        const commentary = {
          ...delta("Previous work"),
          id: "old-commentary",
          pending: false,
          interim: true,
        };
        const oldFinal = { ...final, id: "old-final" };
        const history = [user, commentary, oldFinal];
        select(history, false, true, "a");
        const nextUser = { ...user, id: "next-user" };
        expect(
          select([...history, nextUser, delta("New work")], true, true, "a"),
        ).toEqual([...history, nextUser]);
      });
      it("toggling off reveals live output and toggling back on resumes buffering", () => {
        const select = createTranscriptBuffer();
        const live = [user, delta("partial")];
        expect(select(live, true, false, "a")).toBe(live);
        expect(select(live, true, true, "a")).toEqual([user]);
        expect(select([user, final], false, true, "a")).toEqual([user, final]);
      });
      it("prevents React renders during deltas and publishes each completed message while still busy", () => {
        const state = view();
        let renders = 0;
        const hook = renderHook(() => {
          renders++;
          return useBufferedMessages(state);
        });
        act(() => state.$busy.set(true));
        const before = renders;
        for (let i = 0; i < 20; i++)
          act(() => state.$messages.set([user, delta(String(i))]));
        expect(renders).toBe(before);
        act(() => state.$messages.set([user, final]));
        expect(renders).toBeGreaterThan(before);
        expect(hook.result.current).toEqual([user, final]);
        act(() => state.$busy.set(false));
        expect(hook.result.current).toEqual([user, final]);
      });
      it("flushes partial text when the run stops without a message completion", () => {
        const state = view();
        const hook = renderHook(() => useBufferedMessages(state));
        act(() => {
          state.$busy.set(true);
          state.$messages.set([user, delta("Partial response")]);
        });
        expect(hook.result.current).toEqual([user]);
        act(() => state.$busy.set(false));
        expect(hook.result.current).toEqual([user, delta("Partial response")]);
      });
      it("shows tools and completed text parts while buffering unfinished text and reasoning", () => {
        const select = createTranscriptBuffer();
        const tool: ChatMessage["parts"][number] = {
          type: "tool-call",
          toolCallId: "t",
          toolName: "terminal",
          args: {},
          argsText: "{}",
        };
        const completed: ChatMessage["parts"][number] = {
          type: "text",
          text: "Completed commentary",
          completedAt: 100,
        };
        const running: ChatMessage = {
          ...delta(""),
          parts: [
            completed,
            tool,
            { type: "reasoning", text: "thinking" },
            { type: "text", text: "unfinished" },
          ],
        };
        const first = select([user, running], true, true, "a");
        expect(first[1].parts).toEqual([completed, tool]);
        expect(
          select(
            [
              user,
              {
                ...running,
                parts: [
                  completed,
                  tool,
                  { type: "reasoning", text: "more thinking" },
                  { type: "text", text: "unfinished text" },
                ],
              },
            ],
            true,
            true,
            "a",
          ),
        ).toBe(first);
        const finishedTool = { ...tool, result: "done" };
        expect(
          select(
            [user, { ...running, parts: [completed, finishedTool] }],
            true,
            true,
            "a",
          )[1].parts,
        ).toEqual([completed, finishedTool]);
      });
      it("matches the T3 24,000-character spill limit without streaming subsequent tokens", () => {
        const select = createTranscriptBuffer();
        const initial = [user];
        select(initial, false, true, "a");
        expect(select([user, delta("x".repeat(24_000))], true, true, "a")).toBe(
          initial,
        );
        const spilled = select([user, delta("x".repeat(24_001))], true, true, "a");
        expect(spilled[1].parts).toEqual([
          { type: "text", text: "x".repeat(24_001) },
        ]);
        expect(select([user, delta("x".repeat(24_002))], true, true, "a")).toBe(
          spilled,
        );
        expect(select([user, delta("replacement")], true, true, "a")).toEqual([user]);
      });
      it("hidden panes catch up on reveal and an in-run setting change flushes immediately", () => {
        const state = view();
        const hook = renderHook(() => useBufferedMessages(state));
        visible = false;
        hook.rerender();
        act(() => {
          state.$busy.set(true);
          state.$messages.set([user, delta("partial")]);
        });
        expect(hook.result.current).toEqual([user]);
        visible = true;
        hook.rerender();
        expect(hook.result.current).toEqual([user]);
        act(() => $bufferedOutput.set(false));
        expect(hook.result.current).toEqual([user, delta("partial")]);
      });
    ''
  } "$out/buffered-output.test.ts"
  cp ${
    writeText "buffered-output.tsx" /* typescript */ ''
      import { useStore } from "@nanostores/react";
      import { atom } from "nanostores";
      import { useMemo, useSyncExternalStore } from "react";
      import type { SessionView } from "@/app/chat/session-view";
      import { ToggleRow } from "@/app/settings/primitives";
      import { usePaneVisible } from "@/components/pane-shell/pane-visibility";
      import type { ChatMessage } from "@/lib/chat-messages";
      import { persistBoolean, storedBoolean } from "@/lib/storage";

      const STORAGE_KEY = "hermes.desktop.bufferedOutput";
      export const $bufferedOutput = atom(storedBoolean(STORAGE_KEY, true));
      $bufferedOutput.subscribe((value) => persistBoolean(STORAGE_KEY, value));

      export function BufferedOutputSetting() {
        const enabled = useStore($bufferedOutput);
        return (
          <div id="setting-field-appearance.buffered-output">
            <ToggleRow
              checked={enabled}
              label="Buffer streaming text"
              description="Show text when each message finishes instead of token by token. Completed messages, tool activity, and input requests still appear during the run. Turn off for token-by-token output."
              onChange={(value) => $bufferedOutput.set(value)}
            />
          </div>
        );
      }

      // T3's default buffers assistant text until the message ends, with a
      // 24,000-character spill threshold. Hermes also has completion boundaries on
      // text/reasoning parts, so completed parts can appear alongside live tools.
      // This projection runs before React; the authoritative transcript stays intact.
      const MAX_BUFFERED_CHARS = 24_000;
      type PublishedMessage = {
        parts: Map<number, ChatMessage["parts"][number]>;
        rendered: ChatMessage | null;
      };
      export function createTranscriptBuffer() {
        let owner: string | undefined;
        const published = new Map<string, PublishedMessage>();
        let output: ChatMessage[] = [];
        return (
          messages: ChatMessage[],
          busy: boolean,
          enabled: boolean,
          scope: string,
        ): ChatMessage[] => {
          if (owner !== scope) {
            owner = scope;
            published.clear();
            output = [];
          }
          if (!busy || !enabled) {
            published.clear();
            output = messages;
            return output;
          }
          const ids = new Set(messages.map((message) => message.id));
          for (const id of published.keys()) if (!ids.has(id)) published.delete(id);
          const next: ChatMessage[] = [];
          for (const message of messages) {
            if (message.role !== "assistant" || !message.pending || message.error) {
              published.delete(message.id);
              next.push(message);
              continue;
            }
            const cache = published.get(message.id) ?? {
              parts: new Map(),
              rendered: null,
            };
            published.set(message.id, cache);
            const parts: ChatMessage["parts"] = [];
            message.parts.forEach((part, index) => {
              if (
                (part.type !== "text" && part.type !== "reasoning") ||
                part.completedAt !== undefined
              ) {
                cache.parts.set(index, part);
                parts.push(part);
                return;
              }
              let previous = cache.parts.get(index);
              // A replacement/rewind at this index must not retain stale text.
              if (
                previous &&
                (previous.type !== part.type ||
                  !("text" in previous) ||
                  !part.text.startsWith(previous.text))
              ) {
                cache.parts.delete(index);
                previous = undefined;
              }
              const shown = previous && "text" in previous ? previous.text.length : 0;
              if (part.text.length - shown > MAX_BUFFERED_CHARS) {
                cache.parts.set(index, part);
                parts.push(part);
              } else if (previous) parts.push(previous);
            });
            for (const index of cache.parts.keys())
              if (index >= message.parts.length) cache.parts.delete(index);
            if (!parts.length) {
              cache.rendered = null;
              continue;
            }
            const previous = cache.rendered;
            const sameParts =
              previous &&
              parts.length === previous.parts.length &&
              parts.every((part, index) => part === previous.parts[index]);
            const sameMetadata =
              previous &&
              Object.keys(message).every(
                (key) =>
                  key === "parts" ||
                  message[key as keyof ChatMessage] ===
                    previous[key as keyof ChatMessage],
              ) &&
              Object.keys(previous).every((key) => key in message);
            const rendered =
              sameParts && sameMetadata ? previous : { ...message, parts };
            cache.rendered = rendered;
            next.push(rendered);
          }
          if (
            next.length !== output.length ||
            next.some((message, index) => message !== output[index])
          )
            output = next;
          return output;
        };
      }

      type TranscriptView = Pick<
        SessionView,
        "$messages" | "$busy" | "$runtimeId" | "$storedId"
      >;
      export function createBufferedMessageSource(view: TranscriptView) {
        const project = createTranscriptBuffer();
        return {
          getSnapshot: () =>
            project(
              view.$messages.get(),
              view.$busy.get(),
              $bufferedOutput.get(),
              JSON.stringify([view.$runtimeId.get(), view.$storedId.get()]),
            ),
          subscribe: (notify: () => void) => {
            const off = [
              view.$messages.listen(notify),
              view.$busy.listen(notify),
              view.$runtimeId.listen(notify),
              view.$storedId.listen(notify),
              $bufferedOutput.listen(notify),
            ];
            return () => off.forEach((unsubscribe) => unsubscribe());
          },
        };
      }
      const noSubscription = () => () => {};
      export function useBufferedMessages(view: TranscriptView): ChatMessage[] {
        const visible = usePaneVisible();
        const source = useMemo(() => createBufferedMessageSource(view), [view]);
        return useSyncExternalStore(
          visible ? source.subscribe : noSubscription,
          source.getSnapshot,
          source.getSnapshot,
        );
      }
    ''
  } "$out/buffered-output.tsx"
  cp ${
    writeText "patch-buffered-output.mjs" /* javascript */ ''
      import fs from "node:fs";
      function patch(file, before, after) {
        const source = fs.readFileSync(file, "utf8");
        if (source.split(before).length !== 2)
          throw Error(`Review buffered-output patch: ''${file}: ''${before}`);
        fs.writeFileSync(file, source.replace(before, after));
      }
      const chat = "vendor/hermes-desktop/src/app/chat/index.tsx";
      patch(chat, "import type { ReadableAtom } from 'nanostores'\n", "");
      patch(
        chat,
        "import { usePaneVisible } from '@/components/pane-shell/pane-visibility'",
        "import { useBufferedMessages } from '@/lib/buffered-output'",
      );
      const source = fs.readFileSync(chat, "utf8");
      const start = source.indexOf(
        "/**\n * The view's $messages, live only while this surface is the VISIBLE tab.",
      );
      const end = source.indexOf("/**\n * Owns the $messages subscription", start);
      if (start < 0 || end < 0)
        throw Error("Review buffered-output subscription boundary");
      fs.writeFileSync(chat, source.slice(0, start) + source.slice(end));
      patch(
        chat,
        "useMessagesWhileVisible(view.$messages)",
        "useBufferedMessages(view)",
      );
      const appearance =
        "vendor/hermes-desktop/src/app/settings/appearance-settings.tsx";
      patch(
        appearance,
        "import { useDebounced }",
        "import { BufferedOutputSetting } from '@/lib/buffered-output'\n\nimport { useDebounced }",
      );
      const anchor = `          <ToggleRow
                  checked={composerPopoutGesturesEnabled}`;
      patch(appearance, anchor, `          <BufferedOutputSetting />\n\n''${anchor}`);
      const search = "vendor/hermes-desktop/src/app/settings/use-settings-search.ts";
      const searchAnchor = `    {
            context: appearanceContext,
            description: appearance.toolViewDesc,`;
      patch(
        search,
        searchAnchor,
        `    {
            context: appearanceContext,
            icon: Palette,
            id: 'setting:appearance.buffered-output',
            label: 'Buffer streaming text',
            description: 'Buffer text until each message completes while showing tool activity live.',
            keywords: ['stream', 'streaming', 'buffer', 'performance', 'response', 'output'],
            target: { setting: 'appearance.buffered-output', view: 'config:appearance' }
          },
      ''${searchAnchor}`,
      );
      patch(
        "vendor/hermes-desktop/src/app/settings/settings-search.ts",
        "export const APPEARANCE_SETTING_IDS = {",
        "export const APPEARANCE_SETTING_IDS = {\n  bufferedOutput: 'appearance.buffered-output',",
      );
    ''
  } "$out/patch-buffered-output.mjs"
''
