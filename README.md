# PCIe SSD Connection Stability Tester (with CrystalDiskInfo)

A robust automation script designed to repeatedly reboot a Windows PC, launch a specified application (like CrystalDiskInfo), capture screenshots, and log critical system information. This tool is specifically "vibe-coded" to assist in diagnosing intermittent PCIe connectivity issues, particularly with NVMe SSDs, by simulating a high number of reboot cycles.

## 🌟 Purpose

This script was developed to aid in the diagnosis and validation of PCIe connection stability for NVMe SSDs (and potentially other PCIe devices). Intermittent connection drops or recognition failures often manifest during system reboots. By automating hundreds of reboots and capturing vital drive health and system PnP (Plug and Play) information at each cycle, this tool helps identify and document such issues, making it invaluable for RMA processes or thorough system testing.

## ✨ Features

* **Automated Reboot Cycles:** Configurable number of reboots to stress-test PCIe connections.
* **Application Launch & Screenshot:** Automatically launches a target application (defaults to CrystalDiskInfo) and captures a full-screen screenshot to document drive status visually.
* **Comprehensive Logging:** Records timestamps, SSD detection status, model, bus type, health, and PnP device information (location, status, problem code) for each iteration.
* **State Persistence:** Maintains iteration count across reboots using a dedicated counter file.
* **Automated Task Scheduling:** Includes a setup script to create a Windows Scheduled Task, enabling hands-off automation upon user logon.
* **Clean Exit:** Removes temporary files and creates a completion flag upon test completion.

## 🛠️ Prerequisites

* **Operating System:** Windows 10/11.
* **PowerShell 7 (pwsh.exe):** Recommended for best compatibility and features. Ensure it's installed and accessible in your system's PATH.
* **CrystalDiskInfo:** Install the 64-bit portable version of [CrystalDiskInfo](https://crystalmark.info/en/software/crystaldiskinfo/). The script defaults to `C:\Program Files\CrystalDiskInfo\DiskInfo64.exe`.
* **Administrator Privileges:** Required to set up the scheduled task and for CrystalDiskInfo to access drive information.
* **Auto-Login (Optional but Recommended):** For fully unattended operation, configure Windows to automatically log in to your user account after a reboot. See "Important Considerations" for security warning.

## 🚀 Setup & Usage

### 1. Download & Place Scripts

1.  Create a dedicated folder for the scripts, e.g., `C:\Scripts`.
2.  Download/create the following two PowerShell scripts and place them in `C:\Scripts`:
    * `CheckPCIeAndRebootWithScreenshot.ps1` (The main automation script)
    * `CreatePCIeRebootTask.ps1` (The script to set up the scheduled task)

### 2. Configure `CheckPCIeAndRebootWithScreenshot.ps1`

Open `C:\Scripts\CheckPCIeAndRebootWithScreenshot.ps1` in a text editor (like Notepad++ or VS Code) and adjust the `--- CONFIGURATION ---` section:

* `$NumberOfIterations`: **Set this to a small number (e.g., 3-5) for initial testing!** Once confirmed working, you can change it to your desired high number (e.g., 100, 500, or more).
* `$TargetSSDIdentifier`: **Crucially, set this to the exact Friendly Name of your SSD** as it appears in PowerShell's `Get-PhysicalDisk`. You can find this by running `Get-PhysicalDisk | Select-Object FriendlyName, Model` in PowerShell.
* `$CrystalDiskInfoPath`: **Verify this path matches the exact location of your `DiskInfo64.exe`** executable. The script currently defaults to `C:\Program Files\CrystalDiskInfo\DiskInfo64.exe`.

### 3. Create the Scheduled Task

This script will set up the automation to run at every user logon.

1.  **Open PowerShell as Administrator:** Right-click on the PowerShell icon and select "Run as Administrator."
2.  **Navigate to the scripts folder:**
    ```powershell
    Set-Location C:\Scripts
    ```
3.  **Execute the task creation script:**
    ```powershell
    .\CreatePCIeRebootTask.ps1
    ```
    **Observe the output in the PowerShell window and check `C:\PCIe_Logs_TaskSetup\TaskSetupLog.txt` for any errors.** The script should report "Scheduled Task 'PCIe_SSD_Check_Reboot_Automation' created/updated successfully for user 'YOUR_USERNAME'."

### 4. Prepare for First Run (Clean State)

Before the first automated run, ensure a clean state:

1.  **Delete any existing log/counter files:**
    * `C:\PCIe_Connection_Log.txt`
    * `C:\PCIe_Iteration_Counter.txt`
    * `C:\PCIe_Test_Completed.flag`
2.  **Delete the screenshot folder if it exists:**
    * `C:\PCIe_Screenshots`

### 5. Start the Test Cycle

1.  **Reboot your PC.**
2.  **Ensure you log in** after the reboot. The task is configured to run `AtLogon`, so it will trigger *after* you reach your desktop.
3.  Observe the process. You should see CrystalDiskInfo briefly appear on your screen before the system reboots again (if more iterations are pending).

## 📊 Output

* **Logs:** All activity is logged to `C:\PCIe_Connection_Log.txt`.
* **Screenshots:** Full-screen screenshots of CrystalDiskInfo will be saved to `C:\PCIe_Screenshots` with a timestamped filename (e.g., `CDI_Iteration_1_20250711_093000.png`).

## ⚠️ Important Considerations & Troubleshooting

* **Security Risk with Auto-Login:** If you enable auto-login to achieve fully unattended reboots, understand that your computer will boot directly to your desktop without a password prompt. **Only do this if your system is in a physically secure location.** Remember to disable auto-login after testing if security is a concern.
    * To enable auto-login: Press `Win + R`, type `netplwiz`, uncheck "Users must enter a user name and password to use this computer," and enter your credentials.
    * To disable auto-login: Go back to `netplwiz` and check the box again.
* **"Error taking screenshot: The handle is invalid." or CrystalDiskInfo not appearing:** This issue is typically caused by the script not running in the correct interactive user session. The latest `CreatePCIeRebootTask.ps1` script (running `AtLogon` for the current user) is specifically designed to address this. If it persists, double-check that you ran `CreatePCIeRebootTask.ps1` as Administrator and that there were no errors during its execution.
* **Administrator Rights:** Both setting up the task and running CrystalDiskInfo generally require elevated privileges. Ensure PowerShell is run as Administrator when setting up the task.
* **CrystalDiskInfo Path:** A common mistake is an incorrect path to `DiskInfo64.exe`. Verify it in `CheckPCIeAndRebootWithScreenshot.ps1`.
* **PowerShell Version:** While `powershell.exe` (v5.1, built-in) might work, `pwsh.exe` (PowerShell 7+) is explicitly targeted and recommended in the task definition. Ensure it's installed and correctly referenced.
* **Task Scheduler Manual Verification:** After running `CreatePCIeRebootTask.ps1`, you can open Task Scheduler (`taskschd.msc`), navigate to `Task Scheduler Library`, and verify that `PCIe_SSD_Check_Reboot_Automation` exists, is enabled, and is configured to run `At log on` for your user account with `Highest Privileges`.

## 📜 License

This project is open-source and available under the MIT License. See the [LICENSE](LICENSE) file for details.
