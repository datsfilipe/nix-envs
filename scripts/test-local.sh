#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-nodejs}"

echo "Testing flake in ${TARGET_DIR}"

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Directory ${TARGET_DIR} does not exist"
  exit 1
fi

if [[ "$TARGET_DIR" == "tools" ]]; then
  rm -f "./${TARGET_DIR}/flake.lock"
  echo "Running nix flake check (no lock write, overriding sibling inputs)..."
  nix flake check "./${TARGET_DIR}" \
    --extra-experimental-features "nix-command flakes" \
    --no-write-lock-file \
    --override-input nodejs ./nodejs \
    --override-input go ./go \
    --override-input rust ./rust \
    --override-input python ./python \
    --override-input bun ./bun
else
  echo "Running nix flake check..."
  nix flake check "./${TARGET_DIR}" --extra-experimental-features "nix-command flakes"
fi

echo "Verifying devShell evaluation..."
nix eval "./${TARGET_DIR}#devShells.x86_64-linux.default.outPath" --raw \
  ${TARGET_DIR:+} \
  $(if [[ "$TARGET_DIR" == "tools" ]]; then
      printf -- "--no-write-lock-file --override-input nodejs ./nodejs --override-input go ./go --override-input rust ./rust --override-input python ./python --override-input bun ./bun"
    fi) >/dev/null

if [[ "$TARGET_DIR" == "tools" ]]; then
  rm -f "./${TARGET_DIR}/flake.lock"
fi

echo "Test passed for ${TARGET_DIR}"
