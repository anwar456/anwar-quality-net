import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { testInternetSpeed } from "./internetSpeedTest";

// Protects: the candidate hardware check measures against our API only, and fails closed (audit R-14).
// Production CSP allows connections to this origin and the API, nothing else.
describe("internet speed test", () => {
  beforeEach(() => {
    vi.stubEnv("VITE_API_BASE_URL", "https://api.example.test/api/v1");
    vi.stubEnv("VITE_SPEED_TEST_PING_URL", "");
    vi.stubEnv("VITE_SPEED_TEST_UPLOAD_URL", "");
    vi.stubEnv("VITE_SPEED_TEST_DOWNLOAD_URL", "");
  });
  afterEach(() => {
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
  });

  function stubFetch(behaviour: "ok" | "blocked" | "server-error") {
    const urls: string[] = [];
    vi.stubGlobal(
      "fetch",
      vi.fn(async (url: string) => {
        urls.push(String(url));
        if (behaviour === "blocked") throw new TypeError("blocked by the content security policy");
        if (behaviour === "server-error") return { ok: false, blob: async () => new Blob([]) } as unknown as Response;
        return { ok: true, blob: async () => new Blob([new Uint8Array(1_000_000)]) } as unknown as Response;
      })
    );
    return urls;
  }

  it("only calls the API, never a third-party host", async () => {
    const urls = stubFetch("ok");
    await testInternetSpeed();

    expect(urls.length).toBeGreaterThan(0);
    for (const url of urls) expect(url.startsWith("https://api.example.test/api/v1/")).toBe(true);
  });

  it("fails the check when the network is blocked, instead of inventing a passing speed", async () => {
    stubFetch("blocked");
    const result = await testInternetSpeed();

    expect(result.passed).toBe(false);
    expect(result.download).toBe(0);
    expect(result.upload).toBe(0);
  });

  it("fails the check when the server answers with an error", async () => {
    stubFetch("server-error");
    const result = await testInternetSpeed();

    expect(result.passed).toBe(false);
  });
});
