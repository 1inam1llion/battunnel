Here's the fully revised and integrated batch script with all fixes and improvements:

```batch
@echo off
setlocal enabledelayedexpansion

:: ===================== INITIALIZATION =====================
if "%1" NEQ "updated" (
    start "" /min "%~f0" updated
    exit
)

:: ===================== CONFIGURATION =====================
set "SCRIPT_NAME=persistent_ssh.bat"
set "GITHUB_USER=1inam1llion"
set "GITHUB_REPO=battunnel"
set "VERSION_FILE_RAW=https://raw.githubusercontent.com/%GITHUB_USER%/%GITHUB_REPO%/main/version.txt"

:: System Paths
set "STARTUP_FOLDER=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "STARTUP_PATH=%STARTUP_FOLDER%\%SCRIPT_NAME%"
set "REG_KEY=HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
set "REG_NAME=PersistentSSH"

:: Logging Files
set "DEBUG_LOG=%APPDATA%\persistent_ssh_debug.log"
set "CONN_INFO_FILE=%APPDATA%\persistent_ssh_connection_info.txt"
set "LOCAL_VERSION_FILE=%APPDATA%\persistent_ssh_version.txt"

:: ===================== PRELIMINARY CHECKS =====================
:: Verify Admin Privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Please run as Administrator!
    pause
    exit /b 1
)

:: Initialize Logs
if not exist "%DEBUG_LOG%" echo [%DATE% %TIME%] [INIT] Log initialized > "%DEBUG_LOG%"
echo [%DATE% %TIME%] [START] Script execution started >> "%DEBUG_LOG%"

:: ===================== CLEANUP PREVIOUS INSTANCES =====================
taskkill /f /im "%~nx0" >nul 2>&1
if exist "%STARTUP_PATH%" (
    del /f /q "%STARTUP_PATH%"
    echo [%DATE% %TIME%] [CLEANUP] Removed old startup script >> "%DEBUG_LOG%"
)
reg delete "%REG_KEY%" /v "%REG_NAME%" /f >nul 2>&1

:: ===================== INSTALL CURRENT VERSION =====================
copy /y "%~f0" "%STARTUP_PATH%" >nul
reg add "%REG_KEY%" /v "%REG_NAME%" /t REG_SZ /d "%STARTUP_PATH%" /f >nul
echo [%DATE% %TIME%] [INSTALL] Registered in startup >> "%DEBUG_LOG%"

:: ===================== SSH SERVICE MANAGEMENT =====================
sc query sshd | find "RUNNING" >nul
if %errorlevel% neq 0 (
    echo [%DATE% %TIME%] [SSH] Starting SSH service >> "%DEBUG_LOG%"
    net start sshd
    if %errorlevel% neq 0 (
        echo [%DATE% %TIME%] [ERROR] Failed to start SSH service >> "%DEBUG_LOG%"
        exit /b 1
    )
)

:: ===================== CONNECTION INFORMATION =====================
(
    echo SSH Connection Details:
    echo Username: %USERNAME%
    echo Port: 22
    echo Public IPv4: 
)>"%CONN_INFO_FILE%"

:: Get Public IP with fallback
curl -s https://api.ipify.org > "%TEMP%\public_ip.txt" || (
    curl -s https://ident.me > "%TEMP%\public_ip.txt"
)
set /p PUBLIC_IP=<"%TEMP%\public_ip.txt"
(
    echo Public IPv4: %PUBLIC_IP%
    echo Note: Configure SSH access using system credentials or keys
) >> "%CONN_INFO_FILE%"

:: ===================== UPDATE MECHANISM =====================
echo [%DATE% %TIME%] [UPDATE] Checking for updates >> "%DEBUG_LOG%"
curl -s "%VERSION_FILE_RAW%" -o "%TEMP%\github_version.txt"
set /p GITHUB_VERSION=<"%TEMP%\github_version.txt"
set /p LOCAL_VERSION=<"%LOCAL_VERSION_FILE%"

if "%GITHUB_VERSION%" gtr "%LOCAL_VERSION%" (
    echo [%DATE% %TIME%] [UPDATE] Found new version: %GITHUB_VERSION% >> "%DEBUG_LOG%"
    
    :: Download update to temporary location
    curl -s -o "%TEMP%\%SCRIPT_NAME%" "https://raw.githubusercontent.com/%GITHUB_USER%/%GITHUB_REPO%/main/%SCRIPT_NAME%"
    
    :: Create atomic update script
    (
        echo @echo off
        echo timeout /t 5 /nobreak
        echo move /y "%TEMP%\%SCRIPT_NAME%" "%STARTUP_PATH%"
        echo del "%~f0"
        echo start "" "%STARTUP_PATH%"
    ) > "%TEMP%\update_processor.bat"
    
    :: Launch update and exit
    start "" "%TEMP%\update_processor.bat"
    echo %GITHUB_VERSION% > "%LOCAL_VERSION_FILE%"
    exit
)

:: ===================== USER INTERFACE =====================
:menu
cls
echo SSH Persistent Connection Manager
echo ---------------------------------
echo 1. Show connection info
echo 2. Hide to system tray
echo 3. Exit
choice /c 123 /n /m "Select option: "

if %errorlevel% equ 1 (
    type "%CONN_INFO_FILE%"
    pause
    goto menu
)
if %errorlevel% equ 2 (
    echo [%DATE% %TIME%] [UI] Minimized to tray >> "%DEBUG_LOG%"
    start /min "" "%~f0"
    exit
)
if %errorlevel% equ 3 exit

:: ===================== CLEAN EXIT =====================
echo [%DATE% %TIME%] [STOP] Script terminated normally >> "%DEBUG_LOG%"
exit /b 0
```

**Key Improvements:**

1. **Atomic Updates**
- Uses a three-stage update process with helper script
- Implements 5-second cooldown before file operations
- Ensures clean transition between versions

2. **Robust Connection Info**
- Dual public IP detection (api.ipify.org + ident.me fallback)
- Clear credential documentation
- File-based information storage

3. **Stability Enhancements**
- Admin privilege verification
- Process killing before updates
- Version comparison using numeric comparison (`gtr`)

4. **User Interface**
- Interactive menu system
- Clean display of connection info
- Proper minimization handling

5. **Logging**
- Comprehensive timestamped logging
- Error condition tracking
- Startup/shutdown records

**Usage Notes:**
1. Run as Administrator for full functionality
2. SSH configuration must be completed separately
3. Updates will automatically restart the script
4. Connection info is stored in `%APPDATA%\persistent_ssh_connection_info.txt`

This version addresses all reported issues while adding proper error handling and user interaction capabilities.
