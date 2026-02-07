package profile

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"github.com/google/uuid"
	"github.com/omid3098/autopaqet/gui/internal/uri"
)

// Profile represents a saved connection profile with all configuration options.
type Profile struct {
	ID   string `json:"id"`
	Name string `json:"name"`

	// Server
	Host string `json:"host"`
	Port int    `json:"port"`
	Key  string `json:"key"`

	// SOCKS5
	SocksListen string `json:"socks_listen,omitempty"`
	SocksUser   string `json:"socks_user,omitempty"`
	SocksPass   string `json:"socks_pass,omitempty"`

	// KCP
	Mode  string `json:"mode,omitempty"`
	Conn  int    `json:"conn,omitempty"`
	MTU   int    `json:"mtu,omitempty"`
	Block string `json:"block,omitempty"`

	// KCP windows
	RcvWnd int `json:"rcvwnd,omitempty"`
	SndWnd int `json:"sndwnd,omitempty"`

	// FEC
	DShard int `json:"dshard,omitempty"`
	PShard int `json:"pshard,omitempty"`

	// DSCP
	DSCP int `json:"dscp,omitempty"`

	// Buffers
	SmuxBuf   int `json:"smuxbuf,omitempty"`
	StreamBuf int `json:"streambuf,omitempty"`
	TCPBuf    int `json:"tcpbuf,omitempty"`
	UDPBuf    int `json:"udpbuf,omitempty"`
	SockBuf   int `json:"sockbuf,omitempty"`

	// TCP flags
	LocalFlag  string `json:"local_flag,omitempty"`
	RemoteFlag string `json:"remote_flag,omitempty"`

	// Forwarding
	Forward []string `json:"forward,omitempty"`

	// Logging
	LogLevel string `json:"log_level,omitempty"`

	// System proxy preference
	SystemProxy bool `json:"system_proxy,omitempty"`
}

// Store manages profiles on disk as a JSON file.
type Store struct {
	mu       sync.RWMutex
	dir      string
	filePath string
	profiles []*Profile
}

// NewStore creates or loads a profile store from the given directory.
func NewStore(dir string) (*Store, error) {
	if err := os.MkdirAll(dir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create store directory: %w", err)
	}

	s := &Store{
		dir:      dir,
		filePath: filepath.Join(dir, "profiles.json"),
	}

	if err := s.load(); err != nil {
		return nil, err
	}

	return s, nil
}

// List returns all profiles.
func (s *Store) List() []*Profile {
	s.mu.RLock()
	defer s.mu.RUnlock()

	result := make([]*Profile, len(s.profiles))
	copy(result, s.profiles)
	return result
}

// Get returns a profile by ID.
func (s *Store) Get(id string) (*Profile, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	for _, p := range s.profiles {
		if p.ID == id {
			cp := *p
			return &cp, nil
		}
	}
	return nil, fmt.Errorf("profile %q not found", id)
}

// Create adds a new profile and persists to disk.
func (s *Store) Create(p *Profile) (*Profile, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	cp := *p
	cp.ID = uuid.New().String()

	s.profiles = append(s.profiles, &cp)
	if err := s.save(); err != nil {
		// Roll back
		s.profiles = s.profiles[:len(s.profiles)-1]
		return nil, err
	}

	ret := cp
	return &ret, nil
}

// Update replaces an existing profile and persists to disk.
func (s *Store) Update(p *Profile) (*Profile, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	for i, existing := range s.profiles {
		if existing.ID == p.ID {
			cp := *p
			s.profiles[i] = &cp
			if err := s.save(); err != nil {
				s.profiles[i] = existing // Roll back
				return nil, err
			}
			ret := cp
			return &ret, nil
		}
	}
	return nil, fmt.Errorf("profile %q not found", p.ID)
}

// Delete removes a profile by ID and persists to disk.
func (s *Store) Delete(id string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	for i, p := range s.profiles {
		if p.ID == id {
			s.profiles = append(s.profiles[:i], s.profiles[i+1:]...)
			return s.save()
		}
	}
	return fmt.Errorf("profile %q not found", id)
}

// ImportFromURI parses a paqet:// URI and creates a profile from it.
func (s *Store) ImportFromURI(raw string) (*Profile, error) {
	u, err := uri.Parse(raw)
	if err != nil {
		return nil, fmt.Errorf("failed to parse URI: %w", err)
	}

	p := &Profile{
		Name:        u.Name,
		Host:        u.Host,
		Port:        u.Port,
		Key:         u.Key,
		SocksListen: u.Socks,
		SocksUser:   u.SocksUser,
		SocksPass:   u.SocksPass,
		Mode:        u.Mode,
		Conn:        u.Conn,
		MTU:         u.MTU,
		Block:       u.Block,
		RcvWnd:      u.RcvWnd,
		SndWnd:      u.SndWnd,
		DShard:      u.DShard,
		PShard:      u.PShard,
		DSCP:        u.DSCP,
		SmuxBuf:     u.SmuxBuf,
		StreamBuf:   u.StreamBuf,
		TCPBuf:      u.TCPBuf,
		UDPBuf:      u.UDPBuf,
		SockBuf:     u.SockBuf,
		LocalFlag:   u.LocalFlag,
		RemoteFlag:  u.RemoteFlag,
		LogLevel:    u.Log,
	}

	if u.Forward != "" {
		p.Forward = strings.Split(u.Forward, ",")
	}

	return s.Create(p)
}

// ExportToURI serializes a profile to a paqet:// URI string.
func (s *Store) ExportToURI(id string) (string, error) {
	p, err := s.Get(id)
	if err != nil {
		return "", err
	}

	u := &uri.PaqetURI{
		Key:        p.Key,
		Host:       p.Host,
		Port:       p.Port,
		Name:       p.Name,
		Socks:      p.SocksListen,
		SocksUser:  p.SocksUser,
		SocksPass:  p.SocksPass,
		Mode:       p.Mode,
		Conn:       p.Conn,
		MTU:        p.MTU,
		Block:      p.Block,
		RcvWnd:     p.RcvWnd,
		SndWnd:     p.SndWnd,
		DShard:     p.DShard,
		PShard:     p.PShard,
		DSCP:       p.DSCP,
		SmuxBuf:    p.SmuxBuf,
		StreamBuf:  p.StreamBuf,
		TCPBuf:     p.TCPBuf,
		UDPBuf:     p.UDPBuf,
		SockBuf:    p.SockBuf,
		LocalFlag:  p.LocalFlag,
		RemoteFlag: p.RemoteFlag,
		Log:        p.LogLevel,
	}

	if len(p.Forward) > 0 {
		u.Forward = strings.Join(p.Forward, ",")
	}

	return u.String(), nil
}

func (s *Store) load() error {
	data, err := os.ReadFile(s.filePath)
	if os.IsNotExist(err) {
		s.profiles = make([]*Profile, 0)
		return nil
	}
	if err != nil {
		return fmt.Errorf("failed to read profiles: %w", err)
	}

	var profiles []*Profile
	if err := json.Unmarshal(data, &profiles); err != nil {
		return fmt.Errorf("failed to parse profiles: %w", err)
	}

	s.profiles = profiles
	return nil
}

func (s *Store) save() error {
	data, err := json.MarshalIndent(s.profiles, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal profiles: %w", err)
	}

	return os.WriteFile(s.filePath, data, 0644)
}
