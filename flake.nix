{
  description = "Parameterized Go SDK flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Version parameters with defaults
        goMajor = "1";
        goMinor = "23";
        goPatch = "3";

        # Derived full version
        goVersion = "${goMajor}.${goMinor}.${goPatch}";

        # Function to create Go derivation
        mkGo = { major, minor, patch }:
          pkgs.stdenv.mkDerivation {
            pname = "go";
            version = "${major}.${minor}.${patch}";

            src = pkgs.fetchurl {
              url = "https://go.dev/dl/go${major}.${minor}.${patch}.src.tar.gz";
              # Note: sha256 will need to be updated for different versions
              sha256 = "sha256-jWp3MySHVXxq+iQhExtQ+D20rjxXnDvHLmcO4faWhZk=";
            };

            nativeBuildInputs =
              [ pkgs.go_1_22 pkgs.cacert ]; # Using Go 1.22 as bootstrap

            buildPhase = ''
              export GOROOT_BOOTSTRAP=${pkgs.go_1_22}/share/go
              export GOCACHE=$TMPDIR/go-cache
              export GOROOT_FINAL=$out/share/go
              cd src
              ./make.bash
            '';

            installPhase = ''
              cd ..
              mkdir -p $out/bin $out/share
              cp -r . $out/share/go
              ln -s $out/share/go/bin/go $out/bin/
              ln -s $out/share/go/bin/gofmt $out/bin/
            '';

            meta = with pkgs.lib; {
              description = "The Go Programming language";
              homepage = "https://go.dev/";
              license = licenses.bsd3;
              platforms = platforms.unix;
            };
          };

        # Create the Go derivation with specified version
        go = mkGo {
          major = goMajor;
          minor = goMinor;
          patch = goPatch;
        };
      in {
        packages = {
          default = go;
          go = go;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [ go ];
          shellHook = ''
            export PATH=${go}/bin:$PATH
          '';
        };
      });
}
