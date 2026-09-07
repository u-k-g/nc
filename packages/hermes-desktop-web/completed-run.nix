{ runCommand, writeText }:
runCommand "hermes-completed-run" { } /* bash */ ''
  mkdir -p "$out"
  cp ${
    writeText "completed-run.test.ts" /* typescript */ ''
      import { createElement as h } from "react";
      import {
        AssistantRuntimeProvider,
        MessagePrimitive,
        useExternalStoreRuntime,
        type ThreadMessage,
      } from "@assistant-ui/react";
      import { cleanup, fireEvent, render, screen } from "@testing-library/react";
      import { afterEach, expect, it, vi } from "vitest";
      vi.mock("@/components/assistant-ui/thread/message-parts", () => ({
        MESSAGE_PARTS_COMPONENTS: {
          Text: ({ text }: { text: string }) => h("p", null, text),
          Reasoning: ({ text }: { text: string }) => h("p", null, text),
        },
      }));
      import {
        CompletedMessageParts,
        CompletedRunMessages,
        completedRun,
        finalPartIndices,
      } from "@/components/assistant-ui/thread/completed-run";
      import { toChatMessages } from '@/lib/chat-messages/hydration';
      import { toRuntimeMessage } from '@/lib/chat-runtime';
      afterEach(cleanup);
      const text = (text: string) => ({ type: "text" as const, text });
      function message(
        id: string,
        role: string,
        content: unknown[],
        custom = {},
      ): ThreadMessage {
        return {
          id,
          role,
          content,
          attachments: [],
          createdAt: new Date(),
          status: { type: "complete", reason: "stop" },
          metadata: { custom },
        } as unknown as ThreadMessage;
      }
      const user = message("u", "user", [text("Question")], {
        timelineTimestamp: 100,
      });
      const interim = message("i", "assistant", [text("Earlier commentary")], {
        interim: true,
      });
      const final = message(
        "f",
        "assistant",
        [
          { type: "reasoning", text: "Work details" },
          text("Final answer"),
          { type: "image", image: "https://example.com/result.png" },
        ],
        { durationS: 133 },
      );
      const messages = [user, interim, final];
      it("folds the entire settled group and separates mixed final message parts", () => {
        expect(completedRun(messages, [0, 1, 2], false)).toEqual({
          earlier: [1],
          finalIndex: 2,
          output: [1, 2],
          work: [0],
          label: "Worked for 2m 13s",
        });
        expect(
          finalPartIndices([
            text("Commentary"),
            { type: "tool-call" } as never,
            text("Answer"),
            { type: "tool-call" } as never,
          ]),
        ).toEqual([2]);
        expect(
          finalPartIndices([
            { type: "reasoning", text: "Work" },
            { type: "image", image: "https://example.com/result.png" },
          ]),
        ).toEqual([1]);
      });
      it("never folds between tool calls, during streaming, or on failure", () => {
        expect(completedRun(messages, [0, 1, 2], true)).toBeNull();
        expect(completedRun([user, interim], [0, 1], false)).toBeNull();
        for (const status of [
          { type: "running" },
          { type: "incomplete", reason: "error" },
          { type: "incomplete", reason: "cancelled" },
        ]) {
          expect(
            completedRun(
              [user, interim, { ...final, status } as ThreadMessage],
              [0, 1, 2],
              false,
            ),
          ).toBeNull();
        }
      });
      it("keeps earlier runs folded when a new run starts and avoids empty disclosures", () => {
        expect(
          completedRun(
            [...messages, message("u2", "user", [text("Next")])],
            [0, 1, 2],
            true,
          ),
        ).not.toBeNull();
        expect(
          completedRun(
            [user, message("a", "assistant", [text("Simple answer")])],
            [0, 1],
            false,
          ),
        ).toBeNull();
      });
      it("uses recorded timestamps after reload and never invents missing timing", () => {
        const history = (custom: Record<string, unknown>) =>
          completedRun(
            [user, interim, message("f", "assistant", [...final.content], custom)],
            [0, 1, 2],
            false,
          )?.label;
        expect(history({ timelineCompletedAt: 225 })).toBe("Worked for 2m 5s");
        expect(history({})).toBe("Worked");
        expect(history({ durationS: NaN })).toBe("Worked");
      });
      it('recovers elapsed time through the real history hydration and runtime conversion', () => {
        const restored = toChatMessages([
          { role: 'user', content: 'Question', timestamp: 100 },
          { role: 'assistant', content: 'Checking', timestamp: 105,
            tool_calls: [{ id: 't', type: 'function', function: { name: 'terminal', arguments: '{}' } }] },
          { role: 'tool', content: 'Done', tool_call_id: 't', timestamp: 180 },
          { role: 'assistant', content: 'Final answer', timestamp: 233 }
        ]).map(toRuntimeMessage);
        // Hydration merges the tool exchange and final answer into one message,
        // whose message-level timestamp is the start, not the completion.
        expect(restored).toHaveLength(2);
        expect(restored[1].metadata.custom.durationS).toBeUndefined();
        expect(restored[1].metadata.custom.timelineCompletedAt).toBeUndefined();
        expect(completedRun(restored, [0, 1], false)?.label).toBe('Worked for 2m 13s');
      });
      it('uses the latest saved part timestamp and ignores invalid live duration metadata', () => {
        const restored = message('f', 'assistant', [
          { type: 'reasoning', text: 'Work', timestamp: 105 },
          { type: 'text', text: 'Answer', timestamp: 225 }
        ], { timelineTimestamp: 105, durationS: NaN });
        expect(completedRun([user, restored], [0, 1], false)?.label).toBe('Worked for 2m 5s');
        const invalid = message('f', 'assistant', [...restored.content], { durationS: -1 });
        expect(completedRun([user, invalid], [0, 1], false)?.label).toBe('Worked for 2m 5s');
      });
      function Assistant() {
        return h(MessagePrimitive.Root, null, h(CompletedMessageParts));
      }
      const components = { AssistantMessage: Assistant, UserMessage: Assistant };
      function Harness({ running }: { running: boolean }) {
        const runtime = useExternalStoreRuntime({
          messages,
          isRunning: running,
          onNew: async () => {},
        });
        return h(
          AssistantRuntimeProvider,
          { runtime },
          h(CompletedRunMessages, { indices: [0, 1, 2], components }),
        );
      }
      it("keeps live work and message identity when a run completes", () => {
        const view = render(h(Harness, { running: true }));
        const commentary = screen.getByText("Earlier commentary");
        const answer = screen.getByText("Final answer");
        view.rerender(h(Harness, { running: false }));
        expect(screen.getByText("Earlier commentary")).toBe(commentary);
        expect(screen.getByText("Final answer")).toBe(answer);
        expect(screen.queryByRole("button", { name: "Worked for 2m 13s" })).toBeNull();
      });
      it("folds history, reverses disclosure state, and retains expanded work on close", async () => {
        render(h(Harness, { running: false }));
        const button = await screen.findByRole("button", {
          name: "Worked for 2m 13s",
        });
        expect(button.getAttribute("aria-expanded")).toBe("false");
        expect(screen.queryByText("Earlier commentary")).toBeNull();
        expect(screen.queryByText("Work details")).toBeNull();
        expect(screen.getAllByText("Final answer")).toHaveLength(1);
        expect(screen.getByRole("img").getAttribute("src")).toBe(
          "https://example.com/result.png",
        );
        fireEvent.click(button);
        expect(button.getAttribute("aria-expanded")).toBe("true");
        expect(screen.getByText("Earlier commentary")).toBeTruthy();
        expect(screen.getByText("Work details")).toBeTruthy();
        expect(screen.getAllByText("Final answer")).toHaveLength(1);
        const work = screen.getByText("Earlier commentary");
        fireEvent.click(button);
        const region = document.getElementById(button.getAttribute("aria-controls")!);
        expect(region?.getAttribute("aria-hidden")).toBe("true");
        expect(region?.hasAttribute("inert")).toBe(true);
        fireEvent.click(button);
        expect(region?.getAttribute("aria-hidden")).toBe("false");
        expect(screen.getByText("Earlier commentary")).toBe(work);
        expect(screen.getByText("Final answer")).toBeTruthy();
      });
    ''
  } "$out/completed-run.test.ts"
  cp ${
    writeText "completed-run.tsx" /* typescript */ ''
      import {
        MessagePrimitive,
        MessagePartPrimitive,
        ThreadPrimitive,
        type ThreadMessage,
        useAuiState,
      } from "@assistant-ui/react";
      import {
        createContext,
        useContext,
        useId,
        useRef,
        useState,
        type ComponentProps,
        type ReactNode,
      } from "react";
      import { MESSAGE_PARTS_COMPONENTS } from "./message-parts";
      import { ChevronRightIcon } from "@/lib/icons";
      import { InteractionDisclosure } from "@/lib/interaction-motion";

      // Presentation only: the runtime transcript stays intact for copy, retry and history.
      const FinalParts = createContext<readonly number[] | null>(null);
      type Components = ComponentProps<
        typeof ThreadPrimitive.MessageByIndex
      >["components"];
      const isWork = (part: { type: string }) =>
        part.type === "tool-call" || part.type === "reasoning";
      // PartByIndex does not inherit the web defaults that Parts supplies.
      const SELECTED_PARTS_COMPONENTS = {
        ...MESSAGE_PARTS_COMPONENTS,
        Image: () => <MessagePartPrimitive.Image />,
      };

      export function finalPartIndices(content: ThreadMessage["content"]): number[] {
        let lastOutput = -1;
        content.forEach((part, index) => {
          if (part.type === "text" && part.text.trim()) lastOutput = index;
        });
        if (lastOutput < 0)
          content.forEach((part, index) => {
            if (part.type === "image" || part.type === "file") lastOutput = index;
          });
        if (lastOutput < 0) return [];
        let start = lastOutput;
        while (start > 0 && !isWork(content[start - 1])) start--;
        return content.flatMap((part, index) =>
          index >= start && !isWork(part) ? [index] : [],
        );
      }

      export function completedRun(
        messages: readonly ThreadMessage[],
        indices: readonly number[],
        running: boolean,
      ) {
        const lastIndex = indices.at(-1);
        if (lastIndex === undefined || (running && lastIndex === messages.length - 1))
          return null;
        const final = messages[lastIndex];
        if (
          !final ||
          final.role !== "assistant" ||
          final.status.type !== "complete" ||
          final.metadata.custom?.interim
        )
          return null;
        if (
          indices.some((index) => {
            const message = messages[index];
            return (
              message?.role === "assistant" && message.status.type !== "complete"
            );
          })
        )
          return null;
        const output = finalPartIndices(final.content);
        if (!output.length) return null;
        const work = final.content.flatMap((_, index) =>
          output.includes(index) ? [] : [index],
        );
        const earlier = indices.slice(1, -1);
        if (!earlier.length && !work.length) return null;
        const custom = final.metadata.custom;
        const validTimestamp = (value: unknown): value is number =>
          typeof value === 'number' && Number.isFinite(value) && value > 0;
        // History drops durationS/completedAt and coalesces tool exchanges into
        // a message with the EARLIEST timestamp. Its parts retain the later
        // timestamps, including the final answer. Never use createdAt here:
        // the runtime synthesizes it from Date.now() when a timestamp is absent.
        const timestamps = (message: ThreadMessage) => [
          message.metadata.custom?.timelineTimestamp,
          message.metadata.custom?.timelineCompletedAt,
          ...message.content.flatMap(part => {
            const timed = part as { timestamp?: unknown; completedAt?: unknown };
            return [timed.timestamp, timed.completedAt];
          })
        ].filter(validTimestamp);
        const workTimes = indices.slice(1).flatMap(index => timestamps(messages[index]));
        const userTimes = timestamps(messages[indices[0]]);
        const start = userTimes.length ? Math.min(...userTimes)
          : workTimes.length ? Math.min(...workTimes) : undefined;
        const end = workTimes.length ? Math.max(...workTimes) : undefined;
        const measured = custom?.durationS;
        const duration = typeof measured === 'number' && Number.isFinite(measured) && measured >= 0
          ? measured
          : start !== undefined && end !== undefined && end >= start ? end - start : undefined;
        const seconds =
          duration !== undefined && Number.isFinite(duration) && duration >= 0
            ? Math.round(duration)
            : null;
        const label =
          seconds === null
            ? "Worked"
            : `Worked for ''${Math.floor(seconds / 60)}m ''${seconds % 60}s`;
        return { earlier, finalIndex: lastIndex, output, work, label };
      }

      function SelectedParts({ indices }: { indices: readonly number[] }) {
        // Keep Hermes's tool/reasoning groups and their drill-down UI.
        const types = useAuiState((s) =>
          s.message.content.map((part) => part.type).join(","),
        ).split(",");
        const groups: number[][] = [];
        for (const index of indices) {
          const previous = groups.at(-1);
          if (
            previous &&
            previous.at(-1)! + 1 === index &&
            types[previous[0]] === types[index] &&
            (types[index] === "tool-call" || types[index] === "reasoning")
          )
            previous.push(index);
          else groups.push([index]);
        }
        return groups.map((group) => {
          const children = group.map((index) => (
            <MessagePrimitive.PartByIndex
              components={SELECTED_PARTS_COMPONENTS}
              index={index}
              key={index}
            />
          ));
          const Group =
            types[group[0]] === "tool-call"
              ? MESSAGE_PARTS_COMPONENTS.ToolGroup
              : types[group[0]] === "reasoning"
                ? MESSAGE_PARTS_COMPONENTS.ReasoningGroup
                : null;
          return Group ? (
            <Group key={group[0]} startIndex={group[0]} endIndex={group.at(-1)!}>
              {children}
            </Group>
          ) : (
            children
          );
        });
      }

      export function CompletedMessageParts() {
        const indices = useContext(FinalParts);
        return indices ? (
          <SelectedParts indices={indices} />
        ) : (
          <MessagePrimitive.Parts components={MESSAGE_PARTS_COMPONENTS} />
        );
      }

      function WorkMessage() {
        return (
          <MessagePrimitive.Root data-slot="aui_run-work-parts">
            <CompletedMessageParts />
          </MessagePrimitive.Root>
        );
      }
      const WORK_COMPONENTS = { Message: WorkMessage };

      export function RunDisclosure({
        label,
        work,
        children,
        onExpand,
      }: {
        label: string;
        work: ReactNode;
        children: ReactNode;
        onExpand?: () => void;
      }) {
        const [open, setOpen] = useState(false);
        const id = useId();
        return (
          <>
            <div data-slot="aui_completed-run" className="border-b border-border/65 pb-3">
              <button
                type="button"
                aria-expanded={open}
                aria-controls={id}
                className="flex min-h-11 items-center gap-2 text-sm text-muted-foreground hover:text-foreground"
                onClick={() => {
                  onExpand?.();
                  setOpen((value) => !value);
                }}
              >
                {label}
                <ChevronRightIcon aria-hidden="true" className={open ? "size-4 rotate-90" : "size-4"} />
              </button>
              <InteractionDisclosure id={id} open={open}>
                {work}
              </InteractionDisclosure>
            </div>
            {children}
          </>
        );
      }

      export function CompletedRunMessages({
        indices,
        components,
        onExpand,
      }: {
        indices: number[];
        components: Components;
        onExpand?: () => void;
      }) {
        // A primitive signature avoids rerendering this subtree on each streamed token.
        const signature = useAuiState((s) =>
          JSON.stringify(
            completedRun(s.thread.messages, indices, s.thread.isRunning),
          ),
        );
        const run =
          signature === "null"
            ? null
            : (JSON.parse(signature) as NonNullable<ReturnType<typeof completedRun>>);
        // Completing a live run must not replace work someone is reading.
        // Only history mounted already complete folds; live message instances
        // keep their keys, focus, expanded details and reading position.
        const witnessedLive = useRef(false);
        if (!run) witnessedLive.current = true;
        if (!run || witnessedLive.current)
          return indices.map((index) => (
            <ThreadPrimitive.MessageByIndex
              components={components}
              index={index}
              key={index}
            />
          ));
        return (
          <>
            <ThreadPrimitive.MessageByIndex
              components={components}
              index={indices[0]}
            />
            <RunDisclosure
              key={run.finalIndex}
              label={run.label}
              onExpand={onExpand}
              work={
                <>
                  {run.earlier.map((index) => (
                    <ThreadPrimitive.MessageByIndex
                      components={components}
                      index={index}
                      key={index}
                    />
                  ))}
                  {run.work.length > 0 && (
                    <FinalParts.Provider value={run.work}>
                      <ThreadPrimitive.MessageByIndex
                        components={WORK_COMPONENTS}
                        index={run.finalIndex}
                      />
                    </FinalParts.Provider>
                  )}
                </>
              }
            >
              <FinalParts.Provider value={run.output}>
                <ThreadPrimitive.MessageByIndex
                  components={components}
                  index={run.finalIndex}
                />
              </FinalParts.Provider>
            </RunDisclosure>
          </>
        );
      }
    ''
  } "$out/completed-run.tsx"
  cp ${
    writeText "patch-completed-run.mjs" /* javascript */ ''
      import fs from "node:fs";
      // T3 reference: apps/web/src/components/chat/MessagesTimeline.logic.ts,
      // deriveTurnFolds. Fold only settled work and leave the terminal answer outside.
      const base = "vendor/hermes-desktop/src/components/assistant-ui/thread/";
      function patch(file, before, after) {
        const source = fs.readFileSync(base + file, "utf8");
        if (source.split(before).length !== 2)
          throw Error(`Review completed-run patch: ''${file}: ''${before}`);
        fs.writeFileSync(base + file, source.replace(before, after));
      }
      patch(
        "list.tsx",
        "import { resolveShowEarlierAction",
        "import { CompletedRunMessages } from './completed-run'\n\nimport { resolveShowEarlierAction",
      );
      patch(
        "list.tsx",
        "  virtualized: boolean\n}",
        "  virtualized: boolean\n  onExpand: () => void\n}",
      );
      patch(
        "list.tsx",
        "group, resetKey, virtualized }: TurnRowProps)",
        "group, resetKey, virtualized, onExpand }: TurnRowProps)",
      );
      patch(
        "list.tsx",
        `{group.indices.map(index => (
                    <ThreadPrimitive.MessageByIndex components={components} index={index} key={index} />
                  ))}`,
        "<CompletedRunMessages indices={group.indices} components={components} onExpand={onExpand} />",
      );
      patch(
        "list.tsx",
        "          resetKey={structuralSignature}",
        "          onExpand={stopScroll}\n          resetKey={structuralSignature}",
      );
      patch(
        "list.tsx",
        "[visibleGroups, components, structuralSignature, tailStart]",
        "[visibleGroups, components, structuralSignature, tailStart, stopScroll]",
      );
      patch(
        "assistant-message.tsx",
        "import { MESSAGE_PARTS_COMPONENTS } from '@/components/assistant-ui/thread/message-parts'",
        "import { CompletedMessageParts } from './completed-run'",
      );
      patch(
        "assistant-message.tsx",
        "const MESSAGE_PARTS = <MessagePrimitive.Parts components={MESSAGE_PARTS_COMPONENTS} />",
        "const MESSAGE_PARTS = <CompletedMessageParts />",
      );
    ''
  } "$out/patch-completed-run.mjs"
''
