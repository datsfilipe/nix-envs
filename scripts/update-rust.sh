#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

JSON_FILE="$REPO_ROOT/rust/versions.json"

ensure_manifest "$JSON_FILE"

echo "Checking Rust versions..."
LATEST_VER="$(
  curl -s https://static.rust-lang.org/dist/channel-rust-stable.toml \
    | awk '
        /^\[pkg\.rustc\]/ { in_rustc = 1; next }
        /^\[/ { in_rustc = 0 }
        in_rustc && /^version *=/ {
          if (match($0, /"([^"]+)"/, m)) {
            split(m[1], parts, " ");
            print parts[1];
            exit;
          }
        }
      '
)"

if [[ -z "$LATEST_VER" ]]; then
  echo "Could not determine Rust version from channel file"
  exit 1
fi

CURRENT="$(current_version "$JSON_FILE")"
if [[ "$LATEST_VER" == "$CURRENT" ]]; then
  echo "Rust is up to date ($LATEST_VER)"
  exit 0
fi

URL="https://static.rust-lang.org/dist/rust-${LATEST_VER}-x86_64-unknown-linux-gnu.tar.gz"
echo "Found new Rust ${LATEST_VER}, prefetching ${URL}"
HASH="$(prefetch "$URL")"

write_manifest "$JSON_FILE" "$LATEST_VER" "$HASH"
echo "Updated Rust manifest to ${LATEST_VER}"
