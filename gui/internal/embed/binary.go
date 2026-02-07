package embed

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"runtime"
)

// In production builds, the paqet binary is embedded via:
//
//	//go:embed bin/*
//	var binFS embed.FS
//
// For testing and development, we use the filesystem-based approach below.

// Extractor manages extracting the embedded paqet binary to disk.
type Extractor struct {
	// SourceFS provides the embedded binary content.
	SourceFS fs.FS
	// TargetDir is where extracted binaries are placed.
	TargetDir string
}

// NewExtractor creates an Extractor that writes to the platform-specific app directory.
func NewExtractor(sourceFS fs.FS, targetDir string) *Extractor {
	return &Extractor{
		SourceFS:  sourceFS,
		TargetDir: targetDir,
	}
}

// BinaryName returns the expected binary filename for the current platform.
func BinaryName() string {
	if runtime.GOOS == "windows" {
		return "paqet.exe"
	}
	return "paqet"
}

// Extract extracts the embedded binary to TargetDir.
// Returns the full path to the extracted binary.
// Skips extraction if the file already exists with the same SHA256 hash.
func (e *Extractor) Extract() (string, error) {
	if err := os.MkdirAll(e.TargetDir, 0755); err != nil {
		return "", fmt.Errorf("failed to create target directory: %w", err)
	}

	srcName := BinaryName()
	srcPath := filepath.Join("bin", srcName)

	srcData, err := fs.ReadFile(e.SourceFS, srcPath)
	if err != nil {
		return "", fmt.Errorf("embedded binary not found at %s: %w", srcPath, err)
	}

	destPath := filepath.Join(e.TargetDir, srcName)

	// Check if already extracted with same hash
	if existingData, err := os.ReadFile(destPath); err == nil {
		srcHash := sha256Sum(srcData)
		existingHash := sha256Sum(existingData)
		if srcHash == existingHash {
			return destPath, nil
		}
	}

	// Write binary
	if err := os.WriteFile(destPath, srcData, 0755); err != nil {
		return "", fmt.Errorf("failed to write binary: %w", err)
	}

	return destPath, nil
}

// BinaryPath returns the expected path where the binary should be extracted.
func (e *Extractor) BinaryPath() string {
	return filepath.Join(e.TargetDir, BinaryName())
}

func sha256Sum(data []byte) string {
	h := sha256.Sum256(data)
	return hex.EncodeToString(h[:])
}
