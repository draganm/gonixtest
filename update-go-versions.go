package main

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
)

type VersionInfo struct {
	SHA256 string `json:"sha256"`
}

type VersionMap map[string]map[string]VersionInfo

type GoFile struct {
	Filename string `json:"filename"`
	SHA256   string `json:"sha256"`
	Kind     string `json:"kind"`
}

type GoVersion struct {
	Version string   `json:"version"`
	Stable  bool     `json:"stable"`
	Files   []GoFile `json:"files"`
}

// convertToSRI converts a regular hex SHA256 to SRI format
func convertToSRI(hexHash string) string {
	// Decode hex string to bytes
	hashBytes := make([]byte, len(hexHash)/2)
	for i := 0; i < len(hexHash)/2; i++ {
		b1 := hexDigitToInt(hexHash[i*2])
		b2 := hexDigitToInt(hexHash[i*2+1])
		hashBytes[i] = (b1 << 4) | b2
	}

	// Encode to base64
	return base64.StdEncoding.EncodeToString(hashBytes)
}

func hexDigitToInt(c byte) byte {
	switch {
	case c >= '0' && c <= '9':
		return c - '0'
	case c >= 'a' && c <= 'f':
		return c - 'a' + 10
	case c >= 'A' && c <= 'F':
		return c - 'A' + 10
	default:
		return 0
	}
}

func main() {
	// Get all available versions from the API
	versions, err := fetchGoVersions()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error fetching Go versions: %v\n", err)
		os.Exit(1)
	}

	// Read existing version map
	versionMap := make(VersionMap)
	if data, err := os.ReadFile("go-versions.json"); err == nil {
		if err := json.Unmarshal(data, &versionMap); err != nil {
			fmt.Fprintf(os.Stderr, "Error parsing existing go-versions.json: %v\n", err)
			os.Exit(1)
		}
	}

	// Process each version
	for _, version := range versions {
		// Skip unstable versions
		if !version.Stable {
			continue
		}

		// Find source file and its SHA256
		var sourceFile *GoFile
		for _, file := range version.Files {
			if file.Kind == "source" {
				sourceFile = &file
				break
			}
		}
		if sourceFile == nil {
			fmt.Fprintf(os.Stderr, "No source file found for version %s\n", version.Version)
			continue
		}

		// Parse version string (strip 'go' prefix)
		versionStr := strings.TrimPrefix(version.Version, "go")
		major, minor, patch := parseVersion(versionStr)
		if major == "" || minor == "" || patch == "" {
			continue
		}

		// Skip if we already have this version
		majorMinor := fmt.Sprintf("%s.%s", major, minor)
		if _, exists := versionMap[majorMinor]; !exists {
			versionMap[majorMinor] = make(map[string]VersionInfo)
		}
		if _, exists := versionMap[majorMinor][patch]; exists {
			continue
		}

		// Convert hash to SRI format and add to version map
		sriHash := convertToSRI(sourceFile.SHA256)
		versionMap[majorMinor][patch] = VersionInfo{
			SHA256: fmt.Sprintf("sha256-%s", sriHash),
		}

		fmt.Printf("Added version %s.%s.%s with SHA256: %s\n", major, minor, patch, sriHash)
	}

	// Write updated version map
	data, err := json.MarshalIndent(versionMap, "", "  ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error marshaling version map: %v\n", err)
		os.Exit(1)
	}

	if err := os.WriteFile("go-versions.json", data, 0644); err != nil {
		fmt.Fprintf(os.Stderr, "Error writing go-versions.json: %v\n", err)
		os.Exit(1)
	}
}

func fetchGoVersions() ([]GoVersion, error) {
	// Use include=all to get all versions
	resp, err := http.Get("https://go.dev/dl/?mode=json&include=all")
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var versions []GoVersion
	if err := json.Unmarshal(body, &versions); err != nil {
		return nil, err
	}

	return versions, nil
}

func parseVersion(version string) (major, minor, patch string) {
	parts := strings.Split(version, ".")
	if len(parts) != 3 {
		return "", "", ""
	}
	return parts[0], parts[1], parts[2]
}
