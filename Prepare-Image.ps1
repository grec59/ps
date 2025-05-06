Clear-Host

# Establish variables

$pspath = (Get-Process -Id $PID).Path

$date = (Get-Date).DateTime

$scriptpath = '\\dbfsvs02\ITdb\Tech\Staff` Techs\Austin` Greco\Scripts\Prepare-Image.ps1'

# Check for administrative session, establishes new elevated session if needed

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {Start-Process "$pspath" -Verb runAs -ArgumentList '-NoExit', '-ExecutionPolicy RemoteSigned', '-Command', "& $scriptpath" ; Stop-Process -Id $PID }

# Display list of actions on-screen

$message = @{
    Text = "Welcome to the Post-Image Utilities Script. This script will perform the following on: `n$date"
    Tasks = @(
		"`n"
        '1. Update Group Policy'
        '2. Configuration Manager Actions'
        '3. Dell System Updates'
        '4. Creates Remote User'
		"`n"
    )
}

Write-Host $message.Text
$message.Tasks | ForEach-Object { Write-Host $_ }

# Retrieve User Confirmation

Read-Host -Prompt 'Press any key to continue with tasks or CTRL+C to quit' | Out-Null

# Start PowerShell Transcript

Start-Transcript -Path C:\results.txt

# Group Policy Update

function Invoke-GroupPolicy {
	
    gpupdate /force
	
	Start-Sleep -Seconds 30
}

Invoke-GroupPolicy

Write-Host 'Starting Configuration Manager Actions'

Start-Sleep -Seconds 30

# Configuration Manager Action Execution

function Execute-Actions {
  
$Policies = {
    $SCCMActions = @(
        "{00000000-0000-0000-0000-000000000021}",  # Machine policy retrieval Cycle
        "{00000000-0000-0000-0000-000000000022}",  # Machine policy evaluation cycle
        "{00000000-0000-0000-0000-000000000001}",  # Hardware inventory cycle
        "{00000000-0000-0000-0000-000000000002}",  # Software inventory cycle
        "{00000000-0000-0000-0000-000000000003}",  # Discovery Data Collection Cycle
        "{00000000-0000-0000-0000-000000000113}",  # Software updates scan cycle
        "{00000000-0000-0000-0000-000000000114}",  # Software updates deployment evaluation cycle
        "{00000000-0000-0000-0000-000000000031}",  # Software metering usage report cycle
        "{00000000-0000-0000-0000-000000000121}",  # Application deployment evaluation cycle
        # "{00000000-0000-0000-0000-000000000026}",  # User policy retrieval
        # "{00000000-0000-0000-0000-000000000027}",  # User policy evaluation cycle
        "{00000000-0000-0000-0000-000000000032}",  # Windows installer source list update cycle
        "{00000000-0000-0000-0000-000000000010}"   # File collection
    )

    foreach ($action in $SCCMActions) {  
        Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule -ArgumentList $action ; start-sleep -seconds 2
    }
}

Invoke-Command -ScriptBlock $Policies

}

Execute-Actions

# Dell OEM System Update Initialization

function Dell-Updates {
	
$path = 'C:\Program Files\Dell\CommandUpdate\dcu-cli.exe'

if (Test-Path $path) {
	
Start-Sleep -Seconds 5
	
Write-Host "`nDell Command found, starting Dell updates...`n"

# Start-Process $path -ArgumentList '/applyUpdates', '-autoSuspendBitLocker=enable', '-outputLog=C:\command.log'

& "$path" /applyUpdates -autoSuspendBitLocker=enable -outputLog='C:\command.log'

}

else {

Write-Host "`nDell Command not found, skipping updates.`n"

}

}

Dell-Updates

Start-Sleep -Seconds 5

# Create Local User Account

function Create-User {

$RemoteUserInquiry = Read-Host "`nIs this setup for a remote (off-campus) user? Y or N"

if ($RemoteUserInquiry -eq 'Y') {

$Password = Read-Host 'A local account will be created for initial logon. Enter a password' -AsSecureString

New-LocalUser -Name 'eagle' -Password $Password -Description 'Initial Access for Remote Users' -AccountNeverExpires

Write-Host 'The Post-Installation Utilities Script is complete.'

Stop-Transcript

}

else {

Write-Host 'The Post-Installation Utilities Script is complete.'

Stop-Transcript

}

}

Create-User
