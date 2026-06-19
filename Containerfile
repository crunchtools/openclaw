# OpenClaw — Crunchtools Autonomous Agent
# General-purpose AI assistant with Signal integration, running under
# the crunchtools Autonomous Agent constitution profile.
#
# Build:
#   podman build -t quay.io/crunchtools/openclaw .
#
# Run:
#   podman run -d --name openclaw \
#     --read-only --tmpfs /tmp:rw,nosuid \
#     -p 127.0.0.1:18789:18789 \
#     -v /srv/openclaw.crunchtools.com/data/openclaw:/app/.openclaw:Z \
#     -v /srv/openclaw.crunchtools.com/signal/data:/app/.local/share/signal-cli:Z \
#     -v /srv/openclaw.crunchtools.com/logs:/app/logs:Z \
#     --env-file /srv/openclaw.crunchtools.com/config/env \
#     quay.io/crunchtools/openclaw

# Stage 1: Install OpenClaw and dependencies
# Use UBI 10 Minimal as builder — Hummingbird lacks git which
# OpenClaw's npm dependencies require for installation
FROM registry.access.redhat.com/ubi10/ubi-minimal AS builder

RUN microdnf install -y nodejs npm git tar gzip && microdnf clean all

WORKDIR /build

# Install OpenClaw at a pinned version — update this on upgrades
# --legacy-peer-deps on the in-package overrides: re-resolving OpenClaw's dev
# tree otherwise fails on an upstream peer conflict (oxlint vs oxlint-tsgolint).
RUN npm install --global --prefix /build/install openclaw@2026.6.8 && \
    cd /build/install/lib/node_modules/openclaw && \
    npm install @hono/node-server@1.19.10 --save --legacy-peer-deps && \
    npm install tar@7.5.11 --legacy-peer-deps && \
    npm install fast-xml-parser@5.5.6 --legacy-peer-deps && \
    npm install glob@10.5.0 --legacy-peer-deps && \
    npm install minimatch@9.0.7 --legacy-peer-deps && \
    npm install undici@8.5.0 --legacy-peer-deps && \
    find node_modules -mindepth 3 -path "*/@hono/node-server" -type d -exec rm -rf {} +

# Install mcporter — MCP server client, required for OpenClaw's mcporter skill
# NOT bundled as an OpenClaw dependency; must be installed separately
ARG MCPORTER_VERSION=0.7.3
RUN npm install --global --prefix /build/mcporter mcporter@${MCPORTER_VERSION}

# Install the Matrix channel plugin as a BUNDLED OpenClaw extension (pinned).
# Same bundling rationale as clawphone: read-only + npm-stripped runtime image.
# Matrix uses the official matrix-js-sdk for DMs, rooms, threads, media,
# reactions, and E2EE. Ships DISABLED; enable + configure in openclaw.json.
# Re-vet on every version bump.
ARG MATRIX_VERSION=2026.6.8
RUN npm install --prefix /build/matrix @openclaw/matrix@${MATRIX_VERSION} --legacy-peer-deps && \
    mkdir -p /build/matrix-ext && \
    cp -aL /build/matrix/node_modules/@openclaw/matrix/. /build/matrix-ext/ && \
    cp -aL /build/matrix/node_modules /build/matrix-ext/node_modules

# Download signal-cli native binary (GraalVM, no JVM required)
ARG SIGNAL_CLI_VERSION=0.14.0
RUN curl -sL "https://github.com/AsamK/signal-cli/releases/download/v${SIGNAL_CLI_VERSION}/signal-cli-${SIGNAL_CLI_VERSION}-Linux-native.tar.gz" \
    -o /tmp/signal-cli.tar.gz && \
    mkdir -p /build/signal-cli/bin && \
    tar xf /tmp/signal-cli.tar.gz -C /build/signal-cli/bin && \
    chmod +x /build/signal-cli/bin/signal-cli && \
    rm /tmp/signal-cli.tar.gz

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

# Bundle the Matrix channel plugin into the stock extensions directory.
# Ships DISABLED — enable + configure (homeserver, accessToken, DM policy)
# via openclaw.json.
COPY --from=builder /build/matrix-ext /app/lib/node_modules/openclaw/dist/extensions/matrix

# Copy signal-cli native binary
COPY --from=builder /build/signal-cli /app/signal-cli

# Copy mcporter
COPY --from=builder /build/mcporter /app/mcporter

# Remove npm/npx from the runtime — OpenClaw needs only the `node` runtime to
# run; npm is a build-time package manager. Takeda launches MCP servers over
# HTTP (no npx/stdio), and the image is read-only with deps baked in, so npm is
# never invoked at runtime. Dropping it eliminates the base image's bundled-npm
# CVEs (e.g. picomatch ReDoS) and shrinks the attack surface.
#
# Why strip rather than pick an npm-less base: npm ships inside the Node.js RPM
# in EVERY Hummingbird nodejs variant — confirmed via the catalog SBOM, the
# distroless `default` runtime still lists @npmcli/* as runtime packages. There
# is no npm-less Node runtime image to switch to, and the distroless runtime has
# no dnf to remove it cleanly, so stripping the npm dir + symlinks post-COPY is
# the correct (and only) way to get an npm-free Node runtime.
#
# Briefly switch to root to delete the root-owned base-image files, then
# restore the non-root runtime user (65532).
USER root
RUN rm -rf /usr/lib/node_modules_22/npm \
           /usr/bin/npm /usr/bin/npx \
           /usr/sbin/npm /usr/sbin/npx && \
    find /app -type f \( -name "tsgolint" -o -name "tsgo" \) -delete
USER 65532

ENV PATH="/app/bin:/app/mcporter/bin:/app/signal-cli/bin:${PATH}" \
    NODE_ENV=production \
    HOME=/app

EXPOSE 18789

# Health check — OpenClaw gateway health probe
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD openclaw health --json || exit 1

# Bind 0.0.0.0 inside container — host-side restriction is handled by
# podman's -p 127.0.0.1:18789:18789 (loopback-only on the host).
# Using --bind loopback here would bind to the container's own 127.0.0.1,
# which is unreachable through bridge networking's DNAT port mapping.
ENTRYPOINT ["openclaw", "gateway", "run", "--bind", "lan"]
