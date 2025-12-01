#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

JSON_FILE="$REPO_ROOT/python/versions.json"

ensure_manifest "$JSON_FILE"

echo "Checking Python versions..."
LATEST_VER="$(
  curl -s "https://www.python.org/api/v2/downloads/release/?is_published=true" \
    | jq -r '
      map(select(.version == 3 and (.pre_release | not) and (.name | startswith("Python ")))) |
      map({version: (.name | ltrimstr("Python ")), parts: (.name | ltrimstr("Python ") | split(".") | map(tonumber))}) |
      map(select(.parts | length >= 3)) |
      sort_by(.parts) |
      last
      | .version
    '
)"

if [[ -z "$LATEST_VER" || "$LATEST_VER" == "null" ]]; then
  echo "Could not determine latest Python release"
  exit 1
fi

CURRENT="$(current_version "$JSON_FILE")"
if [[ "$LATEST_VER" == "$CURRENT" ]]; then
  echo "Python is up to date ($LATEST_VER)"
  exit 0
fi

URL="https://www.python.org/ftp/python/${LATEST_VER}/Python-${LATEST_VER}.tar.xz"
echo "Found new Python ${LATEST_VER}, prefetching ${URL}"
HASH="$(prefetch "$URL")"

write_manifest "$JSON_FILE" "$LATEST_VER" "$HASH"
echo "Updated Python manifest to ${LATEST_VER}"
