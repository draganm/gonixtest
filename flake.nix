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

        # Read latest version from JSON
        latestVersion = builtins.fromJSON (builtins.readFile ./latest-version.json);

        # Version parameters with defaults (latest stable version)
        goMajor = latestVersion.major;
        goMinor = latestVersion.minor;
        goPatch = latestVersion.patch;

        # Helper function to get SHA for a version
        getGoSha = { major, minor, patch }:
          let
            majorStr = toString major;
            minorStr = toString minor;
            patchStr = toString patch;
          in
          if builtins.hasAttr "${majorStr}.${minorStr}" goVersions then
            if builtins.hasAttr patchStr goVersions."${majorStr}.${minorStr}" then
              goVersions."${majorStr}.${minorStr}"."${patchStr}".sha256
            else throw "Unknown patch version ${patchStr} for Go ${majorStr}.${minorStr}"
          else throw "Unknown Go version ${majorStr}.${minorStr}";

        # Read version lookup map from JSON
        goVersions = builtins.fromJSON (builtins.readFile ./go-versions.json);

        # Helper function to validate version is >= 1.13
        validateVersion = { major, minor, patch }:
          if major != 1 then throw "Only Go 1.x versions are supported"
          else if minor < 13 then throw "Only Go versions >= 1.13 are supported"
          else true;

        # Function to create Go derivation
        mkGo = { major, minor, patch }:
          let
            # Convert to strings for URL and version string
            versionStr = "${toString major}.${toString minor}.${toString patch}";
            
            # Check if version is compatible with darwin_arm64
            isDarwinArm64 = system == "aarch64-darwin";
            isPreM1Version = minor < 16 || (minor == 16 && patch < 1);
            
            # Throw error for incompatible darwin_arm64 builds
            checkDarwinArm64Compatibility = 
              if isDarwinArm64 && isPreM1Version then
                throw "Go ${versionStr} does not support darwin_arm64 (Apple Silicon). Please use Go 1.16.1 or later."
              else true;
          in
          # Validate version and platform compatibility
          assert validateVersion { inherit major minor patch; };
          assert checkDarwinArm64Compatibility;
          pkgs.stdenv.mkDerivation {
            pname = "go";
            version = versionStr;

            src = pkgs.fetchurl {
              url = "https://go.dev/dl/go${versionStr}.src.tar.gz";
              sha256 = getGoSha { inherit major minor patch; };
            };

            nativeBuildInputs = [ pkgs.go_1_22 pkgs.cacert ];

            buildPhase = ''
              # Set up environment
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

        # Create a shell-specific Go version
        shellGo = mkGo {
          major = 1;
          minor = 24;
          patch = 0;
        };
      in {
        # Expose the mkGo function in lib
        lib = {
          inherit mkGo;
        };

        packages = {
          default = go;
          go = go;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [ shellGo ];
          shellHook = ''
            export PATH=${shellGo}/bin:$PATH
          '';
        };
      });
}
