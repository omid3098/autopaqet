package config

import (
	"fmt"

	"gopkg.in/yaml.v3"
)

// Options holds all fields needed to generate a paqet client configuration.
type Options struct {
	// Required
	ServerAddr    string
	Key           string
	InterfaceName string
	LocalAddr     string // ip:port
	GatewayMAC    string

	// Windows only
	NpcapGUID string

	// SOCKS5
	SocksListen string // default 127.0.0.1:1080
	SocksUser   string
	SocksPass   string

	// KCP
	Mode  string // default fast3
	Conn  int    // default 2
	MTU   int
	Block string // default aes

	// KCP windows
	RcvWnd int
	SndWnd int

	// FEC
	DShard int
	PShard int

	// DSCP
	DSCP int

	// Buffers
	SmuxBuf   int
	StreamBuf int
	TCPBuf    int
	UDPBuf    int
	SockBuf   int

	// TCP flags
	LocalFlag  string // default PA
	RemoteFlag string // default PA

	// Forwarding rules
	Forward []string

	// Logging
	LogLevel string // default none
}

// Generate produces a YAML configuration string matching the paqet client format.
func Generate(opts *Options) (string, error) {
	if opts.ServerAddr == "" {
		return "", fmt.Errorf("server address is required")
	}
	if opts.Key == "" {
		return "", fmt.Errorf("key is required")
	}
	if opts.InterfaceName == "" {
		return "", fmt.Errorf("interface name is required")
	}
	if opts.LocalAddr == "" {
		return "", fmt.Errorf("local address is required")
	}
	if opts.GatewayMAC == "" {
		return "", fmt.Errorf("gateway MAC is required")
	}

	// Apply defaults
	socksListen := opts.SocksListen
	if socksListen == "" {
		socksListen = "127.0.0.1:1080"
	}
	mode := opts.Mode
	if mode == "" {
		mode = "fast3"
	}
	conn := opts.Conn
	if conn == 0 {
		conn = 2
	}
	block := opts.Block
	if block == "" {
		block = "aes"
	}
	localFlag := opts.LocalFlag
	if localFlag == "" {
		localFlag = "PA"
	}
	remoteFlag := opts.RemoteFlag
	if remoteFlag == "" {
		remoteFlag = "PA"
	}
	logLevel := opts.LogLevel
	if logLevel == "" {
		logLevel = "none"
	}

	// Build config structure
	cfg := map[string]interface{}{
		"role": "client",
		"log": map[string]interface{}{
			"level": logLevel,
		},
	}

	// SOCKS5
	socksEntry := map[string]interface{}{
		"listen": socksListen,
	}
	if opts.SocksUser != "" {
		socksEntry["username"] = opts.SocksUser
	}
	if opts.SocksPass != "" {
		socksEntry["password"] = opts.SocksPass
	}
	cfg["socks5"] = []interface{}{socksEntry}

	// Network
	network := map[string]interface{}{
		"interface": opts.InterfaceName,
		"ipv4": map[string]interface{}{
			"addr":       opts.LocalAddr,
			"router_mac": opts.GatewayMAC,
		},
		"tcp": map[string]interface{}{
			"local_flag":  []string{localFlag},
			"remote_flag": []string{remoteFlag},
		},
	}
	if opts.NpcapGUID != "" {
		network["guid"] = opts.NpcapGUID
	}
	cfg["network"] = network

	// Server
	cfg["server"] = map[string]interface{}{
		"addr": opts.ServerAddr,
	}

	// Transport
	kcpSection := map[string]interface{}{
		"mode":  mode,
		"key":   opts.Key,
		"block": block,
	}
	if opts.MTU != 0 {
		kcpSection["mtu"] = opts.MTU
	}
	if opts.RcvWnd != 0 {
		kcpSection["rcvwnd"] = opts.RcvWnd
	}
	if opts.SndWnd != 0 {
		kcpSection["sndwnd"] = opts.SndWnd
	}
	if opts.DShard != 0 {
		kcpSection["datashard"] = opts.DShard
	}
	if opts.PShard != 0 {
		kcpSection["parityshard"] = opts.PShard
	}
	if opts.DSCP != 0 {
		kcpSection["dscp"] = opts.DSCP
	}

	transport := map[string]interface{}{
		"protocol": "kcp",
		"conn":     conn,
		"kcp":      kcpSection,
	}
	if opts.SmuxBuf != 0 {
		transport["smuxbuf"] = opts.SmuxBuf
	}
	if opts.StreamBuf != 0 {
		transport["streambuf"] = opts.StreamBuf
	}
	if opts.TCPBuf != 0 {
		transport["tcpbuf"] = opts.TCPBuf
	}
	if opts.UDPBuf != 0 {
		transport["udpbuf"] = opts.UDPBuf
	}
	if opts.SockBuf != 0 {
		transport["sockbuf"] = opts.SockBuf
	}
	cfg["transport"] = transport

	// Forward rules
	if len(opts.Forward) > 0 {
		cfg["forward"] = opts.Forward
	}

	data, err := yaml.Marshal(cfg)
	if err != nil {
		return "", fmt.Errorf("failed to marshal config: %w", err)
	}

	return string(data), nil
}
