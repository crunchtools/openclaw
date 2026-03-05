# OpenClaw Constitution

> **Version:** 1.0.0
> **Ratified:** 2026-03-05
> **Status:** Active
> **Inherits:** [crunchtools/constitution](https://github.com/crunchtools/constitution) v1.1.0
> **Profile:** Autonomous Agent
> **Deployment:** lotor.dc3.crunchtools.com
> **Tracking:** RT #1406 (deployment), RT #1400 (research)

---

## Overview

OpenClaw general-purpose AI assistant deployed on lotor.dc3.crunchtools.com as a containerized service. Operates in unattended mode with human-in-the-loop gates for all write operations. Dead man's switch active with a 4-hour default window. User interaction via Signal bot (outbound connection, no public web exposure).

---

## Layer 1 — Trust Boundary Architecture

### Current (Phase 1)

Single-agent deployment with deterministic input sanitization and output validation layers. No P-Agent/Q-Agent split — CaMeL-style tooling is not yet mature enough for production use.

- All tool calls go through structured schema validation
- Freeform strings rejected in privileged parameters
- Input from Signal messages sanitized before agent processing
- Output validated before tool execution

### Future (Phase 2)

mcporter as natural trust boundary point:

- Quarantine web-fetching MCP tools behind a sub-agent with no other tool access
- Strip sub-agent output through non-LLM validation
- Use symbolic references for extracted data (no raw content passthrough)

---

## Layer 2 — MCP Server Governance

### Server Allowlist

Initial deployment: read-only, minimal starter set.

| Server | Scorecard | Risk Tier | Rationale |
|--------|-----------|-----------|-----------|
| mcp-request-tracker-crunchtools | A (20/24) | Read-only | Ticket lookups, no writes initially |
| mcp-mediawiki-crunchtools | A (24/24) | Read-only | Wiki page lookups |
| mcp-memory (crunchtools/memory) | B (16/24) | Read-only | Memory search only, no store |

Scorecard evaluations completed 2026-03-05 via `find-mcp-server`. All servers exceed B/15 minimum.

### mcporter Configuration

- Hot-reload: **disabled**
- Version pinning: all servers pinned to specific releases (no `latest` tags)
- Invocation logging: **enabled** (structured JSON, credentials redacted)
- Runtime discovery: **prohibited**
- Ad-hoc server installation: **prohibited**

### Expanding the Allowlist

Adding a server requires:

1. Score the server via `find-mcp-server` (minimum B/15 for production)
2. Update the mcporter config with pinned version
3. Classify all tools by risk tier (read-only, write, system, network)
4. Re-run quality gates
5. Update this constitution with the new server entry

---

## Layer 3 — Container & Supply Chain Security

### Container Image

| Attribute | Value |
|-----------|-------|
| Base image | `quay.io/hummingbird/nodejs:22` (Node.js 22 LTS) |
| Fallback | UBI 10 Minimal + Node.js from AppStream |
| Build file | `Containerfile` (multi-stage: builder + runtime) |
| Registry (primary) | `quay.io/crunchtools/openclaw` |
| Registry (secondary) | `ghcr.io/crunchtools/openclaw` |
| OpenClaw version | Pinned in Containerfile (currently `2026.3.2`) |

### CI Pipeline

- **Build trigger:** Push to main, Containerfile changes
- **Dual-push:** Quay.io + GHCR on every main branch build
- **Weekly rebuild:** Monday 6am UTC (scheduled CI)
- **Trivy scan:** Every build, fail on CRITICAL/HIGH
- **Security scan:** Weekly CodeQL + container scan (Monday 9am UTC)

### OCI Labels

- `org.opencontainers.image.source` — GitHub repo URL
- `org.opencontainers.image.description` — Service description
- `org.opencontainers.image.licenses` — MIT

### Runtime Constraints

| Constraint | Setting |
|------------|---------|
| Rootless | Yes (UID 1001) |
| Read-only root filesystem | `--read-only` |
| SELinux | Enforcing (`:Z` volume mounts) |
| Host network | No |
| Tmpfs | `/tmp:rw,noexec,nosuid` |
| Capabilities | Default (no `--privileged`, no `SYS_ADMIN`) |

### Signal Sidecar

| Attribute | Value |
|-----------|-------|
| Image | `docker.io/bbernhard/signal-cli-rest-api:latest` |
| Port | `127.0.0.1:8093:8080` |
| Mode | `json-rpc` (production), `native` (registration) |
| Data volume | `/srv/openclaw.crunchtools.com/signal/data` |
| Systemd unit | `signal-api.crunchtools.com.service` |

---

## Layer 4 — Runtime Security & Behavioral Controls

### Circuit Breakers

Conservative values for unattended mode (half the profile defaults):

| Breaker | Value |
|---------|-------|
| Max tool calls per conversation | 25 |
| Token budget per conversation | $2.00 |
| Repeated same-tool invocations | 3 consecutive |
| Max conversation depth | 50 turns |

When tripped: agent halts, logs the event, notifies operator via Signal.

### Rate Limiting

| Scope | Limit |
|-------|-------|
| Per-tool | 10/hr (all tools, read-only) |
| Per-server | 50 calls/min to any single MCP server |
| Global | 200 total tool calls/hr |

Repeated failures trigger escalating cooldowns: 1min → 5min → 15min → halt.

### Audit Logging

| Setting | Value |
|---------|-------|
| Format | Structured JSON |
| Path | `/srv/openclaw.crunchtools.com/logs/audit/` |
| Retention | 90 days |
| Credential redaction | Yes |
| Rotation | Daily files |
| Compression | After 7 days |

### Human-in-the-Loop

- ALL write operations require explicit human approval
- No write tools in initial allowlist (gate pre-configured for future expansion)
- Mode: `unattended-gated`

### Dead Man's Switch

- Window: 4 hours
- Notification channel: Signal
- Behavior: If no human input received within window, agent pauses and sends notification

---

## Layer 5 — Credential & Identity Management

### LLM Provider

**Google Gemini** (all tiers, single provider, existing account).

| Tier | Model | Input/1M | Output/1M | Use Case |
|------|-------|----------|-----------|----------|
| cheap | Gemini 2.5 Flash-Lite | $0.10 | $0.40 | Heartbeats, simple lookups |
| fast | Gemini 2.5 Flash | $0.30 | $2.50 | Routine tasks |
| smart | Gemini 2.5 Pro | $1.25 | $10.00 | Complex reasoning |

### Estimated Monthly Cost

| Usage Level | Requests/month | Cost |
|-------------|----------------|------|
| Light | 500 | $2–8 |
| Medium | 2,000 | $8–30 |
| Heavy | 5,000+ | $30–100 |

Token budget circuit breaker ($2.00/conversation) prevents runaway costs.

### Credential Handling

| Credential | Source | Scope |
|------------|--------|-------|
| `GOOGLE_AI_API_KEY` | systemd EnvironmentFile | LLM provider |
| MCP server credentials | Per-server env vars | One per server |

- No persistent API keys in config files
- Config at `/srv/openclaw.crunchtools.com/config/` — secrets-free
- Env file at `/srv/openclaw.crunchtools.com/config/env` — chmod 600

---

## Layer 6 — Monitoring, Detection & Response

### Kill Switches

| Level | Mechanism | Command |
|-------|-----------|---------|
| Container | systemd | `systemctl stop openclaw.crunchtools.com.service` |
| Application | SIGTERM / health endpoint | `podman stop openclaw.crunchtools.com` |
| Network | nftables | Drop outbound from OpenClaw container |

### Monitoring (Zabbix)

| Check | Type | Priority |
|-------|------|----------|
| TCP port 18789 | `net.tcp.service[tcp,,18789]` | HIGH |
| Audit log growth | Log file size check | AVERAGE |
| Container running | service-checker.py integration | DISASTER |

### Incident Response

1. Trigger kill switch (any level)
2. Preserve audit logs (no cleanup on kill)
3. Create RT ticket documenting the incident
4. Post-incident review required before restart

---

## Quality Gates

| # | Gate | Status |
|---|------|--------|
| 1 | Container builds from Containerfile without errors | Pending |
| 2 | Trivy scan passes (no critical/high CVEs) | Pending |
| 3 | MCP server allowlist: all servers scored >= B/15 via find-mcp-server | Pending |
| 4 | Circuit breakers configured and tested (trip each one intentionally) | Pending |
| 5 | Credential audit: no hardcoded secrets in config or image | Pending |
| 6 | Monitoring: Zabbix items created, kill switches tested | Pending |
| 7 | Per-repo constitution written and validated | Done |
| 8 | Firewall: nftables updated only if public access is needed (default: no) | Pending |
| 9 | Systemd unit: enabled, tested start/stop/restart | Pending |

---

## Infrastructure

| Attribute | Value |
|-----------|-------|
| Host | lotor.dc3.crunchtools.com |
| OS | RHEL 10.1 Image Mode (bootc) |
| Resources | 6 vCPU, 16GB RAM |
| Service name | openclaw.crunchtools.com |
| Systemd unit | openclaw.crunchtools.com.service |
| Port | 18789 (127.0.0.1 only) |
| Data volume | `/srv/openclaw.crunchtools.com/` |
| Public access | No (outbound to Signal only) |
| Container count | 2 (OpenClaw + signal-cli-rest-api sidecar) |

---

## References

- [Constitution](https://github.com/crunchtools/constitution) v1.1.0
- [Autonomous Agent Profile](https://github.com/crunchtools/constitution/blob/main/profiles/autonomous-agent.md)
- Research: RT #1400
- Deployment: RT #1406
- Lotor infrastructure: RT #1404
