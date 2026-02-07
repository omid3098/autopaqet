package diag

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"syscall"
	"time"

	"github.com/omid3098/autopaqet/gui/internal/config"
)

// PaqetRunner abstracts paqet process management for testability.
type PaqetRunner interface {
	StartPaqet(configPath string) error
	StopPaqet() error
}

// RunOptions holds parameters for a diagnostic run.
type RunOptions struct {
	ConfigOpts     *config.Options
	SocksAddr      string
	ProfileName    string
	ServerAddr     string
	NpcapCheck     func() (installed bool, detail string)
	AttemptTimeout time.Duration
	IsWindows      bool
	// VerifyFunc overrides the tunnel verification for testing.
	// If nil, uses the real HTTP-based verifySocks5Tunnel.
	VerifyFunc func(ctx context.Context, socksAddr string, timeout time.Duration) (httpOK bool, dnsOK bool, err error)
	// PollFunc overrides SOCKS5 polling for testing.
	// If nil, uses the real SOCKS5-based pollSocks5.
	PollFunc func(ctx context.Context, socksAddr string, timeout time.Duration) error
}

// Prober orchestrates the diagnostic flow.
type Prober struct {
	binaryPath string
	configDir  string
	runner     PaqetRunner
	onStep     func(StepResult)
	onLog      func(string)
}

// NewProber creates a new diagnostic prober.
func NewProber(binaryPath, configDir string, runner PaqetRunner, onStep func(StepResult), onLog func(string)) *Prober {
	return &Prober{
		binaryPath: binaryPath,
		configDir:  configDir,
		runner:     runner,
		onStep:     onStep,
		onLog:      onLog,
	}
}

// Run executes the full diagnostic flow and returns the result.
func (p *Prober) Run(ctx context.Context, opts *RunOptions) *Result {
	if opts.AttemptTimeout == 0 {
		opts.AttemptTimeout = 15 * time.Second
	}

	result := &Result{}

	// Step 1: Network (already detected, just report)
	p.emitStep(StepResult{
		ID:      StepNetwork,
		Status:  StatusPass,
		Message: fmt.Sprintf("Network: %s / %s", opts.ConfigOpts.InterfaceName, opts.ConfigOpts.LocalAddr),
		Detail:  fmt.Sprintf("gateway_mac=%s npcap_guid=%s", opts.ConfigOpts.GatewayMAC, opts.ConfigOpts.NpcapGUID),
	})
	result.Steps = append(result.Steps, StepResult{
		ID: StepNetwork, Status: StatusPass,
		Message: fmt.Sprintf("%s / %s / gw %s", opts.ConfigOpts.InterfaceName, opts.ConfigOpts.LocalAddr, opts.ConfigOpts.GatewayMAC),
	})

	// Check for cancellation
	if ctx.Err() != nil {
		return p.cancelled(result)
	}

	// Step 2: Npcap check (Windows only)
	if opts.IsWindows {
		p.emitStep(StepResult{ID: StepNpcap, Status: StatusRunning, Message: "Checking Npcap..."})
		if opts.NpcapCheck != nil {
			installed, detail := opts.NpcapCheck()
			if !installed {
				step := StepResult{ID: StepNpcap, Status: StatusFail, Message: "Npcap not installed", Detail: detail}
				p.emitStep(step)
				result.Steps = append(result.Steps, step)
				result.Summary = "Npcap is required but not installed"
				result.Suggestions = []string{"Install Npcap from https://npcap.com/#download", "Restart the application after installation"}
				return result
			}
			step := StepResult{ID: StepNpcap, Status: StatusPass, Message: "Npcap installed"}
			p.emitStep(step)
			result.Steps = append(result.Steps, step)
		}
	} else {
		step := StepResult{ID: StepNpcap, Status: StatusSkip, Message: "Npcap check (Windows only)"}
		p.emitStep(step)
		result.Steps = append(result.Steps, step)
	}

	if ctx.Err() != nil {
		return p.cancelled(result)
	}

	// Step 3: ICMP ping
	p.emitStep(StepResult{ID: StepPing, Status: StatusRunning, Message: "Pinging server..."})
	serverHost := extractHost(opts.ServerAddr)
	if err := p.icmpPing(ctx, serverHost); err != nil {
		step := StepResult{ID: StepPing, Status: StatusWarn, Message: "Server ping: timeout", Detail: "ICMP may be blocked by ISP — continuing"}
		p.emitStep(step)
		result.Steps = append(result.Steps, step)
	} else {
		step := StepResult{ID: StepPing, Status: StatusPass, Message: fmt.Sprintf("Server reachable (%s)", serverHost)}
		p.emitStep(step)
		result.Steps = append(result.Steps, step)
	}

	if ctx.Err() != nil {
		return p.cancelled(result)
	}

	// Step 4: Connection attempt with profile's configured flags
	currentFlags := opts.ConfigOpts.LocalFlag
	if currentFlags == "" {
		currentFlags = "PA"
	}
	p.emitStep(StepResult{
		ID:      StepConnect,
		Status:  StatusRunning,
		Message: fmt.Sprintf("Connecting (%s flags, port %s)...", currentFlags, extractPort(opts.ServerAddr)),
	})

	// Generate config and write to temp file
	configPath := filepath.Join(p.configDir, "paqet-diag.yaml")
	yamlStr, err := config.Generate(opts.ConfigOpts)
	if err != nil {
		step := StepResult{ID: StepConnect, Status: StatusFail, Message: "Config generation failed", Detail: err.Error()}
		p.emitStep(step)
		result.Steps = append(result.Steps, step)
		result.Summary = "Failed to generate configuration"
		return result
	}
	if err := os.WriteFile(configPath, []byte(yamlStr), 0644); err != nil {
		step := StepResult{ID: StepConnect, Status: StatusFail, Message: "Failed to write config", Detail: err.Error()}
		p.emitStep(step)
		result.Steps = append(result.Steps, step)
		result.Summary = "Failed to write configuration file"
		return result
	}

	// Record client config for diagnostic report
	cfgMode := opts.ConfigOpts.Mode
	if cfgMode == "" {
		cfgMode = "fast3"
	}
	cfgConn := opts.ConfigOpts.Conn
	if cfgConn == 0 {
		cfgConn = 2
	}
	cfgBlock := opts.ConfigOpts.Block
	if cfgBlock == "" {
		cfgBlock = "aes"
	}
	result.ConfigSummary = fmt.Sprintf("mode=%s conn=%d block=%s flags=%s port=%s",
		cfgMode, cfgConn, cfgBlock, currentFlags, extractPort(opts.ServerAddr))

	// Start paqet and poll SOCKS5
	startTime := time.Now()
	if err := p.runner.StartPaqet(configPath); err != nil {
		step := StepResult{ID: StepConnect, Status: StatusFail, Message: "Failed to start paqet", Detail: err.Error()}
		p.emitStep(step)
		result.Steps = append(result.Steps, step)
		result.Summary = "Failed to start paqet process"
		result.Suggestions = []string{"Check that paqet binary exists and is executable", "Try running as administrator"}
		return result
	}

	pollFn := pollSocks5
	if opts.PollFunc != nil {
		pollFn = opts.PollFunc
	}
	connectErr := pollFn(ctx, opts.SocksAddr, opts.AttemptTimeout)
	elapsed := time.Since(startTime).Round(100 * time.Millisecond)

	if connectErr == nil {
		// Connection successful!
		step := StepResult{
			ID:      StepConnect,
			Status:  StatusPass,
			Message: fmt.Sprintf("Connected (%s flags): SOCKS5 ready in %s", currentFlags, elapsed),
		}
		p.emitStep(step)
		result.Steps = append(result.Steps, step)

		// Step 5: Verify tunnel
		return p.verifyTunnel(ctx, opts, result)
	}

	// Connection failed — stop paqet and run diagnostics
	step := StepResult{
		ID:      StepConnect,
		Status:  StatusFail,
		Message: fmt.Sprintf("Connect (%s flags): SOCKS5 timeout after %s", currentFlags, opts.AttemptTimeout),
	}
	p.emitStep(step)
	result.Steps = append(result.Steps, step)
	p.runner.StopPaqet()

	if ctx.Err() != nil {
		return p.cancelled(result)
	}

	// Step 6: Diagnostic flag probes
	return p.runDiagnostics(ctx, opts, result)
}

// verifyTunnel tests that traffic actually flows through the SOCKS5 proxy
// by performing real HTTP requests through the tunnel.
func (p *Prober) verifyTunnel(ctx context.Context, opts *RunOptions, result *Result) *Result {
	p.emitStep(StepResult{ID: StepVerify, Status: StatusRunning, Message: "Verifying tunnel (HTTP test)..."})

	verifyFn := verifySocks5Tunnel
	if opts.VerifyFunc != nil {
		verifyFn = opts.VerifyFunc
	}
	httpOK, dnsOK, err := verifyFn(ctx, opts.SocksAddr, 10*time.Second)

	if err != nil {
		// Total failure — SOCKS5 accepts but no data flows through tunnel
		step := StepResult{
			ID:      StepVerify,
			Status:  StatusFail,
			Message: "Tunnel not forwarding traffic",
			Detail:  "SOCKS5 proxy responds but HTTP request through tunnel failed: " + err.Error(),
		}
		p.emitStep(step)
		result.Steps = append(result.Steps, step)

		// Stop paqet and run full diagnostics to help the user
		p.runner.StopPaqet()

		if ctx.Err() != nil {
			return p.cancelled(result)
		}

		return p.runDiagnostics(ctx, opts, result)
	}

	if httpOK && !dnsOK {
		// Tunnel works but DNS doesn't resolve through the proxy
		step := StepResult{
			ID:      StepVerify,
			Status:  StatusWarn,
			Message: "Tunnel works but DNS not resolving through proxy",
			Detail:  "HTTP to 1.1.1.1 succeeded. DNS-based requests failed. Configure DNS manually.",
		}
		p.emitStep(step)
		result.Steps = append(result.Steps, step)
		result.Success = true
		result.Summary = "CONNECTED (DNS warning)"
		result.Suggestions = []string{
			"DNS resolution through the tunnel is not working",
			"Configure browser to use DNS over HTTPS (DoH) with 8.8.8.8 or 1.1.1.1",
			"Or set system DNS to 8.8.8.8 / 1.1.1.1",
		}
		p.emitReport(result)
		return result
	}

	// Full success — HTTP and DNS both work
	step := StepResult{
		ID:      StepVerify,
		Status:  StatusPass,
		Message: "Tunnel verified — HTTP and DNS working through proxy",
	}
	p.emitStep(step)
	result.Steps = append(result.Steps, step)
	result.Success = true
	result.Summary = "CONNECTED"
	p.emitReport(result)
	return result
}

// runDiagnostics probes flag combinations and generates suggestions.
func (p *Prober) runDiagnostics(ctx context.Context, opts *RunOptions, result *Result) *Result {
	p.emitStep(StepResult{ID: StepDiagnose, Status: StatusRunning, Message: "Running diagnostics..."})

	flags := []string{"S", "PA", "A"}
	var probes []FlagProbeResult

	for _, flag := range flags {
		if ctx.Err() != nil {
			break
		}
		p.emitStep(StepResult{
			ID:      StepDiagnose,
			Status:  StatusRunning,
			Message: fmt.Sprintf("Testing %s flags with paqet ping...", flag),
		})

		success, output := p.paqetPing(ctx, opts, flag)
		probes = append(probes, FlagProbeResult{
			Flag:    flag,
			Success: success,
			Output:  output,
		})
	}

	result.FlagProbes = probes

	// Build suggestions based on all collected data
	result.Suggestions = p.buildSuggestions(opts, result)

	// Determine diagnose step status
	anyPingSent := false
	for _, pr := range probes {
		if pr.Success {
			anyPingSent = true
			break
		}
	}

	var probeLines []string
	for _, pr := range probes {
		status := "sent OK"
		if !pr.Success {
			status = "failed"
		}
		probeLines = append(probeLines, fmt.Sprintf("  %s flags: %s", pr.Flag, status))
	}
	probeDetail := strings.Join(probeLines, "\n")

	if anyPingSent {
		step := StepResult{
			ID:      StepDiagnose,
			Status:  StatusWarn,
			Message: "Packet injection works but connection failed",
			Detail:  probeDetail,
		}
		p.emitStep(step)
		result.Steps = append(result.Steps, step)
	} else {
		step := StepResult{
			ID:      StepDiagnose,
			Status:  StatusFail,
			Message: "All packet injection tests failed",
			Detail:  probeDetail,
		}
		p.emitStep(step)
		result.Steps = append(result.Steps, step)
	}

	result.Summary = "FAILED — connection did not establish"
	p.emitReport(result)
	return result
}

// paqetPing runs `paqet ping -c <config>` with the specified flag and returns whether it succeeded.
func (p *Prober) paqetPing(ctx context.Context, opts *RunOptions, flag string) (bool, string) {
	// Create a temp config with the probe flag
	probeCfg := *opts.ConfigOpts
	probeCfg.LocalFlag = flag
	probeCfg.RemoteFlag = flag
	probeCfg.LogLevel = "debug"

	yamlStr, err := config.Generate(&probeCfg)
	if err != nil {
		return false, fmt.Sprintf("config error: %v", err)
	}

	configPath := filepath.Join(p.configDir, fmt.Sprintf("paqet-probe-%s.yaml", strings.ToLower(flag)))
	if err := os.WriteFile(configPath, []byte(yamlStr), 0644); err != nil {
		return false, fmt.Sprintf("write error: %v", err)
	}

	cmd := exec.CommandContext(ctx, p.binaryPath, "ping", "-c", configPath)
	hideConsole(cmd)

	out, err := cmd.CombinedOutput()
	output := strings.TrimSpace(string(out))

	if err != nil {
		return false, output
	}

	// paqet ping outputs "Packet sent successfully!" on success
	success := strings.Contains(strings.ToLower(output), "sent successfully")
	return success, output
}

// icmpPing sends a single ICMP ping to the given host.
func (p *Prober) icmpPing(ctx context.Context, host string) error {
	var cmd *exec.Cmd
	if runtime.GOOS == "windows" {
		cmd = exec.CommandContext(ctx, "ping", "-n", "1", "-w", "2000", host)
	} else {
		cmd = exec.CommandContext(ctx, "ping", "-c", "1", "-W", "2", host)
	}
	hideConsole(cmd)
	return cmd.Run()
}

// buildSuggestions generates actionable suggestions from diagnostic results.
func (p *Prober) buildSuggestions(opts *RunOptions, result *Result) []string {
	var suggestions []string

	currentFlags := opts.ConfigOpts.LocalFlag
	if currentFlags == "" {
		currentFlags = "PA"
	}

	// Detect "SOCKS5 ready but tunnel broken" scenario
	tunnelVerifyFailed := false
	for _, s := range result.Steps {
		if s.ID == StepVerify && s.Status == StatusFail {
			tunnelVerifyFailed = true
			break
		}
	}

	// Analyze flag probes
	allPingOK := true
	anyPingOK := false
	synPingOK := false
	for _, pr := range result.FlagProbes {
		if pr.Success {
			anyPingOK = true
			if pr.Flag == "S" {
				synPingOK = true
			}
		} else {
			allPingOK = false
		}
	}

	// Analyze ICMP ping result
	icmpFailed := false
	for _, s := range result.Steps {
		if s.ID == StepPing && s.Status == StatusWarn {
			icmpFailed = true
		}
	}

	if !anyPingOK {
		suggestions = append(suggestions,
			"All packet injection tests failed — Npcap may not be working correctly",
			"Try reinstalling Npcap from https://npcap.com/#download",
			"Ensure the application is running with administrator privileges",
		)
		return suggestions
	}

	// KCP parameter mismatch: SOCKS5 started but tunnel doesn't forward traffic
	if tunnelVerifyFailed && allPingOK {
		mode := opts.ConfigOpts.Mode
		if mode == "" {
			mode = "fast3"
		}
		conn := opts.ConfigOpts.Conn
		if conn == 0 {
			conn = 2
		}
		block := opts.ConfigOpts.Block
		if block == "" {
			block = "aes"
		}

		suggestions = append(suggestions,
			"SOCKS5 proxy started but tunnel is not forwarding traffic",
			fmt.Sprintf("Client KCP settings: mode=%s, conn=%d, block=%s — these MUST match the server", mode, conn, block),
			"Ask admin for the server's transport settings (mode, conn, block) and update your profile to match",
			"Common fix: change Mode to 'fast' and Connections to 1 in Settings tab",
		)

		port := extractPort(opts.ServerAddr)
		suggestions = append(suggestions,
			fmt.Sprintf("Ask admin to run: tcpdump -i eth0 port %s (on server, to check if packets arrive)", port),
			"Ask admin to check server logs for errors or connection attempts",
		)
		return suggestions
	}

	if allPingOK {
		suggestions = append(suggestions,
			"Packets can be sent locally with all flag types (Npcap working)",
			fmt.Sprintf("Server may not be receiving %s packets — ISP/router may be blocking them", currentFlags),
		)
	}

	if synPingOK && currentFlags != "S" {
		suggestions = append(suggestions,
			"Try: Update BOTH the profile AND server config to use S (SYN) flags — SYN passes most firewalls",
		)
	}

	port := extractPort(opts.ServerAddr)
	if port != "443" {
		suggestions = append(suggestions,
			"Try: Change server port to 443 (HTTPS port, less likely to be filtered)",
		)
	}

	if icmpFailed {
		suggestions = append(suggestions,
			"Server IP may be unreachable — verify the server is running and the IP is correct",
		)
	}

	suggestions = append(suggestions,
		fmt.Sprintf("Ask admin to run: tcpdump -i eth0 port %s (on server, to check if packets arrive)", port),
		"Ask admin to check server logs for errors or connection attempts",
	)

	return suggestions
}

// emitStep sends a step update to the frontend callback.
func (p *Prober) emitStep(step StepResult) {
	if p.onStep != nil {
		p.onStep(step)
	}
}

// emitReport formats and emits the full diagnostic report to logs.
func (p *Prober) emitReport(result *Result) {
	if p.onLog == nil {
		return
	}

	p.onLog("")
	p.onLog("=== AutoPaqet Diagnostic Report ===")
	p.onLog(fmt.Sprintf("Time: %s", time.Now().Format("2006-01-02 15:04:05")))
	p.onLog("")

	for _, s := range result.Steps {
		tag := strings.ToUpper(string(s.Status))
		line := fmt.Sprintf("[%s] %s", tag, s.Message)
		p.onLog(line)
		if s.Detail != "" {
			for _, dl := range strings.Split(s.Detail, "\n") {
				p.onLog("       " + dl)
			}
		}
	}

	if result.ConfigSummary != "" {
		p.onLog("")
		p.onLog("--- Client Config ---")
		p.onLog("  " + result.ConfigSummary)
	}

	if len(result.FlagProbes) > 0 {
		p.onLog("")
		p.onLog("--- Flag Probe Results ---")
		for _, pr := range result.FlagProbes {
			status := "PASS"
			if !pr.Success {
				status = "FAIL"
			}
			p.onLog(fmt.Sprintf("[%s] paqet ping %s flags: %s", status, pr.Flag, pr.Output))
		}
	}

	p.onLog("")
	p.onLog(fmt.Sprintf("Result: %s", result.Summary))

	if len(result.Suggestions) > 0 {
		p.onLog("")
		p.onLog("Suggestions:")
		for i, s := range result.Suggestions {
			p.onLog(fmt.Sprintf("  %d. %s", i+1, s))
		}
	}

	p.onLog("=== End Report ===")
	p.onLog("")
}

func (p *Prober) cancelled(result *Result) *Result {
	result.Summary = "Cancelled"
	return result
}

// hideConsole sets process attributes to prevent console windows on Windows.
func hideConsole(cmd *exec.Cmd) {
	if runtime.GOOS == "windows" {
		cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: 0x08000000}
	}
}

// extractHost extracts the host part from a "host:port" string.
func extractHost(addr string) string {
	host, _, err := splitHostPort(addr)
	if err != nil {
		return addr
	}
	return host
}

// extractPort extracts the port part from a "host:port" string.
func extractPort(addr string) string {
	_, port, err := splitHostPort(addr)
	if err != nil {
		return ""
	}
	return port
}

// splitHostPort splits a host:port string. Handles IPv6 [host]:port.
func splitHostPort(addr string) (string, string, error) {
	// Try standard split first
	if host, port, err := splitAddr(addr); err == nil {
		return host, port, nil
	}
	return addr, "", fmt.Errorf("invalid address: %s", addr)
}

func splitAddr(addr string) (string, string, error) {
	last := strings.LastIndex(addr, ":")
	if last < 0 {
		return addr, "", fmt.Errorf("no port")
	}
	return addr[:last], addr[last+1:], nil
}
