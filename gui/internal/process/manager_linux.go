//go:build linux

package process

import (
	"syscall"
	"time"
)

func (m *Manager) killProcess() error {
	if m.cmd == nil || m.cmd.Process == nil {
		m.setState(StateIdle)
		return nil
	}

	// Try SIGTERM first
	if err := m.cmd.Process.Signal(syscall.SIGTERM); err != nil {
		// Process might already be dead
		m.setState(StateIdle)
		return nil
	}

	// Wait up to 5 seconds for graceful shutdown
	done := make(chan struct{})
	go func() {
		m.cmd.Wait()
		close(done)
	}()

	select {
	case <-done:
		m.setState(StateIdle)
		return nil
	case <-time.After(5 * time.Second):
		// Force kill
		m.cmd.Process.Kill()
		m.setState(StateIdle)
		return nil
	}
}
