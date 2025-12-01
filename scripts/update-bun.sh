#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

JSON_FILE="$REPO_ROOT/bun/versions.json"

ensure_manifest "$JSON_FILE"

echo "Checking Bun versions..."
AUTH_HEADER=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  AUTH_HEADER=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

LATEST_TAG="$(curl -s -H 'Accept: application/vnd.github+json' "${AUTH_HEADER[@]}" https://api.github.com/repos/oven-sh/bun/releases/latest | jq -r '.tag_name')"
LATEST_VER="${LATEST_TAG#bun-v}"
LATEST_VER="${LATEST_VER#v}"

CURRENT="$(current_version "$JSON_FILE")"
if [[ "$LATEST_VER" == "$CURRENT" ]]; then
  echo "Bun is up to date ($LATEST_VER)"
  exit 0
fi

URL="https://github.com/oven-sh/bun/releases/download/bun-v${LATEST_VER}/bun-linux-x64.zip"
echo "Found new Bun ${LATEST_VER}, prefetching ${URL}"
HASH="$(prefetch "$URL")"

write_manifest "$JSON_FILE" "$LATEST_VER" "$HASH"
echo "Updated Bun manifest to ${LATEST_VER}"
