# AutoPaqet

Automated setup scripts for the [paqet](https://github.com/hanselime/paqet) project.

## Quick Install

### Server (Linux/Ubuntu)

```bash
curl -fsSL https://raw.githubusercontent.com/omid3098/autopaqet/main/autopaqet-server.sh | sudo bash
```

### Client (Windows)

Run in PowerShell (as Administrator):

```powershell
irm https://raw.githubusercontent.com/omid3098/autopaqet/main/autopaqet-client.ps1 | iex
```

Or with pre-configured server settings:

```powershell
$env:AUTOPAQET_SERVER="YOUR_SERVER_IP:9999"; $env:AUTOPAQET_KEY="YOUR_SECRET_KEY"; irm https://raw.githubusercontent.com/omid3098/autopaqet/main/autopaqet-client.ps1 | iex
```

---

## Detailed Installation

### Server Setup (Linux)

The server script (`autopaqet-server.sh`) performs the following:

- Updates system packages
- Installs Go, build tools, and `libpcap-dev`
- Configures firewall (UFW) and iptables rules
- Clones and builds the `paqet` binary
- Creates and starts a `systemd` service
- Auto-detects network settings and generates `server.yaml`

After installation, the script outputs the client configuration parameters (server address, secret key) needed for Windows client setup.

**Requirements:**
- Ubuntu/Debian-based Linux
- Root privileges

---

### Client Setup (Windows)

The client script (`autopaqet-client.ps1`) performs the following:

- Auto-elevates to Administrator (needed for getting network configuration)
- Downloads and installs dependencies (Git, Go, GCC, Npcap)
- Clones and builds the `paqet.exe` binary
- Auto-detects network configuration
- Generates `client.yaml` configuration
- Launches the client

**Installation Directory:** `%USERPROFILE%\autopaqet`

**Environment Variables:**
| Variable | Description | Default |
|----------|-------------|---------|
| `AUTOPAQET_SERVER` | Server address (IP:PORT) | `127.0.0.1:9999` |
| `AUTOPAQET_KEY` | Secret key (must match server) | Auto-generated |

**Requirements:**
- Windows 10/11 or Server
- Internet connection

**Directory Structure After Setup:**
```
%USERPROFILE%\autopaqet\
├── requirements\
│   ├── autopaqet\          # Cloned source code
│   ├── paqet.exe           # Built binary
│   ├── client.yaml         # Generated configuration
│   ├── setup.log           # Installation log
│   └── *.exe / *.msi       # Cached installers
```

---

### Alternative: Local Script Execution

If you prefer to run the scripts locally:

**Windows (PowerShell):**
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\autopaqet-client.ps1
```

**Linux:**
```bash
sudo bash autopaqet-server.sh
```

---

## Useful Commands

### Server (Linux)

```bash
# Check service status
systemctl status autopaqet

# View logs
journalctl -u autopaqet -f

# Restart service
systemctl restart autopaqet

# Stop service
systemctl stop autopaqet
```

### Client (Windows)

After installation, you can launch AutoPaqet from:
- **Desktop:** Double-click "AutoPaqet" shortcut
- **Start Menu:** Search for "AutoPaqet"

Or manually from PowerShell:
```powershell
cd $env:USERPROFILE\autopaqet\requirements
.\paqet.exe run -c client.yaml
```

---

## Uninstall

### Client (Windows)

Run in PowerShell:
```powershell
irm https://raw.githubusercontent.com/omid3098/autopaqet/main/autopaqet-uninstall.ps1 | iex
```

Or search for "Uninstall AutoPaqet" in the Start Menu.

This removes the installation folder and shortcuts. Dependencies (Git, Go, GCC, Npcap) are not removed.
