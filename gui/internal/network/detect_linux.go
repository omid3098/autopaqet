//go:build linux

package network

import (
	"fmt"
	"os/exec"
	"strings"
)

// LinuxDetector detects network configuration on Linux.
type LinuxDetector struct {
	// RunCommand is injectable for testing.
	RunCommand func(name string, args ...string) (string, error)
}

// NewDetector creates a new LinuxDetector.
func NewDetector() *LinuxDetector {
	return &LinuxDetector{
		RunCommand: defaultRunCommand,
	}
}

// Detect auto-detects the network configuration using ip route and ip neigh.
func (d *LinuxDetector) Detect() (*NetworkInfo, error) {
	routeOutput, err := d.RunCommand("ip", "route", "get", "1.1.1.1")
	if err != nil {
		return nil, fmt.Errorf("failed to get route: %w", err)
	}

	info := &NetworkInfo{}

	info.InterfaceName = extractField(routeOutput, "dev")
	info.LocalIP = extractField(routeOutput, "src")
	info.GatewayIP = extractField(routeOutput, "via")

	if info.InterfaceName == "" {
		return nil, fmt.Errorf("could not detect network interface")
	}
	if info.LocalIP == "" {
		return nil, fmt.Errorf("could not detect local IP")
	}
	if info.GatewayIP == "" {
		return nil, fmt.Errorf("could not detect gateway IP")
	}

	// Ping gateway to populate ARP cache
	d.RunCommand("ping", "-c", "1", "-W", "1", info.GatewayIP)

	neighOutput, err := d.RunCommand("ip", "neigh", "show", info.GatewayIP)
	if err != nil {
		return nil, fmt.Errorf("failed to get neighbor: %w", err)
	}

	info.GatewayMAC = extractMAC(neighOutput)
	if info.GatewayMAC == "" {
		return nil, fmt.Errorf("could not detect gateway MAC address")
	}

	return info, nil
}

func extractField(output, field string) string {
	parts := strings.Fields(output)
	for i, p := range parts {
		if p == field && i+1 < len(parts) {
			return parts[i+1]
		}
	}
	return ""
}

func extractMAC(neighOutput string) string {
	// ip neigh show output: "IP dev IFACE lladdr MAC STATE"
	parts := strings.Fields(neighOutput)
	for i, p := range parts {
		if p == "lladdr" && i+1 < len(parts) {
			return parts[i+1]
		}
	}
	// Fallback: look for MAC-like pattern (5th field)
	if len(parts) >= 5 {
		candidate := parts[4]
		if isMAC(candidate) {
			return candidate
		}
	}
	return ""
}

func isMAC(s string) bool {
	parts := strings.Split(s, ":")
	return len(parts) == 6
}

func defaultRunCommand(name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	out, err := cmd.Output()
	return strings.TrimSpace(string(out)), err
}
