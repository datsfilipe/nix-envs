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

        nodePkgs =
          if pkgs ? nodePackages_latest
          then pkgs.nodePackages_latest
          else pkgs.nodePackages;

        nodeTools =
          [
            nodePkgs.typescript-language-server
            nodePkgs.typescript
            nodePkgs.prettier
          ]
          ++ pkgs.lib.optional (pkgs.lib.hasAttrByPath ["@biomejs/biome"] nodePkgs) nodePkgs."@biomejs/biome";

        goTools = [pkgs.gopls];
        rustTools = [pkgs.rust-analyzer];

        pythonTools =
          let
            py = pkgs.python3Packages;
          in
            [py.python-lsp-server] ++ pkgs.lib.optional (pkgs.lib.hasAttr "pylsp-rope" py) py.pylsp-rope;

        solidityTools = pkgs.lib.optional (pkgs ? nomicfoundation-solidity-language-server) pkgs.nomicfoundation-solidity-language-server;

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
            packages = nodeTools;
          };

          rust = mkShellWith {
            base = baseRust;
            packages = rustTools;
          };

          go = mkShellWith {
            base = baseGo;
            packages = goTools;
          };

          python = mkShellWith {
            base = basePython;
            packages = pythonTools;
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
            packages = solidityTools;
          };

          default = mkShellWith {};
        };
      }
    );
}
