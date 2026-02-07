//go:build windows

package proxy

import (
	"fmt"

	"golang.org/x/sys/windows/registry"
)

const (
	internetSettingsKey = `Software\Microsoft\Windows\CurrentVersion\Internet Settings`
)

// WindowsSetter configures system proxy on Windows via registry.
type WindowsSetter struct {
	enabled bool
}

// NewSetter creates a new WindowsSetter.
func NewSetter() *WindowsSetter {
	return &WindowsSetter{}
}

// EnableSystemProxy sets the AutoConfigURL in Windows Internet Settings registry.
func (s *WindowsSetter) EnableSystemProxy(pacURL string) error {
	key, err := registry.OpenKey(registry.CURRENT_USER, internetSettingsKey, registry.SET_VALUE)
	if err != nil {
		return fmt.Errorf("failed to open registry key: %w", err)
	}
	defer key.Close()

	if err := key.SetStringValue("AutoConfigURL", pacURL); err != nil {
		return fmt.Errorf("failed to set AutoConfigURL: %w", err)
	}

	s.enabled = true

	// Notify the system of the change via WinINet
	notifyProxyChange()

	return nil
}

// DisableSystemProxy removes the AutoConfigURL from Windows Internet Settings.
func (s *WindowsSetter) DisableSystemProxy() error {
	if !s.enabled {
		return nil
	}

	key, err := registry.OpenKey(registry.CURRENT_USER, internetSettingsKey, registry.SET_VALUE)
	if err != nil {
		return fmt.Errorf("failed to open registry key: %w", err)
	}
	defer key.Close()

	key.DeleteValue("AutoConfigURL")

	s.enabled = false
	notifyProxyChange()

	return nil
}

// IsSystemProxyEnabled returns whether the system proxy is currently set.
func (s *WindowsSetter) IsSystemProxyEnabled() bool {
	return s.enabled
}

func notifyProxyChange() {
	// In production, call InternetSetOption(INTERNET_OPTION_SETTINGS_CHANGED)
	// and SendMessage(HWND_BROADCAST, WM_SETTINGCHANGE) via wininet.dll/user32.dll.
	// Omitted here to avoid CGO dependency in the base build.
}
