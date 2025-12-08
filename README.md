# nix-envs

A CLI tool for managing dynamic, stackable Nix development environments. It generates flakes in your local cache (`~/.cache/envs`) and links them via `direnv` to keep your project directories clean.

## Installation

**Using Nix:**
```bash
nix profile install github:datsfilipe/nix-envs
```

## Manual Build:

```bash
git clone [https://github.com/datsfilipe/nix-envs.git](https://github.com/datsfilipe/nix-envs.git) && cd nix-envs
go build -o nix-envs main.go && sudo mv nix-envs /usr/local/bin/
```

## Usage

```bash
# Create specific environments (Node fetches exact binaries from nodejs.org)
nix-envs create nodejs 20.11.0
nix-envs create go 1.22
nix-envs create rust 1.75.0

# Manage environments
nix-envs edit nodejs     # Open flake in $EDITOR
nix-envs delete nodejs   # Remove env and clean .envrc
```

Supported Templates: `nodejs`, `go`, `rust`, `python`, `bun`, `crystal`, `electron`, `elixir`.

## License

[MIT](./LICENSE)
