@echo off
setlocal EnableDelayedExpansion
title Paqet Client Installer
cd /d "%~dp0"

set "SCRIPT_DIR=%~dp0"
set "REQUIREMENTS_DIR=%SCRIPT_DIR%requirements"

:: Ensure requirements directory exists
if not exist "%REQUIREMENTS_DIR%" mkdir "%REQUIREMENTS_DIR%"

:: ============================================================================
:: LOGGING INITIALIZATION
:: ============================================================================
set "LOG_FILE=%REQUIREMENTS_DIR%\install.log"

:: Create/Clear log file
echo ============================================================ > "%LOG_FILE%"
echo PAQET INSTALLER LOG - %DATE% %TIME% >> "%LOG_FILE%"
echo ============================================================ >> "%LOG_FILE%"
echo OS: "%OS%" >> "%LOG_FILE%"
echo User: "%USERNAME%" >> "%LOG_FILE%"
echo Directory: "%CD%" >> "%LOG_FILE%"
echo Path: "%PATH%" >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

:: ============================================================================
:: CONFIGURATION
:: ============================================================================
set "REPO_URL=https://github.com/hanselime/paqet.git"
set "SRC_DIR=%REQUIREMENTS_DIR%\paqet"
set "EXE_PATH=%REQUIREMENTS_DIR%\paqet.exe"
set "CONFIG_FILE=%REQUIREMENTS_DIR%\client.yaml"

:: Download URLs
set "GIT_URL=https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.1/Git-2.47.1-64-bit.exe"
set "GO_URL=https://go.dev/dl/go1.23.4.windows-amd64.msi"
set "GCC_URL=https://github.com/jmeubank/tdm-gcc/releases/download/v10.3.0-tdm64-2/tdm64-gcc-10.3.0-2.exe"
set "NPCAP_URL=https://npcap.com/dist/npcap-1.80.exe"

set "GIT_FILE=Git-2.47.1-64-bit.exe"
set "GO_FILE=go1.23.4.windows-amd64.msi"
set "GCC_FILE=tdm64-gcc-10.3.0-2.exe"
set "NPCAP_FILE=npcap-1.80.exe"

:: Status tracking
set "GIT_STATUS=[  ]"
set "GO_STATUS=[  ]"
set "GCC_STATUS=[  ]"
set "NPCAP_STATUS=[  ]"
set "CLONE_STATUS=[  ]"
set "BUILD_STATUS=[  ]"
set "NETWORK_STATUS=[  ]"
set "CONFIG_STATUS=[  ]"

:: ============================================================================
:: STEP 1: ADMINISTRATOR CHECK
:: ============================================================================
call :log "Checking for administrator privileges..."
net session >nul 2>&1
if !errorLevel! neq 0 (
    call :log_error "Administrator privileges NOT found. Requesting elevation..."
    cls
    echo.
    echo   ========================================================
    echo                 ADMINISTRATOR REQUIRED
    echo   ========================================================
    echo.
    echo   This installer requires Administrator privileges to:
    echo     - Install software system-wide
    echo     - Configure network adapters
    echo     - Capture network packets
    echo.
    echo   Requesting elevation...
    echo.

    :: Create a temporary VBS script to elevate
    echo Set UAC = CreateObject^("Shell.Application"^) > "%TEMP%\elevate.vbs"
    echo UAC.ShellExecute "%~f0", "", "%~dp0", "runas", 1 >> "%TEMP%\elevate.vbs"
    cscript //nologo "%TEMP%\elevate.vbs"
    del "%TEMP%\elevate.vbs"
    exit /B
)
call :log "Administrator privileges confirmed."

:: ============================================================================
:: WELCOME SCREEN
:: ============================================================================
call :show_welcome
echo.
echo   Press any key to start installation...
pause >nul

:: ============================================================================
:: STEP 1: CHECKING SYSTEM
:: ============================================================================
call :log "Step 1: Checking System"
call :show_progress 1 "Checking System"
echo.
echo   [OK] Administrator privileges confirmed
echo   [OK] Requirements directory ready
echo.
timeout /t 1 >nul

:: ============================================================================
:: STEP 2: INSTALLING DEPENDENCIES
:: ============================================================================
call :log "Step 2: Installing Dependencies"
call :show_progress 2 "Installing Dependencies"
echo.

:: --- Check Git ---
call :check_git

:: --- Check Go ---
call :check_go

:: --- Check GCC ---
call :check_gcc

:: --- Check Npcap ---
call :check_npcap

echo.
timeout /t 1 >nul

:: ============================================================================
:: STEP 3: CLONING REPOSITORY
:: ============================================================================
call :log "Step 3: Cloning Repository"
call :show_progress 3 "Cloning Repository"
echo.

:: Verify git is available
call :find_git
if !errorLevel! neq 0 (
    call :log_error "Git not found after dependency check."
    set "CLONE_STATUS=[XX]"
    echo   [XX] Git is not available. Cannot continue.
    echo.
    echo   Please install Git and run this installer again.
    echo.
    echo   A detailed log has been saved to: %LOG_FILE%
    echo.
    echo   Press any key to exit...
    pause >nul
    exit /B 1
)

if not exist "%SRC_DIR%\.git" (
    if exist "%SRC_DIR%" (
        call :log "Found existing directory %SRC_DIR% but no .git folder. Removing and re-cloning..."
        rmdir /s /q "%SRC_DIR%"
    )
    call :log "Cloning Paqet repository from %REPO_URL%..."
    echo   [..] Cloning Paqet repository...
    git config --global --add safe.directory "%SRC_DIR:\=/%" >nul 2>&1
    git clone --depth 1 "%REPO_URL%" "%SRC_DIR%" >> "%LOG_FILE%" 2>&1
    if !errorLevel! neq 0 (
        call :log_error "Failed to clone repository."
        set "CLONE_STATUS=[XX]"
        echo   [XX] Failed to clone repository
        echo.
        echo   A detailed log has been saved to: %LOG_FILE%
        echo.
        echo   Press any key to exit...
        pause >nul
        exit /B 1
    )
    set "CLONE_STATUS=[OK]"
    echo   [OK] Repository cloned successfully
    call :log "Repository cloned successfully."
) else (
    call :log "Updating existing repository in %SRC_DIR%..."
    echo   [..] Updating existing repository...
    git config --global --add safe.directory "%SRC_DIR:\=/%" >nul 2>&1
    pushd "%SRC_DIR%"
    git pull >> "%LOG_FILE%" 2>&1
    popd
    set "CLONE_STATUS=[OK]"
    echo   [OK] Repository updated
    call :log "Repository updated."
)
echo.
timeout /t 1 >nul

:: ============================================================================
:: STEP 4: BUILDING PAQET
:: ============================================================================
call :log "Step 4: Building Paqet"
call :show_progress 4 "Building Paqet"
echo.

:: Verify go is available
call :find_go
if !errorLevel! neq 0 (
    call :log_error "Go not found after dependency check."
    set "BUILD_STATUS=[XX]"
    echo   [XX] Go is not available. Cannot build.
    echo.
    echo   Please install Go and run this installer again.
    echo.
    echo   A detailed log has been saved to: %LOG_FILE%
    echo.
    echo   Press any key to exit...
    pause >nul
    exit /B 1
)

:: Verify gcc is available
call :find_gcc
if !errorLevel! neq 0 (
    call :log_error "GCC not found after dependency check."
    set "BUILD_STATUS=[XX]"
    echo   [XX] GCC is not available. Cannot build with CGO.
    echo.
    echo   Please install TDM-GCC and run this installer again.
    echo.
    echo   A detailed log has been saved to: %LOG_FILE%
    echo.
    echo   Press any key to exit...
    pause >nul
    exit /B 1
)

if not exist "%EXE_PATH%" (
    call :log "Building Paqet binary: %EXE_PATH%"
    echo   [..] Building Paqet binary...
    echo        This may take a few minutes...
    pushd "%SRC_DIR%"
    set "CGO_ENABLED=1"
    call :log "Running: go build -o %EXE_PATH% ./cmd/main.go"
    go build -ldflags "-s -w" -trimpath -o "%EXE_PATH%" ./cmd/main.go >> "%LOG_FILE%" 2>&1
    if !errorLevel! neq 0 (
        popd
        call :log_error "Build failed with errorLevel !errorLevel!."
        set "BUILD_STATUS=[XX]"
        echo   [XX] Build failed
        echo.
        echo   A detailed log has been saved to: %LOG_FILE%
        echo.
        echo   Press any key to exit...
        pause >nul
        exit /B 1
    )
    popd
    set "BUILD_STATUS=[OK]"
    echo   [OK] Build complete: paqet.exe
    call :log "Build complete."
) else (
    set "BUILD_STATUS=[OK]"
    echo   [OK] Binary already exists: paqet.exe
    call :log "Binary already exists, skipping build."
)
echo.
timeout /t 1 >nul

:: ============================================================================
:: STEP 5: DETECTING NETWORK
:: ============================================================================
call :log "Step 5: Detecting Network"
call :show_progress 5 "Detecting Network"
echo.
call :detect_network || (
    call :log_error "Network detection failed."
    echo.
    echo   [XX] Network detection failed.
    echo   [!!] Please ensure you are connected to the internet and have Npcap installed.
    echo.
    echo   A detailed log has been saved to: %LOG_FILE%
    echo.
    echo   Press any key to exit...
    pause >nul
    exit /B 1
)
call :log "Network detected: IF=!NET_INTERFACE!, IP=!LOCAL_IP!, GW_MAC=!GATEWAY_MAC!"
echo.
timeout /t 2 >nul

:: ============================================================================
:: STEP 6: GENERATING CONFIG
:: ============================================================================
call :log "Step 6: Generating Config"
call :show_progress 6 "Generating Config"
echo.

if not exist "%CONFIG_FILE%" (
    call :log "Creating new configuration: %CONFIG_FILE%"
    echo   [..] Creating new configuration...
    echo.
    set /p "SERVER_ADDR=       Enter Server Address [127.0.0.1:9999]: "
    if "!SERVER_ADDR!"=="" set "SERVER_ADDR=127.0.0.1:9999"
    call :log "Server Address: !SERVER_ADDR!"

    set /p "SECRET_KEY=       Enter Secret Key [auto-generate]: "
    if "!SECRET_KEY!"=="" (
        call :log "Auto-generating secret key..."
        echo   [..] Generating secret key...
        if exist "%EXE_PATH%" (
            for /f "usebackq" %%k in (`"%EXE_PATH%" secret`) do set "SECRET_KEY=%%k"
            echo   [OK] Key generated. Update your server with this key!
            call :log "Secret key generated."
        ) else (
            call :log_error "Cannot generate secret key: paqet.exe not found."
            echo   [XX] Cannot generate secret key: paqet.exe not found.
            set "SECRET_KEY=manual-key-required"
        )
    )

    :: Generate random port
    set /a "RANDOM_PORT=10000 + !RANDOM! %% 55000"
    call :log "Local Port: !RANDOM_PORT!"

    :: Create config using PowerShell for proper YAML formatting
    call :log "Writing config file using PowerShell..."
    powershell -NoProfile -Command ^
        "$config = @\"^

role: \"\"client\"\"^

^

log:^

  level: \"\"info\"\"^

^

socks5:^

  - listen: \"\"127.0.0.1:1080\"\"^

^

network:^

  interface: \"\"!NET_INTERFACE!\"\"^

  guid: '!NPCAP_GUID!'^

  ipv4:^

    addr: \"\"!LOCAL_IP!:!RANDOM_PORT!\"\"^

    router_mac: \"\"!GATEWAY_MAC!\"\"^

  tcp:^

    local_flag: [\"\"S\"\"]^

    remote_flag: [\"\"PA\"\"]^

^

server:^

  addr: \"\"!SERVER_ADDR!\"\"^

^

transport:^

  protocol: \"\"kcp\"\"^

  conn: 1^

  kcp:^

    mode: \"\"fast\"\"^

    key: \"\"!SECRET_KEY!\"\"^

    block: \"\"aes\"\"^

\"@; $config | Out-File -FilePath '%CONFIG_FILE%' -Encoding ASCII"

    set "CONFIG_STATUS=[OK]"
    echo.
    echo   [OK] Configuration created: client.yaml
) else (
    set "CONFIG_STATUS=[OK]"
    echo   [OK] Configuration file exists: client.yaml
    echo   [!!] If network changed, delete client.yaml and re-run
)
echo.

:: ============================================================================
:: COMPLETE
:: ============================================================================
call :show_complete
echo.
echo   Installation Summary:
echo   ---------------------
echo   !GIT_STATUS! Git
echo   !GO_STATUS! Go
echo   !GCC_STATUS! GCC (TDM-GCC)
echo   !NPCAP_STATUS! Npcap
echo   !CLONE_STATUS! Repository
echo   !BUILD_STATUS! Build
echo   !NETWORK_STATUS! Network
echo   !CONFIG_STATUS! Configuration
echo.

set /p "LAUNCH=   Start Paqet now? [Y/n]: "
if /i "!LAUNCH!"=="" set "LAUNCH=Y"
if /i "!LAUNCH!"=="Y" (
    echo.
    echo   Starting Paqet...
    echo   -----------------
    "%EXE_PATH%" run -c "%CONFIG_FILE%"
)

echo.
echo   Press any key to exit...
pause >nul
exit /B 0

:: ============================================================================
:: SUBROUTINES
:: ============================================================================

:log
echo [%DATE% %TIME%] %~1 >> "%LOG_FILE%"
goto :eof

:log_error
echo [%DATE% %TIME%] ERROR: %~1 >> "%LOG_FILE%"
goto :eof

:show_welcome
cls
echo.
echo   +============================================================+
echo   ^|                                                            ^|
echo   ^|            PAQET CLIENT INSTALLER (WINDOWS)                ^|
echo   ^|                                                            ^|
echo   +============================================================+
echo   ^|                                                            ^|
echo   ^|   This installer will:                                     ^|
echo   ^|     1. Check and install required software                 ^|
echo   ^|     2. Clone and build the Paqet client                    ^|
echo   ^|     3. Configure network settings automatically            ^|
echo   ^|     4. Generate client configuration                       ^|
echo   ^|                                                            ^|
echo   +============================================================+
goto :eof

:show_progress
:: %1 = step number, %2 = description
set "STEP=%~1"
set "DESC=%~2"
set /a "PERCENT=STEP*100/6"

:: Build progress bar
set "FILLED="
set "EMPTY="
set /a "FILL_COUNT=STEP*5"
set /a "EMPTY_COUNT=30-FILL_COUNT"

for /L %%i in (1,1,!FILL_COUNT!) do set "FILLED=!FILLED!#"
for /L %%i in (1,1,!EMPTY_COUNT!) do set "EMPTY=!EMPTY!-"

cls
echo.
echo   +============================================================+
echo   ^|            PAQET CLIENT INSTALLER (WINDOWS)                ^|
echo   +------------------------------------------------------------+
echo   ^|  Step !STEP! of 6: !DESC!
echo   ^|  [!FILLED!!EMPTY!] !PERCENT!%%
echo   +============================================================+
goto :eof

:show_complete
cls
echo.
echo   +============================================================+
echo   ^|            PAQET CLIENT INSTALLER (WINDOWS)                ^|
echo   +------------------------------------------------------------+
echo   ^|  Step 6 of 6: Complete                                     ^|
echo   ^|  [##############################] 100%%                     ^|
echo   +------------------------------------------------------------+
echo   ^|                                                            ^|
echo   ^|                  INSTALLATION COMPLETE!                    ^|
echo   ^|                                                            ^|
echo   +============================================================+
goto :eof

:download_file
:: %1 = URL, %2 = output path
set "DL_URL=%~1"
set "DL_PATH=%~2"

if exist "%DL_PATH%" (
    call :log "File already exists: %DL_PATH%"
    echo   [OK] !DL_PATH:~-30! already downloaded
    goto :eof
)

call :log "Downloading: %DL_URL% to %DL_PATH%"
echo   [..] Downloading !DL_PATH:~-30!...
powershell -NoProfile -Command ^
    "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; ^
    $ProgressPreference = 'SilentlyContinue'; ^
    try { ^
        Invoke-WebRequest -Uri '%DL_URL%' -OutFile '%DL_PATH%' -UseBasicParsing; ^
        exit 0 ^
    } catch { ^
        Write-Output $_.Exception.Message; ^
        exit 1 ^
    }" >> "%LOG_FILE%" 2>&1

if !errorLevel! neq 0 (
    call :log_error "Download failed: %DL_URL%"
    echo   [XX] Download failed
    exit /B 1
)
call :log "Download complete."
echo   [OK] Download complete
goto :eof

:refresh_path
:: Refresh PATH from registry using PowerShell for expansion
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "$p = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User'); [System.Environment]::ExpandEnvironmentVariables($p)"`) do set "PATH=%%i"
:: Add known paths as fallback
set "PATH=!PATH!;C:\Program Files\Git\cmd;C:\Program Files\Git\bin;C:\Go\bin;C:\TDM-GCC-64\bin;C:\mingw64\bin;%LocalAppData%\Programs\Git\cmd"
goto :eof

:find_git
where.exe git >nul 2>&1 && exit /B 0
if exist "C:\Program Files\Git\cmd\git.exe" (set "PATH=!PATH!;C:\Program Files\Git\cmd" & exit /B 0)
if exist "C:\Program Files\Git\bin\git.exe" (set "PATH=!PATH!;C:\Program Files\Git\bin" & exit /B 0)
if exist "%LocalAppData%\Programs\Git\cmd\git.exe" (set "PATH=!PATH!;%LocalAppData%\Programs\Git\cmd" & exit /B 0)
exit /B 1

:find_go
where.exe go >nul 2>&1 && exit /B 0
if exist "C:\Go\bin\go.exe" (set "PATH=!PATH!;C:\Go\bin" & exit /B 0)
if exist "%ProgramFiles%\Go\bin\go.exe" (set "PATH=!PATH!;%ProgramFiles%\Go\bin" & exit /B 0)
exit /B 1

:find_gcc
where.exe gcc >nul 2>&1 && exit /B 0
if exist "C:\TDM-GCC-64\bin\gcc.exe" (set "PATH=!PATH!;C:\TDM-GCC-64\bin" & exit /B 0)
if exist "C:\mingw64\bin\gcc.exe" (set "PATH=!PATH!;C:\mingw64\bin" & exit /B 0)
exit /B 1

:check_git
call :log "Checking for Git..."
call :find_git && (
    set "GIT_STATUS=[OK]"
    call :log "Git found."
    echo   [OK] Git is already installed
    echo.
    goto :eof
)
call :log "Git NOT found."
set "GIT_STATUS=[!!]"
echo   [!!] Git is not detected in PATH
set /p "INSTALL_GIT=       Install Git? [Y/n]: "
if /i "!INSTALL_GIT!"=="" set "INSTALL_GIT=Y"
if /i not "!INSTALL_GIT!"=="Y" (
    call :log "Git installation skipped by user."
    echo   [--] Git installation skipped
    echo.
    goto :eof
)
call :download_file "%GIT_URL%" "%REQUIREMENTS_DIR%\%GIT_FILE%" || (
    set "GIT_STATUS=[XX]"
    echo   [XX] Failed to download Git
    echo.
    goto :eof
)
call :log "Installing Git silently..."
echo   [..] Installing Git silently...
start /wait "" "%REQUIREMENTS_DIR%\%GIT_FILE%" /VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS >> "%LOG_FILE%" 2>&1
call :refresh_path
call :find_git && (
    call :log "Git installed and detected."
    set "GIT_STATUS=[OK]"
    echo   [OK] Git installed and detected successfully
) || (
    call :log_error "Git installed but not detected in PATH."
    set "GIT_STATUS=[!!]"
    echo   [!!] Git installed but not yet in PATH. May require restart.
)
echo.
goto :eof

:check_go
call :log "Checking for Go..."
call :find_go && (
    call :log "Go found."
    set "GO_STATUS=[OK]"
    echo   [OK] Go is already installed
    echo.
    goto :eof
)
call :log "Go NOT found."
set "GO_STATUS=[!!]"
echo   [!!] Go is not detected in PATH
set /p "INSTALL_GO=       Install Go? [Y/n]: "
if /i "!INSTALL_GO!"=="" set "INSTALL_GO=Y"
if /i not "!INSTALL_GO!"=="Y" (
    call :log "Go installation skipped by user."
    echo   [--] Go installation skipped
    echo.
    goto :eof
)
call :download_file "%GO_URL%" "%REQUIREMENTS_DIR%\%GO_FILE%" || (
    set "GO_STATUS=[XX]"
    echo   [XX] Failed to download Go
    echo.
    goto :eof
)
call :log "Installing Go silently..."
echo   [..] Installing Go silently...
msiexec /i "%REQUIREMENTS_DIR%\%GO_FILE%" /quiet /norestart >> "%LOG_FILE%" 2>&1
call :refresh_path
call :find_go && (
    call :log "Go installed and detected."
    set "GO_STATUS=[OK]"
    echo   [OK] Go installed and detected successfully
) || (
    call :log_error "Go installed but not detected in PATH."
    set "GO_STATUS=[!!]"
    echo   [!!] Go installed but not yet in PATH. May require restart.
)
echo.
goto :eof

:check_gcc
call :log "Checking for GCC..."
call :find_gcc && (
    call :log "GCC found."
    set "GCC_STATUS=[OK]"
    echo   [OK] GCC is already installed
    echo.
    goto :eof
)
call :log "GCC NOT found."
set "GCC_STATUS=[!!]"
echo   [!!] GCC (TDM-GCC) is not detected in PATH
echo        Required for building Paqet with CGO
set /p "INSTALL_GCC=       Install TDM-GCC? [Y/n]: "
if /i "!INSTALL_GCC!"=="" set "INSTALL_GCC=Y"
if /i not "!INSTALL_GCC!"=="Y" (
    call :log "GCC installation skipped by user."
    echo   [--] GCC installation skipped
    echo.
    goto :eof
)
call :download_file "%GCC_URL%" "%REQUIREMENTS_DIR%\%GCC_FILE%" || (
    set "GCC_STATUS=[XX]"
    echo   [XX] Failed to download TDM-GCC
    echo.
    goto :eof
)
call :log "Installing TDM-GCC silently..."
echo   [..] Installing TDM-GCC silently...
start /wait "" "%REQUIREMENTS_DIR%\%GCC_FILE%" /S /D=C:\TDM-GCC-64 >> "%LOG_FILE%" 2>&1
call :refresh_path
call :find_gcc && (
    call :log "GCC installed and detected."
    set "GCC_STATUS=[OK]"
    echo   [OK] GCC installed and detected successfully
) || (
    call :log_error "GCC installed but not detected in PATH."
    set "GCC_STATUS=[!!]"
    echo   [!!] GCC installed but not yet in PATH. May require restart.
)
echo.
goto :eof

:check_npcap
call :log "Checking for Npcap..."
set "NPCAP_FOUND=0"
if exist "%SystemRoot%\System32\Npcap\wpcap.dll" set "NPCAP_FOUND=1"
if exist "%SystemRoot%\SysWOW64\Npcap\wpcap.dll" set "NPCAP_FOUND=1"
if "!NPCAP_FOUND!"=="1" (
    call :log "Npcap found."
    set "NPCAP_STATUS=[OK]"
    echo   [OK] Npcap is already installed
    echo.
    goto :eof
)
call :log "Npcap NOT found."
set "NPCAP_STATUS=[!!]"
echo   [!!] Npcap is not installed
echo        Required for packet capture
set /p "INSTALL_NPCAP=       Install Npcap? [Y/n]: "
if /i "!INSTALL_NPCAP!"=="" set "INSTALL_NPCAP=Y"
if /i not "!INSTALL_NPCAP!"=="Y" (
    call :log "Npcap installation skipped by user."
    echo   [--] Npcap installation skipped
    echo.
    goto :eof
)
call :download_file "%NPCAP_URL%" "%REQUIREMENTS_DIR%\%NPCAP_FILE%" || (
    set "NPCAP_STATUS=[XX]"
    echo   [XX] Failed to download Npcap
    echo.
    goto :eof
)
echo.
echo   +-----------------------------------------------------+
echo   ^|  IMPORTANT: Npcap Installation                      ^|
echo   ^|                                                     ^|
echo   ^|  Please CHECK this option during installation:      ^|
echo   ^|  [X] Install Npcap in WinPcap API-compatible Mode   ^|
echo   +-----------------------------------------------------+
echo.
echo   Press any key to launch Npcap installer...
pause >nul
call :log "Launching Npcap installer..."
start /wait "" "%REQUIREMENTS_DIR%\%NPCAP_FILE%"
set "NPCAP_STATUS=[OK]"
echo   [OK] Npcap installation completed
call :log "Npcap installation complete."
echo.
goto :eof

:detect_network
call :log "Analyzing network configuration..."
echo   [..] Analyzing network configuration...

:: Get network info using PowerShell
for /f "usebackq tokens=1,2 delims=|" %%a in (`powershell -NoProfile -Command "$route = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -AddressFamily IPv4 -ErrorAction SilentlyContinue | Sort-Object RouteMetric | Select-Object -First 1; if ($route) { Write-Output \"$($route.InterfaceIndex)|$($route.NextHop)\" } else { Write-Output '|' }"`) do (
    set "IF_INDEX=%%a"
    set "GATEWAY_IP=%%b"
)
call :log "IF_INDEX=!IF_INDEX!, GATEWAY_IP=!GATEWAY_IP!"

if "!IF_INDEX!"=="" (
    call :log_error "No active internet connection detected (no default route)."
    set "NETWORK_STATUS=[XX]"
    echo   [XX] No active internet connection detected
    echo.
    echo   A detailed log has been saved to: %LOG_FILE%
    echo.
    echo   Press any key to exit...
    pause >nul
    exit /B 1
)

:: Get adapter name and GUID
for /f "usebackq tokens=1,2 delims=|" %%a in (`powershell -NoProfile -Command "$adapter = Get-NetAdapter -InterfaceIndex !IF_INDEX! -ErrorAction SilentlyContinue; if ($adapter) { Write-Output \"$($adapter.Name)|$($adapter.InterfaceGuid)\" } else { Write-Output '|' }"`) do (
    set "NET_INTERFACE=%%a"
    set "NET_GUID=%%b"
)
call :log "NET_INTERFACE=!NET_INTERFACE!, NET_GUID=!NET_GUID!"

:: Get local IP
for /f "usebackq" %%a in (`powershell -NoProfile -Command "$ip = Get-NetIPAddress -InterfaceIndex !IF_INDEX! -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1; if ($ip) { Write-Output $ip.IPAddress }"`) do (
    set "LOCAL_IP=%%a"
)
call :log "LOCAL_IP=!LOCAL_IP!"

:: Ping gateway to populate ARP cache
call :log "Pinging gateway !GATEWAY_IP! to populate ARP..."
ping -n 1 !GATEWAY_IP! >nul 2>&1

:: Get gateway MAC
for /f "usebackq" %%a in (`powershell -NoProfile -Command "$arp = Get-NetNeighbor -IPAddress '!GATEWAY_IP!' -AddressFamily IPv4 -ErrorAction SilentlyContinue; if ($arp) { Write-Output $arp.LinkLayerAddress }"`) do (
    set "GATEWAY_MAC=%%a"
)
call :log "GATEWAY_MAC=!GATEWAY_MAC!"

if "!GATEWAY_MAC!"=="" (
    call :log_error "Could not detect Gateway MAC address."
    set "NETWORK_STATUS=[XX]"
    echo   [XX] Could not detect Gateway MAC address
    echo.
    echo   A detailed log has been saved to: %LOG_FILE%
    echo.
    echo   Press any key to exit...
    pause >nul
    exit /B 1
)

set "NPCAP_GUID=\Device\NPF_!NET_GUID!"
call :log "NPCAP_GUID=!NPCAP_GUID!"

set "NETWORK_STATUS=[OK]"
echo   [OK] Network configuration detected:
echo.
echo        Interface:   !NET_INTERFACE!
echo        Local IP:    !LOCAL_IP!
echo        Gateway IP:  !GATEWAY_IP!
echo        Gateway MAC: !GATEWAY_MAC!
exit /B 0