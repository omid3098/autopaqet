//go:build windows

package diag

import (
	"os/exec"
	"syscall"
)

// hideConsole sets process attributes to prevent console windows on Windows.
func hideConsole(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: 0x08000000}
}
