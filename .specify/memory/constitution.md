# OpenClaw Constitution

> **Version:** 1.2.0
> **Ratified:** 2026-03-05
> **Amended:** 2026-10-02
> **Status:** Active
> **Inherits:** [crunchtools/constitution](https://github.com/crunchtools/constitution) v1.18.0
> **Profile:** Autonomous Agent

OpenClaw, a general-purpose AI assistant, packaged as a container and run
unattended with a human-in-the-loop gate on every write. Users reach it over
Signal (outbound connection, no public web exposure). Tracking: RT #1400
(research), RT #1406 (deployment).

This file holds the values specific to this deployment. The fleet rules and
the Autonomous Agent profile (the six layers' requirements, quality gates,
naming) apply at the inherited version and are checked against this repo's
files by `constitution.yml`. They are not restated here.

## Trust Boundary

Phase 1 is a single agent with deterministic input sanitization and output
validation. There is no P-Agent/Q-Agent split yet: CaMeL-style tooling was
not mature enough for production. Every tool call goes through structured
schema validation, freeform strings are rejected in privileged parameters,
Signal input is sanitized before the agent sees it, and output is validated
before a tool runs.

Phase 2 makes mcporter the boundary: web-fetching MCP tools are quarantined
behind a sub-agent with no other tool access, its output is stripped by
non-LLM validation, and extracted data is passed by symbolic reference, never
as raw content.

## Layer 1 — Trust Boundary Architecture

As above: Phase 1 single agent, Phase 2 quarantined sub-agent behind mcporter.

## Layer 2 — MCP Server Governance

Allowlist, read-only to start (scored 2026-03-05 with `find-mcp-server`):

| Server | Scorecard | Risk tier | Use |
|--------|-----------|-----------|-----|
| mcp-request-tracker-crunchtools | A (20/24) | Read-only | Ticket lookups |
| mcp-mediawiki-crunchtools | A (24/24) | Read-only | Wiki lookups |
| mcp-memory (crunchtools/memory) | B (16/24) | Read-only | Memory search, no store |

mcporter (pinned by `MCPORTER_VERSION` in the Containerfile): hot-reload
disabled, every server pinned to a release, invocation logging on (JSON,
credentials redacted), runtime discovery and ad-hoc installation prohibited.
Adding a server means scoring it, pinning it in the mcporter config,
classifying its tools by risk tier, re-running the gates, and adding it to
the table above.

## Layer 3 — Container & Supply Chain Security

- **Image:** `quay.io/crunchtools/openclaw` and `ghcr.io/crunchtools/openclaw`.
- **Build:** multi-stage. The builder is UBI 10 Minimal because Hummingbird
  lacks the `git` that OpenClaw's npm install needs; the runtime is
  `quay.io/hummingbird/nodejs:22`. OpenClaw is pinned by version in the
  Containerfile, with CVE overrides for transitive npm packages. npm and npx
  are stripped from the runtime: OpenClaw needs only `node`, and npm ships
  inside every Hummingbird Node.js variant.
- **Trivy:** blocking on CRITICAL/HIGH. The weekly rebuild is a
  `workflow_dispatch` pulsed by Hermes, not a `schedule:`.
- **Runtime:** rootless (UID 65532), `--read-only` root filesystem, SELinux
  enforcing with `:Z` mounts, bridge network with `-p 127.0.0.1:18789:18789`
  (the gateway binds `lan` inside the container because loopback is
  unreachable through the bridge DNAT), default capabilities only.
- **Tmpfs:** `/tmp:rw,nosuid`, deliberately without `noexec`: signal-cli
  extracts native libraries to `/tmp`.
- **signal-cli:** the GraalVM native binary (no JVM), pinned by
  `SIGNAL_CLI_VERSION`, bundled in the image and spawned by OpenClaw; no
  sidecar.
- **License:** upstream OpenClaw is MIT; the image's
  `org.opencontainers.image.licenses` label says MIT for that reason.

## Layer 4 — Runtime Security & Behavioral Controls

Circuit breakers, half the profile defaults for unattended mode (set in
`config/openclaw.json5`):

| Breaker | Value |
|---------|-------|
| Tool calls per conversation | 25 |
| Token budget per conversation | $2.00 |
| Repeated same-tool invocations | 3 consecutive |
| Conversation depth | 50 turns |

Rate limits: 10 calls/hr per tool, 50 calls/min per MCP server, 200 tool
calls/hr globally; repeated failures cool down 1 min, 5 min, 15 min, then
halt.

Audit log: JSON at `/app/logs/audit/` (host `logs/audit/`), 90-day retention,
credentials redacted, daily files, compressed after 7 days.

Human in the loop: mode `unattended-gated`; every write needs explicit
approval, and the initial allowlist has no write tools. Dead man's switch:
4-hour window, notification over Signal, the agent pauses when it expires.

## Layer 5 — Credential & Identity Management

- **LLM provider:** Google Gemini only. Tiers in `config/openclaw.json5`:
  cheap `gemini-2.5-flash-lite` (heartbeats, simple lookups), fast
  `gemini-2.5-flash` (routine work), smart `gemini-2.5-pro` (complex
  reasoning).
- `GOOGLE_AI_API_KEY` and each MCP server's credentials are env vars from a
  systemd `EnvironmentFile` (`config/env`, mode 600; shape in
  `config/env.example`). The rest of `config/` holds no secrets.

## Layer 6 — Monitoring, Detection & Response

Kill switches:

| Level | Mechanism |
|-------|-----------|
| Container | `systemctl stop openclaw.crunchtools.com.service` |
| Application | `podman stop openclaw.crunchtools.com` (SIGTERM) |
| Network | nftables rule dropping the container's outbound traffic |

Nagios: TCP check on 18789 (high), container state and health (high), and
container exit code. The image's `HEALTHCHECK` runs `openclaw health --json`.

Incident response: trip a kill switch, preserve the audit logs, open an RT
ticket, and hold a post-incident review before restart.

**Open gate:** the circuit breakers are configured but have not yet been
tripped on purpose to prove them.

## Service

| Attribute | Value |
|-----------|-------|
| Service / unit | `openclaw.crunchtools.com` / `openclaw.crunchtools.com.service` |
| Port | 18789, `127.0.0.1` only |
| Host directory | `/srv/<service>/` (`data/openclaw`, `signal/data`, `logs`, `config`) |
| Public access | None; outbound to Signal only |

## History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-03-05 | Initial constitution |
| 1.1.0 | 2026-03-05 | Updated to match the deployed state |
| 1.2.0 | 2026-10-02 | Manifest under constitution v1.18.0: profile restatement removed; host details dropped (XVII); smart tier and OpenClaw pin taken from the config and Containerfile |
