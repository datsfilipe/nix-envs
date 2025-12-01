# nix-envs

Zero-config Nix development shells that you select via the flake URL fragment (e.g. `#v25-2-1`).

## Usage

- Node.js: `use flake "github:datsfilipe/nix-envs?dir=nodejs#v25-2-1"`
- Go: `use flake "github:datsfilipe/nix-envs?dir=go#v1-25-4"`
- Rust: `use flake "github:datsfilipe/nix-envs?dir=rust#v1-91-1"`
- Python: `use flake "github:datsfilipe/nix-envs?dir=python#v3-14-0"`
- Bun: `use flake "github:datsfilipe/nix-envs?dir=bun#v1-3-3"`
- Tools (static helpers like LSPs): `use flake "github:datsfilipe/nix-envs?dir=tools#rust"`

Versions are declared in `*/versions.json` and exposed as devShell names formatted as `v<major>-<minor>-<patch>`. Each directory still exposes `#default` as the latest entry in its manifest.

## Automation

- `scripts/update-*.sh`: fetches the latest upstream versions and updates `versions.json` (uses `nix-prefetch-url`).
- `scripts/test-local.sh <dir>`: quick check that a flake evaluates (`nix flake check` + `nix eval`).
- `.github/workflows/update-versions.yml`: cron (Wed/Sat @ 00:00 UTC) + manual dispatch to refresh manifests and commit them.
- `.github/workflows/test.yml`: CI smoke test across the dynamic flakes.

## Templates

Directories double as flake templates: `nodejs`, `go`, `rust`, `python`, `bun`, `crystal`, `elixir`, `electron`, `prisma`, `git-hooks`, `tools`, `work`.
