package proxy

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"time"
)

const defaultPACPort = 18384

// PACServer serves a PAC (Proxy Auto-Configuration) file over HTTP.
type PACServer struct {
	socksAddr string
	server    *http.Server
	port      int
}

// NewPACServer creates a new PAC server that routes traffic through the given SOCKS5 address.
func NewPACServer(socksAddr string) *PACServer {
	return &PACServer{
		socksAddr: socksAddr,
	}
}

// Start begins serving the PAC file. Returns the actual port used.
func (p *PACServer) Start() (int, error) {
	mux := http.NewServeMux()
	mux.HandleFunc("/proxy.pac", p.handlePAC)
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/proxy.pac" {
			http.NotFound(w, r)
		}
	})

	// Try default port first, then fall back to a random port
	listener, err := net.Listen("tcp", fmt.Sprintf("127.0.0.1:%d", defaultPACPort))
	if err != nil {
		listener, err = net.Listen("tcp", "127.0.0.1:0")
		if err != nil {
			return 0, fmt.Errorf("failed to bind PAC server: %w", err)
		}
	}

	p.port = listener.Addr().(*net.TCPAddr).Port

	p.server = &http.Server{
		Handler: mux,
	}

	go p.server.Serve(listener)

	return p.port, nil
}

// Stop shuts down the PAC server.
func (p *PACServer) Stop() error {
	if p.server == nil {
		return nil
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	return p.server.Shutdown(ctx)
}

// GetPACURL returns the URL to the PAC file.
func (p *PACServer) GetPACURL() string {
	return fmt.Sprintf("http://127.0.0.1:%d/proxy.pac", p.port)
}

// GetPort returns the port the server is listening on.
func (p *PACServer) GetPort() int {
	return p.port
}

func (p *PACServer) handlePAC(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/x-ns-proxy-autoconfig")
	w.WriteHeader(http.StatusOK)

	pac := fmt.Sprintf(`function FindProxyForURL(url, host) {
  // Bypass localhost and private ranges
  if (shExpMatch(host, "localhost") ||
      shExpMatch(host, "127.*") ||
      shExpMatch(host, "10.*") ||
      shExpMatch(host, "172.16.*") ||
      shExpMatch(host, "172.17.*") ||
      shExpMatch(host, "172.18.*") ||
      shExpMatch(host, "172.19.*") ||
      shExpMatch(host, "172.2?.*") ||
      shExpMatch(host, "172.30.*") ||
      shExpMatch(host, "172.31.*") ||
      shExpMatch(host, "192.168.*") ||
      shExpMatch(host, "*.local")) {
    return "DIRECT";
  }
  return "SOCKS5 %s; DIRECT";
}
`, p.socksAddr)

	w.Write([]byte(pac))
}
