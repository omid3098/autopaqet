package diag

// StepID identifies a diagnostic step.
type StepID string

const (
	StepNetwork  StepID = "network"
	StepNpcap    StepID = "npcap"
	StepPing     StepID = "ping"
	StepConnect  StepID = "connect"
	StepVerify   StepID = "verify"
	StepDiagnose StepID = "diagnose"
)

// StepStatus indicates the outcome of a diagnostic step.
type StepStatus string

const (
	StatusRunning StepStatus = "running"
	StatusPass    StepStatus = "pass"
	StatusFail    StepStatus = "fail"
	StatusSkip    StepStatus = "skip"
	StatusWarn    StepStatus = "warn"
)

// StepResult is emitted for each diagnostic step update.
type StepResult struct {
	ID      StepID     `json:"id"`
	Status  StepStatus `json:"status"`
	Message string     `json:"message"`
	Detail  string     `json:"detail,omitempty"`
}

// FlagProbeResult holds the outcome of a single paqet ping probe.
type FlagProbeResult struct {
	Flag    string `json:"flag"`
	Success bool   `json:"success"`
	Output  string `json:"output"`
}

// Result is the final diagnostic outcome.
type Result struct {
	Success       bool              `json:"success"`
	Steps         []StepResult      `json:"steps"`
	FlagProbes    []FlagProbeResult `json:"flag_probes,omitempty"`
	Suggestions   []string          `json:"suggestions,omitempty"`
	Summary       string            `json:"summary"`
	ConfigSummary string            `json:"config_summary,omitempty"`
}
