#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

ensure_manifest() {
  local manifest_path="$1"
  mkdir -p "$(dirname "$manifest_path")"

  if [[ ! -f "$manifest_path" ]]; then
    echo '{"latest": "", "versions": {}}' >"$manifest_path"
  fi
}

current_version() {
  local manifest_path="$1"
  jq -r '.latest // ""' "$manifest_path"
}

write_manifest() {
  local manifest_path="$1"
  local version="$2"
  local hash="$3"

  jq --arg v "$version" --arg h "$hash" \
    '.latest = $v | .versions[$v] = $h' \
    "$manifest_path" >"${manifest_path}.tmp"

  mv "${manifest_path}.tmp" "$manifest_path"
}

prefetch() {
  local url="$1"
  nix-prefetch-url "$url"
}
