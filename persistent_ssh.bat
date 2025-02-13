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

:: GitHub Repo (Replace if needed)
set "GITHUB_VERSION_URL=https://raw.githubusercontent.com/1inam1llion/battunnel/main/version.txt"
set "GITHUB_SCRIPT_URL=https://raw.githubusercontent.com/1inam1llion/battunnel/main/persistent_ssh.bat"

:: Ensure log files exist
if not exist "%DEBUG_LOG%" echo [INFO] Log file created. > "%DEBUG_LOG%"
if not exist "%CONN_INFO_FILE%" echo [INFO] SSH connection info will be stored here. > "%CONN_INFO_FILE%"
if not exist "%LOCAL_VERSION_FILE%" echo 0.0 > "%LOCAL_VERSION_FILE%"

:: ===================== PERSISTENCE SETUP =====================
echo [INFO] Checking persistence... >> "%DEBUG_LOG%"
if not exist "%STARTUP_PATH%" (
    copy "%~f0" "%STARTUP_PATH%" >nul
    echo [INFO] Script copied to startup folder: %STARTUP_PATH% >> "%DEBUG_LOG%"
) else (
    echo [INFO] Script already in startup folder. >> "%DEBUG_LOG%"
)

:: ===================== INSTALL & START OPENSSH =====================
echo [INFO] Checking OpenSSH installation... >> "%DEBUG_LOG%"
powershell -Command "Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'" | findstr "Installed" >nul
if errorlevel 1 (
    echo [INSTALL] Installing OpenSSH... >> "%DEBUG_LOG%"
    powershell -Command "Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0" >> "%DEBUG_LOG%" 2>&1
    if errorlevel 1 (
        echo [ERROR] Failed to install OpenSSH. Check logs. >> "%DEBUG_LOG%"
        echo [ERROR] Failed to install OpenSSH. See %DEBUG_LOG%
        pause
        exit /b
    )
) else (
    echo [INFO] OpenSSH already installed. >> "%DEBUG_LOG%"
)

:: Start the OpenSSH service
echo [INFO] Ensuring SSH service is running... >> "%DEBUG_LOG%"
sc query sshd | findstr /i "RUNNING" >nul
if errorlevel 1 (
    echo [INFO] Starting SSH service... >> "%DEBUG_LOG%"
    net start sshd >> "%DEBUG_LOG%" 2>&1
    if errorlevel 1 (
        echo [ERROR] SSH service failed to start. Check logs. >> "%DEBUG_LOG%"
        echo [ERROR] SSH service failed to start. See %DEBUG_LOG%
        pause
        exit /b
    )
) else (
    echo [INFO] SSH service is already running. >> "%DEBUG_LOG%"
)

:: ===================== FIREWALL RULES =====================
echo [INFO] Configuring firewall rules for SSH... >> "%DEBUG_LOG%"
netsh advfirewall firewall add rule name="OpenSSH" dir=in action=allow protocol=TCP localport=22 >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Failed to configure firewall for SSH. >> "%DEBUG_LOG%"
    echo [ERROR] Firewall setup failed! Check logs at %DEBUG_LOG%
    pause
    exit /b
) else (
    echo [INFO] Firewall rule added for SSH. >> "%DEBUG_LOG%"
)

:: ===================== FETCH PUBLIC IP & SSH DETAILS =====================
echo [INFO] Fetching SSH connection details... >> "%DEBUG_LOG%"
for /f "tokens=2 delims=: " %%I in ('ipconfig ^| findstr /C:"IPv4 Address"') do set "LOCAL_IP=%%I"
echo [INFO] Local SSH: ssh username@%LOCAL_IP% >> "%CONN_INFO_FILE%"

:: Fetch external IP
powershell -Command "(Invoke-WebRequest -Uri 'http://ifconfig.me/ip').Content" > "%TEMP%\external_ip.txt" 2>nul
if exist "%TEMP%\external_ip.txt" (
    set /p PUBLIC_IP=<"%TEMP%\external_ip.txt"
    echo [INFO] External SSH: ssh username@%PUBLIC_IP% >> "%CONN_INFO_FILE%"
    echo [INFO] Public SSH IP fetched successfully. >> "%DEBUG_LOG%"
) else (
    echo [WARNING] Could not fetch public IP. >> "%DEBUG_LOG%"
    echo [WARNING] External SSH may not work.
)

:: ===================== UPDATES FROM GITHUB =====================
echo [INFO] Checking for script updates... >> "%DEBUG_LOG%"
curl -s "%GITHUB_VERSION_URL%" -o "%TEMP%\latest_version.txt"
if exist "%TEMP%\latest_version.txt" (
    set /p LATEST_VERSION=<"%TEMP%\latest_version.txt"
    set /p CURRENT_VERSION=<"%LOCAL_VERSION_FILE%"

    if not "%LATEST_VERSION%"=="%CURRENT_VERSION%" (
        echo [UPDATE] New version found: %LATEST_VERSION%. Updating... >> "%DEBUG_LOG%"
        echo [INFO] Fetching updated script... >> "%DEBUG_LOG%"
        curl -s "%GITHUB_SCRIPT_URL%" -o "%TEMP%\persistent_ssh_update.bat"

        if exist "%TEMP%\persistent_ssh_update.bat" (
            echo [INFO] Update downloaded. Applying now... >> "%DEBUG_LOG%"
            move /y "%TEMP%\persistent_ssh_update.bat" "%STARTUP_FOLDER%\persistent_ssh_%LATEST_VERSION%.bat" >nul
            echo %LATEST_VERSION% > "%LOCAL_VERSION_FILE%"
            start "" "%STARTUP_FOLDER%\persistent_ssh_%LATEST_VERSION%.bat"
            echo [INFO] Update successful. Restarting script... >> "%DEBUG_LOG%"
            exit /b
        ) else (
            echo [ERROR] Failed to download update. Check logs. >> "%DEBUG_LOG%"
        )
    ) else (
        echo [INFO] Already running latest version (%CURRENT_VERSION%). >> "%DEBUG_LOG%"
    )
) else (
    echo [ERROR] Could not check for updates. Skipping... >> "%DEBUG_LOG%"
)

:: ===================== FINAL MESSAGE =====================
echo [SUCCESS] SSH service is active! >> "%DEBUG_LOG%"
echo [INFO] Connection details saved to: %CONN_INFO_FILE%
echo [INFO] Debug log available at: %DEBUG_LOG%
echo [INFO] To hide this script in the future, use `attrib +h %~f0`
pause
exit /b
