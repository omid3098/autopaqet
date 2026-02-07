package config

import (
	"strings"
	"testing"

	"gopkg.in/yaml.v3"
)

func TestGenerateMinimalConfig(t *testing.T) {
	opts := &Options{
		ServerAddr:    "1.2.3.4:8080",
		Key:           "mysecret",
		InterfaceName: "eth0",
		LocalAddr:     "192.168.1.100:12345",
		GatewayMAC:    "aa:bb:cc:dd:ee:ff",
	}

	out, err := Generate(opts)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Verify it's valid YAML
	var parsed map[string]interface{}
	if err := yaml.Unmarshal([]byte(out), &parsed); err != nil {
		t.Fatalf("generated config is not valid YAML: %v", err)
	}

	// Check role
	if parsed["role"] != "client" {
		t.Errorf("role = %v, want %q", parsed["role"], "client")
	}

	// Check server addr
	server, ok := parsed["server"].(map[string]interface{})
	if !ok {
		t.Fatal("missing server section")
	}
	if server["addr"] != "1.2.3.4:8080" {
		t.Errorf("server.addr = %v, want %q", server["addr"], "1.2.3.4:8080")
	}

	// Check key is in transport.kcp.key
	transport, ok := parsed["transport"].(map[string]interface{})
	if !ok {
		t.Fatal("missing transport section")
	}
	kcp, ok := transport["kcp"].(map[string]interface{})
	if !ok {
		t.Fatal("missing transport.kcp section")
	}
	if kcp["key"] != "mysecret" {
		t.Errorf("transport.kcp.key = %v, want %q", kcp["key"], "mysecret")
	}
}

func TestGenerateDefaultValues(t *testing.T) {
	opts := &Options{
		ServerAddr:    "1.2.3.4:8080",
		Key:           "mysecret",
		InterfaceName: "eth0",
		LocalAddr:     "192.168.1.100:12345",
		GatewayMAC:    "aa:bb:cc:dd:ee:ff",
	}

	out, err := Generate(opts)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Should contain default values
	if !strings.Contains(out, "127.0.0.1:1080") {
		t.Error("expected default SOCKS5 listen address 127.0.0.1:1080")
	}
	if !strings.Contains(out, "mode: fast\n") {
		t.Error("expected default KCP mode fast")
	}
	if !strings.Contains(out, "aes") {
		t.Error("expected default block cipher aes")
	}
}

func TestGenerateWithSocksAuth(t *testing.T) {
	opts := &Options{
		ServerAddr:    "1.2.3.4:8080",
		Key:           "mysecret",
		InterfaceName: "eth0",
		LocalAddr:     "192.168.1.100:12345",
		GatewayMAC:    "aa:bb:cc:dd:ee:ff",
		SocksUser:     "user1",
		SocksPass:     "pass1",
	}

	out, err := Generate(opts)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var parsed map[string]interface{}
	if err := yaml.Unmarshal([]byte(out), &parsed); err != nil {
		t.Fatalf("generated config is not valid YAML: %v", err)
	}

	socks5, ok := parsed["socks5"].([]interface{})
	if !ok || len(socks5) == 0 {
		t.Fatal("missing socks5 section")
	}

	first, ok := socks5[0].(map[string]interface{})
	if !ok {
		t.Fatal("socks5[0] is not a map")
	}

	if first["username"] != "user1" {
		t.Errorf("socks5[0].username = %v, want %q", first["username"], "user1")
	}
	if first["password"] != "pass1" {
		t.Errorf("socks5[0].password = %v, want %q", first["password"], "pass1")
	}
}

func TestGenerateCustomKCPParams(t *testing.T) {
	opts := &Options{
		ServerAddr:    "1.2.3.4:8080",
		Key:           "mysecret",
		InterfaceName: "eth0",
		LocalAddr:     "192.168.1.100:12345",
		GatewayMAC:    "aa:bb:cc:dd:ee:ff",
		Mode:          "fast",
		Conn:          4,
		MTU:           1400,
		RcvWnd:        2048,
		SndWnd:        2048,
		Block:         "salsa20",
	}

	out, err := Generate(opts)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var parsed map[string]interface{}
	if err := yaml.Unmarshal([]byte(out), &parsed); err != nil {
		t.Fatalf("generated config is not valid YAML: %v", err)
	}

	transport := parsed["transport"].(map[string]interface{})
	kcp := transport["kcp"].(map[string]interface{})

	if kcp["mode"] != "fast" {
		t.Errorf("mode = %v, want %q", kcp["mode"], "fast")
	}
	if kcp["block"] != "salsa20" {
		t.Errorf("block = %v, want %q", kcp["block"], "salsa20")
	}

	// conn is an int, yaml may parse as int
	connVal := toInt(transport["conn"])
	if connVal != 4 {
		t.Errorf("conn = %v, want %d", transport["conn"], 4)
	}

	mtuVal := toInt(kcp["mtu"])
	if mtuVal != 1400 {
		t.Errorf("mtu = %v, want %d", kcp["mtu"], 1400)
	}

	rcvwndVal := toInt(kcp["rcvwnd"])
	if rcvwndVal != 2048 {
		t.Errorf("rcvwnd = %v, want %d", kcp["rcvwnd"], 2048)
	}

	sndwndVal := toInt(kcp["sndwnd"])
	if sndwndVal != 2048 {
		t.Errorf("sndwnd = %v, want %d", kcp["sndwnd"], 2048)
	}
}

func TestGenerateWithTCPFlags(t *testing.T) {
	opts := &Options{
		ServerAddr:    "1.2.3.4:8080",
		Key:           "mysecret",
		InterfaceName: "eth0",
		LocalAddr:     "192.168.1.100:12345",
		GatewayMAC:    "aa:bb:cc:dd:ee:ff",
		LocalFlag:     "S",
		RemoteFlag:    "A",
	}

	out, err := Generate(opts)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var parsed map[string]interface{}
	if err := yaml.Unmarshal([]byte(out), &parsed); err != nil {
		t.Fatalf("generated config is not valid YAML: %v", err)
	}

	network := parsed["network"].(map[string]interface{})
	tcp := network["tcp"].(map[string]interface{})

	lf := tcp["local_flag"].([]interface{})
	if len(lf) != 1 || lf[0] != "S" {
		t.Errorf("local_flag = %v, want [S]", lf)
	}

	rf := tcp["remote_flag"].([]interface{})
	if len(rf) != 1 || rf[0] != "A" {
		t.Errorf("remote_flag = %v, want [A]", rf)
	}
}

func TestGenerateWithWindowsGUID(t *testing.T) {
	opts := &Options{
		ServerAddr:    "1.2.3.4:8080",
		Key:           "mysecret",
		InterfaceName: "Ethernet",
		LocalAddr:     "192.168.1.100:12345",
		GatewayMAC:    "aa:bb:cc:dd:ee:ff",
		NpcapGUID:     `\Device\NPF_{12345678-1234-1234-1234-123456789012}`,
	}

	out, err := Generate(opts)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var parsed map[string]interface{}
	if err := yaml.Unmarshal([]byte(out), &parsed); err != nil {
		t.Fatalf("generated config is not valid YAML: %v", err)
	}

	network := parsed["network"].(map[string]interface{})
	guid, ok := network["guid"]
	if !ok {
		t.Fatal("missing network.guid when NpcapGUID provided")
	}
	if guid != `\Device\NPF_{12345678-1234-1234-1234-123456789012}` {
		t.Errorf("guid = %v, want the npcap guid", guid)
	}
}

func TestGenerateWithoutGUID(t *testing.T) {
	opts := &Options{
		ServerAddr:    "1.2.3.4:8080",
		Key:           "mysecret",
		InterfaceName: "eth0",
		LocalAddr:     "192.168.1.100:12345",
		GatewayMAC:    "aa:bb:cc:dd:ee:ff",
	}

	out, err := Generate(opts)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if strings.Contains(out, "guid:") {
		t.Error("expected no guid field when NpcapGUID is empty")
	}
}

func TestGenerateWithBufferSizes(t *testing.T) {
	opts := &Options{
		ServerAddr:    "1.2.3.4:8080",
		Key:           "mysecret",
		InterfaceName: "eth0",
		LocalAddr:     "192.168.1.100:12345",
		GatewayMAC:    "aa:bb:cc:dd:ee:ff",
		SmuxBuf:       4194304,
		StreamBuf:     2097152,
		TCPBuf:        4194304,
		UDPBuf:        1048576,
		SockBuf:       4194304,
	}

	out, err := Generate(opts)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var parsed map[string]interface{}
	if err := yaml.Unmarshal([]byte(out), &parsed); err != nil {
		t.Fatalf("generated config is not valid YAML: %v", err)
	}

	transport := parsed["transport"].(map[string]interface{})

	if toInt(transport["smuxbuf"]) != 4194304 {
		t.Errorf("smuxbuf = %v, want %d", transport["smuxbuf"], 4194304)
	}
	if toInt(transport["streambuf"]) != 2097152 {
		t.Errorf("streambuf = %v, want %d", transport["streambuf"], 2097152)
	}
	if toInt(transport["tcpbuf"]) != 4194304 {
		t.Errorf("tcpbuf = %v, want %d", transport["tcpbuf"], 4194304)
	}
	if toInt(transport["udpbuf"]) != 1048576 {
		t.Errorf("udpbuf = %v, want %d", transport["udpbuf"], 1048576)
	}
	if toInt(transport["sockbuf"]) != 4194304 {
		t.Errorf("sockbuf = %v, want %d", transport["sockbuf"], 4194304)
	}
}

func TestGenerateWithFECShards(t *testing.T) {
	opts := &Options{
		ServerAddr:    "1.2.3.4:8080",
		Key:           "mysecret",
		InterfaceName: "eth0",
		LocalAddr:     "192.168.1.100:12345",
		GatewayMAC:    "aa:bb:cc:dd:ee:ff",
		DShard:        10,
		PShard:        3,
	}

	out, err := Generate(opts)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var parsed map[string]interface{}
	if err := yaml.Unmarshal([]byte(out), &parsed); err != nil {
		t.Fatalf("generated config is not valid YAML: %v", err)
	}

	transport := parsed["transport"].(map[string]interface{})
	kcp := transport["kcp"].(map[string]interface{})

	if toInt(kcp["datashard"]) != 10 {
		t.Errorf("datashard = %v, want %d", kcp["datashard"], 10)
	}
	if toInt(kcp["parityshard"]) != 3 {
		t.Errorf("parityshard = %v, want %d", kcp["parityshard"], 3)
	}
}

func TestGenerateWithDSCP(t *testing.T) {
	opts := &Options{
		ServerAddr:    "1.2.3.4:8080",
		Key:           "mysecret",
		InterfaceName: "eth0",
		LocalAddr:     "192.168.1.100:12345",
		GatewayMAC:    "aa:bb:cc:dd:ee:ff",
		DSCP:          46,
	}

	out, err := Generate(opts)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var parsed map[string]interface{}
	if err := yaml.Unmarshal([]byte(out), &parsed); err != nil {
		t.Fatalf("generated config is not valid YAML: %v", err)
	}

	transport := parsed["transport"].(map[string]interface{})
	kcp := transport["kcp"].(map[string]interface{})

	if toInt(kcp["dscp"]) != 46 {
		t.Errorf("dscp = %v, want %d", kcp["dscp"], 46)
	}
}

func TestGenerateWithForwardRules(t *testing.T) {
	opts := &Options{
		ServerAddr:    "1.2.3.4:8080",
		Key:           "mysecret",
		InterfaceName: "eth0",
		LocalAddr:     "192.168.1.100:12345",
		GatewayMAC:    "aa:bb:cc:dd:ee:ff",
		Forward:       []string{"tcp:8080:internal:80", "udp:9090:internal:9090"},
	}

	out, err := Generate(opts)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var parsed map[string]interface{}
	if err := yaml.Unmarshal([]byte(out), &parsed); err != nil {
		t.Fatalf("generated config is not valid YAML: %v", err)
	}

	fwd, ok := parsed["forward"].([]interface{})
	if !ok {
		t.Fatal("missing forward section")
	}
	if len(fwd) != 2 {
		t.Errorf("forward has %d entries, want 2", len(fwd))
	}
}

func TestGenerateLogLevel(t *testing.T) {
	opts := &Options{
		ServerAddr:    "1.2.3.4:8080",
		Key:           "mysecret",
		InterfaceName: "eth0",
		LocalAddr:     "192.168.1.100:12345",
		GatewayMAC:    "aa:bb:cc:dd:ee:ff",
		LogLevel:      "debug",
	}

	out, err := Generate(opts)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var parsed map[string]interface{}
	if err := yaml.Unmarshal([]byte(out), &parsed); err != nil {
		t.Fatalf("generated config is not valid YAML: %v", err)
	}

	log := parsed["log"].(map[string]interface{})
	if log["level"] != "debug" {
		t.Errorf("log.level = %v, want %q", log["level"], "debug")
	}
}

func TestGenerateMissingRequiredFields(t *testing.T) {
	tests := []struct {
		name string
		opts *Options
	}{
		{"missing server addr", &Options{Key: "k", InterfaceName: "eth0", LocalAddr: "1.1.1.1:1", GatewayMAC: "aa:bb:cc:dd:ee:ff"}},
		{"missing key", &Options{ServerAddr: "1.2.3.4:8080", InterfaceName: "eth0", LocalAddr: "1.1.1.1:1", GatewayMAC: "aa:bb:cc:dd:ee:ff"}},
		{"missing interface", &Options{ServerAddr: "1.2.3.4:8080", Key: "k", LocalAddr: "1.1.1.1:1", GatewayMAC: "aa:bb:cc:dd:ee:ff"}},
		{"missing local addr", &Options{ServerAddr: "1.2.3.4:8080", Key: "k", InterfaceName: "eth0", GatewayMAC: "aa:bb:cc:dd:ee:ff"}},
		{"missing gateway mac", &Options{ServerAddr: "1.2.3.4:8080", Key: "k", InterfaceName: "eth0", LocalAddr: "1.1.1.1:1"}},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			_, err := Generate(tc.opts)
			if err == nil {
				t.Error("expected error for missing required field")
			}
		})
	}
}

// helper to convert yaml-parsed numbers to int
func toInt(v interface{}) int {
	switch n := v.(type) {
	case int:
		return n
	case float64:
		return int(n)
	case int64:
		return int(n)
	default:
		return 0
	}
}
