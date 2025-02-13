@echo off
setlocal enabledelayedexpansion

:: ----- INITIALIZATION ----- to view your debug log please refer below.
set "SCRIPT_NAME=%~nx0"
set "STARTUP_PATH=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\%SCRIPT_NAME%"
set "DEBUG_LOG=%APPDATA%\ssh_setup.log"
set "CONNECTION_INFO=%APPDATA%\ssh_connection.txt"

:: Elevate to admin if not already
if not "%1"=="admin" (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c %~0 admin' -Verb RunAs"
    exit
)

:: ----- LOGGING SETUP -----
echo [%DATE% %TIME%] Starting SSH setup > "%DEBUG_LOG%"

:: ----- OPENSSH INSTALLATION -----
echo Checking OpenSSH Server installation...
echo [%DATE% %TIME%] Checking OpenSSH installation >> "%DEBUG_LOG%"

powershell -Command "Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0" 2>&1 >> "%DEBUG_LOG%"
if %errorlevel% neq 0 (
    echo [ERROR] Failed to install OpenSSH Server. Check %DEBUG_LOG%
    exit /b 1
)

:: ----- SERVICE CONFIGURATION -----
echo Configuring SSH services...
echo [%DATE% %TIME%] Configuring services >> "%DEBUG_LOG%"

sc config sshd start= auto >> "%DEBUG_LOG%" 2>&1
sc config ssh-agent start= auto >> "%DEBUG_LOG%" 2>&1
net start sshd >> "%DEBUG_LOG%" 2>&1

if %errorlevel% neq 0 (
    echo [ERROR] Failed to start SSH service. Check %DEBUG_LOG%
    exit /b 1
)

:: ----- FIREWALL CONFIGURATION -----
echo Configuring firewall rules...
echo [%DATE% %TIME%] Configuring firewall >> "%DEBUG_LOG%"

netsh advfirewall firewall show rule name="SSHD" | find "SSHD" >nul
if %errorlevel% neq 0 (
    netsh advfirewall firewall add rule name="SSHD" dir=in action=allow protocol=TCP localport=22 >> "%DEBUG_LOG%" 2>&1
)

:: ----- PERSISTENCE MECHANISM -----
echo Setting up persistence...
echo [%DATE% %TIME%] Setting up persistence >> "%DEBUG_LOG%"

if not exist "%STARTUP_PATH%" (
    copy /y "%~f0" "%STARTUP_PATH%" >> "%DEBUG_LOG%" 2>&1
    reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Run /v PersistentSSH /t REG_SZ /d "%STARTUP_PATH%" /f >> "%DEBUG_LOG%" 2>&1
)

:: ----- CONNECTION INFORMATION -----
echo Gathering connection details...
echo [%DATE% %TIME%] Gathering connection info >> "%DEBUG_LOG%"

(
    echo SSH Connection Details:
    echo Username: %USERNAME%
    echo Port: 22
) > "%CONNECTION_INFO%"

:: Get public IP with fallback
curl -s https://api.ipify.org > "%TEMP%\public_ip.txt" 2>> "%DEBUG_LOG%"
if %errorlevel% neq 0 (
    curl -s https://ident.me > "%TEMP%\public_ip.txt" 2>> "%DEBUG_LOG%"
)
set /p PUBLIC_IP=<"%TEMP%\public_ip.txt"

(
    echo Public IP: %PUBLIC_IP%
    echo Authentication: Use your Windows account password
    echo Note: Ensure remote connections are allowed in system settings
) >> "%CONNECTION_INFO%"

:: ----- FINAL OUTPUT -----
echo.
echo ===== SSH SETUP COMPLETE =====
type "%CONNECTION_INFO%"
echo ==============================
echo.
echo This script will automatically maintain SSH access after reboots
echo Connection info saved to: %CONNECTION_INFO%
echo.

:: Keep window open
pause
