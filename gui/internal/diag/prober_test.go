package diag

import (
	"context"
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/omid3098/autopaqet/gui/internal/config"
)

// mockRunner tracks StartPaqet/StopPaqet calls.
type mockRunner struct {
	startCalls []string
	stopCalls  int
	startErr   error
}

func (m *mockRunner) StartPaqet(configPath string) error {
	m.startCalls = append(m.startCalls, configPath)
	return m.startErr
}

func (m *mockRunner) StopPaqet() error {
	m.stopCalls++
	return nil
}

func baseOpts() *RunOptions {
	return &RunOptions{
		ConfigOpts: &config.Options{
			ServerAddr:    "1.2.3.4:9999",
			Key:           "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
			InterfaceName: "eth0",
			LocalAddr:     "10.0.0.1:12345",
			GatewayMAC:    "aa:bb:cc:dd:ee:ff",
			LocalFlag:     "PA",
			RemoteFlag:    "PA",
		},
		SocksAddr:      "127.0.0.1:1080",
		ProfileName:    "TestProfile",
		ServerAddr:     "1.2.3.4:9999",
		AttemptTimeout: 100 * time.Millisecond, // Very short for tests
		IsWindows:      false,
		NpcapCheck:     func() (bool, string) { return true, "" },
	}
}

func TestExtractHost(t *testing.T) {
	tests := []struct {
		addr, want string
	}{
		{"1.2.3.4:9999", "1.2.3.4"},
		{"example.com:443", "example.com"},
		{"just-host", "just-host"},
	}
	for _, tc := range tests {
		got := extractHost(tc.addr)
		if got != tc.want {
			t.Errorf("extractHost(%q) = %q, want %q", tc.addr, got, tc.want)
		}
	}
}

func TestExtractPort(t *testing.T) {
	tests := []struct {
		addr, want string
	}{
		{"1.2.3.4:9999", "9999"},
		{"example.com:443", "443"},
	}
	for _, tc := range tests {
		got := extractPort(tc.addr)
		if got != tc.want {
			t.Errorf("extractPort(%q) = %q, want %q", tc.addr, got, tc.want)
		}
	}
}

func TestBuildSuggestions_AllPingOK_PA_Flags(t *testing.T) {
	opts := baseOpts()
	result := &Result{
		Steps: []StepResult{
			{ID: StepPing, Status: StatusWarn},
		},
		FlagProbes: []FlagProbeResult{
			{Flag: "S", Success: true},
			{Flag: "PA", Success: true},
			{Flag: "A", Success: true},
		},
	}

	p := &Prober{}
	suggestions := p.buildSuggestions(opts, result)

	// Should suggest SYN since current is PA
	hasSynSuggestion := false
	hasPort443Suggestion := false
	hasServerUnreachable := false
	for _, s := range suggestions {
		if strings.Contains(s, "SYN") {
			hasSynSuggestion = true
		}
		if strings.Contains(s, "443") {
			hasPort443Suggestion = true
		}
		if strings.Contains(s, "unreachable") {
			hasServerUnreachable = true
		}
	}
	if !hasSynSuggestion {
		t.Error("expected SYN flag suggestion when current flags are PA")
	}
	if !hasPort443Suggestion {
		t.Error("expected port 443 suggestion when using port 9999")
	}
	if !hasServerUnreachable {
		t.Error("expected server unreachable suggestion when ICMP failed")
	}
}

func TestBuildSuggestions_NoPingOK(t *testing.T) {
	opts := baseOpts()
	result := &Result{
		FlagProbes: []FlagProbeResult{
			{Flag: "S", Success: false},
			{Flag: "PA", Success: false},
			{Flag: "A", Success: false},
		},
	}

	p := &Prober{}
	suggestions := p.buildSuggestions(opts, result)

	hasNpcapSuggestion := false
	for _, s := range suggestions {
		if strings.Contains(s, "Npcap") || strings.Contains(s, "npcap") {
			hasNpcapSuggestion = true
		}
	}
	if !hasNpcapSuggestion {
		t.Error("expected Npcap reinstall suggestion when all pings fail")
	}
}

func TestBuildSuggestions_AlreadyOnPort443(t *testing.T) {
	opts := baseOpts()
	opts.ServerAddr = "1.2.3.4:443"
	opts.ConfigOpts.ServerAddr = "1.2.3.4:443"
	result := &Result{
		FlagProbes: []FlagProbeResult{
			{Flag: "S", Success: true},
			{Flag: "PA", Success: true},
		},
	}

	p := &Prober{}
	suggestions := p.buildSuggestions(opts, result)

	for _, s := range suggestions {
		if strings.Contains(s, "Change server port to 443") {
			t.Error("should not suggest port 443 when already using 443")
		}
	}
}

func TestBuildSuggestions_AlreadySYN(t *testing.T) {
	opts := baseOpts()
	opts.ConfigOpts.LocalFlag = "S"
	result := &Result{
		FlagProbes: []FlagProbeResult{
			{Flag: "S", Success: true},
		},
	}

	p := &Prober{}
	suggestions := p.buildSuggestions(opts, result)

	for _, s := range suggestions {
		if strings.Contains(s, "Update BOTH the profile AND server config to use S") {
			t.Error("should not suggest switching to SYN when already using SYN")
		}
	}
}

func TestProber_StartFailure(t *testing.T) {
	runner := &mockRunner{startErr: fmt.Errorf("binary not found")}
	var steps []StepResult

	p := NewProber("/fake/paqet", t.TempDir(), runner, func(s StepResult) {
		steps = append(steps, s)
	}, nil)

	opts := baseOpts()
	result := p.Run(context.Background(), opts)

	if result.Success {
		t.Error("expected failure when start fails")
	}

	// Should have failed at connect step
	hasConnectFail := false
	for _, s := range result.Steps {
		if s.ID == StepConnect && s.Status == StatusFail {
			hasConnectFail = true
		}
	}
	if !hasConnectFail {
		t.Error("expected connect step to fail")
	}
}

func TestProber_Cancellation(t *testing.T) {
	runner := &mockRunner{}
	ctx, cancel := context.WithCancel(context.Background())
	cancel() // Cancel immediately

	p := NewProber("/fake/paqet", t.TempDir(), runner, func(s StepResult) {}, nil)

	opts := baseOpts()
	result := p.Run(ctx, opts)

	if result.Success {
		t.Error("expected failure on cancelled context")
	}
	if result.Summary != "Cancelled" {
		t.Errorf("expected 'Cancelled' summary, got %q", result.Summary)
	}
}

func TestProber_NpcapFail_Windows(t *testing.T) {
	runner := &mockRunner{}
	var steps []StepResult

	p := NewProber("/fake/paqet", t.TempDir(), runner, func(s StepResult) {
		steps = append(steps, s)
	}, nil)

	opts := baseOpts()
	opts.IsWindows = true
	opts.NpcapCheck = func() (bool, string) { return false, "Npcap DLL not found" }

	result := p.Run(context.Background(), opts)

	if result.Success {
		t.Error("expected failure when Npcap not installed")
	}

	hasNpcapFail := false
	for _, s := range result.Steps {
		if s.ID == StepNpcap && s.Status == StatusFail {
			hasNpcapFail = true
		}
	}
	if !hasNpcapFail {
		t.Error("expected npcap step to fail")
	}

	if len(runner.startCalls) != 0 {
		t.Error("paqet should not be started when Npcap is missing")
	}
}

func TestVerifyTunnel_FullSuccess(t *testing.T) {
	runner := &mockRunner{}
	var steps []StepResult
	var logLines []string

	p := NewProber("/fake/paqet", t.TempDir(), runner, func(s StepResult) {
		steps = append(steps, s)
	}, func(line string) {
		logLines = append(logLines, line)
	})

	opts := baseOpts()
	// Mock: poll succeeds, verify returns full success
	opts.PollFunc = func(ctx context.Context, socksAddr string, timeout time.Duration) error {
		return nil
	}
	opts.VerifyFunc = func(ctx context.Context, socksAddr string, timeout time.Duration) (bool, bool, error) {
		return true, true, nil
	}

	result := p.Run(context.Background(), opts)

	if !result.Success {
		t.Error("expected success when HTTP and DNS both pass")
	}
	if result.Summary != "CONNECTED" {
		t.Errorf("expected CONNECTED summary, got %q", result.Summary)
	}

	// Verify step should be PASS
	hasVerifyPass := false
	for _, s := range result.Steps {
		if s.ID == StepVerify && s.Status == StatusPass {
			hasVerifyPass = true
		}
	}
	if !hasVerifyPass {
		t.Error("expected verify step to pass")
	}

	// Report should be emitted
	report := strings.Join(logLines, "\n")
	if !strings.Contains(report, "CONNECTED") {
		t.Error("report should contain CONNECTED")
	}
}

func TestVerifyTunnel_HTTPFailRunsDiagnostics(t *testing.T) {
	runner := &mockRunner{}
	var steps []StepResult

	p := NewProber("/fake/paqet", t.TempDir(), runner, func(s StepResult) {
		steps = append(steps, s)
	}, func(line string) {})

	opts := baseOpts()
	opts.PollFunc = func(ctx context.Context, socksAddr string, timeout time.Duration) error {
		return nil
	}
	opts.VerifyFunc = func(ctx context.Context, socksAddr string, timeout time.Duration) (bool, bool, error) {
		return false, false, fmt.Errorf("HTTP request timed out")
	}

	result := p.Run(context.Background(), opts)

	if result.Success {
		t.Error("expected failure when HTTP verification fails")
	}

	// Should have verify fail step
	hasVerifyFail := false
	for _, s := range result.Steps {
		if s.ID == StepVerify && s.Status == StatusFail {
			hasVerifyFail = true
		}
	}
	if !hasVerifyFail {
		t.Error("expected verify step to fail")
	}

	// Should have run diagnostics (diagnose step should exist)
	hasDiagnoseStep := false
	for _, s := range steps {
		if s.ID == StepDiagnose {
			hasDiagnoseStep = true
		}
	}
	if !hasDiagnoseStep {
		t.Error("expected diagnostics to run after verify failure")
	}

	// Paqet should have been stopped
	if runner.stopCalls == 0 {
		t.Error("expected paqet to be stopped after verify failure")
	}
}

func TestVerifyTunnel_DNSWarning(t *testing.T) {
	runner := &mockRunner{}
	var steps []StepResult

	p := NewProber("/fake/paqet", t.TempDir(), runner, func(s StepResult) {
		steps = append(steps, s)
	}, func(line string) {})

	opts := baseOpts()
	opts.PollFunc = func(ctx context.Context, socksAddr string, timeout time.Duration) error {
		return nil
	}
	opts.VerifyFunc = func(ctx context.Context, socksAddr string, timeout time.Duration) (bool, bool, error) {
		return true, false, nil // HTTP works, DNS doesn't
	}

	result := p.Run(context.Background(), opts)

	if !result.Success {
		t.Error("expected success when HTTP works (even if DNS fails)")
	}
	if !strings.Contains(result.Summary, "DNS") {
		t.Errorf("expected DNS warning in summary, got %q", result.Summary)
	}

	// Should have verify warn step
	hasVerifyWarn := false
	for _, s := range result.Steps {
		if s.ID == StepVerify && s.Status == StatusWarn {
			hasVerifyWarn = true
		}
	}
	if !hasVerifyWarn {
		t.Error("expected verify step to have warn status for DNS failure")
	}

	// Should have DNS suggestions
	hasDNSSuggestion := false
	for _, s := range result.Suggestions {
		if strings.Contains(s, "DNS") {
			hasDNSSuggestion = true
		}
	}
	if !hasDNSSuggestion {
		t.Error("expected DNS-related suggestion")
	}
}

func TestBuildSuggestions_TunnelVerifyFailed(t *testing.T) {
	opts := baseOpts()
	// Simulate default KCP settings (empty = defaults to fast/1/aes)
	opts.ConfigOpts.Mode = ""
	opts.ConfigOpts.Conn = 0
	opts.ConfigOpts.Block = ""
	opts.ServerAddr = "1.2.3.4:443"
	opts.ConfigOpts.ServerAddr = "1.2.3.4:443"
	opts.ConfigOpts.LocalFlag = "S"

	result := &Result{
		Steps: []StepResult{
			{ID: StepConnect, Status: StatusPass, Message: "Connected (S flags)"},
			{ID: StepVerify, Status: StatusFail, Message: "Tunnel not forwarding traffic"},
		},
		FlagProbes: []FlagProbeResult{
			{Flag: "S", Success: true},
			{Flag: "PA", Success: true},
			{Flag: "A", Success: true},
		},
	}

	p := &Prober{}
	suggestions := p.buildSuggestions(opts, result)

	// Should suggest KCP parameter check
	hasKCPSuggestion := false
	hasModeMention := false
	for _, s := range suggestions {
		if strings.Contains(s, "MUST match the server") {
			hasKCPSuggestion = true
		}
		if strings.Contains(s, "mode=fast") {
			hasModeMention = true
		}
	}
	if !hasKCPSuggestion {
		t.Error("expected KCP parameter match suggestion when tunnel verify fails")
	}
	if !hasModeMention {
		t.Error("expected mode=fast in suggestion (default applied)")
	}

	// Should NOT suggest changing flags/port since tunnel verify failed (server IS receiving)
	for _, s := range suggestions {
		if strings.Contains(s, "Server may not be receiving") {
			t.Error("should not suggest server not receiving packets when SOCKS5 was ready")
		}
	}
}

func TestBuildSuggestions_TunnelVerifyFailed_CustomKCP(t *testing.T) {
	opts := baseOpts()
	opts.ConfigOpts.Mode = "fast2"
	opts.ConfigOpts.Conn = 3
	opts.ConfigOpts.Block = "salsa20"
	opts.ServerAddr = "1.2.3.4:443"
	opts.ConfigOpts.ServerAddr = "1.2.3.4:443"
	opts.ConfigOpts.LocalFlag = "S"

	result := &Result{
		Steps: []StepResult{
			{ID: StepVerify, Status: StatusFail, Message: "Tunnel not forwarding traffic"},
		},
		FlagProbes: []FlagProbeResult{
			{Flag: "S", Success: true},
			{Flag: "PA", Success: true},
			{Flag: "A", Success: true},
		},
	}

	p := &Prober{}
	suggestions := p.buildSuggestions(opts, result)

	// Should show actual KCP params, not defaults
	hasCorrectParams := false
	for _, s := range suggestions {
		if strings.Contains(s, "mode=fast2") && strings.Contains(s, "conn=3") && strings.Contains(s, "block=salsa20") {
			hasCorrectParams = true
		}
	}
	if !hasCorrectParams {
		t.Errorf("expected actual KCP params (fast2/3/salsa20) in suggestions, got: %v", suggestions)
	}
}

func TestEmitReport(t *testing.T) {
	var logLines []string
	p := &Prober{
		onLog: func(line string) {
			logLines = append(logLines, line)
		},
	}

	result := &Result{
		Success: true,
		Steps: []StepResult{
			{ID: StepNetwork, Status: StatusPass, Message: "WiFi / 10.0.0.1:1234"},
			{ID: StepNpcap, Status: StatusPass, Message: "Npcap installed"},
			{ID: StepPing, Status: StatusWarn, Message: "Server ping: timeout", Detail: "ICMP blocked"},
			{ID: StepConnect, Status: StatusPass, Message: "Connected (S flags)"},
			{ID: StepVerify, Status: StatusPass, Message: "Tunnel verified"},
		},
		Summary: "CONNECTED",
	}

	p.emitReport(result)

	report := strings.Join(logLines, "\n")
	if !strings.Contains(report, "=== AutoPaqet Diagnostic Report ===") {
		t.Error("report missing header")
	}
	if !strings.Contains(report, "[PASS] WiFi") {
		t.Error("report missing network step")
	}
	if !strings.Contains(report, "[WARN] Server ping") {
		t.Error("report missing ping warning")
	}
	if !strings.Contains(report, "Result: CONNECTED") {
		t.Error("report missing result line")
	}
	if !strings.Contains(report, "=== End Report ===") {
		t.Error("report missing footer")
	}
}

func TestEmitReport_WithConfigSummary(t *testing.T) {
	var logLines []string
	p := &Prober{
		onLog: func(line string) {
			logLines = append(logLines, line)
		},
	}

	result := &Result{
		Steps: []StepResult{
			{ID: StepVerify, Status: StatusFail, Message: "Tunnel not forwarding traffic"},
		},
		Summary:       "FAILED",
		ConfigSummary: "mode=fast3 conn=2 block=aes flags=S port=443",
	}

	p.emitReport(result)

	report := strings.Join(logLines, "\n")
	if !strings.Contains(report, "--- Client Config ---") {
		t.Error("report missing client config section")
	}
	if !strings.Contains(report, "mode=fast3 conn=2") {
		t.Error("report missing config summary values")
	}
}

func TestEmitReport_WithSuggestions(t *testing.T) {
	var logLines []string
	p := &Prober{
		onLog: func(line string) {
			logLines = append(logLines, line)
		},
	}

	result := &Result{
		Steps: []StepResult{
			{ID: StepConnect, Status: StatusFail, Message: "SOCKS5 timeout"},
		},
		FlagProbes: []FlagProbeResult{
			{Flag: "S", Success: true, Output: "Packet sent successfully!"},
			{Flag: "PA", Success: true, Output: "Packet sent successfully!"},
		},
		Suggestions: []string{"Try S flags", "Check server logs"},
		Summary:     "FAILED",
	}

	p.emitReport(result)

	report := strings.Join(logLines, "\n")
	if !strings.Contains(report, "Flag Probe Results") {
		t.Error("report missing flag probe section")
	}
	if !strings.Contains(report, "Suggestions:") {
		t.Error("report missing suggestions section")
	}
	if !strings.Contains(report, "1. Try S flags") {
		t.Error("report missing first suggestion")
	}
}
