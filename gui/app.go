package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	mathrand "math/rand"
	"os"
	"path/filepath"
	"runtime"
	"sync"

	wailsRuntime "github.com/wailsapp/wails/v2/pkg/runtime"

	"github.com/omid3098/autopaqet/gui/internal/config"
	"github.com/omid3098/autopaqet/gui/internal/diag"
	"github.com/omid3098/autopaqet/gui/internal/network"
	"github.com/omid3098/autopaqet/gui/internal/npcap"
	"github.com/omid3098/autopaqet/gui/internal/process"
	"github.com/omid3098/autopaqet/gui/internal/profile"
	"github.com/omid3098/autopaqet/gui/internal/proxy"
	"github.com/omid3098/autopaqet/gui/internal/uri"
)

// ConnectionState represents the current connection state.
type ConnectionState string

const (
	StateIdle      ConnectionState = "idle"
	StateTesting   ConnectionState = "testing"
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
	ctx           context.Context
	store         *profile.Store
	connState     ConnectionState
	lastError     string
	networkInfo   *NetworkInfo
	manager       *process.Manager
	detector      *network.WindowsDetector
	npcapChecker  *npcap.WindowsChecker
	proxySetter   *proxy.WindowsSetter
	pacServer     *proxy.PACServer
	configDir     string
	activeProfile *profile.Profile
	binaryPath    string
	cancelDiag    context.CancelFunc
	diagMu        sync.Mutex
	diagActive    bool
}

// managerRunner adapts process.Manager to diag.PaqetRunner.
type managerRunner struct {
	m *process.Manager
}

func (r *managerRunner) StartPaqet(configPath string) error { return r.m.Start(configPath) }
func (r *managerRunner) StopPaqet() error                   { return r.m.Stop() }

// NewApp creates a new App instance.
func NewApp() *App {
	return &App{
		connState: StateIdle,
	}
}

// startup is called when the app starts.
func (a *App) startup(ctx context.Context) {
	a.ctx = ctx

	// Initialize profile store
	dir := ProfileDir()
	store, err := profile.NewStore(dir)
	if err != nil {
		a.lastError = fmt.Sprintf("failed to initialize profile store: %v", err)
		return
	}
	a.store = store

	// Find paqet binary
	a.binaryPath = findPaqetBinary()

	// Initialize process manager
	a.manager = process.NewManager(a.binaryPath)

	// State change handler is set during Connect() to control
	// when state events reach the frontend (suppressed during diagnostics).

	// Subscribe to log lines and forward to frontend
	logCh := a.manager.Subscribe()
	go func() {
		for line := range logCh {
			wailsRuntime.EventsEmit(a.ctx, "log:line", line)
		}
	}()

	// Initialize system components
	a.detector = network.NewDetector()
	a.npcapChecker = npcap.NewChecker()
	a.proxySetter = proxy.NewSetter()

	// Create temp dir for configs
	a.configDir = filepath.Join(os.TempDir(), "autopaqet")
	os.MkdirAll(a.configDir, 0755)
}

// shutdown is called when the app is closing.
func (a *App) shutdown(ctx context.Context) {
	if a.manager != nil {
		a.manager.Stop()
	}
	if a.proxySetter != nil && a.proxySetter.IsSystemProxyEnabled() {
		a.proxySetter.DisableSystemProxy()
	}
	if a.pacServer != nil {
		a.pacServer.Stop()
	}
}

// --- Connection Methods ---

// Connect starts the diagnostic + connection flow for the given profile ID.
func (a *App) Connect(profileID string) error {
	if a.store == nil {
		return fmt.Errorf("store not initialized")
	}
	if a.manager == nil {
		return fmt.Errorf("process manager not initialized")
	}

	p, err := a.store.Get(profileID)
	if err != nil {
		return err
	}
	a.activeProfile = p

	// Enter testing state
	a.emitState(StateTesting)

	// Suppress manager state changes during diagnostics
	a.manager.SetStateChangeHandler(nil)

	// Create cancellable context
	ctx, cancel := context.WithCancel(context.Background())
	a.diagMu.Lock()
	a.cancelDiag = cancel
	a.diagActive = true
	a.diagMu.Unlock()

	// Detect network
	netInfo, err := a.detector.Detect()
	if err != nil {
		a.finishDiag()
		a.emitState(StateError)
		return fmt.Errorf("network detection failed: %w", err)
	}

	// Build config options
	socksListen := p.SocksListen
	if socksListen == "" {
		socksListen = "127.0.0.1:1080"
	}
	serverAddr := fmt.Sprintf("%s:%d", p.Host, p.Port)

	configOpts := &config.Options{
		ServerAddr:    serverAddr,
		Key:           p.Key,
		InterfaceName: netInfo.InterfaceName,
		LocalAddr:     fmt.Sprintf("%s:%d", netInfo.LocalIP, 10000+mathrand.Intn(55000)),
		GatewayMAC:    netInfo.GatewayMAC,
		NpcapGUID:     netInfo.NpcapGUID,
		SocksListen:   socksListen,
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
		LogLevel:      "info",
	}

	// Create prober
	runner := &managerRunner{m: a.manager}
	prober := diag.NewProber(a.binaryPath, a.configDir, runner, func(step diag.StepResult) {
		wailsRuntime.EventsEmit(a.ctx, "diag:step", step)
	}, func(line string) {
		wailsRuntime.EventsEmit(a.ctx, "log:line", line)
	})

	// Run diagnostics
	npcapChecker := a.npcapChecker
	result := prober.Run(ctx, &diag.RunOptions{
		ConfigOpts:  configOpts,
		SocksAddr:   socksListen,
		ProfileName: p.Name,
		ServerAddr:  serverAddr,
		NpcapCheck: func() (bool, string) {
			if npcapChecker == nil {
				return true, ""
			}
			status := npcapChecker.Check()
			return status.Installed, status.DownloadURL
		},
		IsWindows: runtime.GOOS == "windows",
	})

	a.finishDiag()

	if result.Success {
		// Re-enable manager state handler for crash detection
		a.manager.SetStateChangeHandler(func(state process.State) {
			if state == process.StateError || state == process.StateIdle {
				a.emitState(ConnectionState(state))
				a.activeProfile = nil
			}
		})
		a.emitState(StateConnected)
		return nil
	}

	// Failure — stop paqet if still running
	a.manager.Stop()
	a.emitState(StateError)
	a.lastError = result.Summary
	return fmt.Errorf("%s", result.Summary)
}

// CancelConnect cancels an in-progress diagnostic/connection attempt.
func (a *App) CancelConnect() {
	a.diagMu.Lock()
	if a.cancelDiag != nil {
		a.cancelDiag()
	}
	a.diagMu.Unlock()

	if a.manager != nil {
		a.manager.Stop()
	}
	a.emitState(StateIdle)
}

func (a *App) emitState(state ConnectionState) {
	a.connState = state
	wailsRuntime.EventsEmit(a.ctx, "connection:state", string(state))
}

func (a *App) finishDiag() {
	a.diagMu.Lock()
	a.diagActive = false
	a.cancelDiag = nil
	a.diagMu.Unlock()
}

// Disconnect stops the running paqet process.
func (a *App) Disconnect() error {
	// Disable proxy first
	if a.proxySetter != nil && a.proxySetter.IsSystemProxyEnabled() {
		a.proxySetter.DisableSystemProxy()
	}
	if a.pacServer != nil {
		a.pacServer.Stop()
		a.pacServer = nil
	}

	if a.manager != nil {
		return a.manager.Stop()
	}
	a.activeProfile = nil
	return nil
}

// GetConnectionState returns the current connection state.
func (a *App) GetConnectionState() ConnectionState {
	if a.manager != nil {
		return ConnectionState(a.manager.GetState())
	}
	return a.connState
}

// --- System Proxy Methods ---

// EnableSystemProxy starts the PAC server and sets the system proxy.
func (a *App) EnableSystemProxy() error {
	if a.proxySetter == nil {
		return fmt.Errorf("proxy setter not initialized")
	}

	socksAddr := "127.0.0.1:1080"
	if a.activeProfile != nil && a.activeProfile.SocksListen != "" {
		socksAddr = a.activeProfile.SocksListen
	}

	a.pacServer = proxy.NewPACServer(socksAddr)
	_, err := a.pacServer.Start()
	if err != nil {
		return fmt.Errorf("failed to start PAC server: %w", err)
	}

	pacURL := a.pacServer.GetPACURL()
	if err := a.proxySetter.EnableSystemProxy(pacURL); err != nil {
		a.pacServer.Stop()
		a.pacServer = nil
		return fmt.Errorf("failed to set system proxy: %w", err)
	}

	return nil
}

// DisableSystemProxy removes the system proxy and stops the PAC server.
func (a *App) DisableSystemProxy() error {
	if a.proxySetter != nil {
		a.proxySetter.DisableSystemProxy()
	}
	if a.pacServer != nil {
		a.pacServer.Stop()
		a.pacServer = nil
	}
	return nil
}

// IsSystemProxyEnabled returns whether the system proxy is active.
func (a *App) IsSystemProxyEnabled() bool {
	if a.proxySetter != nil {
		return a.proxySetter.IsSystemProxyEnabled()
	}
	return false
}

// --- Network Methods ---

// DetectNetwork auto-detects the network configuration.
func (a *App) DetectNetwork() (*NetworkInfo, error) {
	if a.detector == nil {
		return nil, fmt.Errorf("network detector not initialized")
	}
	info, err := a.detector.Detect()
	if err != nil {
		return nil, err
	}
	return &NetworkInfo{
		InterfaceName: info.InterfaceName,
		LocalIP:       info.LocalIP,
		GatewayIP:     info.GatewayIP,
		GatewayMAC:    info.GatewayMAC,
		NpcapGUID:     info.NpcapGUID,
	}, nil
}

// CheckNpcap checks if Npcap is installed (Windows only).
func (a *App) CheckNpcap() (*NpcapStatus, error) {
	if runtime.GOOS != "windows" {
		return &NpcapStatus{Installed: true}, nil
	}
	if a.npcapChecker == nil {
		return nil, fmt.Errorf("npcap checker not initialized")
	}
	status := a.npcapChecker.Check()
	return &NpcapStatus{
		Installed:   status.Installed,
		DownloadURL: status.DownloadURL,
	}, nil
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

// --- Log Methods ---

// GetLogs returns the last N log lines.
func (a *App) GetLogs(count int) []string {
	if a.manager != nil {
		return a.manager.GetLogs(count)
	}
	return nil
}

// ClearLogs clears the log buffer.
func (a *App) ClearLogs() {
	if a.manager != nil {
		a.manager.ClearLogs()
	}
}

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

// findPaqetBinary locates the paqet binary.
func findPaqetBinary() string {
	name := "paqet"
	if runtime.GOOS == "windows" {
		name = "paqet.exe"
	}

	// Check next to executable (production: bin/paqet.exe beside bin/autopaqet-gui.exe)
	exe, err := os.Executable()
	if err == nil {
		exeDir := filepath.Dir(exe)
		p := filepath.Join(exeDir, name)
		if _, err := os.Stat(p); err == nil {
			return p
		}

		// Wails build puts exe in build/bin/, paqet may be in gui/bin/ (two levels up)
		p = filepath.Join(exeDir, "..", "..", "bin", name)
		if _, err := os.Stat(p); err == nil {
			return p
		}

		// Or in gui/bin/ relative to build/bin/
		p = filepath.Join(exeDir, "..", "..", "gui", "bin", name)
		if _, err := os.Stat(p); err == nil {
			return p
		}
	}

	// Check gui/bin/ from cwd (development with wails dev)
	cwd, _ := os.Getwd()
	p := filepath.Join(cwd, "bin", name)
	if _, err := os.Stat(p); err == nil {
		return p
	}

	// Check repo root bin/ from gui/ cwd
	p = filepath.Join(cwd, "..", "bin", name)
	if _, err := os.Stat(p); err == nil {
		return p
	}

	// Fallback to PATH lookup
	return name
}
