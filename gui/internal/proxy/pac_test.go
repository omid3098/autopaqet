package proxy

import (
	"fmt"
	"io"
	"net/http"
	"strings"
	"testing"
	"time"
)

func TestPACServerServesContent(t *testing.T) {
	srv := NewPACServer("127.0.0.1:1080")
	port, err := srv.Start()
	if err != nil {
		t.Fatalf("Start failed: %v", err)
	}
	defer srv.Stop()

	time.Sleep(50 * time.Millisecond)

	resp, err := http.Get(fmt.Sprintf("http://127.0.0.1:%d/proxy.pac", port))
	if err != nil {
		t.Fatalf("GET /proxy.pac failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		t.Errorf("status = %d, want 200", resp.StatusCode)
	}

	ct := resp.Header.Get("Content-Type")
	if ct != "application/x-ns-proxy-autoconfig" {
		t.Errorf("Content-Type = %q, want application/x-ns-proxy-autoconfig", ct)
	}

	body, _ := io.ReadAll(resp.Body)
	content := string(body)

	if !strings.Contains(content, "FindProxyForURL") {
		t.Error("PAC content should contain FindProxyForURL")
	}
	if !strings.Contains(content, "SOCKS5 127.0.0.1:1080") {
		t.Error("PAC content should contain SOCKS5 proxy address")
	}
	if !strings.Contains(content, "DIRECT") {
		t.Error("PAC content should contain DIRECT fallback")
	}
}

func TestPACServerBypassesLocalhost(t *testing.T) {
	srv := NewPACServer("127.0.0.1:1080")
	port, err := srv.Start()
	if err != nil {
		t.Fatalf("Start failed: %v", err)
	}
	defer srv.Stop()

	time.Sleep(50 * time.Millisecond)

	resp, err := http.Get(fmt.Sprintf("http://127.0.0.1:%d/proxy.pac", port))
	if err != nil {
		t.Fatalf("GET failed: %v", err)
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	content := string(body)

	if !strings.Contains(content, "localhost") {
		t.Error("PAC should bypass localhost")
	}
	if !strings.Contains(content, "127.") {
		t.Error("PAC should bypass 127.x.x.x")
	}
	if !strings.Contains(content, "10.") {
		t.Error("PAC should bypass 10.x.x.x")
	}
}

func TestPACServerStop(t *testing.T) {
	srv := NewPACServer("127.0.0.1:1080")
	port, err := srv.Start()
	if err != nil {
		t.Fatalf("Start failed: %v", err)
	}

	time.Sleep(50 * time.Millisecond)

	err = srv.Stop()
	if err != nil {
		t.Fatalf("Stop failed: %v", err)
	}

	time.Sleep(100 * time.Millisecond)

	_, err = http.Get(fmt.Sprintf("http://127.0.0.1:%d/proxy.pac", port))
	if err == nil {
		t.Error("expected error after server stopped")
	}
}

func TestPACServerReturns404ForOtherPaths(t *testing.T) {
	srv := NewPACServer("127.0.0.1:1080")
	port, err := srv.Start()
	if err != nil {
		t.Fatalf("Start failed: %v", err)
	}
	defer srv.Stop()

	time.Sleep(50 * time.Millisecond)

	resp, err := http.Get(fmt.Sprintf("http://127.0.0.1:%d/other", port))
	if err != nil {
		t.Fatalf("GET failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 404 {
		t.Errorf("status = %d, want 404", resp.StatusCode)
	}
}

func TestPACServerGetURL(t *testing.T) {
	srv := NewPACServer("127.0.0.1:1080")
	port, err := srv.Start()
	if err != nil {
		t.Fatalf("Start failed: %v", err)
	}
	defer srv.Stop()

	url := srv.GetPACURL()
	expected := fmt.Sprintf("http://127.0.0.1:%d/proxy.pac", port)
	if url != expected {
		t.Errorf("GetPACURL() = %q, want %q", url, expected)
	}
}

func TestPACServerCustomSocksAddr(t *testing.T) {
	srv := NewPACServer("10.0.0.1:9999")
	port, err := srv.Start()
	if err != nil {
		t.Fatalf("Start failed: %v", err)
	}
	defer srv.Stop()

	time.Sleep(50 * time.Millisecond)

	resp, err := http.Get(fmt.Sprintf("http://127.0.0.1:%d/proxy.pac", port))
	if err != nil {
		t.Fatalf("GET failed: %v", err)
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	if !strings.Contains(string(body), "SOCKS5 10.0.0.1:9999") {
		t.Error("PAC should reference custom SOCKS5 address")
	}
}
