{
  description = "Go 1.23.3 SDK flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        
        go_1_23_3 = pkgs.stdenv.mkDerivation {
          pname = "go";
          version = "1.23.3";
          
          src = pkgs.fetchurl {
            url = "https://go.dev/dl/go1.23.3.src.tar.gz";
            sha256 = "sha256-jWp3MySHVXxq+iQhExtQ+D20rjxXnDvHLmcO4faWhZk=";
          };

          nativeBuildInputs = [ pkgs.go_1_22 pkgs.cacert ];  # Using Go 1.20 as bootstrap
          
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
      in
      {
        packages = {
          default = go_1_23_3;
          go = go_1_23_3;
        };
      }
    );
} 