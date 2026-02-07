package network

import (
	"fmt"
	"testing"
)

func TestDetectWithMockLinuxCommands(t *testing.T) {
	d := &LinuxDetector{
		RunCommand: func(name string, args ...string) (string, error) {
			switch name {
			case "ip":
				if len(args) >= 1 && args[0] == "route" {
					return "1.1.1.1 via 192.168.1.1 dev eth0 src 192.168.1.100 uid 1000", nil
				}
				if len(args) >= 1 && args[0] == "neigh" {
					return "192.168.1.1 dev eth0 lladdr aa:bb:cc:dd:ee:ff REACHABLE", nil
				}
			case "ping":
				return "", nil
			}
			return "", fmt.Errorf("unknown command: %s %v", name, args)
		},
	}

	info, err := d.Detect()
	if err != nil {
		t.Fatalf("Detect failed: %v", err)
	}

	if info.InterfaceName != "eth0" {
		t.Errorf("InterfaceName = %q, want %q", info.InterfaceName, "eth0")
	}
	if info.LocalIP != "192.168.1.100" {
		t.Errorf("LocalIP = %q, want %q", info.LocalIP, "192.168.1.100")
	}
	if info.GatewayIP != "192.168.1.1" {
		t.Errorf("GatewayIP = %q, want %q", info.GatewayIP, "192.168.1.1")
	}
	if info.GatewayMAC != "aa:bb:cc:dd:ee:ff" {
		t.Errorf("GatewayMAC = %q, want %q", info.GatewayMAC, "aa:bb:cc:dd:ee:ff")
	}
}

func TestDetectFailsOnNoInterface(t *testing.T) {
	d := &LinuxDetector{
		RunCommand: func(name string, args ...string) (string, error) {
			if name == "ip" && len(args) >= 1 && args[0] == "route" {
				return "unreachable", nil
			}
			return "", nil
		},
	}

	_, err := d.Detect()
	if err == nil {
		t.Error("expected error for missing interface")
	}
}

func TestDetectFailsOnNoGatewayMAC(t *testing.T) {
	d := &LinuxDetector{
		RunCommand: func(name string, args ...string) (string, error) {
			if name == "ip" && len(args) >= 1 && args[0] == "route" {
				return "1.1.1.1 via 192.168.1.1 dev eth0 src 192.168.1.100", nil
			}
			if name == "ip" && len(args) >= 1 && args[0] == "neigh" {
				return "192.168.1.1 dev eth0 FAILED", nil
			}
			return "", nil
		},
	}

	_, err := d.Detect()
	if err == nil {
		t.Error("expected error for missing gateway MAC")
	}
}

func TestDetectFailsOnRouteError(t *testing.T) {
	d := &LinuxDetector{
		RunCommand: func(name string, args ...string) (string, error) {
			if name == "ip" && len(args) >= 1 && args[0] == "route" {
				return "", fmt.Errorf("network unreachable")
			}
			return "", nil
		},
	}

	_, err := d.Detect()
	if err == nil {
		t.Error("expected error for route failure")
	}
}

func TestExtractField(t *testing.T) {
	tests := []struct {
		output string
		field  string
		want   string
	}{
		{"1.1.1.1 via 192.168.1.1 dev eth0 src 192.168.1.100", "dev", "eth0"},
		{"1.1.1.1 via 192.168.1.1 dev eth0 src 192.168.1.100", "src", "192.168.1.100"},
		{"1.1.1.1 via 192.168.1.1 dev eth0 src 192.168.1.100", "via", "192.168.1.1"},
		{"1.1.1.1 via 192.168.1.1 dev eth0 src 192.168.1.100", "missing", ""},
	}

	for _, tc := range tests {
		got := extractField(tc.output, tc.field)
		if got != tc.want {
			t.Errorf("extractField(%q, %q) = %q, want %q", tc.output, tc.field, got, tc.want)
		}
	}
}

func TestExtractMAC(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"192.168.1.1 dev eth0 lladdr aa:bb:cc:dd:ee:ff REACHABLE", "aa:bb:cc:dd:ee:ff"},
		{"192.168.1.1 dev eth0 FAILED", ""},
		{"", ""},
	}

	for _, tc := range tests {
		got := extractMAC(tc.input)
		if got != tc.want {
			t.Errorf("extractMAC(%q) = %q, want %q", tc.input, got, tc.want)
		}
	}
}

func TestIsMAC(t *testing.T) {
	tests := []struct {
		input string
		want  bool
	}{
		{"aa:bb:cc:dd:ee:ff", true},
		{"REACHABLE", false},
		{"192.168.1.1", false},
	}

	for _, tc := range tests {
		got := isMAC(tc.input)
		if got != tc.want {
			t.Errorf("isMAC(%q) = %v, want %v", tc.input, got, tc.want)
		}
	}
}
