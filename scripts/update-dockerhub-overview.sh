#!/bin/bash
# ============================================================
# update-dockerhub-overview.sh
# Extracts bundled versions from the built Docker image and
# updates docs/DOCKERHUB_OVERVIEW.md automatically.
#
# Usage:
#   ./scripts/update-dockerhub-overview.sh [image:tag]
#
# Default image: neoplanetz/openclaw-desktop-docker:latest
# ============================================================
set -e

IMAGE="${1:-neoplanetz/openclaw-desktop-docker:latest}"
OVERVIEW="$(cd "$(dirname "$0")/.." && pwd)/docs/DOCKERHUB_OVERVIEW.md"

echo ">> Extracting versions from ${IMAGE}..."

# Force amd64 when extracting Chrome — on arm64 the same binary name
# resolves to Chromium, which would land in the amd64 version row.
OC_VER=$(docker run --rm --platform linux/amd64 --entrypoint="" "${IMAGE}" cat /etc/openclaw-version 2>/dev/null) \
    || OC_VER=$(docker run --rm --platform linux/amd64 --entrypoint="" "${IMAGE}" sh -c "npm list -g openclaw --depth=0 2>/dev/null | grep -oP 'openclaw@\K[^\s]+'" 2>/dev/null) \
    || OC_VER="unknown"
NODE_VER=$(docker run --rm --platform linux/amd64 --entrypoint="" "${IMAGE}" node --version 2>/dev/null || echo "unknown")
CHROME_VER=$(docker run --rm --platform linux/amd64 --entrypoint="" "${IMAGE}" google-chrome-stable-real --version 2>/dev/null | awk '{print $NF}' || echo "unknown")

# Chromium version may legitimately be unknown on an amd64-only host if the
# arm64 manifest hasn't been pulled; treat it as optional.
CHROMIUM_VER=$(docker run --rm --platform linux/arm64 --entrypoint="" "${IMAGE}" google-chrome-stable-real --version 2>/dev/null | awk '{print $2}' || true)
CHROMIUM_VER="${CHROMIUM_VER:-unknown}"

echo "   OpenClaw : ${OC_VER}"
echo "   Node.js  : ${NODE_VER}"
echo "   Chrome   (amd64): ${CHROME_VER}"
echo "   Chromium (arm64): ${CHROMIUM_VER}"

if [ ! -f "${OVERVIEW}" ]; then
    echo "ERROR: ${OVERVIEW} not found"
    exit 1
fi

# Update the Bundled Versions table. Row labels carry the `(amd64)` /
# `(arm64)` suffix since v1.3.0, so the patterns must tolerate it.
sed -i "s/| \*\*OpenClaw\*\* | \`[^\`]*\` |/| **OpenClaw** | \`${OC_VER}\` |/" "${OVERVIEW}"
sed -i "s/| \*\*Node.js\*\* | \`[^\`]*\` |/| **Node.js** | \`${NODE_VER}\` |/" "${OVERVIEW}"
sed -i "s/| \*\*Google Chrome\*\*[^|]*| \`[^\`]*\` |/| **Google Chrome** (amd64) | \`${CHROME_VER}\` |/" "${OVERVIEW}"
if [ "${CHROMIUM_VER}" != "unknown" ]; then
    sed -i "s/| \*\*Chromium\*\*[^|]*| \`[^\`]*\`[^|]*|/| **Chromium** (arm64) | \`${CHROMIUM_VER}\` (from \`ppa:xtradeb\/apps\`) |/" "${OVERVIEW}"
fi

echo ""
echo ">> Updated ${OVERVIEW}"
echo "   Copy its contents to Docker Hub repository overview."
