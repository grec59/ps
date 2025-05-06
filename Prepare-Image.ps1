<#
.SYNOPSIS
    Provisioning utility script for system setup and configuration.

.DESCRIPTION
    Updates group policy, runs Configuration Manager tasks, installs Dell updates,
    and optionally creates a standard account for local access.

.PARAMETER RemoteSetup
    If specified, creates a local "eagle" user for remote access.

.EXAMPLE
    .\Prepare-Image.ps1 -RemoteSetup
#>

param (
    [switch]$RemoteSetup
)

Clear-Host

# ===== Functions =====

function Create-User {
    try {
        $Password = Read-Host 'A standard account will be created for local logon. Enter a password' -AsSecureString
        New-LocalUser -Name 'eagle' -Password $Password -Description 'Initial Access for Remote Users' -AccountNeverExpires
        Write-Host "`nThe eagle user has been created.`n" -ForegroundColor Green
        Add-Content -Path $log -Value "[$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')] User 'eagle' created successfully."
    }
    catch {
        Write-Host "`nFailed to create user: $($_.Exception.Message)`n" -ForegroundColor Red
        Add-Content -Path $log -Value "[$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')] ERROR creating user: $($_.Exception.Message)"
    }
}

function Invoke-GroupPolicy {
    Write-Host 'Updating Group Policy...'
    try {
        gpupdate /force >> $log
        Start-Sleep -Seconds 25
        Write-Host 'Group Policy updated.' -ForegroundColor Green
        Add-Content -Path $log -Value "[$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')] Group Policy updated."
    }
    catch {
        Write-Host 'Group Policy update failed.' -ForegroundColor Red
        Add-Content -Path $log -Value "[$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')] ERROR during Group Policy update: $($_.Exception.Message)"
    }
}

function Execute-Actions {
    Write-Host 'Running Configuration Manager actions...'
    $errors = $false
    $SCCMActions = @(
        "{00000000-0000-0000-0000-000000000021}",
        "{00000000-0000-0000-0000-000000000022}",
        "{00000000-0000-0000-0000-000000000001}",
        "{00000000-0000-0000-0000-000000000002}",
        "{00000000-0000-0000-0000-000000000003}",
        "{00000000-0000-0000-0000-000000000113}",
        "{00000000-0000-0000-0000-000000000114}",
        "{00000000-0000-0000-0000-000000000031}",
        "{00000000-0000-0000-0000-000000000121}",
        "{00000000-0000-0000-0000-000000000032}",
        "{00000000-0000-0000-0000-000000000010}"
    )

    foreach ($action in $SCCMActions) {
        try {
            $result = Invoke-WmiMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule -ArgumentList $action
            Add-Content -Path $log -Value "[$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')] Action $action SUCCEEDED. Output: $($result | Out-String)"
        }
        catch {
            Add-Content -Path $log -Value "[$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')] Action $action FAILED. Error: $($_.Exception.Message)"
            $errors = $true
        }
        Start-Sleep -Seconds 2
    }

    if ($errors) {
        Write-Host "Errors occurred during SCCM actions. Check log." -ForegroundColor Red
    }
    else {
        Write-Host "Configuration actions completed successfully." -ForegroundColor Green
    }
}

function Dell-Updates {
    $path = 'C:\Program Files\Dell\CommandUpdate\dcu-cli.exe'
    if (Test-Path $path) {
        Write-Host "`nDell Command found, starting Dell updates`n"
        try {
            & "$path" /applyUpdates -autoSuspendBitLocker=enable -outputLog 'C:\command.log'
            Add-Content -Path $log -Value "[$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')] Dell Command Update ran successfully."
        }
        catch {
            Write-Host "`nDell update failed: $($_.Exception.Message)`n" -ForegroundColor Red
            Add-Content -Path $log -Value "[$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')] ERROR running Dell updates: $($_.Exception.Message)"
        }
    }
    else {
        Write-Host "`nDell Command not found, skipping updates.`n"
        Add-Content -Path $log -Value "[$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')] Dell Command not found. Skipping updates."
    }
}

# ===== Main Execution =====

$logDir = 'C:\Logs\PostImage'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$log = Join-Path $logDir 'results.txt'

$pspath = (Get-Process -Id $PID).Path
$date = (Get-Date).DateTime
$scriptpath = 'https://raw.githubusercontent.com/grec59/ps/refs/heads/main/Prepare-Image.ps1'

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process "$pspath" -Verb runAs -ArgumentList '-NoExit', '-ExecutionPolicy RemoteSigned', "-Command & '$scriptpath'"
    Stop-Process -Id $PID
}

$message = @{
    Text  = "Welcome to the Post-Image Utilities Script. This script will perform the following on: `n$date"
    Tasks = @(
        "`n"
        '1. Update Group Policy'
        '2. Configuration Manager Actions'
        '3. Dell System Updates'
        '4. Creates Remote User (parameter)'
        "`n"
    )
}

Write-Host $message.Text -ForegroundColor Gray
$message.Tasks | ForEach-Object { Write-Host $_ }

if ($Host.UI.RawUI.KeyAvailable -or $Host.Name -notmatch 'ServerRemoteHost') {
    Read-Host -Prompt 'Press any key to continue or CTRL+C to quit' | Out-Null
}

try {
    Start-Transcript -Path $log
}
catch {
    Write-Host "`nWARNING: Failed to start transcript: $($_.Exception.Message)`n" -ForegroundColor Yellow
    Add-Content -Path $log -Value "[$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')] Failed to start transcript: $($_.Exception.Message)"
}

if ($RemoteSetup) {
    Add-Content -Path $log -Value "[$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')] RemoteSetup parameter detected. Proceeding to create user."
    Create-User
}

Invoke-GroupPolicy

Start-Sleep -Seconds 5

Execute-Actions

Start-Sleep -Seconds 5

Dell-Updates

Start-Sleep -Seconds 5

try {
    Stop-Transcript
}
catch {
    Write-Host "`nWARNING: Could not stop transcript properly: $($_.Exception.Message)`n" -ForegroundColor Yellow
}

Write-Host "`nAll tasks completed. Please review $log for full details.`n" -ForegroundColor Cyan

$reboot = Read-Host "Do you want to reboot now? (Y/N)"
if ($reboot -match '^[Yy]$') {
    Write-Host "Rebooting system..." -ForegroundColor Yellow
    try {
        Restart-Computer -Force
    }
    catch {
        Write-Host "Failed to reboot: $($_.Exception.Message)" -ForegroundColor Red
        Add-Content -Path $log -Value "[$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')] ERROR restarting computer: $($_.Exception.Message)"
    }
}
else {
    Write-Host "Reboot skipped. You may need to restart manually." -ForegroundColor DarkGray
}
