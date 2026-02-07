//go:build windows

package network

import (
	"fmt"
	"os/exec"
	"strings"
	"syscall"
)

// WindowsDetector detects network configuration on Windows.
type WindowsDetector struct {
	RunCommand func(name string, args ...string) (string, error)
}

// NewDetector creates a new WindowsDetector.
func NewDetector() *WindowsDetector {
	return &WindowsDetector{
		RunCommand: defaultRunCommand,
	}
}

// Detect auto-detects the network configuration on Windows.
// Uses PowerShell commands to mirror AutoPaqet.Network.ps1 behavior.
func (d *WindowsDetector) Detect() (*NetworkInfo, error) {
	// Get default route interface
	routeOutput, err := d.RunCommand("powershell", "-NoProfile", "-Command",
		"(Get-NetRoute -DestinationPrefix '0.0.0.0/0' | Sort-Object RouteMetric | Select-Object -First 1).InterfaceIndex")
	if err != nil {
		return nil, fmt.Errorf("failed to get default route: %w", err)
	}

	ifIndex := strings.TrimSpace(routeOutput)

	// Get interface details
	ifaceOutput, err := d.RunCommand("powershell", "-NoProfile", "-Command",
		fmt.Sprintf("Get-NetAdapter -InterfaceIndex %s | Select-Object -ExpandProperty Name", ifIndex))
	if err != nil {
		return nil, fmt.Errorf("failed to get interface name: %w", err)
	}

	info := &NetworkInfo{}
	info.InterfaceName = strings.TrimSpace(ifaceOutput)

	// Get local IP
	ipOutput, err := d.RunCommand("powershell", "-NoProfile", "-Command",
		fmt.Sprintf("(Get-NetIPAddress -InterfaceIndex %s -AddressFamily IPv4).IPAddress", ifIndex))
	if err != nil {
		return nil, fmt.Errorf("failed to get local IP: %w", err)
	}
	info.LocalIP = strings.TrimSpace(strings.Split(ipOutput, "\n")[0])

	// Get gateway IP
	gwOutput, err := d.RunCommand("powershell", "-NoProfile", "-Command",
		fmt.Sprintf("(Get-NetRoute -InterfaceIndex %s -DestinationPrefix '0.0.0.0/0').NextHop", ifIndex))
	if err != nil {
		return nil, fmt.Errorf("failed to get gateway IP: %w", err)
	}
	info.GatewayIP = strings.TrimSpace(gwOutput)

	// Ping to populate ARP cache, then get MAC
	d.RunCommand("ping", "-n", "1", "-w", "1000", info.GatewayIP)

	arpOutput, err := d.RunCommand("arp", "-a", info.GatewayIP)
	if err != nil {
		return nil, fmt.Errorf("failed to get ARP entry: %w", err)
	}
	info.GatewayMAC = extractWindowsMAC(arpOutput)

	// Get Npcap GUID
	guidOutput, err := d.RunCommand("powershell", "-NoProfile", "-Command",
		fmt.Sprintf("(Get-NetAdapter -InterfaceIndex %s).InterfaceGuid", ifIndex))
	if err == nil {
		guid := strings.TrimSpace(guidOutput)
		if guid != "" {
			info.NpcapGUID = fmt.Sprintf(`\Device\NPF_%s`, guid)
		}
	}

	return info, nil
}

func extractWindowsMAC(arpOutput string) string {
	lines := strings.Split(arpOutput, "\n")
	for _, line := range lines {
		fields := strings.Fields(line)
		if len(fields) >= 2 {
			mac := fields[1]
			// Windows ARP uses dashes: aa-bb-cc-dd-ee-ff
			if strings.Count(mac, "-") == 5 {
				return strings.ReplaceAll(mac, "-", ":")
			}
		}
	}
	return ""
}

func defaultRunCommand(name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: 0x08000000}
	out, err := cmd.Output()
	return strings.TrimSpace(string(out)), err
}
