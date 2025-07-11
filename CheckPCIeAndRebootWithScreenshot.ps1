# Script: CheckPCIeAndRebootWithScreenshot.ps1

# --- CONFIGURATION ---
$LogFilePath = "C:\PCIe_Connection_Log.txt"           # Main log file
$ScreenshotFolder = "C:\PCIe_Screenshots"             # Folder to save screenshots
$NumberOfIterations = 90                             # Total number of reboots (START WITH A SMALL NUMBER LIKE 3 FOR TESTING!)
# Once testing is successful, you can change $NumberOfIterations to 100 or your desired count.

$IterationCounterFile = "C:\PCIe_Iteration_Counter.txt" # Tracks current iteration across reboots
$CompletionFlagFile = "C:\PCIe_Test_Completed.flag"   # Flag file to signal completion
$TargetSSDIdentifier = "Samsung SSD 990 PRO 2TB"      # Your specific SSD's friendly name (as seen in Get-PhysicalDisk)
                                                      # You can find this in PowerShell by running: Get-PhysicalDisk | Select-Object FriendlyName, Model, MediaType

# CrystalDiskInfo Configuration
# !!! IMPORTANT: VERIFY THIS PATH MATCHES YOUR EXACT CrystalDiskInfo64.exe LOCATION !!!
# This script now defaults to the common "Program Files" location.
$CrystalDiskInfoPath = "C:\Program Files\CrystalDiskInfo\DiskInfo64.exe" # <--- DEFAULTED TO C:\Program Files\
$CDIProcessName = "DiskInfo64" # The process name for CrystalDiskInfo (e.g., DiskInfo64, DiskInfo)

# --- DO NOT MODIFY BELOW THIS LINE UNLESS YOU KNOW WHAT YOU ARE DOING ---

#region Functions
function LogMessage {
    param (
        [string]$Message
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFilePath -Value "$Timestamp - $Message"
    Write-Host "$Timestamp - $Message"
}

function Take-FullScreenshot {
    param (
        [string]$OutputFolder,
        [string]$FileNamePrefix
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $ScreenshotFile = Join-Path $OutputFolder "$($FileNamePrefix)_$(Get-Date -Format 'yyyyMMdd_HHmmss').png"

    try {
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen
        $bounds = $screen.Bounds
        $bitmap = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
        $graphic = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphic.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
        
        $bitmap.Save($ScreenshotFile, [System.Drawing.Imaging.ImageFormat]::Png)
        $graphic.Dispose()
        $bitmap.Dispose()

        LogMessage "Screenshot saved: $ScreenshotFile (Full-screen capture)."
        return $true

    } catch {
        LogMessage "Error taking screenshot: $($_.Exception.Message)"
        return false
    }
}

function Get-SSDInfoAndScreenshot {
    param (
        [string]$LogFilePath,
        [string]$ScreenshotFolder,
        [string]$CDIPath,
        [string]$CDIProcName,
        [string]$CurrentIteration
    )

    LogMessage "Searching for SSD: $TargetSSDIdentifier"
    
    $diskInfo = Get-PhysicalDisk | Where-Object { $_.FriendlyName -like "*$TargetSSDIdentifier*" }
    
    if ($diskInfo) {
        LogMessage "Found SSD: $($diskInfo.FriendlyName) - Model: $($diskInfo.Model) - Bus Type: $($diskInfo.BusType) - Health: $($diskInfo.HealthStatus)"
        try {
            $PnpDevice = Get-PnpDevice -Class "DiskDrive" | Where-Object { 
                $_.FriendlyName -like "*$($diskInfo.FriendlyName)*" -or $_.Description -like "*$($diskInfo.FriendlyName)*" 
            } | Select-Object -First 1

            if ($PnpDevice) {
                LogMessage "  PnP Device Location: $($PnpDevice.LocationInformation)"
                LogMessage "  PnP Device Status: $($PnpDevice.Status)"
                LogMessage "  PnP Problem Code: $($PnpDevice.ProblemCode)"
            } else {
                LogMessage "  Could not find corresponding PnP Device for $($diskInfo.FriendlyName)."
            }
        }
        catch {
            LogMessage "  Error retrieving detailed PnP info: $($_.Exception.Message)"
        }
    } else {
        LogMessage "SSD '$TargetSSDIdentifier' not found. This iteration might be problematic."
    }

    if (Test-Path $CDIPath) {
        LogMessage "Launching CrystalDiskInfo..."
        # REVERTED: Added /Exit argument back for automated closure.
        Start-Process -FilePath $CDIPath -ArgumentList "/NOINSTALL /Exit" -WindowStyle Normal -Verb RunAs -ErrorAction SilentlyContinue | Out-Null
        
        LogMessage "Waiting 20 seconds for CrystalDiskInfo to load and for screenshot..."
        Start-Sleep -Seconds 20 # Sleep time for CDI loading

        Take-FullScreenshot -OutputFolder $ScreenshotFolder -FileNamePrefix "CDI_Iteration_$CurrentIteration"

        LogMessage "Attempting to close CrystalDiskInfo process..."
        $cdiProcesses = Get-Process -Name $CDIProcName -ErrorAction SilentlyContinue
        if ($cdiProcesses.Count -gt 0) {
            $cdiProcesses | Stop-Process -Force -ErrorAction SilentlyContinue | Out-Null
            LogMessage "CrystalDiskInfo closed successfully."
        } else {
            LogMessage "CrystalDiskInfo process '$CDIProcName' not found after screenshot attempt."
        }
        Start-Sleep -Seconds 2
    } else {
        LogMessage "ERROR: CrystalDiskInfo executable not found at '$CDIPath'. Skipping SSD check and screenshot for this iteration."
    }
}
#endregion

# --- MAIN SCRIPT LOGIC ---

# Initial delay to ensure the desktop environment is fully loaded and stable.
LogMessage "Initial wait (20 seconds) to ensure desktop environment is ready for screen operations..."
Start-Sleep -Seconds 20 # Initial wait time.

# Check if the test was already completed in a previous boot cycle
if (Test-Path $CompletionFlagFile) {
    LogMessage "Completion flag file detected. Test was already finished in a previous cycle."
    LogMessage "Script exiting to prevent further reboots."
    exit # Exit immediately if test is already complete
}


# 1. Ensure required folders exist
if (-not (Test-Path $ScreenshotFolder)) {
    New-Item -ItemType Directory -Path $ScreenshotFolder -Force | Out-Null
    LogMessage "Created screenshot folder: $ScreenshotFolder"
}

# 2. Initialize or read iteration counter
$currentIteration = 0
if (Test-Path $IterationCounterFile) {
    try {
        $content = Get-Content $IterationCounterFile -Raw # Use -Raw to avoid line ending issues
        # Ensure only digits are read, trim whitespace
        if ($content -match "^\s*(\d+)\s*$") {
            $currentIteration = [int]$Matches[1]
            LogMessage "Resuming from iteration $currentIteration from counter file."
        } else {
            LogMessage "Warning: Invalid content in iteration counter file. Starting from 0. Content: '$content'"
            $currentIteration = 0
        }
    } catch {
        LogMessage "Error reading iteration counter file: $($_.Exception.Message). Starting from 0."
        $currentIteration = 0
    }
} else {
    LogMessage "Starting new test cycle. Iteration counter file not found."
}

# 3. Perform current iteration's actions
$currentIteration++
LogMessage "--- Starting Iteration $currentIteration of $NumberOfIterations ---"

Get-SSDInfoAndScreenshot `
    -LogFilePath $LogFilePath `
    -ScreenshotFolder $ScreenshotFolder `
    -CDIPath $CrystalDiskInfoPath `
    -CDIProcName $CDIProcessName `
    -CurrentIteration $currentIteration

# 4. Save current iteration for next boot
LogMessage "Updating iteration counter to $currentIteration..."
Set-Content -Path $IterationCounterFile -Value $currentIteration -Force

# 5. Check if more reboots are needed
if ($currentIteration -lt $NumberOfIterations) {
    LogMessage "Iteration $currentIteration completed. Rebooting system for next iteration..."
    LogMessage "Next iteration will be $($currentIteration + 1)."
    Start-Sleep -Seconds 10 # Give enough time for logs/screenshots to be fully written
    Restart-Computer -Force
} else {
    LogMessage "All $NumberOfIterations iterations completed. Test finished."
    LogMessage "Attempting to remove iteration counter file: $IterationCounterFile"
    Remove-Item -Path $IterationCounterFile -ErrorAction SilentlyContinue
    if (-not (Test-Path $IterationCounterFile)) {
        LogMessage "Iteration counter file successfully removed."
    } else {
        LogMessage "Warning: Could not remove iteration counter file. It might be locked or permission issue."
    }
    
    LogMessage "Creating completion flag file: $CompletionFlagFile"
    New-Item -Path $CompletionFlagFile -ItemType File -Force | Out-Null
    if (Test-Path $CompletionFlagFile) {
        LogMessage "Completion flag file successfully created."
    } else {
        LogMessage "Error: Could not create completion flag file."
    }

    LogMessage "Script finished. System will NOT reboot."
}