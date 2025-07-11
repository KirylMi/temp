# Script: CreatePCIeRebootTask.ps1

# --- CONFIGURATION FOR SCHEDULED TASK ---
$TaskName = "PCIe_SSD_Check_Reboot_Automation"
$ScriptPath = "C:\Scripts\CheckPCIeAndRebootWithScreenshot.ps1" # !!! ADJUST THIS PATH to your main script !!!
$LogFolder = "C:\PCIe_Logs_TaskSetup" # Folder for task setup logs
$TaskLogFile = "$LogFolder\TaskSetupLog.txt"

# --- DO NOT MODIFY BELOW THIS LINE UNLESS YOU KNOW WHAT YOU ARE DOING ---

# Ensure log folder exists
if (-not (Test-Path $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
}

function LogTaskSetupMessage {
    param (
        [string]$Message
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $TaskLogFile -Value "$Timestamp - $Message"
    Write-Host "$Timestamp - $Message"
}

LogTaskSetupMessage "--- Starting Scheduled Task Setup ---"

if (-not (Test-Path $ScriptPath)) {
    LogTaskSetupMessage "ERROR: Main script not found at '$ScriptPath'. Please verify the path before creating the task."
    LogTaskSetupMessage "Scheduled Task setup FAILED."
    exit
}

# Define scheduled task actions
$pwshPath = (Get-Command pwsh.exe -ErrorAction SilentlyContinue).Source # Get the actual path to pwsh.exe
if (-not $pwshPath) { # If pwsh.exe isn't found in PATH (e.g., if you only installed it to a custom path)
    LogTaskSetupMessage "WARNING: pwsh.exe not found in system PATH. Attempting common installation paths."
    # Common install paths for PowerShell 7.x
    if (Test-Path "$env:ProgramFiles\PowerShell\7\pwsh.exe") {
        $pwshPath = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
    } elseif (Test-Path "$env:ProgramFiles (x86)\PowerShell\7\pwsh.exe") {
        $pwshPath = "$env:ProgramFiles (x86)\PowerShell\7\pwsh.exe"
    } else {
        LogTaskSetupMessage "ERROR: Could not locate pwsh.exe. Falling back to default powershell.exe (v5.1). This might cause issues."
        $pwshPath = "powershell.exe"
    }
} else {
    LogTaskSetupMessage "Using pwsh.exe found at: $pwshPath"
}


$action = New-ScheduledTaskAction -Execute $pwshPath -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""

# Define scheduled task trigger (On user logon - CRITICAL CHANGE)
$trigger = New-ScheduledTaskTrigger -AtLogon

# Define scheduled task principal to run as CURRENT USER for interactive logon (CRITICAL CHANGE)
# This ensures the script runs in the actual user session after login,
# which is necessary for GUI applications to display correctly.
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
LogTaskSetupMessage "Attempting to create task for current user: $currentUser"

$principal = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType Interactive -RunLevel Highest

# Define scheduled task settings (Minimal and robust for desktop systems)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit "00:30:00"

# Register the scheduled task
try {
    LogTaskSetupMessage "Attempting to register scheduled task '$TaskName'..."
    Register-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings -TaskName $TaskName -Force
    LogTaskSetupMessage "Scheduled Task '$TaskName' created/updated successfully for user '$currentUser'."
    LogTaskSetupMessage "The script '$ScriptPath' will now run at every user logon using PowerShell 7."
}
catch {
    LogTaskSetupMessage "ERROR: Failed to create scheduled task: $($_.Exception.Message)"
    LogTaskSetupMessage "Possible causes: Insufficient permissions (ensure you are running PowerShell as Administrator), or Group Policy restrictions."
    LogTaskSetupMessage "If issues persist, you may need to try creating the task manually via Task Scheduler GUI (as previously discussed)."
}

LogTaskSetupMessage "--- Scheduled Task Setup Finished ---"