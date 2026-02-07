//go:build windows

package process

import (
	"fmt"
	"os/exec"
)

func (m *Manager) killProcess() error {
	if m.cmd == nil || m.cmd.Process == nil {
		m.setState(StateIdle)
		return nil
	}

	pid := m.cmd.Process.Pid
	killCmd := exec.Command("taskkill", "/PID", fmt.Sprintf("%d", pid), "/F")
	if err := killCmd.Run(); err != nil {
		// Try direct kill as fallback
		m.cmd.Process.Kill()
	}

	m.setState(StateIdle)
	return nil
}
