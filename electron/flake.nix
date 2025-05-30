{
  description = "dats electron shell";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};

      inputs = with pkgs; [
        electron
      ];
    in
      with pkgs; {
        devShells.default = mkShell {
          name = "electron";
          packages = inputs;
        };
      });
}
