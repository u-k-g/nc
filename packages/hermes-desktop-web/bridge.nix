{ runCommand, writeText }:
runCommand "hermes-bridge-reliability" { } /* bash */ ''
  mkdir -p "$out"
  cp ${
    writeText "request-policy.ts" /* typescript */ ''
      // Only concurrent, explicitly safe reads share work; this is not a data cache.
      const reads = new Map<string, Promise<unknown>>();
      export const DEFAULT_READ_TIMEOUT_MS = 30_000;
      export const SHARED_READ_PATHS = new Set(["/api/status", "/api/config", "/api/profiles"]);
      export function invalidateReads() { reads.clear(); }
      export function shareRead<T>(key: string, run: () => Promise<T>): Promise<T> {
        let pending = reads.get(key);
        if (!pending) {
          const current = run().finally(() => {
            // An earlier request may finish after a mutation has started a newer one.
            if (reads.get(key) === current) reads.delete(key);
          });
          reads.set(key, current);
          pending = current;
        }
        // Callers own their result objects, including nested config values.
        return pending.then(value => structuredClone(value) as T);
      }
      export function isMissingEndpoint(body: string): boolean {
        try {
          const detail = JSON.parse(body)?.detail;
          return typeof detail === "string" && (detail === "Not Found" || detail.startsWith("No such API endpoint:"));
        } catch { return false; }
      }
      export function decodeApiBody(text: string, contentType: string | null): unknown {
        if (!text) return undefined;
        try { return JSON.parse(text); }
        catch {
          const mime = contentType?.split(";", 1)[0].trim().toLowerCase();
          if (mime === "application/json" || mime?.endsWith("+json")) {
            throw new Error("Hermes returned invalid JSON. Try refreshing this view.");
          }
          if (mime === "text/html") {
            throw new Error("Hermes returned a web page instead of an API response. Check the connection.");
          }
          // File/log endpoints legitimately return text.
          return text;
        }
      }
      export interface ProxyMeta { defaultGatewayUrl: string | null; allowedTargets: string[] }
      export function parseProxyMeta(value: unknown): ProxyMeta {
        if (!value || typeof value !== "object") throw new Error("Invalid Hermes connection settings");
        const meta = value as Record<string, unknown>;
        if (!Array.isArray(meta.allowedTargets) || !meta.allowedTargets.every(item => typeof item === "string")) {
          throw new Error("Invalid Hermes allowed targets");
        }
        if (meta.defaultGatewayUrl !== null) {
          if (typeof meta.defaultGatewayUrl !== "string") throw new Error("Invalid Hermes gateway URL");
          const url = new URL(meta.defaultGatewayUrl);
          if (!["http:", "https:"].includes(url.protocol) || url.username || url.password) throw new Error("Invalid Hermes gateway URL");
        }
        return { defaultGatewayUrl: meta.defaultGatewayUrl as string | null, allowedTargets: meta.allowedTargets };
      }
    ''
  } "$out/request-policy.ts"
  cp ${
    writeText "rest-policy.test.ts" /* typescript */ ''
      import { afterEach, beforeEach, expect, it, vi } from "vitest";
      import { webApi, proxySessionLogin, fetchProxyMeta } from "./rest";
      import { invalidateReads, parseProxyMeta } from "./request-policy";
      import { loadRegistry, upsertConnection } from "../registry";

      const fetchMock = vi.fn();
      const json = (value: unknown, status = 200) => new Response(JSON.stringify(value), { status, headers: { "Content-Type": "application/json" } });
      function deferred<T>() {
        let resolve!: (value: T) => void;
        const promise = new Promise<T>(done => { resolve = done; });
        return { promise, resolve };
      }
      beforeEach(() => {
        invalidateReads(); window.localStorage.clear(); loadRegistry();
        fetchMock.mockReset(); vi.stubGlobal("fetch", fetchMock);
      });
      afterEach(() => { invalidateReads(); vi.useRealTimers(); vi.unstubAllGlobals(); });
      it("rejects removed connections through the Promise API", async () => {
        const result = webApi({ path: "/api/status", connectionId: "removed" });
        expect(result).toBeInstanceOf(Promise);
        await expect(result).rejects.toThrow();
        await expect(webApi({ path: "/api/config", method: "PATCH", connectionId: "removed" })).rejects.toThrow("No connection with id");
        expect(fetchMock).not.toHaveBeenCalled();
      });
      it("shares only concurrent safe reads and gives each consumer its own object", async () => {
        const response = deferred<Response>(); fetchMock.mockReturnValueOnce(response.promise);
        const first = webApi<{ nested: { value: number } }>({ path: "/api/config" });
        const second = webApi<{ nested: { value: number } }>({ path: "/api/config" });
        expect(fetchMock).toHaveBeenCalledTimes(1);
        response.resolve(json({ nested: { value: 1 } }));
        const [a, b] = await Promise.all([first, second]); a.nested.value = 2;
        expect(b.nested.value).toBe(1);
        fetchMock.mockResolvedValueOnce(json({ nested: { value: 3 } }));
        expect(await webApi({ path: "/api/config" })).toEqual({ nested: { value: 3 } });
        expect(fetchMock).toHaveBeenCalledTimes(2);
      });
      it("does not merge different targets, profiles, credentials or timeout policies", async () => {
        fetchMock.mockImplementation(() => Promise.resolve(json({})));
        upsertConnection({ id: "other", label: "Other", kind: "remote", url: "https://other.example", authMode: "token", token: "first" });
        const requests = [webApi({ path: "/api/config" }), webApi({ path: "/api/config", profile: "writer" }), webApi({ path: "/api/config", timeoutMs: 5 }), webApi({ path: "/api/config", connectionId: "other" })];
        upsertConnection({ id: "other", label: "Other", kind: "remote", url: "https://other.example", authMode: "token", token: "second" });
        requests.push(webApi({ path: "/api/config", connectionId: "other" }));
        await Promise.all(requests); expect(fetchMock).toHaveBeenCalledTimes(5);
      });
      it("a write invalidates earlier reads and old completion cannot evict a newer request", async () => {
        const old = deferred<Response>(), fresh = deferred<Response>();
        fetchMock.mockReturnValueOnce(old.promise).mockResolvedValueOnce(json({})).mockReturnValueOnce(fresh.promise);
        const first = webApi({ path: "/api/config" });
        await webApi({ path: "/api/config", method: "PATCH", body: { changed: true } });
        const second = webApi({ path: "/api/config" });
        old.resolve(json({ generation: 1 })); await first;
        const third = webApi({ path: "/api/config" });
        expect(fetchMock).toHaveBeenCalledTimes(3);
        fresh.resolve(json({ generation: 2 }));
        expect(await Promise.all([second, third])).toEqual([{ generation: 2 }, { generation: 2 }]);
      });
      it("authentication changes invalidate pending reads", async () => {
        const old = deferred<Response>();
        fetchMock.mockReturnValueOnce(old.promise).mockResolvedValueOnce(json({})).mockResolvedValueOnce(json({ authenticated: true }));
        const first = webApi({ path: "/api/status" });
        await proxySessionLogin("http://127.0.0.1:5180", "basic", "test", "test");
        expect(await webApi({ path: "/api/status" })).toEqual({ authenticated: true });
        old.resolve(json({ authenticated: false })); await first;
        expect(fetchMock).toHaveBeenCalledTimes(3);
      });
      it("does not share writes or arbitrary GET endpoints, and never automatically retries", async () => {
        fetchMock.mockRejectedValue(new Error("network unavailable"));
        const requests = [webApi({ path: "/api/config", method: "PATCH" }), webApi({ path: "/api/config", method: "PATCH" }), webApi({ path: "/api/sessions/x" }), webApi({ path: "/api/sessions/x" })];
        await Promise.allSettled(requests); expect(fetchMock).toHaveBeenCalledTimes(4);
      });
      it("clears failed shared reads so a deliberate retry can succeed", async () => {
        fetchMock.mockRejectedValueOnce(new Error("offline")).mockResolvedValueOnce(json({ ready: true }));
        await expect(webApi({ path: "/api/status" })).rejects.toThrow("offline");
        expect(await webApi({ path: "/api/status" })).toEqual({ ready: true });
      });
      it("bounds stalled reads and cleans up the deadline", async () => {
        vi.useFakeTimers();
        fetchMock.mockImplementation((_url, init) => new Promise((_resolve, reject) => init.signal.addEventListener("abort", () => reject(new DOMException("aborted", "AbortError")))));
        const result = expect(webApi({ path: "/api/status" })).rejects.toThrow("timed out");
        await vi.advanceTimersByTimeAsync(30_000); await result;
        expect(fetchMock.mock.calls[0][1].signal.aborted).toBe(true); expect(vi.getTimerCount()).toBe(0);
      });
      it("keeps the timeout active while consuming a stalled response body", async () => {
        vi.useFakeTimers();
        fetchMock.mockImplementation((_url, init) => Promise.resolve({ ok: true, status: 200, headers: new Headers(), text: () => new Promise((_resolve, reject) => init.signal.addEventListener("abort", () => reject(new Error("body aborted")))) }));
        const result = expect(webApi({ path: "/api/status", timeoutMs: 50 })).rejects.toThrow("timed out");
        await vi.advanceTimersByTimeAsync(50); await result; expect(vi.getTimerCount()).toBe(0);
      });
      it("preserves unbounded writes by default and reports uncertain completion on explicit timeout", async () => {
        vi.useFakeTimers(); const response = deferred<Response>(); fetchMock.mockReturnValueOnce(response.promise);
        const write = webApi({ path: "/api/config", method: "PATCH" });
        expect(vi.getTimerCount()).toBe(0); response.resolve(json({})); await write;
        fetchMock.mockImplementation((_url, init) => new Promise((_resolve, reject) => init.signal.addEventListener("abort", () => reject(new Error("aborted")))));
        const timed = expect(webApi({ path: "/api/config", method: "PATCH", timeoutMs: 50 })).rejects.toThrow("may have completed");
        await vi.advanceTimersByTimeAsync(50); await timed; expect(fetchMock).toHaveBeenCalledTimes(2);
      });
      it("honors an explicit zero read timeout and clears timers after success", async () => {
        vi.useFakeTimers(); fetchMock.mockImplementation(() => Promise.resolve(json({})));
        await webApi({ path: "/api/status", timeoutMs: 0 }); expect(vi.getTimerCount()).toBe(0);
        await webApi({ path: "/api/status" }); expect(vi.getTimerCount()).toBe(0);
      });
      it("distinguishes missing records from missing API endpoints", async () => {
        fetchMock.mockResolvedValueOnce(json({ detail: "Session not found" }, 404)).mockResolvedValueOnce(json({ detail: "Not Found" }, 404));
        await expect(webApi({ path: "/api/sessions/missing" })).rejects.toThrow('HTTP 404: {"detail":"Session not found"}');
        await expect(webApi({ path: "/api/unsupported" })).rejects.toThrow("No such API endpoint:");
      });
      it("rejects broken JSON and HTML fallbacks but preserves legitimate text and empty responses", async () => {
        fetchMock.mockResolvedValueOnce(new Response("{broken", { headers: { "Content-Type": "application/json" } }))
          .mockResolvedValueOnce(new Response("<!doctype html>", { headers: { "Content-Type": "text/html" } }))
          .mockResolvedValueOnce(new Response("log output", { headers: { "Content-Type": "text/plain" } }))
          .mockResolvedValueOnce(new Response(null, { status: 204 }));
        await expect(webApi({ path: "/api/status" })).rejects.toThrow("invalid JSON");
        await expect(webApi({ path: "/api/status" })).rejects.toThrow("web page");
        expect(await webApi({ path: "/api/logs" })).toBe("log output");
        expect(await webApi({ path: "/api/empty" })).toBeUndefined();
      });
      it("validates connection metadata before it can enter the registry", async () => {
        for (const value of [null, [], {}, { allowedTargets: [], defaultGatewayUrl: "javascript:alert(1)" }, { allowedTargets: [2], defaultGatewayUrl: null }, { allowedTargets: [], defaultGatewayUrl: "https://user:password@example.com" }]) {
          expect(() => parseProxyMeta(value)).toThrow();
        }
        fetchMock.mockResolvedValueOnce(json({ allowedTargets: [], defaultGatewayUrl: 42 }));
        expect(await fetchProxyMeta()).toBeNull();
        const good = { allowedTargets: ["http://127.0.0.1:9119"], defaultGatewayUrl: "http://127.0.0.1:9119" };
        expect(parseProxyMeta(good)).toEqual(good);
      });
    ''
  } "$out/rest-policy.test.ts"
  cp ${
    writeText "patch-rest.mjs" /* javascript */ ''
      import fs from "node:fs";
      const path = "apps/web/src/bridge/gateway/rest.ts";
      let source = fs.readFileSync(path, "utf8");
      function replace(before, after) {
        if (!source.includes(before)) throw new Error("Upstream REST bridge changed; review patch: " + before.slice(0, 60));
        source = source.replace(before, after);
      }
      replace(
      `import { getConnectionById } from '../registry'`,
      `import { DEFAULT_READ_TIMEOUT_MS, SHARED_READ_PATHS, shareRead, invalidateReads, isMissingEndpoint, decodeApiBody, parseProxyMeta } from './request-policy'
      import { getConnectionById as lookupConnection, loadRegistry } from '../registry'
      function getConnectionById(id?: null | string): WebConnectionRecord {
        const normalized = id?.trim()
        if (!normalized) return lookupConnection()
        const connection = loadRegistry().connections.find(item => item.id === normalized)
        if (!connection) throw new Error('No connection with id: ' + normalized)
        return connection
      }`
      );
      replace(
      `  return fetch(input, { ...init, credentials: 'include' })`,
      `  const mutation = !['GET', 'HEAD'].includes((init.method ?? 'GET').toUpperCase())
        if (mutation) invalidateReads()
        return fetch(input, { ...init, credentials: 'include' }).finally(() => {
          if (mutation) invalidateReads()
        })`
      );
      replace(
      `  if (status === 404) {`,
      `  if (status === 404 && isMissingEndpoint(body)) {`
      );
      replace(
      `export async function webApi<T>(request: HermesApiRequest): Promise<T> {`,
      `export async function webApi<T>(request: HermesApiRequest): Promise<T> {
        const method = (request.method ?? 'GET').toUpperCase()
        const path = request.path.startsWith('/') ? request.path : '/' + request.path
        if (method !== 'GET' || request.upload || !SHARED_READ_PATHS.has(path.split('?', 1)[0])) {
          return executeWebApi<T>(request)
        }
        const conn = getConnectionById(request.connectionId)
        const key = JSON.stringify([proxyBaseUrl(), conn.id, conn.url, conn.authMode, conn.token, request.profile, path, request.timeoutMs ?? DEFAULT_READ_TIMEOUT_MS])
        return shareRead(key, () => executeWebApi<T>(request))
      }

      async function executeWebApi<T>(request: HermesApiRequest): Promise<T> {`
      );
      replace(
      `  const timer = request.timeoutMs
          ? window.setTimeout(() => controller.abort(), request.timeoutMs)
          : undefined`,
      `  const read = method === 'GET' || method === 'HEAD'
        const timeoutMs = request.timeoutMs ?? (read ? DEFAULT_READ_TIMEOUT_MS : undefined)
        const timer = timeoutMs && timeoutMs > 0
          ? window.setTimeout(() => controller.abort(), timeoutMs)
          : undefined`
      );
      replace(
      `    try {
            return JSON.parse(text) as T
          } catch {
            return text as T
          }
        } finally {`,
      `    return decodeApiBody(text, res.headers.get('content-type')) as T
        } catch (error) {
          if (controller.signal.aborted) {
            throw new Error(read
              ? 'Hermes request timed out. Try refreshing this view.'
              : 'Hermes request timed out; the action may have completed. Check its result before retrying.', { cause: error })
          }
          throw error
        } finally {`
      );
      replace(
      `const res = await fetch(\`\''${proxy}/api/proxy/meta\`)`,
      `const res = await proxyFetch(\`\''${proxy}/api/proxy/meta\`, { signal: AbortSignal.timeout(DEFAULT_READ_TIMEOUT_MS) })`
      );
      replace(
      `    return (await res.json()) as {
            defaultGatewayUrl: string | null
            allowedTargets: string[]
          }`,
      `    return parseProxyMeta(await res.json())`
      );
      fs.writeFileSync(path, source);
    ''
  } "$out/patch-rest.mjs"
''
