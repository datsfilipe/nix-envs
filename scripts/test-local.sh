#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-nodejs}"

echo "Testing flake in ${TARGET_DIR}"

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Directory ${TARGET_DIR} does not exist"
  exit 1
fi

echo "Running nix flake check..."
nix flake check "./${TARGET_DIR}" --extra-experimental-features "nix-command flakes"

echo "Verifying devShell evaluation..."
nix eval "./${TARGET_DIR}#devShells.x86_64-linux.default.outPath" --raw >/dev/null

echo "Test passed for ${TARGET_DIR}"
