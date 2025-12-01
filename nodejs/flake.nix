{
  description = "Dynamic Node.js environments";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {self, nixpkgs, flake-utils}:
    let
      manifest = builtins.fromJSON (builtins.readFile ./versions.json);
      sanitize = v: "v" + builtins.replaceStrings ["."] ["-"] v;

      mkNode = pkgs: version: hash:
        pkgs.stdenv.mkDerivation {
          pname = "nodejs-custom";
          inherit version;

          src = pkgs.fetchurl {
            url = "https://nodejs.org/dist/v${version}/node-v${version}-linux-x64.tar.xz";
            sha256 = hash;
          };

          dontConfigure = true;
          dontBuild = true;
          nativeBuildInputs = [pkgs.autoPatchelfHook pkgs.gnutar pkgs.xz];
          buildInputs = [pkgs.stdenv.cc.cc.lib];

          installPhase = ''
            mkdir -p "$out"
            cp -r bin include lib share "$out"/
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
              name = "nodejs-${version}";
              packages = [(mkNode pkgs version hash)];
              shellHook = "echo \"Node.js ${version} ready\"";
            }))
          manifest.versions;

        defaultName = sanitize manifest.latest;
      in {
        devShells = shells // {default = shells.${defaultName};};
      });
}
