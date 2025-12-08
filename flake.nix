{
  description = "nix-envs CLI tool";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      packages.default = pkgs.buildGoModule {
        pname = "nix-envs";
        version = "0.1.0";
        src = ./.;

        vendorHash = null;

        postInstall = ''
          mv $out/bin/main $out/bin/nix-envs || true
        '';
      };

      devShells.default = pkgs.mkShell {
        name = "nix-envs-dev";
        packages = with pkgs; [
          go
          gopls
          alejandra
        ];
      };
    });
}
