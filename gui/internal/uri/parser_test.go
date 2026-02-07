package uri

import (
	"testing"
)

func TestParseMinimalURI(t *testing.T) {
	raw := "paqet://mykey@1.2.3.4:8080"
	u, err := Parse(raw)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if u.Key != "mykey" {
		t.Errorf("Key = %q, want %q", u.Key, "mykey")
	}
	if u.Host != "1.2.3.4" {
		t.Errorf("Host = %q, want %q", u.Host, "1.2.3.4")
	}
	if u.Port != 8080 {
		t.Errorf("Port = %d, want %d", u.Port, 8080)
	}
	if u.Name != "" {
		t.Errorf("Name = %q, want empty", u.Name)
	}
}

func TestParseFullParamURI(t *testing.T) {
	raw := "paqet://secretkey@10.0.0.1:9090?socks=127.0.0.1:1080&mode=fast3&conn=2&mtu=1400&rcvwnd=1024&sndwnd=1024&block=aes&dscp=46&dshard=10&pshard=3&smuxbuf=4194304&streambuf=2097152&tcpbuf=4194304&udpbuf=1048576&sockbuf=4194304&log=info&socks_user=user1&socks_pass=pass1&lf=PA&rf=PA#MyProfile"
	u, err := Parse(raw)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if u.Key != "secretkey" {
		t.Errorf("Key = %q, want %q", u.Key, "secretkey")
	}
	if u.Host != "10.0.0.1" {
		t.Errorf("Host = %q, want %q", u.Host, "10.0.0.1")
	}
	if u.Port != 9090 {
		t.Errorf("Port = %d, want %d", u.Port, 9090)
	}
	if u.Name != "MyProfile" {
		t.Errorf("Name = %q, want %q", u.Name, "MyProfile")
	}
	if u.Socks != "127.0.0.1:1080" {
		t.Errorf("Socks = %q, want %q", u.Socks, "127.0.0.1:1080")
	}
	if u.Mode != "fast3" {
		t.Errorf("Mode = %q, want %q", u.Mode, "fast3")
	}
	if u.Conn != 2 {
		t.Errorf("Conn = %d, want %d", u.Conn, 2)
	}
	if u.MTU != 1400 {
		t.Errorf("MTU = %d, want %d", u.MTU, 1400)
	}
	if u.RcvWnd != 1024 {
		t.Errorf("RcvWnd = %d, want %d", u.RcvWnd, 1024)
	}
	if u.SndWnd != 1024 {
		t.Errorf("SndWnd = %d, want %d", u.SndWnd, 1024)
	}
	if u.Block != "aes" {
		t.Errorf("Block = %q, want %q", u.Block, "aes")
	}
	if u.DSCP != 46 {
		t.Errorf("DSCP = %d, want %d", u.DSCP, 46)
	}
	if u.DShard != 10 {
		t.Errorf("DShard = %d, want %d", u.DShard, 10)
	}
	if u.PShard != 3 {
		t.Errorf("PShard = %d, want %d", u.PShard, 3)
	}
	if u.SmuxBuf != 4194304 {
		t.Errorf("SmuxBuf = %d, want %d", u.SmuxBuf, 4194304)
	}
	if u.StreamBuf != 2097152 {
		t.Errorf("StreamBuf = %d, want %d", u.StreamBuf, 2097152)
	}
	if u.TCPBuf != 4194304 {
		t.Errorf("TCPBuf = %d, want %d", u.TCPBuf, 4194304)
	}
	if u.UDPBuf != 1048576 {
		t.Errorf("UDPBuf = %d, want %d", u.UDPBuf, 1048576)
	}
	if u.SockBuf != 4194304 {
		t.Errorf("SockBuf = %d, want %d", u.SockBuf, 4194304)
	}
	if u.Log != "info" {
		t.Errorf("Log = %q, want %q", u.Log, "info")
	}
	if u.SocksUser != "user1" {
		t.Errorf("SocksUser = %q, want %q", u.SocksUser, "user1")
	}
	if u.SocksPass != "pass1" {
		t.Errorf("SocksPass = %q, want %q", u.SocksPass, "pass1")
	}
	if u.LocalFlag != "PA" {
		t.Errorf("LocalFlag = %q, want %q", u.LocalFlag, "PA")
	}
	if u.RemoteFlag != "PA" {
		t.Errorf("RemoteFlag = %q, want %q", u.RemoteFlag, "PA")
	}
}

func TestParseIPv6URI(t *testing.T) {
	raw := "paqet://mykey@[::1]:8080#IPv6Test"
	u, err := Parse(raw)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if u.Key != "mykey" {
		t.Errorf("Key = %q, want %q", u.Key, "mykey")
	}
	if u.Host != "::1" {
		t.Errorf("Host = %q, want %q", u.Host, "::1")
	}
	if u.Port != 8080 {
		t.Errorf("Port = %d, want %d", u.Port, 8080)
	}
	if u.Name != "IPv6Test" {
		t.Errorf("Name = %q, want %q", u.Name, "IPv6Test")
	}
}

func TestParseMissingKey(t *testing.T) {
	raw := "paqet://1.2.3.4:8080"
	_, err := Parse(raw)
	if err == nil {
		t.Fatal("expected error for missing key, got nil")
	}
}

func TestParseMissingHost(t *testing.T) {
	raw := "paqet://mykey@:8080"
	_, err := Parse(raw)
	if err == nil {
		t.Fatal("expected error for missing host, got nil")
	}
}

func TestParseMissingPort(t *testing.T) {
	raw := "paqet://mykey@1.2.3.4"
	_, err := Parse(raw)
	if err == nil {
		t.Fatal("expected error for missing port, got nil")
	}
}

func TestParseInvalidScheme(t *testing.T) {
	raw := "http://mykey@1.2.3.4:8080"
	_, err := Parse(raw)
	if err == nil {
		t.Fatal("expected error for invalid scheme, got nil")
	}
}

func TestParseInvalidPort(t *testing.T) {
	raw := "paqet://mykey@1.2.3.4:99999"
	_, err := Parse(raw)
	if err == nil {
		t.Fatal("expected error for invalid port, got nil")
	}
}

func TestRoundTrip(t *testing.T) {
	original := &PaqetURI{
		Key:        "testsecret",
		Host:       "192.168.1.1",
		Port:       7070,
		Name:       "TestProfile",
		Socks:      "127.0.0.1:1080",
		Mode:       "fast3",
		Conn:       2,
		MTU:        1400,
		RcvWnd:     512,
		SndWnd:     512,
		Block:      "aes",
		DSCP:       46,
		DShard:     10,
		PShard:     3,
		SmuxBuf:    4194304,
		StreamBuf:  2097152,
		TCPBuf:     4194304,
		UDPBuf:     1048576,
		SockBuf:    4194304,
		Log:        "info",
		SocksUser:  "user1",
		SocksPass:  "pass1",
		LocalFlag:  "PA",
		RemoteFlag: "PA",
	}

	str := original.String()
	parsed, err := Parse(str)
	if err != nil {
		t.Fatalf("round-trip parse failed: %v", err)
	}

	if parsed.Key != original.Key {
		t.Errorf("Key mismatch: got %q, want %q", parsed.Key, original.Key)
	}
	if parsed.Host != original.Host {
		t.Errorf("Host mismatch: got %q, want %q", parsed.Host, original.Host)
	}
	if parsed.Port != original.Port {
		t.Errorf("Port mismatch: got %d, want %d", parsed.Port, original.Port)
	}
	if parsed.Name != original.Name {
		t.Errorf("Name mismatch: got %q, want %q", parsed.Name, original.Name)
	}
	if parsed.Socks != original.Socks {
		t.Errorf("Socks mismatch: got %q, want %q", parsed.Socks, original.Socks)
	}
	if parsed.Mode != original.Mode {
		t.Errorf("Mode mismatch: got %q, want %q", parsed.Mode, original.Mode)
	}
	if parsed.Conn != original.Conn {
		t.Errorf("Conn mismatch: got %d, want %d", parsed.Conn, original.Conn)
	}
	if parsed.MTU != original.MTU {
		t.Errorf("MTU mismatch: got %d, want %d", parsed.MTU, original.MTU)
	}
	if parsed.RcvWnd != original.RcvWnd {
		t.Errorf("RcvWnd mismatch: got %d, want %d", parsed.RcvWnd, original.RcvWnd)
	}
	if parsed.SndWnd != original.SndWnd {
		t.Errorf("SndWnd mismatch: got %d, want %d", parsed.SndWnd, original.SndWnd)
	}
	if parsed.Block != original.Block {
		t.Errorf("Block mismatch: got %q, want %q", parsed.Block, original.Block)
	}
	if parsed.DSCP != original.DSCP {
		t.Errorf("DSCP mismatch: got %d, want %d", parsed.DSCP, original.DSCP)
	}
	if parsed.DShard != original.DShard {
		t.Errorf("DShard mismatch: got %d, want %d", parsed.DShard, original.DShard)
	}
	if parsed.PShard != original.PShard {
		t.Errorf("PShard mismatch: got %d, want %d", parsed.PShard, original.PShard)
	}
	if parsed.SmuxBuf != original.SmuxBuf {
		t.Errorf("SmuxBuf mismatch: got %d, want %d", parsed.SmuxBuf, original.SmuxBuf)
	}
	if parsed.StreamBuf != original.StreamBuf {
		t.Errorf("StreamBuf mismatch: got %d, want %d", parsed.StreamBuf, original.StreamBuf)
	}
	if parsed.TCPBuf != original.TCPBuf {
		t.Errorf("TCPBuf mismatch: got %d, want %d", parsed.TCPBuf, original.TCPBuf)
	}
	if parsed.UDPBuf != original.UDPBuf {
		t.Errorf("UDPBuf mismatch: got %d, want %d", parsed.UDPBuf, original.UDPBuf)
	}
	if parsed.SockBuf != original.SockBuf {
		t.Errorf("SockBuf mismatch: got %d, want %d", parsed.SockBuf, original.SockBuf)
	}
	if parsed.Log != original.Log {
		t.Errorf("Log mismatch: got %q, want %q", parsed.Log, original.Log)
	}
	if parsed.SocksUser != original.SocksUser {
		t.Errorf("SocksUser mismatch: got %q, want %q", parsed.SocksUser, original.SocksUser)
	}
	if parsed.SocksPass != original.SocksPass {
		t.Errorf("SocksPass mismatch: got %q, want %q", parsed.SocksPass, original.SocksPass)
	}
	if parsed.LocalFlag != original.LocalFlag {
		t.Errorf("LocalFlag mismatch: got %q, want %q", parsed.LocalFlag, original.LocalFlag)
	}
	if parsed.RemoteFlag != original.RemoteFlag {
		t.Errorf("RemoteFlag mismatch: got %q, want %q", parsed.RemoteFlag, original.RemoteFlag)
	}
}

func TestRoundTripMinimal(t *testing.T) {
	original := &PaqetURI{
		Key:  "key123",
		Host: "example.com",
		Port: 443,
	}

	str := original.String()
	parsed, err := Parse(str)
	if err != nil {
		t.Fatalf("round-trip parse failed: %v", err)
	}

	if parsed.Key != original.Key {
		t.Errorf("Key mismatch: got %q, want %q", parsed.Key, original.Key)
	}
	if parsed.Host != original.Host {
		t.Errorf("Host mismatch: got %q, want %q", parsed.Host, original.Host)
	}
	if parsed.Port != original.Port {
		t.Errorf("Port mismatch: got %d, want %d", parsed.Port, original.Port)
	}
}

func TestParseWithForwardRules(t *testing.T) {
	raw := "paqet://mykey@1.2.3.4:8080?fwd=tcp:8080:internal:80,udp:9090:internal:9090#FwdTest"
	u, err := Parse(raw)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if u.Forward != "tcp:8080:internal:80,udp:9090:internal:9090" {
		t.Errorf("Forward = %q, want %q", u.Forward, "tcp:8080:internal:80,udp:9090:internal:9090")
	}
}

func TestParseWithDomainHost(t *testing.T) {
	raw := "paqet://mykey@vpn.example.com:8080#DomainTest"
	u, err := Parse(raw)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if u.Host != "vpn.example.com" {
		t.Errorf("Host = %q, want %q", u.Host, "vpn.example.com")
	}
}

func TestStringMinimalOmitsDefaults(t *testing.T) {
	u := &PaqetURI{
		Key:  "key",
		Host: "1.2.3.4",
		Port: 8080,
	}
	s := u.String()
	if s != "paqet://key@1.2.3.4:8080" {
		t.Errorf("String() = %q, want %q", s, "paqet://key@1.2.3.4:8080")
	}
}

func TestParseURLEncodedFragment(t *testing.T) {
	raw := "paqet://mykey@1.2.3.4:8080#My%20Profile"
	u, err := Parse(raw)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if u.Name != "My Profile" {
		t.Errorf("Name = %q, want %q", u.Name, "My Profile")
	}
}
