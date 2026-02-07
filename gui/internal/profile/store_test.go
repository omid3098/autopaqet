package profile

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/omid3098/autopaqet/gui/internal/uri"
)

func tempStore(t *testing.T) *Store {
	t.Helper()
	dir := t.TempDir()
	s, err := NewStore(dir)
	if err != nil {
		t.Fatalf("NewStore failed: %v", err)
	}
	return s
}

func TestCreateAndList(t *testing.T) {
	s := tempStore(t)

	p := &Profile{
		Name:       "TestProfile",
		Host:       "1.2.3.4",
		Port:       8080,
		Key:        "secret",
		Mode:       "fast3",
		Conn:       2,
		Block:      "aes",
		LocalFlag:  "PA",
		RemoteFlag: "PA",
	}

	created, err := s.Create(p)
	if err != nil {
		t.Fatalf("Create failed: %v", err)
	}
	if created.ID == "" {
		t.Error("expected non-empty ID")
	}
	if created.Name != "TestProfile" {
		t.Errorf("Name = %q, want %q", created.Name, "TestProfile")
	}

	profiles := s.List()
	if len(profiles) != 1 {
		t.Fatalf("List returned %d profiles, want 1", len(profiles))
	}
	if profiles[0].ID != created.ID {
		t.Errorf("ID mismatch: got %q, want %q", profiles[0].ID, created.ID)
	}
}

func TestGetByID(t *testing.T) {
	s := tempStore(t)

	p, _ := s.Create(&Profile{
		Name: "FindMe",
		Host: "1.2.3.4",
		Port: 8080,
		Key:  "secret",
	})

	found, err := s.Get(p.ID)
	if err != nil {
		t.Fatalf("Get failed: %v", err)
	}
	if found.Name != "FindMe" {
		t.Errorf("Name = %q, want %q", found.Name, "FindMe")
	}
}

func TestGetNotFound(t *testing.T) {
	s := tempStore(t)

	_, err := s.Get("nonexistent-id")
	if err == nil {
		t.Error("expected error for nonexistent profile")
	}
}

func TestUpdate(t *testing.T) {
	s := tempStore(t)

	p, _ := s.Create(&Profile{
		Name: "Original",
		Host: "1.2.3.4",
		Port: 8080,
		Key:  "secret",
	})

	p.Name = "Updated"
	p.Host = "5.6.7.8"

	updated, err := s.Update(p)
	if err != nil {
		t.Fatalf("Update failed: %v", err)
	}
	if updated.Name != "Updated" {
		t.Errorf("Name = %q, want %q", updated.Name, "Updated")
	}
	if updated.Host != "5.6.7.8" {
		t.Errorf("Host = %q, want %q", updated.Host, "5.6.7.8")
	}

	// Verify persistence
	found, _ := s.Get(p.ID)
	if found.Name != "Updated" {
		t.Errorf("persisted Name = %q, want %q", found.Name, "Updated")
	}
}

func TestUpdateNotFound(t *testing.T) {
	s := tempStore(t)

	_, err := s.Update(&Profile{ID: "nonexistent"})
	if err == nil {
		t.Error("expected error for nonexistent profile")
	}
}

func TestDelete(t *testing.T) {
	s := tempStore(t)

	p, _ := s.Create(&Profile{
		Name: "ToDelete",
		Host: "1.2.3.4",
		Port: 8080,
		Key:  "secret",
	})

	err := s.Delete(p.ID)
	if err != nil {
		t.Fatalf("Delete failed: %v", err)
	}

	profiles := s.List()
	if len(profiles) != 0 {
		t.Errorf("List returned %d profiles, want 0", len(profiles))
	}
}

func TestDeleteNotFound(t *testing.T) {
	s := tempStore(t)

	err := s.Delete("nonexistent-id")
	if err == nil {
		t.Error("expected error for nonexistent profile")
	}
}

func TestFilePersistence(t *testing.T) {
	dir := t.TempDir()

	// Create first store and add profile
	s1, _ := NewStore(dir)
	s1.Create(&Profile{
		Name: "Persistent",
		Host: "1.2.3.4",
		Port: 8080,
		Key:  "secret",
	})

	// Create a new store pointing at same dir
	s2, err := NewStore(dir)
	if err != nil {
		t.Fatalf("second NewStore failed: %v", err)
	}

	profiles := s2.List()
	if len(profiles) != 1 {
		t.Fatalf("second store has %d profiles, want 1", len(profiles))
	}
	if profiles[0].Name != "Persistent" {
		t.Errorf("Name = %q, want %q", profiles[0].Name, "Persistent")
	}
}

func TestImportFromURI(t *testing.T) {
	s := tempStore(t)

	raw := "paqet://secretkey@10.0.0.1:9090?socks=127.0.0.1:1080&mode=fast3&conn=2&block=aes&lf=PA&rf=PA#ImportedProfile"
	p, err := s.ImportFromURI(raw)
	if err != nil {
		t.Fatalf("ImportFromURI failed: %v", err)
	}

	if p.Name != "ImportedProfile" {
		t.Errorf("Name = %q, want %q", p.Name, "ImportedProfile")
	}
	if p.Host != "10.0.0.1" {
		t.Errorf("Host = %q, want %q", p.Host, "10.0.0.1")
	}
	if p.Port != 9090 {
		t.Errorf("Port = %d, want %d", p.Port, 9090)
	}
	if p.Key != "secretkey" {
		t.Errorf("Key = %q, want %q", p.Key, "secretkey")
	}
	if p.Mode != "fast3" {
		t.Errorf("Mode = %q, want %q", p.Mode, "fast3")
	}

	// Verify it was persisted
	profiles := s.List()
	if len(profiles) != 1 {
		t.Fatalf("List returned %d profiles, want 1", len(profiles))
	}
}

func TestExportToURI(t *testing.T) {
	s := tempStore(t)

	p, _ := s.Create(&Profile{
		Name:       "ExportMe",
		Host:       "1.2.3.4",
		Port:       8080,
		Key:        "secret",
		Mode:       "fast3",
		Conn:       2,
		Block:      "aes",
		LocalFlag:  "PA",
		RemoteFlag: "PA",
	})

	raw, err := s.ExportToURI(p.ID)
	if err != nil {
		t.Fatalf("ExportToURI failed: %v", err)
	}

	// Parse back and verify
	parsed, err := uri.Parse(raw)
	if err != nil {
		t.Fatalf("parse exported URI failed: %v", err)
	}
	if parsed.Key != "secret" {
		t.Errorf("Key = %q, want %q", parsed.Key, "secret")
	}
	if parsed.Host != "1.2.3.4" {
		t.Errorf("Host = %q, want %q", parsed.Host, "1.2.3.4")
	}
	if parsed.Port != 8080 {
		t.Errorf("Port = %d, want %d", parsed.Port, 8080)
	}
	if parsed.Name != "ExportMe" {
		t.Errorf("Name = %q, want %q", parsed.Name, "ExportMe")
	}
}

func TestImportExportRoundTrip(t *testing.T) {
	s := tempStore(t)

	original := "paqet://key123@192.168.1.1:7070?socks=127.0.0.1:1080&mode=fast3&conn=2&mtu=1400&rcvwnd=512&sndwnd=512&block=aes&dscp=46&dshard=10&pshard=3&lf=PA&rf=PA#RoundTrip"

	p, err := s.ImportFromURI(original)
	if err != nil {
		t.Fatalf("ImportFromURI failed: %v", err)
	}

	exported, err := s.ExportToURI(p.ID)
	if err != nil {
		t.Fatalf("ExportToURI failed: %v", err)
	}

	// Parse both and compare
	orig, _ := uri.Parse(original)
	exp, _ := uri.Parse(exported)

	if orig.Key != exp.Key {
		t.Errorf("Key: %q != %q", orig.Key, exp.Key)
	}
	if orig.Host != exp.Host {
		t.Errorf("Host: %q != %q", orig.Host, exp.Host)
	}
	if orig.Port != exp.Port {
		t.Errorf("Port: %d != %d", orig.Port, exp.Port)
	}
	if orig.Name != exp.Name {
		t.Errorf("Name: %q != %q", orig.Name, exp.Name)
	}
	if orig.Mode != exp.Mode {
		t.Errorf("Mode: %q != %q", orig.Mode, exp.Mode)
	}
	if orig.Conn != exp.Conn {
		t.Errorf("Conn: %d != %d", orig.Conn, exp.Conn)
	}
	if orig.MTU != exp.MTU {
		t.Errorf("MTU: %d != %d", orig.MTU, exp.MTU)
	}
	if orig.RcvWnd != exp.RcvWnd {
		t.Errorf("RcvWnd: %d != %d", orig.RcvWnd, exp.RcvWnd)
	}
	if orig.SndWnd != exp.SndWnd {
		t.Errorf("SndWnd: %d != %d", orig.SndWnd, exp.SndWnd)
	}
	if orig.Block != exp.Block {
		t.Errorf("Block: %q != %q", orig.Block, exp.Block)
	}
	if orig.DSCP != exp.DSCP {
		t.Errorf("DSCP: %d != %d", orig.DSCP, exp.DSCP)
	}
	if orig.DShard != exp.DShard {
		t.Errorf("DShard: %d != %d", orig.DShard, exp.DShard)
	}
	if orig.PShard != exp.PShard {
		t.Errorf("PShard: %d != %d", orig.PShard, exp.PShard)
	}
}

func TestMultipleProfiles(t *testing.T) {
	s := tempStore(t)

	for i := 0; i < 5; i++ {
		s.Create(&Profile{
			Name: "Profile" + string(rune('A'+i)),
			Host: "1.2.3.4",
			Port: 8080 + i,
			Key:  "secret",
		})
	}

	profiles := s.List()
	if len(profiles) != 5 {
		t.Errorf("List returned %d profiles, want 5", len(profiles))
	}
}

func TestStoreCreatesDirectory(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "nested", "dir")
	_, err := NewStore(dir)
	if err != nil {
		t.Fatalf("NewStore failed: %v", err)
	}

	if _, err := os.Stat(dir); os.IsNotExist(err) {
		t.Error("expected directory to be created")
	}
}

func TestProfileAllFields(t *testing.T) {
	s := tempStore(t)

	p := &Profile{
		Name:        "FullProfile",
		Host:        "1.2.3.4",
		Port:        8080,
		Key:         "secret",
		SocksListen: "127.0.0.1:1080",
		SocksUser:   "user",
		SocksPass:   "pass",
		Mode:        "fast3",
		Conn:        4,
		MTU:         1400,
		Block:       "salsa20",
		RcvWnd:      2048,
		SndWnd:      2048,
		DShard:      10,
		PShard:      3,
		DSCP:        46,
		SmuxBuf:     4194304,
		StreamBuf:   2097152,
		TCPBuf:      4194304,
		UDPBuf:      1048576,
		SockBuf:     4194304,
		LocalFlag:   "S",
		RemoteFlag:  "A",
		Forward:     []string{"tcp:8080:internal:80"},
		LogLevel:    "debug",
		SystemProxy: true,
	}

	created, err := s.Create(p)
	if err != nil {
		t.Fatalf("Create failed: %v", err)
	}

	found, _ := s.Get(created.ID)
	if found.SmuxBuf != 4194304 {
		t.Errorf("SmuxBuf = %d, want %d", found.SmuxBuf, 4194304)
	}
	if found.SystemProxy != true {
		t.Error("SystemProxy should be true")
	}
	if len(found.Forward) != 1 || found.Forward[0] != "tcp:8080:internal:80" {
		t.Errorf("Forward = %v, want [tcp:8080:internal:80]", found.Forward)
	}
}
