# ============================================================================
# Poll Master Bot - Windows Service Setup (PowerShell)
# ============================================================================
# This script installs the bot as a Windows Service that runs 24/7
# Requirements: NSSM (Non-Sucking Service Manager) must be installed
# Download: https://nssm.cc/download
#
# Usage:
#   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
#   .\install-service-windows.ps1
# ============================================================================

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("install", "remove", "start", "stop", "status", "restart")]
    [string]$Action = "install",
    
    [Parameter(Mandatory = $false)]
    [string]$ServiceName = "PollMasterBot",
    
    [Parameter(Mandatory = $false)]
    [string]$NssmPath = "C:\nssm\nssm.exe"
)

# Configuration
$ServiceDisplayName = "Poll Master Bot - 24/7 Telegram Bot & API Server"
$BashPath = "C:\Program Files\Git\bin\bash.exe"
$WorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$LogDir = Join-Path $WorkingDir "logs"
$ScriptPath = Join-Path $WorkingDir "start.sh"

# Helper functions
function Write-ColorOutput {
    param (
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Type = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    switch ($Type) {
        "Success" { Write-Host "[$timestamp] SUCCESS: $Message" -ForegroundColor Green }
        "Warning" { Write-Host "[$timestamp] WARNING: $Message" -ForegroundColor Yellow }
        "Error" { Write-Host "[$timestamp] ERROR: $Message" -ForegroundColor Red }
        default { Write-Host "[$timestamp] $Message" -ForegroundColor Cyan }
    }
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Main execution
Clear-Host
Write-ColorOutput "Poll Master Bot - Windows Service Setup (PowerShell)"
Write-ColorOutput "========================================================"

# Check if running as administrator
if (-not (Test-Administrator)) {
    Write-ColorOutput "This script must be run as Administrator" "Error"
    Write-ColorOutput "Please run PowerShell as Administrator and try again" "Error"
    exit 1
}

Write-ColorOutput "Running as Administrator" "Success"

# Check if NSSM exists
if (-not (Test-Path $NssmPath)) {
    Write-ColorOutput "NSSM not found at: $NssmPath" "Error"
    Write-ColorOutput ""
    Write-ColorOutput "NSSM Installation Instructions:" "Warning"
    Write-ColorOutput "1. Download NSSM from https://nssm.cc/download"
    Write-ColorOutput "2. Extract to C:\nssm"
    Write-ColorOutput "3. Or modify -NssmPath parameter"
    exit 1
}

Write-ColorOutput "NSSM found at: $NssmPath" "Success"

# Check if Bash is available
if (-not (Test-Path $BashPath)) {
    Write-ColorOutput "Git Bash not found at: $BashPath" "Warning"
    Write-ColorOutput "Attempting to find bash in PATH..."
    
    $bashCmd = Get-Command bash -ErrorAction SilentlyContinue
    if (-not $bashCmd) {
        Write-ColorOutput "Git Bash not found" "Error"
        Write-ColorOutput "Please install Git for Windows with bash support"
        Write-ColorOutput "Download: https://git-scm.com/download/win"
        exit 1
    }
    
    $BashPath = $bashCmd.Source
    Write-ColorOutput "Bash found at: $BashPath" "Success"
}
else {
    Write-ColorOutput "Git Bash found at: $BashPath" "Success"
}

# Execute action
Write-ColorOutput ""
Write-ColorOutput "Action: $Action"

switch ($Action) {
    "install" {
        Write-ColorOutput "Installing service: $ServiceName"
        
        # Check if service already exists
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($service) {
            Write-ColorOutput "Service $ServiceName already exists, removing it first" "Warning"
            & $NssmPath stop $ServiceName 2>&1 | Out-Null
            Start-Sleep -Seconds 2
            & $NssmPath remove $ServiceName confirm 2>&1 | Out-Null
            Write-ColorOutput "Existing service removed" "Success"
        }
        
        # Create logs directory
        if (-not (Test-Path $LogDir)) {
            New-Item -ItemType Directory -Path $LogDir | Out-Null
            Write-ColorOutput "Created logs directory: $LogDir" "Success"
        }
        
        # Install service
        $installCmd = @(
            "install",
            $ServiceName,
            $BashPath,
            "-c",
            "cd /d $($WorkingDir.Replace('\', '/')) && bash start.sh"
        )
        
        & $NssmPath $installCmd 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "Service installed successfully" "Success"
        }
        else {
            Write-ColorOutput "Failed to install service" "Error"
            exit 1
        }
        
        # Configure service
        Write-ColorOutput "Configuring service settings..."
        
        & $NssmPath set $ServiceName Start SERVICE_AUTO_START 2>&1 | Out-Null
        Write-ColorOutput "Auto-start on boot: enabled" "Success"
        
        & $NssmPath set $ServiceName AppDirectory $WorkingDir 2>&1 | Out-Null
        Write-ColorOutput "Working directory: $WorkingDir" "Success"
        
        & $NssmPath set $ServiceName AppStdout (Join-Path $LogDir "stdout.log") 2>&1 | Out-Null
        Write-ColorOutput "Stdout log: $(Join-Path $LogDir 'stdout.log')" "Success"
        
        & $NssmPath set $ServiceName AppStderr (Join-Path $LogDir "stderr.log") 2>&1 | Out-Null
        Write-ColorOutput "Stderr log: $(Join-Path $LogDir 'stderr.log')" "Success"
        
        & $NssmPath set $ServiceName AppThrottle 1500 2>&1 | Out-Null
        Write-ColorOutput "App throttle: 1500ms" "Success"
        
        & $NssmPath set $ServiceName AppExit Default Restart 2>&1 | Out-Null
        Write-ColorOutput "Auto-restart on exit: enabled" "Success"
        
        # Start service
        Write-ColorOutput ""
        Write-ColorOutput "Starting service..."
        Start-Service -Name $ServiceName -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($service.Status -eq "Running") {
            Write-ColorOutput "Service is running" "Success"
        }
        else {
            Write-ColorOutput "Service failed to start. Check logs:" "Error"
            Write-ColorOutput "  - $(Join-Path $LogDir 'stderr.log')"
            Write-ColorOutput "  - $(Join-Path $LogDir 'stdout.log')"
        }
        
        Write-ColorOutput ""
        Write-ColorOutput "========================================================"
        Write-ColorOutput "Service installation complete!" "Success"
        Write-ColorOutput "========================================================"
        Write-ColorOutput ""
        Write-ColorOutput "Service Name: $ServiceName"
        Write-ColorOutput "Working Directory: $WorkingDir"
        Write-ColorOutput "Log Files: $LogDir"
        Write-ColorOutput ""
        Write-ColorOutput "Management:"
        Write-ColorOutput "  Start:   Start-Service -Name '$ServiceName'"
        Write-ColorOutput "  Stop:    Stop-Service -Name '$ServiceName'"
        Write-ColorOutput "  Restart: Restart-Service -Name '$ServiceName'"
        Write-ColorOutput "  Status:  Get-Service -Name '$ServiceName'"
        Write-ColorOutput "  Remove:  & '$NssmPath' remove '$ServiceName' confirm"
        Write-ColorOutput ""
        Write-ColorOutput "Or use Services.msc for GUI management"
        Write-ColorOutput ""
    }
    
    "remove" {
        Write-ColorOutput "Removing service: $ServiceName"
        & $NssmPath stop $ServiceName 2>&1 | Out-Null
        Start-Sleep -Seconds 2
        & $NssmPath remove $ServiceName confirm 2>&1 | Out-Null
        Write-ColorOutput "Service removed" "Success"
    }
    
    "start" {
        Write-ColorOutput "Starting service: $ServiceName"
        Start-Service -Name $ServiceName
        Start-Sleep -Seconds 1
        Get-Service -Name $ServiceName
    }
    
    "stop" {
        Write-ColorOutput "Stopping service: $ServiceName"
        Stop-Service -Name $ServiceName
        Start-Sleep -Seconds 1
        Get-Service -Name $ServiceName
    }
    
    "restart" {
        Write-ColorOutput "Restarting service: $ServiceName"
        Restart-Service -Name $ServiceName
        Start-Sleep -Seconds 2
        Get-Service -Name $ServiceName
    }
    
    "status" {
        Write-ColorOutput "Service status: $ServiceName"
        Get-Service -Name $ServiceName
    }
}

Write-ColorOutput "Done" "Success"
