{
  description = "Dynamic Bun environments";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {self, nixpkgs, flake-utils}:
    let
      manifest = builtins.fromJSON (builtins.readFile ./versions.json);
      sanitize = v: "v" + builtins.replaceStrings ["."] ["-"] v;

      mkBun = pkgs: version: hash:
        pkgs.stdenv.mkDerivation {
          pname = "bun";
          inherit version;

          src = pkgs.fetchurl {
            url = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-linux-x64.zip";
            sha256 = hash;
          };

          dontConfigure = true;
          dontBuild = true;
          nativeBuildInputs = [pkgs.unzip pkgs.autoPatchelfHook];
          buildInputs = [pkgs.stdenv.cc.cc.lib];

          installPhase = ''
            mkdir -p "$out/bin"
            install -m755 bun "$out/bin/bun"
          '';
        };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        shells =
          pkgs.lib.mapAttrs'
          (version: hash:
            pkgs.lib.nameValuePair
            (sanitize version)
            (pkgs.mkShell {
              name = "bun-${version}";
              packages = [(mkBun pkgs version hash)];
              shellHook = "echo \"Bun ${version} ready\"";
            }))
          manifest.versions;

        defaultName = sanitize manifest.latest;
      in {
        devShells = shells // {default = shells.${defaultName};};
      });
}
