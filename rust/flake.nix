{
  description = "Dynamic Rust environments";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {self, nixpkgs, flake-utils}:
    let
      manifest = builtins.fromJSON (builtins.readFile ./versions.json);
      sanitize = v: "v" + builtins.replaceStrings ["."] ["-"] v;

      mkRust = pkgs: version: hash:
        pkgs.stdenv.mkDerivation {
          pname = "rust-custom";
          inherit version;

          src = pkgs.fetchurl {
            url = "https://static.rust-lang.org/dist/rust-${version}-x86_64-unknown-linux-gnu.tar.gz";
            sha256 = hash;
          };

          dontConfigure = true;
          dontBuild = true;
          nativeBuildInputs = [pkgs.autoPatchelfHook pkgs.gnutar pkgs.gzip pkgs.xz];
          buildInputs = [pkgs.stdenv.cc.cc.lib pkgs.zlib];

          installPhase = ''
            ./install.sh --prefix="$out" --disable-ldconfig \
              --components=rustc,cargo,rust-std-x86_64-unknown-linux-gnu
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
              name = "rust-${version}";
              packages = [(mkRust pkgs version hash)];
              shellHook = "echo \"Rust ${version} ready\"";
            }))
          manifest.versions;

        defaultName = sanitize manifest.latest;
      in {
        devShells = shells // {default = shells.${defaultName};};
      });
}
