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

OC_VER=$(docker run --rm --entrypoint="" "${IMAGE}" cat /etc/openclaw-version 2>/dev/null) \
    || OC_VER=$(docker run --rm --entrypoint="" "${IMAGE}" sh -c "npm list -g openclaw --depth=0 2>/dev/null | grep -oP 'openclaw@\K[^\s]+'" 2>/dev/null) \
    || OC_VER="unknown"
NODE_VER=$(docker run --rm --entrypoint="" "${IMAGE}" node --version 2>/dev/null || echo "unknown")
CHROME_VER=$(docker run --rm --entrypoint="" "${IMAGE}" google-chrome-stable-real --version 2>/dev/null | awk '{print $NF}' || echo "unknown")

echo "   OpenClaw : ${OC_VER}"
echo "   Node.js  : ${NODE_VER}"
echo "   Chrome   : ${CHROME_VER}"

if [ ! -f "${OVERVIEW}" ]; then
    echo "ERROR: ${OVERVIEW} not found"
    exit 1
fi

# Update the Bundled Versions table in DOCKERHUB_OVERVIEW.md
sed -i "s/| \*\*OpenClaw\*\* | \`[^\`]*\` |/| **OpenClaw** | \`${OC_VER}\` |/" "${OVERVIEW}"
sed -i "s/| \*\*Node.js\*\* | \`[^\`]*\` |/| **Node.js** | \`${NODE_VER}\` |/" "${OVERVIEW}"
sed -i "s/| \*\*Google Chrome\*\* | \`[^\`]*\` |/| **Google Chrome** | \`${CHROME_VER}\` |/" "${OVERVIEW}"

echo ""
echo ">> Updated ${OVERVIEW}"
echo "   Copy its contents to Docker Hub repository overview."
