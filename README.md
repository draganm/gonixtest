# Go Version Manager Flake

This Nix flake provides a flexible way to build and use different versions of Go. It automatically tracks the latest stable Go version and supports building any Go version from 1.13 onwards.

## Features

- Automatically tracks the latest stable Go version
- Supports building any Go version >= 1.13
- Provides proper Apple Silicon (M1/M2) support for Go versions >= 1.16.1
- Uses SRI hashes for reproducible builds
- Maintains a version database with SHA256 hashes

## Usage

### As a Development Shell

To use this flake in your project for development:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    goenv.url = "path/to/this/flake"; # Replace with your actual flake URL
  };

  outputs = { self, nixpkgs, goenv }:
    let
      # Systems supported
      allSystems = [
        "x86_64-linux" "aarch64-linux" # Linux 64-bit (Intel/AMD and ARM)
        "x86_64-darwin" "aarch64-darwin" # macOS (Intel and Apple Silicon)
      ];

      # Helper to create system-specific attributes
      forAllSystems = f: nixpkgs.lib.genAttrs allSystems (system: f system);
    in
    {
      devShells = forAllSystems (system: {
        default = goenv.devShells.${system}.default;
      });
    };
}
```

### As a Package

To use a specific Go version in your project:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    goenv.url = "path/to/this/flake"; # Replace with your actual flake URL
  };

  outputs = { self, nixpkgs, goenv }:
    let
      system = "x86_64-linux"; # Replace with your target system
    in {
      packages.${system}.default = goenv.packages.${system}.go;
    };
}
```

### Specifying a Version

To use a specific Go version, you can override the default version:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    goenv.url = "path/to/this/flake";
  };

  outputs = { self, nixpkgs, goenv }:
    let
      system = "x86_64-linux";
      # Create a custom Go version
      go_1_20_1 = goenv.lib.${system}.mkGo {
        major = 1;
        minor = 20;
        patch = 1;
      };
    in {
      devShells.${system}.default = nixpkgs.legacyPackages.${system}.mkShell {
        buildInputs = [ go_1_20_1 ];
      };
    };
}
```

## Updating Versions

The flake includes a Go program to update the version database:

```bash
go run update-go-versions.go
```

This will:
1. Fetch all available Go versions
2. Update the version database with SHA256 hashes
3. Update the latest version information

## Platform Support

- Linux (x86_64, aarch64)
- macOS (x86_64, aarch64)
  - Note: Apple Silicon (aarch64-darwin) support requires Go 1.16.1 or later

## Requirements

- Nix with flakes enabled
- For updating versions: Go 1.13 or later

## License

MIT License 