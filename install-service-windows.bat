@echo off
REM ============================================================================
REM Poll Master Bot - Windows Service Setup Script
REM ============================================================================
REM This script installs the bot as a Windows Service that runs 24/7
REM Requirements: NSSM (Non-Sucking Service Manager) must be installed
REM Download: https://nssm.cc/download
REM
REM Usage:
REM   1. Download NSSM and extract to a folder (e.g., C:\nssm)
REM   2. Add NSSM to PATH or edit the NSSM_PATH below
REM   3. Run this script as Administrator
REM ============================================================================

setlocal enabledelayedexpansion

REM Configuration
set SERVICE_NAME=PollMasterBot
set SERVICE_DISPLAY_NAME=Poll Master Bot - 24/7 Telegram Bot & API Server
set SCRIPT_PATH=%~dp0start.sh
set BASH_PATH=C:\Program Files\Git\bin\bash.exe
set NSSM_PATH=C:\nssm\nssm.exe
set LOG_DIR=%~dp0logs
set WORKING_DIR=%~dp0

REM Color codes simulation (for later use if needed)
cls
echo.
echo ============================================================================
echo Poll Master Bot - Windows Service Setup
echo ============================================================================
echo.

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] This script must be run as Administrator
    echo Please right-click and select "Run as Administrator"
    pause
    exit /b 1
)

echo [OK] Running as Administrator

REM Check if NSSM exists
if not exist "%NSSM_PATH%" (
    echo.
    echo [ERROR] NSSM not found at: %NSSM_PATH%
    echo.
    echo NSSM Installation Instructions:
    echo 1. Download NSSM from https://nssm.cc/download
    echo 2. Extract to C:\nssm
    echo 3. Add to PATH or edit NSSM_PATH in this script
    pause
    exit /b 1
)

echo [OK] NSSM found at: %NSSM_PATH%

REM Check if Bash is available
if not exist "%BASH_PATH%" (
    echo.
    echo [WARNING] Git Bash not found at: %BASH_PATH%
    echo Attempting to find bash in PATH...
    where bash >nul 2>&1
    if %errorLevel% neq 0 (
        echo [ERROR] Git Bash not found. Please install Git for Windows with bash support
        echo Download: https://git-scm.com/download/win
        pause
        exit /b 1
    )
    echo [OK] Bash found in PATH
) else (
    echo [OK] Git Bash found at: %BASH_PATH%
)

REM Check if service already exists
"%NSSM_PATH%" status "%SERVICE_NAME%" >nul 2>&1
if %errorLevel% equ 0 (
    echo.
    echo [INFO] Service "%SERVICE_NAME%" already exists
    echo Stopping and removing existing service...
    "%NSSM_PATH%" stop "%SERVICE_NAME%" >nul 2>&1
    timeout /t 2 /nobreak >nul
    "%NSSM_PATH%" remove "%SERVICE_NAME%" confirm >nul
    echo [OK] Existing service removed
)

REM Create logs directory
if not exist "%LOG_DIR%" (
    mkdir "%LOG_DIR%"
    echo [OK] Created logs directory: %LOG_DIR%
)

REM Install service
echo.
echo [INFO] Installing service "%SERVICE_NAME%"...
echo.

"%NSSM_PATH%" install "%SERVICE_NAME%" "%BASH_PATH%" -c "cd /d %WORKING_DIR:\=/%  && bash start.sh"

if %errorLevel% neq 0 (
    echo [ERROR] Failed to install service
    pause
    exit /b 1
)

echo [OK] Service installed

REM Configure service settings
echo [INFO] Configuring service settings...

REM Set service to auto-start
"%NSSM_PATH%" set "%SERVICE_NAME%" Start SERVICE_AUTO_START >nul
echo [OK] Service will auto-start on boot

REM Set log files
"%NSSM_PATH%" set "%SERVICE_NAME%" AppStdout "%LOG_DIR%\stdout.log" >nul
"%NSSM_PATH%" set "%SERVICE_NAME%" AppStderr "%LOG_DIR%\stderr.log" >nul
echo [OK] Log files configured: %LOG_DIR%\stdout.log, %LOG_DIR%\stderr.log

REM Set working directory
"%NSSM_PATH%" set "%SERVICE_NAME%" AppDirectory "%WORKING_DIR%" >nul
echo [OK] Working directory: %WORKING_DIR%

REM Set app throttle to restart crashed service quickly
"%NSSM_PATH%" set "%SERVICE_NAME%" AppThrottle 1500 >nul
echo [OK] App throttle enabled (auto-restart on crash)

REM Set to restart on exit
"%NSSM_PATH%" set "%SERVICE_NAME%" AppExit Default Restart >nul
echo [OK] Auto-restart on exit configured

REM Set environment variables (optional)
echo.
echo [INFO] Environment Variables:
echo [INFO] Make sure these are set in your system environment or .env file:
echo   - TELEGRAM_BOT_TOKEN (or BOT_TOKEN)
echo   - POLLING_CHANNEL_ID
echo   - ADMIN_IDS (optional)
echo   - DATABASE_URL (recommended for persistent state)
echo.

REM Start service
echo [INFO] Starting service...
net start "%SERVICE_NAME%"

if %errorLevel% neq 0 (
    echo [ERROR] Failed to start service
    echo Checking service status...
    "%NSSM_PATH%" status "%SERVICE_NAME%"
    pause
    exit /b 1
)

echo.
echo ============================================================================
echo [SUCCESS] Service installed and started!
echo ============================================================================
echo.
echo Service Name: %SERVICE_NAME%
echo Working Directory: %WORKING_DIR%
echo Log Files: %LOG_DIR%
echo.
echo Management Commands:
echo   Start:   net start "%SERVICE_NAME%"
echo   Stop:    net stop "%SERVICE_NAME%"
echo   Status:  "%NSSM_PATH%" status "%SERVICE_NAME%"
echo   Remove:  "%NSSM_PATH%" remove "%SERVICE_NAME%" confirm
echo.
echo Or use Services.msc to manage the service graphically
echo.
echo ============================================================================
echo.

pause
