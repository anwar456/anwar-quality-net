// Internet Speed Test Utilities — standalone, no backend dependency

export interface InternetSpeedResult {
    download: number;
    upload: number;
    ping: number;
    passed: boolean;
    downloadTests: number[];
    uploadTests: number[];
    pingTests: number[];
}

export interface SpeedThresholds {
    minDownloadMbps: number;
    minUploadMbps: number;
    maxPingMs: number;
}

export const DEFAULT_THRESHOLDS: SpeedThresholds = {
    minDownloadMbps: 8,
    minUploadMbps: 4,
    maxPingMs: 300,
};

// The hardware check measures the path to OUR API, which is the path the interview audio uses. It must not call
// third-party hosts: the production Content-Security-Policy only allows this origin and the API, so those calls
// were blocked and every candidate failed the check (audit R-14). Each URL can still be overridden.
const DOWNLOAD_BYTES = 1_000_000;
const UPLOAD_BYTES = 500_000;

function speedTestUrls() {
    const apiBase = (import.meta.env.VITE_API_BASE_URL ?? "http://localhost:3000/api/v1") as string;
    const fresh = (url: string) => `${url}${url.includes("?") ? "&" : "?"}_=${Date.now()}`;
    return {
        ping: fresh((import.meta.env.VITE_SPEED_TEST_PING_URL as string | undefined) || `${apiBase}/health`),
        upload: (import.meta.env.VITE_SPEED_TEST_UPLOAD_URL as string | undefined) || `${apiBase}/speed_test`,
        download: fresh(
            (import.meta.env.VITE_SPEED_TEST_DOWNLOAD_URL as string | undefined) || `${apiBase}/speed_test?bytes=${DOWNLOAD_BYTES}`
        ),
    };
}

// A measurement that cannot be taken counts as failed. Never invent a plausible number: an unreachable server
// used to be reported as "just enough" upload speed, so the check passed exactly when it should not.
async function measurePing(): Promise<number> {
    try {
        const start = performance.now();
        const response = await fetch(speedTestUrls().ping, { cache: "no-cache" });
        if (!response.ok) return 999;
        return performance.now() - start;
    } catch {
        return 999;
    }
}

async function measureDownloadSpeed(): Promise<number> {
    try {
        const start = performance.now();
        const response = await fetch(speedTestUrls().download, { cache: "no-cache" });
        if (!response.ok) return 0;
        const blob = await response.blob();
        const seconds = (performance.now() - start) / 1000;
        return blob.size / (1024 * 1024) / seconds; // MB/s
    } catch {
        return 0;
    }
}

async function measureUploadSpeed(): Promise<number> {
    try {
        const formData = new FormData();
        formData.append("test", new Blob([new ArrayBuffer(UPLOAD_BYTES)], { type: "application/octet-stream" }));
        const start = performance.now();
        const response = await fetch(speedTestUrls().upload, { method: "POST", body: formData });
        if (!response.ok) return 0;
        const seconds = (performance.now() - start) / 1000;
        return UPLOAD_BYTES / (1024 * 1024) / seconds; // MB/s
    } catch {
        return 0;
    }
}

async function runMultipleTests<T>(testFn: () => Promise<T>, count = 3): Promise<T[]> {
    const results: T[] = [];
    for (let i = 0; i < count; i++) {
        try {
            results.push(await testFn());
            await new Promise((r) => setTimeout(r, 100));
        } catch {
            // skip failed test
        }
    }
    return results;
}

function average(values: number[]): number {
    if (values.length === 0) return 0;
    if (values.length <= 2) return values.reduce((a, b) => a + b, 0) / values.length;
    const sorted = [...values].sort((a, b) => a - b);
    const trimmed = sorted.slice(1, -1);
    return trimmed.reduce((a, b) => a + b, 0) / trimmed.length;
}

export async function testInternetSpeed(
    thresholds: SpeedThresholds = DEFAULT_THRESHOLDS
): Promise<InternetSpeedResult> {
    try {
        const [downloadTests, uploadTests, pingTests] = await Promise.all([
            runMultipleTests(measureDownloadSpeed, 3),
            runMultipleTests(measureUploadSpeed, 3),
            runMultipleTests(measurePing, 3),
        ]);

        const downloadMbps = average(downloadTests) * 8;
        const uploadMbps = average(uploadTests) * 8;
        const ping = average(pingTests);

        const passed =
            downloadMbps >= thresholds.minDownloadMbps &&
            uploadMbps >= thresholds.minUploadMbps &&
            ping <= thresholds.maxPingMs;

        return {
            download: Math.round(downloadMbps * 100) / 100,
            upload: Math.round(uploadMbps * 100) / 100,
            ping: Math.round(ping),
            passed,
            downloadTests: downloadTests.map((v) => Math.round(v * 8 * 100) / 100),
            uploadTests: uploadTests.map((v) => Math.round(v * 8 * 100) / 100),
            pingTests: pingTests.map((v) => Math.round(v)),
        };
    } catch {
        return { download: 0, upload: 0, ping: 999, passed: false, downloadTests: [], uploadTests: [], pingTests: [] };
    }
}
