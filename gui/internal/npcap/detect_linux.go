//go:build linux

package npcap

import (
	"os"
	"os/exec"
	"strings"
)

const npcapDownloadURL = "https://npcap.com/#download"

// LinuxChecker checks for libpcap on Linux.
type LinuxChecker struct {
	// CheckFile is injectable for testing.
	CheckFile func(path string) bool
	// RunCommand is injectable for testing.
	RunCommand func(name string, args ...string) (string, error)
}

// NewChecker creates a new LinuxChecker.
func NewChecker() *LinuxChecker {
	return &LinuxChecker{
		CheckFile:  defaultCheckFile,
		RunCommand: defaultRunCommand,
	}
}

// Check verifies that libpcap is available on Linux.
func (c *LinuxChecker) Check() *Status {
	// Check common library paths
	libPaths := []string{
		"/usr/lib/x86_64-linux-gnu/libpcap.so",
		"/usr/lib/libpcap.so",
		"/usr/lib/aarch64-linux-gnu/libpcap.so",
	}

	for _, p := range libPaths {
		if c.CheckFile(p) {
			return &Status{
				Installed: true,
				Message:   "libpcap found",
			}
		}
	}

	// Check via ldconfig
	out, err := c.RunCommand("ldconfig", "-p")
	if err == nil && strings.Contains(out, "libpcap") {
		return &Status{
			Installed: true,
			Message:   "libpcap found via ldconfig",
		}
	}

	// Check via dpkg
	out, err = c.RunCommand("dpkg", "-l", "libpcap-dev")
	if err == nil && strings.Contains(out, "libpcap") {
		return &Status{
			Installed: true,
			Message:   "libpcap-dev package installed",
		}
	}

	return &Status{
		Installed:   false,
		DownloadURL: npcapDownloadURL,
		Message:     "libpcap not found. Install with: sudo apt-get install libpcap-dev",
	}
}

func defaultCheckFile(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func defaultRunCommand(name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	out, err := cmd.Output()
	return string(out), err
}
