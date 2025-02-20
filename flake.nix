{
  description = "Nix powered development environment templates";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: rec {
    templates = {
      nodejs = {
        path = ./nodejs;
        description = "NodeJS template";
      };

      bun = {
        path = ./bun;
        description = "Bun template";
      };

      python = {
        path = ./nodejs;
        description = "NodeJS template";
      };

      go = {
        path = ./go;
        description = "Golang template";
      };

      golang = templates.go;

      crystal = {
        path = ./crystal;
        description = "Crystal template";
      };

      rust = {
        path = ./rust;
        description = "Rust template";
      };

      electron = {
        path = ./electron;
        description = "Electron template";
      };

      elixir = {
        path = ./elixir;
        description = "Elixir template";
      };

      qmk = {
        path = ./qmk;
        description = "QMK template";
      };

      prisma = {
        path = ./prisma;
        description = "Prisma template";
      };

      git-hooks = {
        path = ./git-hooks;
        description = "Git hooks template";
      };
    };

    devShells.x86_64-linux = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in {
      default = pkgs.mkShell {
        packages = with pkgs; [
          alejandra
        ];
        name = "nix-envs";
      };
    };

    formatter = let
      system = "x86_64-linux";
    in
      nixpkgs.legacyPackages.${system}.alejandra;
  };
}
