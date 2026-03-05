#!/bin/bash
# Setup script for OpenClaw on Lotor
# Run once on lotor.dc3.crunchtools.com to create directory structure
#
# Usage: sudo bash setup-lotor.sh

set -euo pipefail

SERVICE_DIR="/srv/openclaw.crunchtools.com"
OPENCLAW_UID=65532

echo "Creating directory structure at ${SERVICE_DIR}..."

mkdir -p "${SERVICE_DIR}/config"
mkdir -p "${SERVICE_DIR}/data/openclaw"
mkdir -p "${SERVICE_DIR}/logs/audit"
mkdir -p "${SERVICE_DIR}/signal/data"

# Copy config template if env file doesn't exist
if [ ! -f "${SERVICE_DIR}/config/env" ]; then
    cp "$(dirname "$0")/env.example" "${SERVICE_DIR}/config/env"
    chmod 600 "${SERVICE_DIR}/config/env"
    echo "Created ${SERVICE_DIR}/config/env — edit with real credentials"
fi

# Copy OpenClaw config
cp "$(dirname "$0")/openclaw.json5" "${SERVICE_DIR}/config/openclaw.json5"

# Set ownership for container user (UID 1001)
chown -R ${OPENCLAW_UID}:${OPENCLAW_UID} "${SERVICE_DIR}/data"
chown -R ${OPENCLAW_UID}:${OPENCLAW_UID} "${SERVICE_DIR}/logs"

echo "Directory structure created."
echo ""
echo "Next steps:"
echo "  1. Edit ${SERVICE_DIR}/config/env with real API keys"
echo "  2. Copy systemd units:"
echo "     cp config/openclaw.crunchtools.com.service /etc/systemd/system/"
echo "     cp config/signal-api.crunchtools.com.service /etc/systemd/system/"
echo "  3. systemctl daemon-reload"
echo "  4. Register Signal (run signal-api in native mode first):"
echo "     podman run --rm -p 127.0.0.1:8093:8080 \\"
echo "       -v ${SERVICE_DIR}/signal/data:/home/.local/share/signal-cli:Z \\"
echo "       -e MODE=native docker.io/bbernhard/signal-cli-rest-api:latest"
echo "     Then: curl http://127.0.0.1:8093/v1/qrcodelink?device_name=OpenClaw"
echo "  5. systemctl enable --now signal-api.crunchtools.com.service"
echo "  6. systemctl enable --now openclaw.crunchtools.com.service"
