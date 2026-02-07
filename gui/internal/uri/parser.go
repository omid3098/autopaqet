package uri

import (
	"fmt"
	"net/url"
	"strconv"
	"strings"
)

// PaqetURI represents a parsed paqet:// URI with all configuration fields.
type PaqetURI struct {
	// Required
	Key  string
	Host string
	Port int

	// Optional identity
	Name string // from fragment

	// Network
	Socks     string // SOCKS5 listen address
	SocksUser string
	SocksPass string

	// KCP
	Mode  string // normal, fast, fast2, fast3, manual
	Conn  int
	MTU   int
	Block string // aes, etc.

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
	LocalFlag  string
	RemoteFlag string

	// Forwarding
	Forward string

	// Logging
	Log string
}

// Parse parses a paqet:// URI string into a PaqetURI struct.
func Parse(raw string) (*PaqetURI, error) {
	u, err := url.Parse(raw)
	if err != nil {
		return nil, fmt.Errorf("invalid URI: %w", err)
	}

	if u.Scheme != "paqet" {
		return nil, fmt.Errorf("invalid scheme %q, expected \"paqet\"", u.Scheme)
	}

	if u.User == nil || u.User.Username() == "" {
		return nil, fmt.Errorf("missing key in userinfo position")
	}
	key := u.User.Username()

	host := u.Hostname()
	if host == "" {
		return nil, fmt.Errorf("missing host")
	}

	portStr := u.Port()
	if portStr == "" {
		return nil, fmt.Errorf("missing port")
	}
	port, err := strconv.Atoi(portStr)
	if err != nil {
		return nil, fmt.Errorf("invalid port %q: %w", portStr, err)
	}
	if port < 1 || port > 65535 {
		return nil, fmt.Errorf("port %d out of range (1-65535)", port)
	}

	result := &PaqetURI{
		Key:  key,
		Host: host,
		Port: port,
	}

	// Parse fragment as profile name
	if u.Fragment != "" {
		result.Name = u.Fragment
	}

	// Parse query parameters
	q := u.Query()
	result.Socks = q.Get("socks")
	result.SocksUser = q.Get("socks_user")
	result.SocksPass = q.Get("socks_pass")
	result.Mode = q.Get("mode")
	result.Block = q.Get("block")
	result.LocalFlag = q.Get("lf")
	result.RemoteFlag = q.Get("rf")
	result.Forward = q.Get("fwd")
	result.Log = q.Get("log")

	result.Conn = getIntParam(q, "conn")
	result.MTU = getIntParam(q, "mtu")
	result.RcvWnd = getIntParam(q, "rcvwnd")
	result.SndWnd = getIntParam(q, "sndwnd")
	result.DSCP = getIntParam(q, "dscp")
	result.DShard = getIntParam(q, "dshard")
	result.PShard = getIntParam(q, "pshard")
	result.SmuxBuf = getIntParam(q, "smuxbuf")
	result.StreamBuf = getIntParam(q, "streambuf")
	result.TCPBuf = getIntParam(q, "tcpbuf")
	result.UDPBuf = getIntParam(q, "udpbuf")
	result.SockBuf = getIntParam(q, "sockbuf")

	return result, nil
}

// String serializes the PaqetURI back into a paqet:// URI string.
func (p *PaqetURI) String() string {
	var b strings.Builder
	b.WriteString("paqet://")
	b.WriteString(url.PathEscape(p.Key))
	b.WriteString("@")

	// IPv6 needs brackets
	if strings.Contains(p.Host, ":") {
		b.WriteString("[")
		b.WriteString(p.Host)
		b.WriteString("]")
	} else {
		b.WriteString(p.Host)
	}
	b.WriteString(":")
	b.WriteString(strconv.Itoa(p.Port))

	// Query params - only include non-zero values
	q := url.Values{}
	addStringParam(q, "socks", p.Socks)
	addStringParam(q, "mode", p.Mode)
	addIntParam(q, "conn", p.Conn)
	addIntParam(q, "mtu", p.MTU)
	addIntParam(q, "rcvwnd", p.RcvWnd)
	addIntParam(q, "sndwnd", p.SndWnd)
	addStringParam(q, "block", p.Block)
	addIntParam(q, "dscp", p.DSCP)
	addIntParam(q, "dshard", p.DShard)
	addIntParam(q, "pshard", p.PShard)
	addIntParam(q, "smuxbuf", p.SmuxBuf)
	addIntParam(q, "streambuf", p.StreamBuf)
	addIntParam(q, "tcpbuf", p.TCPBuf)
	addIntParam(q, "udpbuf", p.UDPBuf)
	addIntParam(q, "sockbuf", p.SockBuf)
	addStringParam(q, "lf", p.LocalFlag)
	addStringParam(q, "rf", p.RemoteFlag)
	addStringParam(q, "log", p.Log)
	addStringParam(q, "socks_user", p.SocksUser)
	addStringParam(q, "socks_pass", p.SocksPass)
	addStringParam(q, "fwd", p.Forward)

	encoded := q.Encode()
	if encoded != "" {
		b.WriteString("?")
		b.WriteString(encoded)
	}

	if p.Name != "" {
		b.WriteString("#")
		b.WriteString(url.PathEscape(p.Name))
	}

	return b.String()
}

func getIntParam(q url.Values, key string) int {
	v := q.Get(key)
	if v == "" {
		return 0
	}
	n, _ := strconv.Atoi(v)
	return n
}

func addStringParam(q url.Values, key, val string) {
	if val != "" {
		q.Set(key, val)
	}
}

func addIntParam(q url.Values, key string, val int) {
	if val != 0 {
		q.Set(key, strconv.Itoa(val))
	}
}
