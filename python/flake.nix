{
  description = "Dynamic Python environments";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {self, nixpkgs, flake-utils}:
    let
      manifest = builtins.fromJSON (builtins.readFile ./versions.json);
      sanitize = v: "v" + builtins.replaceStrings ["."] ["-"] v;

      mkPython = pkgs: version: hash:
        pkgs.stdenv.mkDerivation {
          pname = "python";
          inherit version;

          src = pkgs.fetchurl {
            url = "https://www.python.org/ftp/python/${version}/Python-${version}.tar.xz";
            sha256 = hash;
          };

          nativeBuildInputs = [pkgs.pkg-config pkgs.autoconf];
          buildInputs = with pkgs; [
            bzip2
            expat
            gdbm
            libffi
            libnsl
            libuuid
            ncurses
            openssl
            readline
            sqlite
            util-linux
            xz
            zlib
          ];

          configureFlags = [
            "--enable-optimizations"
            "--with-ensurepip=install"
          ];

          doCheck = false;
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
              name = "python-${version}";
              packages = [(mkPython pkgs version hash)];
              shellHook = "echo \"Python ${version} ready\"";
            }))
          manifest.versions;

        defaultName = sanitize manifest.latest;
      in {
        devShells = shells // {default = shells.${defaultName};};
      });
}
