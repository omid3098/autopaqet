# AutoPaqet

This directory contains automated setup scripts for the [AutoPaqet](https://github.com/hanselime/paqet) project.

## 1. AutoPaqet Client (Windows)

Two options are available for Windows:

### Option A: Batch Script (`autopaqet-client.bat`) - Recommended

A user-friendly batch script with visual progress bar and automatic dependency setup.

#### Features
*   **Right-click to Run:** Simply right-click and select "Run as administrator"
*   **Visual Progress Bar:** Shows progress with step-by-step status
*   **Automatic Downloads:** Downloads and sets up Git, Go, GCC, and Npcap automatically
*   **Interactive Prompts:** Asks before setting up each component
*   **Cached Downloads:** Downloads are saved to `requirements/` folder for reuse
*   **Network Auto-Detection:** Automatically configures network settings
*   **Configuration Wizard:** Generates ready-to-use `client.yaml`

#### Usage
1.  **Right-click** `autopaqet-client.bat`
2.  Select **"Run as administrator"**
3.  Follow the on-screen prompts

#### Directory Structure After Setup
```
autopaqet/
├── requirements/          # Downloaded files (cached)
│   ├── Git-*.exe
│   ├── go*.msi
│   ├── tdm64-gcc-*.exe
│   └── npcap-*.exe
├── autopaqet/             # Cloned source code
├── autopaqet.exe          # Built binary
└── client.yaml            # Generated configuration
```

---

### Option B: PowerShell Script (`autopaqet-client.ps1`)

A PowerShell script for advanced users who prefer manual dependency setup.

#### Features
*   **Dependency Check:** Verifies Git, Go, GCC (MinGW), and Npcap are present
*   **Build Automation:** Clones the repository and compiles the `autopaqet.exe` binary
*   **Network Auto-Detection:** Automatically detects network configuration
*   **Configuration Wizard:** Generates ready-to-use `client.yaml`

#### Usage
1.  Set up dependencies manually: Git, Go, TDM-GCC, Npcap
2.  Open **PowerShell** as **Administrator**
3.  Navigate to this directory
4.  Run the script:
    ```powershell
    .\autopaqet-client.ps1
    ```

---

### Windows Requirements
*   Windows 10/11 or Server
*   Administrator privileges
*   Internet connection (for cloning and fetching dependencies)

---

## 2. AutoPaqet Server (Linux)

A Bash script (`autopaqet-server.sh`) to set up the AutoPaqet Server on Linux (Ubuntu/Debian).

### Features
*   **System Update:** Updates `apt` packages.
*   **Dependency Setup:** Sets up Go, build tools, `libpcap-dev`, etc.
*   **Firewall Configuration:** Configures `ufw` and raw `iptables` rules to bypass connection tracking (essential for AutoPaqet).
*   **Build Automation:** Clones and builds the `autopaqet` binary.
*   **Service Management:** Creates and starts a `systemd` service (`autopaqet.service`).
*   **Config Generation:** Auto-detects network settings and generates `server.yaml`.

### Usage
Run as root:
```bash
sudo bash autopaqet-server.sh
```

### Requirements
*   Ubuntu/Debian-based Linux distribution.
*   Root privileges.
