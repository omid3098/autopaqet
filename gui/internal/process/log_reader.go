package process

import "sync"

// RingBuffer is a thread-safe circular buffer for log lines.
type RingBuffer struct {
	mu    sync.RWMutex
	lines []string
	size  int
	pos   int
	count int
}

// NewRingBuffer creates a new ring buffer with the given capacity.
func NewRingBuffer(size int) *RingBuffer {
	return &RingBuffer{
		lines: make([]string, size),
		size:  size,
	}
}

// Add appends a line to the buffer, overwriting oldest if full.
func (r *RingBuffer) Add(line string) {
	r.mu.Lock()
	defer r.mu.Unlock()

	r.lines[r.pos] = line
	r.pos = (r.pos + 1) % r.size
	if r.count < r.size {
		r.count++
	}
}

// Get returns the last N lines in chronological order.
func (r *RingBuffer) Get(n int) []string {
	r.mu.RLock()
	defer r.mu.RUnlock()

	if n <= 0 || r.count == 0 {
		return nil
	}
	if n > r.count {
		n = r.count
	}

	result := make([]string, n)
	start := (r.pos - n + r.size) % r.size
	for i := 0; i < n; i++ {
		result[i] = r.lines[(start+i)%r.size]
	}
	return result
}

// Clear resets the buffer.
func (r *RingBuffer) Clear() {
	r.mu.Lock()
	defer r.mu.Unlock()

	r.pos = 0
	r.count = 0
	r.lines = make([]string, r.size)
}

// Len returns the current number of lines in the buffer.
func (r *RingBuffer) Len() int {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return r.count
}
