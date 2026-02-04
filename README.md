# AutoPaqet

Automated setup scripts for the [paqet](https://github.com/hanselime/paqet) project.

## Quick Install

### Server (Linux/Ubuntu)

```bash
curl -fsSL https://raw.githubusercontent.com/omid3098/autopaqet/main/autopaqet-server.sh | sudo bash
```
<img width="409" height="294" alt="image" src="https://github.com/user-attachments/assets/950e377e-9daf-46c9-8a46-684ab656133e" />

### Client (Windows)

Run in PowerShell (as Administrator):

```powershell
irm https://raw.githubusercontent.com/omid3098/autopaqet/main/autopaqet-client.ps1 | iex
```
<img width="515" height="226" alt="image" src="https://github.com/user-attachments/assets/d2be1bef-b142-4c18-8ce9-b2258f1a86c6" />

---

## Interactive Mode

Both scripts support an interactive menu when run directly (not piped).

### Client Menu (Windows)

Run the script directly to access the menu:

```powershell
.\autopaqet-client.ps1
```

**Menu Options:**
- Fresh Install
- Update AutoPaqet (download latest scripts)
- Update Paqet (git pull + rebuild)
- Uninstall
- Configuration (view/edit server, key, network)
- Diagnostics (test connection, view logs, network info)

### Server Menu (Linux)

After installation, use the management command:

```bash
sudo autopaqet-manage
```

Or download and run the script directly:

```bash
curl -fsSL https://raw.githubusercontent.com/omid3098/autopaqet/main/autopaqet-server.sh -o autopaqet-server.sh
sudo bash autopaqet-server.sh
```

**Menu Options:**
- Fresh Install
- Update AutoPaqet (download latest scripts)
- Update Paqet (git pull + rebuild)
- Uninstall
- Service Management (start, stop, restart, enable, disable)
- Configuration (view/edit port, key, config file)
- View Logs

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
- Creates desktop and Start Menu shortcuts
- Launches the client

**Installation Directory:** `%USERPROFILE%\autopaqet`

**Environment Variables:**
| Variable | Description | Default |
|----------|-------------|---------|
| `AUTOPAQET_SERVER` | Server address (IP:PORT) | *(required)* |
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
# Open management menu (update, uninstall, config, etc.)
sudo autopaqet-manage

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

### Server (Linux)

Use the management menu:
```bash
sudo autopaqet-manage
# Select option 4: Uninstall
```

Or run the uninstall script directly:
```bash
curl -fsSL https://raw.githubusercontent.com/omid3098/autopaqet/main/autopaqet-uninstall.sh | sudo bash
```

This removes:
- Systemd service (stopped and disabled)
- Binary (`/usr/local/bin/autopaqet`)
- Configuration (`/etc/autopaqet/`)
- Source directory (`/opt/autopaqet/`)

**Note:** iptables rules and Go installation are NOT removed automatically. The script provides instructions to remove them manually if needed.

---

## Development

### Project Structure

```
paqet_installer/
├── autopaqet-client.ps1      # Windows client (bundled)
├── autopaqet-server.sh       # Linux server (bundled)
├── autopaqet-uninstall.ps1   # Windows uninstaller
├── autopaqet-uninstall.sh    # Linux uninstaller
├── gates.ps1                 # Quality gates runner
├── build.ps1                 # Build validation script
├── lib/
│   ├── powershell/           # PowerShell modules (for testing)
│   │   ├── AutoPaqet.Validate.ps1
│   │   ├── AutoPaqet.Config.ps1
│   │   ├── AutoPaqet.Menu.ps1
│   │   ├── AutoPaqet.Network.ps1
│   │   ├── AutoPaqet.Install.ps1
│   │   └── AutoPaqet.Logging.ps1
│   └── bash/                 # Bash modules (for testing)
│       ├── validate.sh
│       ├── config.sh
│       ├── menu.sh
│       ├── service.sh
│       └── install.sh
├── tests/
│   ├── powershell/           # Pester tests
│   │   ├── Validate.Tests.ps1
│   │   └── Config.Tests.ps1
│   └── bash/                 # Bats tests
│       └── validate.bats
└── .github/
    └── workflows/
        └── test.yml          # CI workflow
```

### Running Tests

Run all quality gates:
```powershell
.\gates.ps1
```

This executes:
1. PowerShell syntax check (all `.ps1` files)
2. Pester unit tests
3. Bash syntax check (requires Git Bash or WSL)
4. Bats tests (requires WSL with bats-core)
5. Critical files existence check

### Architecture Notes

- **Root scripts** are self-contained "bundled" versions with all functions inline for one-liner use
- **lib/ modules** contain the same functions in modular form for testing
- **Tests** use the lib/ modules via dot-sourcing
- Scripts detect if running interactively (menu mode) or piped (direct install)

---

## License

MIT License - See [paqet](https://github.com/hanselime/paqet) for the main project license.
