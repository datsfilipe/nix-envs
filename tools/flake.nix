{
  description = "Development tooling shells (aligned with dynamic language envs)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    nodejs.url = "path:../nodejs";
    go.url = "path:../go";
    rust.url = "path:../rust";
    python.url = "path:../python";
    bun.url = "path:../bun";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    nodejs,
    go,
    rust,
    python,
    bun,
  }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        baseNode = nodejs.devShells.${system}.default;
        baseGo = go.devShells.${system}.default;
        baseRust = rust.devShells.${system}.default;
        basePython = python.devShells.${system}.default;
        baseBun = bun.devShells.${system}.default;

        mkShellWith = {
          base ? null,
          packages ? [],
          shellHook ? "",
        }:
          pkgs.mkShell {
            inherit shellHook;
            inputsFrom = pkgs.lib.optionals (base != null) [base];
            inherit packages;
          };
      in {
        devShells = {
          general = mkShellWith {
            packages = with pkgs; [
              vscode-langservers-extracted
              codespell
            ];
          };

          typescript = mkShellWith {
            base = baseNode;
            shellHook = ''
              set -euo pipefail
              project_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
              export NPM_CONFIG_PREFIX="$project_root/.tools/node"
              export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"
              export NODE_PATH="$NPM_CONFIG_PREFIX/lib/node_modules"

              need_install=0
              for pkg in typescript-language-server typescript prettier @biomejs/biome; do
                if ! npm list -g "$pkg" --depth=0 >/dev/null 2>&1; then
                  need_install=1
                  break
                fi
              done

              if [ "$need_install" -eq 1 ]; then
                echo "Installing TypeScript tooling with npm..."
                npm install -g typescript-language-server typescript prettier @biomejs/biome
              fi
            '';
          };

          rust = mkShellWith {
            base = baseRust;
            shellHook = ''
              set -euo pipefail
              project_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
              export CARGO_HOME="$project_root/.tools/rust/cargo"
              export PATH="$project_root/.tools/rust/bin:$PATH"

              if ! command -v rust-analyzer >/dev/null 2>&1; then
                echo "Installing rust-analyzer with cargo..."
                mkdir -p "$project_root/.tools/rust/bin"
                cargo install rust-analyzer --locked --git https://github.com/rust-lang/rust-analyzer --tag 2024-11-25
              fi
            '';
          };

          go = mkShellWith {
            base = baseGo;
            shellHook = ''
              set -euo pipefail
              project_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
              export GOBIN="$project_root/.tools/go/bin"
              export PATH="$GOBIN:$PATH"

              if ! command -v gopls >/dev/null 2>&1; then
                echo "Installing gopls with go install..."
                go install golang.org/x/tools/gopls@latest
              fi
            '';
          };

          python = mkShellWith {
            base = basePython;
            shellHook = ''
              set -euo pipefail
              project_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
              export PYTHONUSERBASE="$project_root/.tools/python"
              export PATH="$PYTHONUSERBASE/bin:$PATH"

              if ! command -v pylsp >/dev/null 2>&1; then
                echo "Installing python-lsp-server with pip..."
                pip install --user "python-lsp-server[rope,pyflakes]"
              fi
            '';
          };

          bun = mkShellWith {
            base = baseBun;
          };

          lua = mkShellWith {
            packages = with pkgs; [
              lua-language-server
              stylua
            ];
          };

          nix = mkShellWith {
            packages = [pkgs.alejandra];
          };

          solidity = mkShellWith {
            base = baseNode;
            shellHook = ''
              if ! command -v npm &>/dev/null; then
                echo "[WARN]: npm is not enabled in current shell, skipping solidity-language-server install"
                exit 0
              fi

              project_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
              export NODE_PATH="$project_root/node_modules/.global/lib/node_modules"
              export NPM_CONFIG_PREFIX="$project_root/node_modules/.global"
              export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"

              if ! npm list -g @nomicfoundation/solidity-language-server &>/dev/null; then
                echo "adding solidity-language-server..."
                npm install -g @nomicfoundation/solidity-language-server
              fi
            '';
          };

          default = mkShellWith {};
        };
      }
    );
}
