package process

import (
	"os"
	"path/filepath"
	stdsync "sync"
	"testing"
	"time"
)

func TestRingBufferAddAndGet(t *testing.T) {
	rb := NewRingBuffer(5)
	rb.Add("line1")
	rb.Add("line2")
	rb.Add("line3")

	lines := rb.Get(3)
	if len(lines) != 3 {
		t.Fatalf("Get(3) returned %d lines, want 3", len(lines))
	}
	if lines[0] != "line1" || lines[1] != "line2" || lines[2] != "line3" {
		t.Errorf("lines = %v, want [line1, line2, line3]", lines)
	}
}

func TestRingBufferOverflow(t *testing.T) {
	rb := NewRingBuffer(3)
	rb.Add("a")
	rb.Add("b")
	rb.Add("c")
	rb.Add("d") // overwrites "a"
	rb.Add("e") // overwrites "b"

	lines := rb.Get(3)
	if len(lines) != 3 {
		t.Fatalf("Get(3) returned %d lines, want 3", len(lines))
	}
	if lines[0] != "c" || lines[1] != "d" || lines[2] != "e" {
		t.Errorf("lines = %v, want [c, d, e]", lines)
	}
}

func TestRingBufferGetMoreThanAvailable(t *testing.T) {
	rb := NewRingBuffer(10)
	rb.Add("only")

	lines := rb.Get(5)
	if len(lines) != 1 {
		t.Fatalf("Get(5) returned %d lines, want 1", len(lines))
	}
	if lines[0] != "only" {
		t.Errorf("lines[0] = %q, want %q", lines[0], "only")
	}
}

func TestRingBufferGetZero(t *testing.T) {
	rb := NewRingBuffer(5)
	rb.Add("line")

	lines := rb.Get(0)
	if lines != nil {
		t.Errorf("Get(0) should return nil, got %v", lines)
	}
}

func TestRingBufferClear(t *testing.T) {
	rb := NewRingBuffer(5)
	rb.Add("line1")
	rb.Add("line2")

	rb.Clear()

	if rb.Len() != 0 {
		t.Errorf("Len() = %d, want 0 after Clear()", rb.Len())
	}

	lines := rb.Get(5)
	if lines != nil {
		t.Errorf("Get after Clear should return nil, got %v", lines)
	}
}

func TestRingBufferLen(t *testing.T) {
	rb := NewRingBuffer(5)
	if rb.Len() != 0 {
		t.Errorf("Len() = %d, want 0", rb.Len())
	}

	rb.Add("a")
	rb.Add("b")
	if rb.Len() != 2 {
		t.Errorf("Len() = %d, want 2", rb.Len())
	}
}

func TestRingBufferLenCapsAtSize(t *testing.T) {
	rb := NewRingBuffer(3)
	rb.Add("a")
	rb.Add("b")
	rb.Add("c")
	rb.Add("d") // overflow

	if rb.Len() != 3 {
		t.Errorf("Len() = %d, want 3 (capped at buffer size)", rb.Len())
	}
}

func TestManagerInitialState(t *testing.T) {
	m := NewManager("/fake/binary")
	if m.GetState() != StateIdle {
		t.Errorf("initial state = %q, want %q", m.GetState(), StateIdle)
	}
}

func TestManagerStartWithBadBinary(t *testing.T) {
	m := NewManager("/nonexistent/binary")
	err := m.Start("/fake/config.yml")
	if err == nil {
		t.Error("expected error when starting with nonexistent binary")
	}
	if m.GetState() != StateError {
		t.Errorf("state = %q, want %q", m.GetState(), StateError)
	}
}

func TestManagerStartAndStop(t *testing.T) {
	// Create a simple script that sleeps
	tmpDir := t.TempDir()
	scriptPath := filepath.Join(tmpDir, "fake-paqet.sh")
	os.WriteFile(scriptPath, []byte("#!/bin/sh\nwhile true; do echo running; sleep 0.1; done\n"), 0755)
	configPath := filepath.Join(tmpDir, "config.yml")
	os.WriteFile(configPath, []byte("role: client\n"), 0644)

	m := NewManager(scriptPath)
	err := m.Start(configPath)
	if err != nil {
		t.Fatalf("Start failed: %v", err)
	}

	// Give process time to start
	time.Sleep(200 * time.Millisecond)

	if m.GetState() != StateConnected {
		t.Errorf("state = %q, want %q", m.GetState(), StateConnected)
	}

	err = m.Stop()
	if err != nil {
		t.Fatalf("Stop failed: %v", err)
	}

	// Wait for state to update
	time.Sleep(200 * time.Millisecond)

	if m.GetState() != StateIdle {
		t.Errorf("state after stop = %q, want %q", m.GetState(), StateIdle)
	}
}

func TestManagerCannotStartWhileRunning(t *testing.T) {
	tmpDir := t.TempDir()
	scriptPath := filepath.Join(tmpDir, "fake-paqet.sh")
	os.WriteFile(scriptPath, []byte("#!/bin/sh\nsleep 60\n"), 0755)
	configPath := filepath.Join(tmpDir, "config.yml")
	os.WriteFile(configPath, []byte("role: client\n"), 0644)

	m := NewManager(scriptPath)
	m.Start(configPath)
	defer m.Stop()

	time.Sleep(100 * time.Millisecond)

	err := m.Start(configPath)
	if err == nil {
		t.Error("expected error when starting while already running")
	}
}

func TestManagerLogCapture(t *testing.T) {
	tmpDir := t.TempDir()
	scriptPath := filepath.Join(tmpDir, "fake-paqet.sh")
	os.WriteFile(scriptPath, []byte("#!/bin/sh\necho 'log line 1'\necho 'log line 2'\nsleep 0.5\n"), 0755)
	configPath := filepath.Join(tmpDir, "config.yml")
	os.WriteFile(configPath, []byte("role: client\n"), 0644)

	m := NewManager(scriptPath)
	m.Start(configPath)

	// Wait for process to output and finish
	time.Sleep(800 * time.Millisecond)

	logs := m.GetLogs(10)
	if len(logs) == 0 {
		t.Error("expected captured log lines, got none")
	}
}

func TestManagerSubscribe(t *testing.T) {
	tmpDir := t.TempDir()
	scriptPath := filepath.Join(tmpDir, "fake-paqet.sh")
	os.WriteFile(scriptPath, []byte("#!/bin/sh\necho 'hello'\nsleep 0.5\n"), 0755)
	configPath := filepath.Join(tmpDir, "config.yml")
	os.WriteFile(configPath, []byte("role: client\n"), 0644)

	m := NewManager(scriptPath)
	ch := m.Subscribe()
	defer m.Unsubscribe(ch)

	m.Start(configPath)

	select {
	case line := <-ch:
		if line != "hello" {
			t.Errorf("received %q, want %q", line, "hello")
		}
	case <-time.After(2 * time.Second):
		t.Error("timed out waiting for log line")
	}
}

func TestManagerStateChangeCallback(t *testing.T) {
	states := make([]State, 0)
	var mu stdsync.Mutex

	m := NewManager("/nonexistent/binary")
	m.SetStateChangeHandler(func(s State) {
		mu.Lock()
		states = append(states, s)
		mu.Unlock()
	})

	m.Start("/fake/config")

	time.Sleep(200 * time.Millisecond)

	mu.Lock()
	defer mu.Unlock()
	if len(states) < 2 {
		t.Fatalf("expected at least 2 state changes (starting, error), got %d: %v", len(states), states)
	}
	if states[0] != StateStarting {
		t.Errorf("first state = %q, want %q", states[0], StateStarting)
	}
	if states[1] != StateError {
		t.Errorf("second state = %q, want %q", states[1], StateError)
	}
}
