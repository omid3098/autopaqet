//go:build windows

package npcap

import (
	"os"
	"path/filepath"
)

const npcapDownloadURL = "https://npcap.com/#download"

// WindowsChecker checks for Npcap on Windows.
type WindowsChecker struct {
	CheckFile func(path string) bool
}

// NewChecker creates a new WindowsChecker.
func NewChecker() *WindowsChecker {
	return &WindowsChecker{
		CheckFile: defaultCheckFile,
	}
}

// Check verifies that Npcap is installed on Windows.
// Mirrors the check in AutoPaqet.Network.ps1:123-137.
func (c *WindowsChecker) Check() *Status {
	systemRoot := os.Getenv("SystemRoot")
	if systemRoot == "" {
		systemRoot = `C:\Windows`
	}

	npcapDLL := filepath.Join(systemRoot, "System32", "Npcap", "wpcap.dll")
	if c.CheckFile(npcapDLL) {
		return &Status{
			Installed: true,
			Message:   "Npcap is installed",
		}
	}

	// Also check legacy WinPcap path
	winpcapDLL := filepath.Join(systemRoot, "System32", "wpcap.dll")
	if c.CheckFile(winpcapDLL) {
		return &Status{
			Installed: true,
			Message:   "WinPcap/Npcap is installed (legacy path)",
		}
	}

	return &Status{
		Installed:   false,
		DownloadURL: npcapDownloadURL,
		Message:     "Npcap is not installed. Download from npcap.com (free for personal use).",
	}
}

func defaultCheckFile(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
