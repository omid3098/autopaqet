package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"os"
	"runtime"

	"github.com/omid3098/autopaqet/gui/internal/config"
	"github.com/omid3098/autopaqet/gui/internal/profile"
	"github.com/omid3098/autopaqet/gui/internal/uri"
)

// ConnectionState represents the current connection state.
type ConnectionState string

const (
	StateIdle      ConnectionState = "idle"
	StateStarting  ConnectionState = "starting"
	StateConnected ConnectionState = "connected"
	StateError     ConnectionState = "error"
)

// NetworkInfo holds auto-detected network configuration.
type NetworkInfo struct {
	InterfaceName string `json:"interface_name"`
	LocalIP       string `json:"local_ip"`
	GatewayIP     string `json:"gateway_ip"`
	GatewayMAC    string `json:"gateway_mac"`
	NpcapGUID     string `json:"npcap_guid,omitempty"`
}

// NpcapStatus holds Npcap detection results.
type NpcapStatus struct {
	Installed   bool   `json:"installed"`
	Version     string `json:"version,omitempty"`
	DownloadURL string `json:"download_url"`
}

// App struct holds the application state and bound methods.
type App struct {
	ctx         context.Context
	store       *profile.Store
	connState   ConnectionState
	lastError   string
	networkInfo *NetworkInfo
}

// NewApp creates a new App instance.
func NewApp() *App {
	return &App{
		connState: StateIdle,
	}
}

// startup is called when the app starts.
func (a *App) startup(ctx context.Context) {
	a.ctx = ctx

	dir := ProfileDir()
	store, err := profile.NewStore(dir)
	if err != nil {
		a.lastError = fmt.Sprintf("failed to initialize profile store: %v", err)
		return
	}
	a.store = store
}

// shutdown is called when the app is closing.
func (a *App) shutdown(ctx context.Context) {
	// Phase 4: DisableSystemProxy() called here
	// Phase 2: Stop paqet process if running
}

// --- Connection Methods (Phase 2 implements fully) ---

// Connect starts the paqet process with the given profile ID.
func (a *App) Connect(profileID string) error {
	if a.store == nil {
		return fmt.Errorf("store not initialized")
	}
	_, err := a.store.Get(profileID)
	if err != nil {
		return err
	}
	a.connState = StateStarting
	return nil
}

// Disconnect stops the running paqet process.
func (a *App) Disconnect() error {
	a.connState = StateIdle
	return nil
}

// GetConnectionState returns the current connection state.
func (a *App) GetConnectionState() ConnectionState {
	return a.connState
}

// --- Network Methods (Phase 2 implements fully) ---

// DetectNetwork auto-detects the network configuration.
func (a *App) DetectNetwork() (*NetworkInfo, error) {
	return nil, fmt.Errorf("not implemented - Phase 2")
}

// CheckNpcap checks if Npcap is installed (Windows only).
func (a *App) CheckNpcap() (*NpcapStatus, error) {
	if runtime.GOOS != "windows" {
		return &NpcapStatus{Installed: true}, nil
	}
	return nil, fmt.Errorf("not implemented - Phase 2")
}

// --- Profile Methods ---

// ListProfiles returns all saved profiles.
func (a *App) ListProfiles() []*profile.Profile {
	if a.store == nil {
		return nil
	}
	return a.store.List()
}

// CreateProfile creates a new profile.
func (a *App) CreateProfile(p *profile.Profile) (*profile.Profile, error) {
	if a.store == nil {
		return nil, fmt.Errorf("store not initialized")
	}
	return a.store.Create(p)
}

// UpdateProfile updates an existing profile.
func (a *App) UpdateProfile(p *profile.Profile) (*profile.Profile, error) {
	if a.store == nil {
		return nil, fmt.Errorf("store not initialized")
	}
	return a.store.Update(p)
}

// DeleteProfile removes a profile by ID.
func (a *App) DeleteProfile(id string) error {
	if a.store == nil {
		return fmt.Errorf("store not initialized")
	}
	return a.store.Delete(id)
}

// ImportURI imports a paqet:// URI and creates a profile.
func (a *App) ImportURI(raw string) (*profile.Profile, error) {
	if a.store == nil {
		return nil, fmt.Errorf("store not initialized")
	}
	return a.store.ImportFromURI(raw)
}

// ExportURI exports a profile as a paqet:// URI string.
func (a *App) ExportURI(id string) (string, error) {
	if a.store == nil {
		return "", fmt.Errorf("store not initialized")
	}
	return a.store.ExportToURI(id)
}

// GenerateQRCode generates a QR code PNG for the given profile ID.
func (a *App) GenerateQRCode(id string) ([]byte, error) {
	raw, err := a.ExportURI(id)
	if err != nil {
		return nil, err
	}
	_ = raw
	return nil, fmt.Errorf("not implemented - Phase 3")
}

// --- Log Methods (Phase 2 implements fully) ---

// GetLogs returns the last N log lines.
func (a *App) GetLogs(count int) []string {
	return nil
}

// ClearLogs clears the log buffer.
func (a *App) ClearLogs() {}

// --- Utility Methods ---

// GenerateKey generates a random 32-byte hex key.
func (a *App) GenerateKey() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", fmt.Errorf("failed to generate key: %w", err)
	}
	return hex.EncodeToString(b), nil
}

// GenerateConfigYAML generates YAML config from a profile and network info.
func (a *App) GenerateConfigYAML(profileID string, net *NetworkInfo) (string, error) {
	if a.store == nil {
		return "", fmt.Errorf("store not initialized")
	}
	p, err := a.store.Get(profileID)
	if err != nil {
		return "", err
	}

	localAddr := fmt.Sprintf("%s:%d", net.LocalIP, 12345)

	opts := &config.Options{
		ServerAddr:    fmt.Sprintf("%s:%d", p.Host, p.Port),
		Key:           p.Key,
		InterfaceName: net.InterfaceName,
		LocalAddr:     localAddr,
		GatewayMAC:    net.GatewayMAC,
		NpcapGUID:     net.NpcapGUID,
		SocksListen:   p.SocksListen,
		SocksUser:     p.SocksUser,
		SocksPass:     p.SocksPass,
		Mode:          p.Mode,
		Conn:          p.Conn,
		MTU:           p.MTU,
		Block:         p.Block,
		RcvWnd:        p.RcvWnd,
		SndWnd:        p.SndWnd,
		DShard:        p.DShard,
		PShard:        p.PShard,
		DSCP:          p.DSCP,
		SmuxBuf:       p.SmuxBuf,
		StreamBuf:     p.StreamBuf,
		TCPBuf:        p.TCPBuf,
		UDPBuf:        p.UDPBuf,
		SockBuf:       p.SockBuf,
		LocalFlag:     p.LocalFlag,
		RemoteFlag:    p.RemoteFlag,
		Forward:       p.Forward,
		LogLevel:      p.LogLevel,
	}

	return config.Generate(opts)
}

// ParseURI parses a paqet:// URI without saving it (for preview).
func (a *App) ParseURI(raw string) (*uri.PaqetURI, error) {
	return uri.Parse(raw)
}

// ProfileDir returns the platform-specific profile storage directory.
func ProfileDir() string {
	if runtime.GOOS == "windows" {
		appdata := os.Getenv("APPDATA")
		if appdata == "" {
			appdata = "."
		}
		return appdata + `\autopaqet`
	}
	home := os.Getenv("HOME")
	if home == "" {
		home = "."
	}
	return home + "/.autopaqet"
}
