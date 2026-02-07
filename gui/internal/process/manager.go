package process

import (
	"bufio"
	"fmt"
	"io"
	"os/exec"
	"sync"
)

// State represents the process lifecycle state.
type State string

const (
	StateIdle      State = "idle"
	StateStarting  State = "starting"
	StateConnected State = "connected"
	StateError     State = "error"
)

// Manager manages the paqet process lifecycle.
type Manager struct {
	mu            sync.RWMutex
	state         State
	cmd           *exec.Cmd
	logBuffer     *RingBuffer
	subscribers   []chan string
	lastError     string
	binaryPath    string
	onStateChange func(State)
	stopping      bool // true when Stop() was explicitly called
}

// NewManager creates a new process manager.
func NewManager(binaryPath string) *Manager {
	return &Manager{
		state:      StateIdle,
		logBuffer:  NewRingBuffer(1000),
		binaryPath: binaryPath,
	}
}

// SetStateChangeHandler sets a callback for state changes.
func (m *Manager) SetStateChangeHandler(fn func(State)) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.onStateChange = fn
}

// Start launches the paqet process with the given config file.
func (m *Manager) Start(configPath string) error {
	m.mu.Lock()
	if m.state != StateIdle && m.state != StateError {
		m.mu.Unlock()
		return fmt.Errorf("cannot start: current state is %s", m.state)
	}

	m.setState(StateStarting)
	m.mu.Unlock()

	cmd := exec.Command(m.binaryPath, "run", "-c", configPath)

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		m.setError(fmt.Sprintf("failed to create stdout pipe: %v", err))
		return err
	}

	stderr, err := cmd.StderrPipe()
	if err != nil {
		m.setError(fmt.Sprintf("failed to create stderr pipe: %v", err))
		return err
	}

	if err := cmd.Start(); err != nil {
		m.setError(fmt.Sprintf("failed to start paqet: %v", err))
		return err
	}

	m.mu.Lock()
	m.cmd = cmd
	m.setState(StateConnected)
	m.mu.Unlock()

	// Read stdout and stderr in goroutines
	go m.readOutput(stdout)
	go m.readOutput(stderr)

	// Monitor process in goroutine
	go func() {
		err := cmd.Wait()
		m.mu.Lock()
		defer m.mu.Unlock()

		if m.stopping {
			// Explicit stop — always go to Idle regardless of exit code
			m.stopping = false
			m.setState(StateIdle)
		} else if err != nil {
			m.setError(fmt.Sprintf("paqet exited with error: %v", err))
		} else {
			m.setState(StateIdle)
		}
		m.cmd = nil
	}()

	return nil
}

// Stop terminates the running paqet process.
func (m *Manager) Stop() error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.cmd == nil || m.cmd.Process == nil {
		m.setState(StateIdle)
		return nil
	}

	m.stopping = true
	return m.killProcess()
}

// GetState returns the current process state.
func (m *Manager) GetState() State {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.state
}

// GetLastError returns the last error message.
func (m *Manager) GetLastError() string {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.lastError
}

// GetLogs returns the last N log lines.
func (m *Manager) GetLogs(count int) []string {
	return m.logBuffer.Get(count)
}

// ClearLogs clears the log buffer.
func (m *Manager) ClearLogs() {
	m.logBuffer.Clear()
}

// Subscribe returns a channel that receives new log lines.
func (m *Manager) Subscribe() chan string {
	m.mu.Lock()
	defer m.mu.Unlock()
	ch := make(chan string, 100)
	m.subscribers = append(m.subscribers, ch)
	return ch
}

// Unsubscribe removes a subscriber channel.
func (m *Manager) Unsubscribe(ch chan string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	for i, sub := range m.subscribers {
		if sub == ch {
			m.subscribers = append(m.subscribers[:i], m.subscribers[i+1:]...)
			close(ch)
			return
		}
	}
}

func (m *Manager) setState(s State) {
	m.state = s
	if m.onStateChange != nil {
		go m.onStateChange(s)
	}
}

func (m *Manager) setError(msg string) {
	m.lastError = msg
	m.setState(StateError)
	m.logBuffer.Add("[ERROR] " + msg)
}

func (m *Manager) readOutput(r io.Reader) {
	scanner := bufio.NewScanner(r)
	for scanner.Scan() {
		line := scanner.Text()
		m.logBuffer.Add(line)
		m.notifySubscribers(line)
	}
}

func (m *Manager) notifySubscribers(line string) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	for _, ch := range m.subscribers {
		select {
		case ch <- line:
		default:
			// Drop if subscriber is slow
		}
	}
}
