{
  description = "Development environment flakes";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};

        mkDevShell = {
          packages ? [],
          env ? {},
          shellHook ? "",
        }:
          pkgs.mkShell {
            inherit packages;
            shellHook = ''
              ${builtins.concatStringsSep "\n" (builtins.attrValues (builtins.mapAttrs (k: v: "export ${k}=${v}") env))}
              ${shellHook}
              echo "env is ready!"
            '';
          };
      in {
        devShells = {
          general = mkDevShell {
            packages = with pkgs; [
              vscode-langservers-extracted
              codespell
            ];
          };

          typescript = mkDevShell {
            packages = with pkgs; [
              nodePackages.typescript-language-server
              nodePackages.prettier
              biome
            ];
          };

          rust = mkDevShell {
            packages = with pkgs; [
              rust-analyzer
            ];
          };

          go = mkDevShell {
            packages = with pkgs; [
              gopls
            ];
          };

          lua = mkDevShell {
            packages = with pkgs; [
              lua-language-server
              stylua
            ];
          };

          nix = mkDevShell {
            packages = with pkgs; [
              alejandra
            ];
          };

          solidity = mkDevShell {
            shellHook = ''
              if ! command -v npm &>/dev/null; then
                echo -e "\033[33m[WARN]: npm is not enabled in current shell, skipping...\033[0m"
                exit 0
              fi

              project_root=$(git rev-parse --show-toplevel 2>/dev/null)
              export NODE_PATH="$project_root/node_modules/.global/lib/node_modules"

              if [ -z "$project_root" ]; then
                project_root=$(pwd)
              fi

              export NPM_CONFIG_PREFIX="$project_root/node_modules/.global"
              export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"

              if ! npm list -g @nomicfoundation/solidity-language-server &>/dev/null; then
                echo "adding solidity-language-server..."
                npm install -g @nomicfoundation/solidity-language-server
              fi
            '';
          };
        };

        devShells.default = mkDevShell {
          packages = with pkgs; [];
        };
      }
    );
}
