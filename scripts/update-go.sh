#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

JSON_FILE="$REPO_ROOT/go/versions.json"

ensure_manifest "$JSON_FILE"

echo "Checking Go versions..."
RAW_VERSION="$(curl -s 'https://go.dev/dl/?mode=json' | jq -r '[.[] | select(.stable == true)][0].version')"
LATEST_VER="${RAW_VERSION#go}"

CURRENT="$(current_version "$JSON_FILE")"
if [[ "$LATEST_VER" == "$CURRENT" ]]; then
  echo "Go is up to date ($LATEST_VER)"
  exit 0
fi

URL="https://go.dev/dl/go${LATEST_VER}.linux-amd64.tar.gz"
echo "Found new Go ${LATEST_VER}, prefetching ${URL}"
HASH="$(prefetch "$URL")"

write_manifest "$JSON_FILE" "$LATEST_VER" "$HASH"
echo "Updated Go manifest to ${LATEST_VER}"
