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
        }:
          pkgs.mkShell {
            inherit packages;
            shellHook = ''
              ${builtins.concatStringsSep "\n" (builtins.attrValues (builtins.mapAttrs (k: v: "export ${k}=${v}") env))}
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
        };

        devShells.default = mkDevShell {
          packages = with pkgs; [];
        };
      }
    );
}
