package proxy

// Setter is the interface for OS-level proxy configuration.
type Setter interface {
	EnableSystemProxy(pacURL string) error
	DisableSystemProxy() error
	IsSystemProxyEnabled() bool
}
