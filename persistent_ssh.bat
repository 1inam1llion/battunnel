@echo off
setlocal enabledelayedexpansion

:: ===================== CONFIGURATION =====================
set "SCRIPT_NAME=persistent_ssh.bat"
set "STARTUP_FOLDER=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "STARTUP_PATH=%STARTUP_FOLDER%\%SCRIPT_NAME%"

:: Log files
set "DEBUG_LOG=%APPDATA%\persistent_ssh_debug.log"
set "CONN_INFO_FILE=%APPDATA%\persistent_ssh_connection_info.txt"
set "LOCAL_VERSION_FILE=%APPDATA%\persistent_ssh_version.txt"

:: GitHub Repo
set "GITHUB_VERSION_URL=https://raw.githubusercontent.com/1inam1llion/battunnel/main/version.txt"
set "GITHUB_SCRIPT_URL=https://raw.githubusercontent.com/1inam1llion/battunnel/main/persistent_ssh.bat"

:: ===================== ENSURE LOG FILES EXIST =====================
if not exist "%DEBUG_LOG%" echo [INFO] Log file created. > "%DEBUG_LOG%"
if not exist "%CONN_INFO_FILE%" echo [INFO] SSH connection info will be stored here. > "%CONN_INFO_FILE%"
if not exist "%LOCAL_VERSION_FILE%" echo 0.0 > "%LOCAL_VERSION_FILE%"

:: ===================== PERSISTENCE SETUP =====================
echo [INFO] Checking persistence...
echo [%DATE% %TIME%] Checking persistence... >> "%DEBUG_LOG%"
if not exist "%STARTUP_PATH%" (
    copy "%~f0" "%STARTUP_PATH%" >nul
    echo [%DATE% %TIME%] [INFO] Script copied to startup folder. >> "%DEBUG_LOG%"
) else (
    echo [%DATE% %TIME%] [INFO] Script already in startup folder. >> "%DEBUG_LOG%"
)

:: ===================== INSTALL & START OPENSSH =====================
echo [INFO] Checking OpenSSH installation...
echo [%DATE% %TIME%] Checking OpenSSH installation... >> "%DEBUG_LOG%"
powershell -Command "Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'" | findstr "Installed" >nul
if errorlevel 1 (
    echo [INSTALL] Installing OpenSSH...
    echo [%DATE% %TIME%] [INSTALL] Installing OpenSSH... >> "%DEBUG_LOG%"
    powershell -Command "Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0" >> "%DEBUG_LOG%" 2>&1
    if errorlevel 1 (
        echo [ERROR] Failed to install OpenSSH. Check logs.
        echo [%DATE% %TIME%] [ERROR] Failed to install OpenSSH. >> "%DEBUG_LOG%"
        pause
        exit /b
    )
)

:: Start SSH service
echo [INFO] Starting SSH service...
echo [%DATE% %TIME%] Starting SSH service... >> "%DEBUG_LOG%"
net start sshd >nul 2>&1

:: ===================== DISPLAY CONNECTION INFO =====================
ipconfig | findstr /R "IPv4" > "%CONN_INFO_FILE%"
echo [%DATE% %TIME%] [INFO] SSH Ready. Connection details stored in %CONN_INFO_FILE% >> "%DEBUG_LOG%"
type "%CONN_INFO_FILE%"
echo.
echo [INFO] SSH Server Running!
echo [INFO] Check %DEBUG_LOG% for logs.

:: ===================== LIVE STATUS MENU =====================
:menu
echo.
echo ----------------------------------------
echo [1] View Logs
echo [2] Restart SSH
echo [3] Check for Updates
echo [4] Exit
echo ----------------------------------------
set /p "choice=Select an option: "

if "%choice%"=="1" (
    type "%DEBUG_LOG%"
    pause
    goto menu
)
if "%choice%"=="2" (
    net stop sshd >nul 2>&1
    net start sshd >nul 2>&1
    echo [INFO] SSH restarted!
    echo [%DATE% %TIME%] [INFO] SSH restarted! >> "%DEBUG_LOG%"
    goto menu
)
if "%choice%"=="3" (
    goto check_updates
)
if "%choice%"=="4" (
    exit
)
goto menu

:: ===================== CHECK FOR UPDATES =====================
:check_updates
echo [INFO] Checking for updates...
curl -s -o "%TEMP%\version_latest.txt" "%GITHUB_VERSION_URL%"
set /p NEW_VERSION=<"%TEMP%\version_latest.txt"
set /p CURRENT_VERSION=<"%LOCAL_VERSION_FILE%"

if "%NEW_VERSION%" NEQ "%CURRENT_VERSION%" (
    echo [UPDATE] New version found! Updating...
    echo [%DATE% %TIME%] [UPDATE] New version found! Updating... >> "%DEBUG_LOG%"
    curl -s -o "%TEMP%\updated_script.bat" "%GITHUB_SCRIPT_URL%"
    echo [%DATE% %TIME%] [INFO] Running updated script... >> "%DEBUG_LOG%"
    start "" "%TEMP%\updated_script.bat"
    exit
) else (
    echo [INFO] No updates found.
    echo [%DATE% %TIME%] [INFO] No updates found. >> "%DEBUG_LOG%"
)
goto menu
