package npcap

import (
	"testing"
)

func TestLinuxCheckerLibpcapFound(t *testing.T) {
	c := &LinuxChecker{
		CheckFile: func(path string) bool {
			return path == "/usr/lib/x86_64-linux-gnu/libpcap.so"
		},
		RunCommand: func(name string, args ...string) (string, error) {
			return "", nil
		},
	}

	s := c.Check()
	if !s.Installed {
		t.Error("expected Installed=true when libpcap.so exists")
	}
}

func TestLinuxCheckerLibpcapFoundViaLdconfig(t *testing.T) {
	c := &LinuxChecker{
		CheckFile: func(path string) bool { return false },
		RunCommand: func(name string, args ...string) (string, error) {
			if name == "ldconfig" {
				return "libpcap.so.1 (libc6,x86-64) => /usr/lib/x86_64-linux-gnu/libpcap.so.1", nil
			}
			return "", nil
		},
	}

	s := c.Check()
	if !s.Installed {
		t.Error("expected Installed=true when ldconfig shows libpcap")
	}
}

func TestLinuxCheckerLibpcapNotFound(t *testing.T) {
	c := &LinuxChecker{
		CheckFile: func(path string) bool { return false },
		RunCommand: func(name string, args ...string) (string, error) {
			return "", nil
		},
	}

	s := c.Check()
	if s.Installed {
		t.Error("expected Installed=false when libpcap not found")
	}
	if s.DownloadURL == "" {
		t.Error("expected non-empty DownloadURL")
	}
}

func TestLinuxCheckerArm64Path(t *testing.T) {
	c := &LinuxChecker{
		CheckFile: func(path string) bool {
			return path == "/usr/lib/aarch64-linux-gnu/libpcap.so"
		},
		RunCommand: func(name string, args ...string) (string, error) {
			return "", nil
		},
	}

	s := c.Check()
	if !s.Installed {
		t.Error("expected Installed=true when arm64 libpcap.so exists")
	}
}
