{
  description = "Dynamic Go environments";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {self, nixpkgs, flake-utils}:
    let
      manifest = builtins.fromJSON (builtins.readFile ./versions.json);
      sanitize = v: "v" + builtins.replaceStrings ["."] ["-"] v;

      mkGo = pkgs: version: hash:
        pkgs.stdenv.mkDerivation {
          pname = "go-custom";
          inherit version;

          src = pkgs.fetchurl {
            url = "https://go.dev/dl/go${version}.linux-amd64.tar.gz";
            sha256 = hash;
          };

          dontConfigure = true;
          dontBuild = true;
          nativeBuildInputs = [pkgs.autoPatchelfHook pkgs.gnutar pkgs.gzip];
          buildInputs = [pkgs.stdenv.cc.cc.lib];

          installPhase = ''
            mkdir -p "$out"
            cp -r ./* "$out"/
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
              name = "go-${version}";
              packages = [(mkGo pkgs version hash)];
              shellHook = "echo \"Go ${version} ready\"";
            }))
          manifest.versions;

        defaultName = sanitize manifest.latest;
      in {
        devShells = shells // {default = shells.${defaultName};};
      });
}
