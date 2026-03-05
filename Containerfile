# OpenClaw — Crunchtools Autonomous Agent
# General-purpose AI assistant with Signal integration, running under
# the crunchtools Autonomous Agent constitution profile.
#
# Build:
#   podman build -t quay.io/crunchtools/openclaw .
#
# Run:
#   podman run -d --name openclaw \
#     --read-only --tmpfs /tmp:rw,noexec,nosuid \
#     -p 127.0.0.1:18789:18789 \
#     -v /srv/openclaw.crunchtools.com/data/openclaw:/app/.openclaw:Z \
#     -v /srv/openclaw.crunchtools.com/logs:/app/logs:Z \
#     --env-file /srv/openclaw.crunchtools.com/config/env \
#     quay.io/crunchtools/openclaw

# Stage 1: Install OpenClaw and dependencies
# Use UBI 10 Minimal as builder — Hummingbird lacks git which
# OpenClaw's npm dependencies require for installation
FROM registry.access.redhat.com/ubi10/ubi-minimal AS builder

RUN microdnf install -y nodejs npm git && microdnf clean all

WORKDIR /build

# Install OpenClaw at a pinned version — update this on upgrades
# mcporter is bundled as an OpenClaw dependency, not a separate install
RUN npm install --global --prefix /build/install openclaw@2026.3.2 && \
    npm install --global --prefix /build/install @hono/node-server@1.19.10

# Stage 2: Runtime image — minimal, no build tools
# Hummingbird images are immutable (/etc/passwd, /home are read-only)
# so we use /app as the working directory (same pattern as mcp-github)
FROM quay.io/hummingbird/nodejs:22

LABEL name="openclaw-crunchtools" \
      version="1.0.0" \
      summary="OpenClaw autonomous agent under crunchtools constitution" \
      description="General-purpose AI assistant with Signal channel, MCP server governance, and behavioral circuit breakers" \
      maintainer="crunchtools.com" \
      io.k8s.display-name="OpenClaw CrunchTools" \
      org.opencontainers.image.source="https://github.com/crunchtools/openclaw" \
      org.opencontainers.image.description="OpenClaw autonomous agent — crunchtools deployment" \
      org.opencontainers.image.licenses="MIT"

WORKDIR /app

# Copy installed OpenClaw from builder into /app
COPY --from=builder /build/install /app

ENV PATH="/app/bin:${PATH}" \
    NODE_ENV=production \
    HOME=/app

EXPOSE 18789

# Health check — OpenClaw gateway health probe
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD openclaw health --json || exit 1

ENTRYPOINT ["openclaw", "gateway", "run", "--bind", "loopback"]
