//go:build windows

package proxy

import (
	"fmt"
	"unsafe"

	"golang.org/x/sys/windows"
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
	wininet := windows.NewLazyDLL("wininet.dll")
	internetSetOption := wininet.NewProc("InternetSetOptionW")

	// INTERNET_OPTION_SETTINGS_CHANGED = 39
	internetSetOption.Call(0, 39, 0, 0)
	// INTERNET_OPTION_REFRESH = 37
	internetSetOption.Call(0, 37, 0, 0)

	// Broadcast WM_SETTINGCHANGE so apps pick up the proxy change
	user32 := windows.NewLazyDLL("user32.dll")
	sendMessageTimeout := user32.NewProc("SendMessageTimeoutW")
	internetSettings, _ := windows.UTF16PtrFromString("Internet Settings")
	// HWND_BROADCAST=0xFFFF, WM_SETTINGCHANGE=0x001A, SMTO_ABORTIFHUNG=0x0002
	sendMessageTimeout.Call(
		0xFFFF, 0x001A, 0,
		uintptr(unsafe.Pointer(internetSettings)),
		0x0002, 1000, 0,
	)
}
