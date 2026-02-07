package proxy

import (
	"testing"
)

func TestLinuxSetterGnome(t *testing.T) {
	commands := []struct {
		name string
		args []string
	}{}

	s := &LinuxSetter{
		RunCommand: func(name string, args ...string) error {
			commands = append(commands, struct {
				name string
				args []string
			}{name, args})
			return nil
		},
		desktop: "gnome",
	}

	err := s.EnableSystemProxy("http://127.0.0.1:18384/proxy.pac")
	if err != nil {
		t.Fatalf("EnableSystemProxy failed: %v", err)
	}

	if !s.IsSystemProxyEnabled() {
		t.Error("expected IsSystemProxyEnabled=true after Enable")
	}

	// Should have called gsettings twice (mode + autoconfig-url)
	if len(commands) != 2 {
		t.Fatalf("expected 2 commands, got %d", len(commands))
	}
	if commands[0].name != "gsettings" {
		t.Errorf("first command = %q, want gsettings", commands[0].name)
	}

	// Disable
	err = s.DisableSystemProxy()
	if err != nil {
		t.Fatalf("DisableSystemProxy failed: %v", err)
	}

	if s.IsSystemProxyEnabled() {
		t.Error("expected IsSystemProxyEnabled=false after Disable")
	}
}

func TestLinuxSetterKDE(t *testing.T) {
	commands := []string{}

	s := &LinuxSetter{
		RunCommand: func(name string, args ...string) error {
			commands = append(commands, name)
			return nil
		},
		desktop: "kde",
	}

	err := s.EnableSystemProxy("http://127.0.0.1:18384/proxy.pac")
	if err != nil {
		t.Fatalf("EnableSystemProxy failed: %v", err)
	}

	if len(commands) != 2 {
		t.Fatalf("expected 2 commands, got %d", len(commands))
	}
	if commands[0] != "kwriteconfig5" {
		t.Errorf("first command = %q, want kwriteconfig5", commands[0])
	}
}

func TestLinuxSetterUnsupportedDesktop(t *testing.T) {
	s := &LinuxSetter{
		RunCommand: func(name string, args ...string) error { return nil },
		desktop:    "i3",
	}

	err := s.EnableSystemProxy("http://127.0.0.1:18384/proxy.pac")
	if err == nil {
		t.Error("expected error for unsupported desktop")
	}
}

func TestLinuxSetterDisableWithoutEnable(t *testing.T) {
	s := &LinuxSetter{
		RunCommand: func(name string, args ...string) error { return nil },
		desktop:    "gnome",
	}

	// Should not error when disabling without enabling
	err := s.DisableSystemProxy()
	if err != nil {
		t.Errorf("DisableSystemProxy failed: %v", err)
	}
}

func TestLinuxSetterInitialState(t *testing.T) {
	s := &LinuxSetter{
		RunCommand: func(name string, args ...string) error { return nil },
		desktop:    "gnome",
	}

	if s.IsSystemProxyEnabled() {
		t.Error("expected IsSystemProxyEnabled=false initially")
	}
}
