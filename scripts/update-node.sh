#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

JSON_FILE="$REPO_ROOT/nodejs/versions.json"

ensure_manifest "$JSON_FILE"

echo "Checking Node.js versions..."
LATEST_VER="$(curl -s https://nodejs.org/dist/index.json | jq -r '.[0].version' | sed 's/^v//')"

CURRENT="$(current_version "$JSON_FILE")"
if [[ "$LATEST_VER" == "$CURRENT" ]]; then
  echo "Node.js is up to date ($LATEST_VER)"
  exit 0
fi

URL="https://nodejs.org/dist/v${LATEST_VER}/node-v${LATEST_VER}-linux-x64.tar.xz"
echo "Found new Node.js ${LATEST_VER}, prefetching ${URL}"
HASH="$(prefetch "$URL")"

write_manifest "$JSON_FILE" "$LATEST_VER" "$HASH"
echo "Updated Node.js manifest to ${LATEST_VER}"
