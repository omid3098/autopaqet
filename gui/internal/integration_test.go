package internal

import (
	"fmt"
	"io"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/omid3098/autopaqet/gui/internal/config"
	"github.com/omid3098/autopaqet/gui/internal/profile"
	"github.com/omid3098/autopaqet/gui/internal/proxy"
	"github.com/omid3098/autopaqet/gui/internal/uri"
	"gopkg.in/yaml.v3"
)

// Test 1: URI parse -> profile create -> YAML generate -> validate output
func TestURIToProfileToYAML(t *testing.T) {
	raw := "paqet://secretkey@10.0.0.1:9090?socks=127.0.0.1:1080&mode=fast3&conn=2&block=aes&lf=PA&rf=PA#TestProfile"

	// Parse URI
	u, err := uri.Parse(raw)
	if err != nil {
		t.Fatalf("Parse URI failed: %v", err)
	}

	// Create profile store and import
	dir := t.TempDir()
	store, err := profile.NewStore(dir)
	if err != nil {
		t.Fatalf("NewStore failed: %v", err)
	}

	p, err := store.ImportFromURI(raw)
	if err != nil {
		t.Fatalf("ImportFromURI failed: %v", err)
	}

	// Verify profile matches URI
	if p.Key != u.Key {
		t.Errorf("profile Key = %q, URI Key = %q", p.Key, u.Key)
	}
	if p.Host != u.Host {
		t.Errorf("profile Host = %q, URI Host = %q", p.Host, u.Host)
	}
	if p.Port != u.Port {
		t.Errorf("profile Port = %d, URI Port = %d", p.Port, u.Port)
	}

	// Generate YAML
	opts := &config.Options{
		ServerAddr:    fmt.Sprintf("%s:%d", p.Host, p.Port),
		Key:           p.Key,
		InterfaceName: "eth0",
		LocalAddr:     "192.168.1.100:12345",
		GatewayMAC:    "aa:bb:cc:dd:ee:ff",
		SocksListen:   p.SocksListen,
		Mode:          p.Mode,
		Conn:          p.Conn,
		Block:         p.Block,
		LocalFlag:     p.LocalFlag,
		RemoteFlag:    p.RemoteFlag,
	}

	yamlStr, err := config.Generate(opts)
	if err != nil {
		t.Fatalf("Generate YAML failed: %v", err)
	}

	// Validate YAML structure
	var parsed map[string]interface{}
	if err := yaml.Unmarshal([]byte(yamlStr), &parsed); err != nil {
		t.Fatalf("generated YAML is invalid: %v", err)
	}

	// Verify key fields
	if parsed["role"] != "client" {
		t.Errorf("role = %v, want client", parsed["role"])
	}

	server := parsed["server"].(map[string]interface{})
	if server["addr"] != "10.0.0.1:9090" {
		t.Errorf("server.addr = %v, want 10.0.0.1:9090", server["addr"])
	}

	transport := parsed["transport"].(map[string]interface{})
	kcp := transport["kcp"].(map[string]interface{})
	if kcp["key"] != "secretkey" {
		t.Errorf("kcp.key = %v, want secretkey", kcp["key"])
	}
	if kcp["mode"] != "fast3" {
		t.Errorf("kcp.mode = %v, want fast3", kcp["mode"])
	}

	// Verify SOCKS5
	socks5 := parsed["socks5"].([]interface{})
	first := socks5[0].(map[string]interface{})
	if first["listen"] != "127.0.0.1:1080" {
		t.Errorf("socks5[0].listen = %v, want 127.0.0.1:1080", first["listen"])
	}

	// Verify network
	network := parsed["network"].(map[string]interface{})
	if network["interface"] != "eth0" {
		t.Errorf("network.interface = %v, want eth0", network["interface"])
	}

	tcp := network["tcp"].(map[string]interface{})
	lf := tcp["local_flag"].([]interface{})
	if len(lf) != 1 || lf[0] != "PA" {
		t.Errorf("local_flag = %v, want [PA]", lf)
	}
}

// Test 2: URI round-trip through profile store
func TestURIRoundTripThroughProfile(t *testing.T) {
	original := "paqet://key123@192.168.1.1:7070?socks=127.0.0.1:1080&mode=fast3&conn=2&mtu=1400&rcvwnd=512&sndwnd=512&block=aes&dscp=46&dshard=10&pshard=3&smuxbuf=4194304&streambuf=2097152&tcpbuf=4194304&udpbuf=1048576&sockbuf=4194304&lf=PA&rf=PA&log=info#RoundTrip"

	dir := t.TempDir()
	store, _ := profile.NewStore(dir)

	// Import
	p, err := store.ImportFromURI(original)
	if err != nil {
		t.Fatalf("ImportFromURI failed: %v", err)
	}

	// Export
	exported, err := store.ExportToURI(p.ID)
	if err != nil {
		t.Fatalf("ExportToURI failed: %v", err)
	}

	// Parse both and compare all fields
	orig, _ := uri.Parse(original)
	exp, _ := uri.Parse(exported)

	fields := []struct {
		name string
		a, b interface{}
	}{
		{"Key", orig.Key, exp.Key},
		{"Host", orig.Host, exp.Host},
		{"Port", orig.Port, exp.Port},
		{"Name", orig.Name, exp.Name},
		{"Socks", orig.Socks, exp.Socks},
		{"Mode", orig.Mode, exp.Mode},
		{"Conn", orig.Conn, exp.Conn},
		{"MTU", orig.MTU, exp.MTU},
		{"RcvWnd", orig.RcvWnd, exp.RcvWnd},
		{"SndWnd", orig.SndWnd, exp.SndWnd},
		{"Block", orig.Block, exp.Block},
		{"DSCP", orig.DSCP, exp.DSCP},
		{"DShard", orig.DShard, exp.DShard},
		{"PShard", orig.PShard, exp.PShard},
		{"SmuxBuf", orig.SmuxBuf, exp.SmuxBuf},
		{"StreamBuf", orig.StreamBuf, exp.StreamBuf},
		{"TCPBuf", orig.TCPBuf, exp.TCPBuf},
		{"UDPBuf", orig.UDPBuf, exp.UDPBuf},
		{"SockBuf", orig.SockBuf, exp.SockBuf},
		{"LocalFlag", orig.LocalFlag, exp.LocalFlag},
		{"RemoteFlag", orig.RemoteFlag, exp.RemoteFlag},
		{"Log", orig.Log, exp.Log},
	}

	for _, f := range fields {
		if f.a != f.b {
			t.Errorf("%s: original=%v, exported=%v", f.name, f.a, f.b)
		}
	}
}

// Test 3: Profile persistence through store reload
func TestProfilePersistenceReload(t *testing.T) {
	dir := t.TempDir()

	// Create store and add profiles
	store1, _ := profile.NewStore(dir)
	store1.Create(&profile.Profile{
		Name: "Profile1",
		Host: "1.2.3.4",
		Port: 8080,
		Key:  "secret1",
		Mode: "fast3",
	})
	store1.Create(&profile.Profile{
		Name: "Profile2",
		Host: "5.6.7.8",
		Port: 9090,
		Key:  "secret2",
		Mode: "fast",
	})

	// Create new store instance (simulates app restart)
	store2, err := profile.NewStore(dir)
	if err != nil {
		t.Fatalf("second store creation failed: %v", err)
	}

	profiles := store2.List()
	if len(profiles) != 2 {
		t.Fatalf("expected 2 profiles after reload, got %d", len(profiles))
	}

	// Verify data integrity
	found := false
	for _, p := range profiles {
		if p.Name == "Profile1" {
			found = true
			if p.Host != "1.2.3.4" {
				t.Errorf("Profile1 host = %q, want 1.2.3.4", p.Host)
			}
			if p.Mode != "fast3" {
				t.Errorf("Profile1 mode = %q, want fast3", p.Mode)
			}
		}
	}
	if !found {
		t.Error("Profile1 not found after reload")
	}
}

// Test 4: PAC server integration
func TestPACServerIntegration(t *testing.T) {
	srv := proxy.NewPACServer("127.0.0.1:1080")
	port, err := srv.Start()
	if err != nil {
		t.Fatalf("PAC server start failed: %v", err)
	}
	defer srv.Stop()

	time.Sleep(50 * time.Millisecond)

	// Verify PAC URL
	url := srv.GetPACURL()
	if !strings.Contains(url, fmt.Sprintf(":%d", port)) {
		t.Errorf("PAC URL %q doesn't contain port %d", url, port)
	}

	// Fetch and verify content
	resp, err := http.Get(url)
	if err != nil {
		t.Fatalf("GET PAC failed: %v", err)
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	content := string(body)

	// Verify PAC structure
	if !strings.Contains(content, "function FindProxyForURL") {
		t.Error("missing FindProxyForURL function")
	}
	if !strings.Contains(content, "SOCKS5 127.0.0.1:1080") {
		t.Error("missing SOCKS5 proxy")
	}
	if !strings.Contains(content, "DIRECT") {
		t.Error("missing DIRECT fallback")
	}

	// Verify server stops cleanly
	err = srv.Stop()
	if err != nil {
		t.Errorf("PAC server stop failed: %v", err)
	}

	time.Sleep(100 * time.Millisecond)

	_, err = http.Get(url)
	if err == nil {
		t.Error("expected error after PAC server stop")
	}
}

// Test 5: Full workflow - import URI, create profile, export, verify round-trip with all extended fields
func TestFullWorkflow(t *testing.T) {
	dir := t.TempDir()
	store, _ := profile.NewStore(dir)

	// Step 1: Import from URI
	raw := "paqet://mykey@server.example.com:443?socks=127.0.0.1:1080&mode=fast3&conn=4&block=salsa20&dscp=46&lf=S&rf=A#ProductionVPN"
	imported, err := store.ImportFromURI(raw)
	if err != nil {
		t.Fatalf("import failed: %v", err)
	}

	// Step 2: Verify it's in the list
	profiles := store.List()
	if len(profiles) != 1 {
		t.Fatalf("expected 1 profile, got %d", len(profiles))
	}

	// Step 3: Get by ID
	fetched, _ := store.Get(imported.ID)
	if fetched.Name != "ProductionVPN" {
		t.Errorf("name = %q, want ProductionVPN", fetched.Name)
	}

	// Step 4: Update
	fetched.Name = "Updated VPN"
	updated, _ := store.Update(fetched)
	if updated.Name != "Updated VPN" {
		t.Errorf("updated name = %q, want Updated VPN", updated.Name)
	}

	// Step 5: Export
	exported, _ := store.ExportToURI(imported.ID)
	parsed, _ := uri.Parse(exported)
	if parsed.Name != "Updated VPN" {
		t.Errorf("exported name = %q, want Updated VPN", parsed.Name)
	}
	if parsed.Host != "server.example.com" {
		t.Errorf("exported host = %q, want server.example.com", parsed.Host)
	}

	// Step 6: Generate config
	opts := &config.Options{
		ServerAddr:    fmt.Sprintf("%s:%d", fetched.Host, fetched.Port),
		Key:           fetched.Key,
		InterfaceName: "wlan0",
		LocalAddr:     "10.0.0.5:54321",
		GatewayMAC:    "11:22:33:44:55:66",
		Mode:          fetched.Mode,
		Conn:          fetched.Conn,
		Block:         fetched.Block,
		DSCP:          fetched.DSCP,
		LocalFlag:     fetched.LocalFlag,
		RemoteFlag:    fetched.RemoteFlag,
	}
	yamlStr, err := config.Generate(opts)
	if err != nil {
		t.Fatalf("config generate failed: %v", err)
	}

	if !strings.Contains(yamlStr, "server.example.com:443") {
		t.Error("YAML missing server address")
	}
	if !strings.Contains(yamlStr, "salsa20") {
		t.Error("YAML missing block cipher")
	}

	// Step 7: Delete
	store.Delete(imported.ID)
	if len(store.List()) != 0 {
		t.Error("expected 0 profiles after delete")
	}
}
