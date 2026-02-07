//go:build windows

package process

import (
	"fmt"
	"os/exec"
	"syscall"
)

func (m *Manager) killProcess() error {
	if m.cmd == nil || m.cmd.Process == nil {
		m.setState(StateIdle)
		return nil
	}

	pid := m.cmd.Process.Pid
	killCmd := exec.Command("taskkill", "/PID", fmt.Sprintf("%d", pid), "/F")
	killCmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: 0x08000000}
	if err := killCmd.Run(); err != nil {
		// Try direct kill as fallback
		m.cmd.Process.Kill()
	}

	m.setState(StateIdle)
	return nil
}

// hideWindow sets process attributes to prevent a console window from appearing.
func hideWindow(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: 0x08000000}
}
