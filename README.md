# Paqet Installers

This directory contains automated installer scripts for the [Paqet](https://github.com/hanselime/paqet) project.

## 1. Windows Client Installer

Two installer options are available for Windows:

### Option A: Batch Script (`install-paqet-client.bat`) - Recommended

A user-friendly batch script with visual progress bar and automatic dependency installation.

#### Features
*   **Right-click to Run:** Simply right-click and select "Run as administrator"
*   **Visual Progress Bar:** Shows installation progress with step-by-step status
*   **Automatic Downloads:** Downloads and installs Git, Go, GCC, and Npcap automatically
*   **Interactive Prompts:** Asks before installing each component
*   **Cached Installers:** Downloads are saved to `requirements/` folder for reuse
*   **Network Auto-Detection:** Automatically configures network settings
*   **Configuration Wizard:** Generates ready-to-use `client.yaml`

#### Usage
1.  **Right-click** `install-paqet-client.bat`
2.  Select **"Run as administrator"**
3.  Follow the on-screen prompts

#### Directory Structure After Installation
```
paqet_installer/
├── requirements/          # Downloaded installers (cached)
│   ├── Git-*.exe
│   ├── go*.msi
│   ├── tdm64-gcc-*.exe
│   └── npcap-*.exe
├── paqet/                 # Cloned source code
├── paqet.exe              # Built binary
└── client.yaml            # Generated configuration
```

---

### Option B: PowerShell Script (`install-paqet-client.ps1`)

A PowerShell script for advanced users who prefer manual dependency installation.

#### Features
*   **Dependency Check:** Verifies Git, Go, GCC (MinGW), and Npcap are installed
*   **Build Automation:** Clones the repository and compiles the `paqet.exe` binary
*   **Network Auto-Detection:** Automatically detects network configuration
*   **Configuration Wizard:** Generates ready-to-use `client.yaml`

#### Usage
1.  Install dependencies manually: Git, Go, TDM-GCC, Npcap
2.  Open **PowerShell** as **Administrator**
3.  Navigate to this directory
4.  Run the script:
    ```powershell
    .\install-paqet-client.ps1
    ```

---

### Windows Requirements
*   Windows 10/11 or Server
*   Administrator privileges
*   Internet connection (for cloning and fetching dependencies)

---

## 2. Linux Server Installer (`install-paqet-server.sh`)

A Bash script to set up the Paqet Server on Linux (Ubuntu/Debian).

### Features
*   **System Update:** Updates `apt` packages.
*   **Dependency Installation:** Installs Go, build tools, `libpcap-dev`, etc.
*   **Firewall Configuration:** Configures `ufw` and raw `iptables` rules to bypass connection tracking (essential for Paqet).
*   **Build Automation:** Clones and builds the `paqet` binary.
*   **Service Management:** Creates and starts a `systemd` service (`paqet.service`).
*   **Config Generation:** Auto-detects network settings and generates `server.yaml`.

### Usage
Run as root:
```bash
sudo bash install-paqet-server.sh
```

### Requirements
*   Ubuntu/Debian-based Linux distribution.
*   Root privileges.
