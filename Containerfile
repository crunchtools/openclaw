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
#     -v /srv/openclaw.crunchtools.com/data/openclaw:/home/openclaw/.openclaw:Z \
#     -v /srv/openclaw.crunchtools.com/logs:/home/openclaw/logs:Z \
#     --env-file /srv/openclaw.crunchtools.com/config/env \
#     quay.io/crunchtools/openclaw

# Stage 1: Install OpenClaw and dependencies with build tools
FROM quay.io/hummingbird/nodejs:22-builder AS builder

WORKDIR /build

# Install OpenClaw at a pinned version — update this on upgrades
# mcporter is bundled as an OpenClaw dependency, not a separate install
RUN npm install --global --prefix /build/install openclaw@2026.3.2

# Stage 2: Runtime image — minimal, no build tools
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

# Create non-root user
RUN echo 'openclaw:x:1001:1001:OpenClaw Agent:/home/openclaw:/bin/sh' >> /etc/passwd && \
    echo 'openclaw:x:1001:' >> /etc/group && \
    mkdir -p /home/openclaw/.openclaw /home/openclaw/logs && \
    chown -R 1001:1001 /home/openclaw

# Copy installed OpenClaw from builder
COPY --from=builder --chown=1001:1001 /build/install /home/openclaw/.local

ENV PATH="/home/openclaw/.local/bin:${PATH}" \
    NODE_ENV=production \
    HOME=/home/openclaw

USER 1001
WORKDIR /home/openclaw

EXPOSE 18789

# Health check — OpenClaw gateway health probe
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD openclaw health --json || exit 1

ENTRYPOINT ["openclaw", "gateway", "run", "--bind", "loopback"]
