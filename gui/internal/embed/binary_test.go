package embed

import (
	"os"
	"path/filepath"
	"testing"
	"testing/fstest"
)

func TestExtractBinary(t *testing.T) {
	targetDir := t.TempDir()
	binaryContent := []byte("fake-paqet-binary-content")

	srcFS := fstest.MapFS{
		"bin/paqet": &fstest.MapFile{
			Data: binaryContent,
			Mode: 0755,
		},
	}

	e := NewExtractor(srcFS, targetDir)
	path, err := e.Extract()
	if err != nil {
		t.Fatalf("Extract failed: %v", err)
	}

	if path != filepath.Join(targetDir, "paqet") {
		t.Errorf("path = %q, want %q", path, filepath.Join(targetDir, "paqet"))
	}

	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("failed to read extracted binary: %v", err)
	}
	if string(data) != string(binaryContent) {
		t.Error("extracted binary content mismatch")
	}

	// Verify executable permissions
	info, _ := os.Stat(path)
	if info.Mode()&0100 == 0 {
		t.Error("expected executable permission on extracted binary")
	}
}

func TestExtractSkipsIfHashMatches(t *testing.T) {
	targetDir := t.TempDir()
	binaryContent := []byte("fake-paqet-binary-content")

	srcFS := fstest.MapFS{
		"bin/paqet": &fstest.MapFile{
			Data: binaryContent,
			Mode: 0755,
		},
	}

	e := NewExtractor(srcFS, targetDir)

	// First extraction
	path1, err := e.Extract()
	if err != nil {
		t.Fatalf("First Extract failed: %v", err)
	}
	info1, _ := os.Stat(path1)

	// Second extraction should skip (same hash)
	path2, err := e.Extract()
	if err != nil {
		t.Fatalf("Second Extract failed: %v", err)
	}

	// Verify paths are the same
	if path1 != path2 {
		t.Errorf("paths differ: %q vs %q", path1, path2)
	}

	// The file should still exist and have the same content
	info2, _ := os.Stat(path2)
	if info1.Size() != info2.Size() {
		t.Error("file sizes differ after second extraction")
	}
}

func TestExtractOverwritesIfHashDiffers(t *testing.T) {
	targetDir := t.TempDir()

	// Pre-write a different binary
	destPath := filepath.Join(targetDir, "paqet")
	os.WriteFile(destPath, []byte("old-content"), 0755)

	newContent := []byte("new-paqet-binary")
	srcFS := fstest.MapFS{
		"bin/paqet": &fstest.MapFile{
			Data: newContent,
			Mode: 0755,
		},
	}

	e := NewExtractor(srcFS, targetDir)
	_, err := e.Extract()
	if err != nil {
		t.Fatalf("Extract failed: %v", err)
	}

	data, _ := os.ReadFile(destPath)
	if string(data) != "new-paqet-binary" {
		t.Errorf("expected new content, got %q", string(data))
	}
}

func TestExtractMissingBinary(t *testing.T) {
	targetDir := t.TempDir()

	srcFS := fstest.MapFS{} // empty FS

	e := NewExtractor(srcFS, targetDir)
	_, err := e.Extract()
	if err == nil {
		t.Error("expected error for missing embedded binary")
	}
}

func TestExtractCreatesTargetDir(t *testing.T) {
	targetDir := filepath.Join(t.TempDir(), "nested", "dir")
	binaryContent := []byte("content")

	srcFS := fstest.MapFS{
		"bin/paqet": &fstest.MapFile{Data: binaryContent, Mode: 0755},
	}

	e := NewExtractor(srcFS, targetDir)
	_, err := e.Extract()
	if err != nil {
		t.Fatalf("Extract failed: %v", err)
	}

	if _, err := os.Stat(targetDir); os.IsNotExist(err) {
		t.Error("target directory was not created")
	}
}

func TestBinaryPath(t *testing.T) {
	e := NewExtractor(nil, "/tmp/test")
	path := e.BinaryPath()
	expected := filepath.Join("/tmp/test", BinaryName())
	if path != expected {
		t.Errorf("BinaryPath() = %q, want %q", path, expected)
	}
}

func TestSha256Sum(t *testing.T) {
	data := []byte("test data")
	h1 := sha256Sum(data)
	h2 := sha256Sum(data)
	if h1 != h2 {
		t.Error("same data should produce same hash")
	}

	h3 := sha256Sum([]byte("different data"))
	if h1 == h3 {
		t.Error("different data should produce different hash")
	}
}
