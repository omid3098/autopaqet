package network

// NetworkInfo holds the auto-detected network configuration.
type NetworkInfo struct {
	InterfaceName string `json:"interface_name"`
	LocalIP       string `json:"local_ip"`
	GatewayIP     string `json:"gateway_ip"`
	GatewayMAC    string `json:"gateway_mac"`
	NpcapGUID     string `json:"npcap_guid,omitempty"` // Windows only
}

// Detector is the interface for network auto-detection.
type Detector interface {
	Detect() (*NetworkInfo, error)
}
