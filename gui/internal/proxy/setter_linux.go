//go:build linux

package proxy

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

// LinuxSetter configures system proxy on Linux desktop environments.
type LinuxSetter struct {
	RunCommand func(name string, args ...string) error
	enabled    bool
	desktop    string
}

// NewSetter creates a new LinuxSetter.
func NewSetter() *LinuxSetter {
	return &LinuxSetter{
		RunCommand: defaultSetterRunCommand,
		desktop:    detectDesktop(),
	}
}

// EnableSystemProxy sets the system proxy to use the PAC URL.
func (s *LinuxSetter) EnableSystemProxy(pacURL string) error {
	switch s.desktop {
	case "gnome", "unity", "cinnamon", "budgie":
		if err := s.RunCommand("gsettings", "set", "org.gnome.system.proxy", "mode", "auto"); err != nil {
			return fmt.Errorf("failed to set proxy mode: %w", err)
		}
		if err := s.RunCommand("gsettings", "set", "org.gnome.system.proxy", "autoconfig-url", pacURL); err != nil {
			return fmt.Errorf("failed to set autoconfig URL: %w", err)
		}
	case "kde":
		if err := s.RunCommand("kwriteconfig5", "--file", "kioslaverc", "--group", "Proxy Settings", "--key", "ProxyType", "2"); err != nil {
			return fmt.Errorf("failed to set KDE proxy type: %w", err)
		}
		if err := s.RunCommand("kwriteconfig5", "--file", "kioslaverc", "--group", "Proxy Settings", "--key", "Proxy Config Script", pacURL); err != nil {
			return fmt.Errorf("failed to set KDE PAC URL: %w", err)
		}
	default:
		return fmt.Errorf("automatic proxy configuration not supported for desktop %q. Please manually configure SOCKS5 proxy in your application settings", s.desktop)
	}

	s.enabled = true
	return nil
}

// DisableSystemProxy removes the system proxy configuration.
func (s *LinuxSetter) DisableSystemProxy() error {
	if !s.enabled {
		return nil
	}

	switch s.desktop {
	case "gnome", "unity", "cinnamon", "budgie":
		s.RunCommand("gsettings", "set", "org.gnome.system.proxy", "mode", "none")
	case "kde":
		s.RunCommand("kwriteconfig5", "--file", "kioslaverc", "--group", "Proxy Settings", "--key", "ProxyType", "0")
	}

	s.enabled = false
	return nil
}

// IsSystemProxyEnabled returns whether the system proxy is currently set.
func (s *LinuxSetter) IsSystemProxyEnabled() bool {
	return s.enabled
}

func detectDesktop() string {
	desktop := os.Getenv("XDG_CURRENT_DESKTOP")
	desktop = strings.ToLower(desktop)

	if strings.Contains(desktop, "gnome") {
		return "gnome"
	}
	if strings.Contains(desktop, "kde") {
		return "kde"
	}
	if strings.Contains(desktop, "unity") {
		return "unity"
	}
	if strings.Contains(desktop, "cinnamon") {
		return "cinnamon"
	}
	if strings.Contains(desktop, "budgie") {
		return "budgie"
	}

	return desktop
}

func defaultSetterRunCommand(name string, args ...string) error {
	return exec.Command(name, args...).Run()
}
