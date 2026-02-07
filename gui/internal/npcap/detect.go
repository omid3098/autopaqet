package npcap

// Status represents the Npcap/libpcap detection result.
type Status struct {
	Installed   bool   `json:"installed"`
	Version     string `json:"version,omitempty"`
	DownloadURL string `json:"download_url"`
	Message     string `json:"message,omitempty"`
}

// Checker is the interface for pcap library detection.
type Checker interface {
	Check() *Status
}
