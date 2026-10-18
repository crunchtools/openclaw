// Smoke test for the RT #1534 build patch: the OpenRouter image provider must
// reach a private baseUrl only when models.providers.openrouter.request.
// allowPrivateNetwork is true. Runs inside the built image:
//   podman run --rm -v ./scripts:/t:ro,Z <image> node /t/test-openrouter-private-network.mjs
import { createServer } from "node:http";
import { readdirSync, readFileSync } from "node:fs";

const DIST = "/app/lib/node_modules/openclaw/dist";
const MARKER = "region extensions/openrouter/image-generation-provider.ts";
const file = readdirSync(DIST).find(
  (f) => f.endsWith(".js") && readFileSync(`${DIST}/${f}`, "utf8").includes(MARKER),
);
if (!file) throw new Error("OpenRouter image provider not found in dist");
const { t: buildProvider } = await import(`${DIST}/${file}`);

// The patch governs network policy only, so the fake upstream just records
// hits; response parsing is upstream's concern.
const hits = [];
const server = createServer((req, res) => {
  hits.push(`${req.method} ${req.url}`);
  req.resume();
  req.on("end", () => {
    res.setHeader("content-type", "application/json");
    res.end(JSON.stringify({ choices: [] }));
  });
});
await new Promise((r) => server.listen(0, "127.0.0.1", r));
const baseUrl = `http://127.0.0.1:${server.address().port}/v1`;
process.env.OPENROUTER_API_KEY = "test";

const run = (request) =>
  buildProvider().generateImage({
    provider: "openrouter",
    model: "google/gemini-2.5-flash-image",
    prompt: "test",
    cfg: { models: { providers: { openrouter: { baseUrl, apiKey: "test", models: [], ...(request ? { request } : {}) } } } },
    timeoutMs: 10000,
  });

const blocked = (e) => /Blocked hostname or private/.test(e?.message ?? "");
let failed = false;

await run({ allowPrivateNetwork: true }).catch((e) => {
  if (blocked(e)) failed = true;
});
if (!failed && hits.includes("POST /v1/chat/completions")) {
  console.log("PASS: allowPrivateNetwork=true reaches private baseUrl");
} else {
  failed = true;
  console.error(`FAIL: allowPrivateNetwork=true did not reach private baseUrl (hits: ${hits.join(", ") || "none"})`);
}

hits.length = 0;
const err = await run(undefined).then(() => null, (e) => e);
if (blocked(err) && hits.length === 0) {
  console.log("PASS: private baseUrl blocked without opt-in");
} else {
  failed = true;
  console.error(`FAIL: private baseUrl not blocked without opt-in (${err?.message ?? "succeeded"})`);
}
server.close();
process.exit(failed ? 1 : 0);
