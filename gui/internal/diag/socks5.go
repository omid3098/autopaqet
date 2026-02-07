package diag

import (
	"context"
	"fmt"
	"io"
	"net"
	"net/http"
	"time"

	"golang.org/x/net/proxy"
)

// verifySocks5Tunnel tests end-to-end connectivity through the SOCKS5 proxy
// by making real HTTP requests. Returns whether HTTP (data flow) and DNS
// (name resolution) work through the tunnel.
//
// Test 1: HTTP GET to 1.1.1.1 (IP-based, no DNS) — proves data flows
// Test 2: HTTP GET to www.gstatic.com/generate_204 (hostname) — proves DNS works
func verifySocks5Tunnel(ctx context.Context, socksAddr string, timeout time.Duration) (httpOK bool, dnsOK bool, err error) {
	dialer, err := proxy.SOCKS5("tcp", socksAddr, nil, &net.Dialer{Timeout: timeout})
	if err != nil {
		return false, false, fmt.Errorf("failed to create SOCKS5 dialer: %w", err)
	}

	ctxDialer, ok := dialer.(proxy.ContextDialer)
	if !ok {
		return false, false, fmt.Errorf("SOCKS5 dialer does not support context")
	}

	transport := &http.Transport{
		DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
			return ctxDialer.DialContext(ctx, network, addr)
		},
	}
	client := &http.Client{Transport: transport, Timeout: timeout}

	// Test 1: HTTP GET to IP address (no DNS needed)
	req1, err := http.NewRequestWithContext(ctx, "GET", "http://1.1.1.1/", nil)
	if err != nil {
		return false, false, fmt.Errorf("failed to create request: %w", err)
	}
	resp, err := client.Do(req1)
	if err != nil {
		return false, false, fmt.Errorf("HTTP via tunnel failed: %w", err)
	}
	io.Copy(io.Discard, resp.Body)
	resp.Body.Close()
	// Any HTTP response means data flows through the tunnel
	httpOK = true

	// Test 2: HTTP GET to hostname (tests DNS resolution through tunnel)
	req2, err := http.NewRequestWithContext(ctx, "GET", "http://www.gstatic.com/generate_204", nil)
	if err != nil {
		return true, false, nil
	}
	resp2, err := client.Do(req2)
	if err != nil {
		// HTTP works but DNS doesn't — still usable but warn
		return true, false, nil
	}
	io.Copy(io.Discard, resp2.Body)
	resp2.Body.Close()
	dnsOK = true

	return true, true, nil
}

// pollSocks5 repeatedly tries to connect through the SOCKS5 proxy until
// the tunnel is actually forwarding traffic, not just the listener port is open.
// It polls every 2 seconds with a SOCKS5 CONNECT attempt.
func pollSocks5(ctx context.Context, socksAddr string, timeout time.Duration) error {
	deadline := time.After(timeout)
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()

	// Try immediately first
	if trySOCKS5Connect(socksAddr) == nil {
		return nil
	}

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-deadline:
			return fmt.Errorf("SOCKS5 timeout after %s: tunnel not ready on %s", timeout, socksAddr)
		case <-ticker.C:
			if trySOCKS5Connect(socksAddr) == nil {
				return nil
			}
		}
	}
}

// trySOCKS5Connect attempts a full SOCKS5 handshake + CONNECT to 1.1.1.1:80
// through the proxy. This verifies the tunnel is actually forwarding, not just
// that the listener port is open.
func trySOCKS5Connect(socksAddr string) error {
	dialer, err := proxy.SOCKS5("tcp", socksAddr, nil, &net.Dialer{Timeout: 3 * time.Second})
	if err != nil {
		return err
	}
	conn, err := dialer.Dial("tcp", "1.1.1.1:80")
	if err != nil {
		return err
	}
	conn.Close()
	return nil
}
