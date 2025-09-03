<#
.SYNOPSIS
    Automates the configuration of a Windows Server for hosting web applications.
.DESCRIPTION
    This script installs and configures IIS with necessary features, installs PowerShell 7,
    .NET 8 runtimes, the latest VC++ Redistributable, Azure CLI, and SQL command-line tools.
    It includes checks to skip components that are already installed, making it safe to re-run.
.NOTES
    Run this script with Administrator privileges.
#>

# --- Setup Directories and Logging ---
# All downloaded packages and logs will be stored in C:\Temp.
$downloadDir = "C:\Temp"
if (-not (Test-Path -Path $downloadDir)) {
    New-Item -Path $downloadDir -ItemType Directory -Force | Out-Null
}

$logFolder = Join-Path -Path $downloadDir -ChildPath "logs"
if (-not (Test-Path -Path $logFolder)) {
    New-Item -Path $logFolder -ItemType Directory -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = Join-Path -Path $logFolder -ChildPath "Server_Setup_$timestamp.log"
Start-Transcript -Path $logFile
Write-Output "Script execution started. Logging to $logFile"
Write-Output "All downloads will be saved to $downloadDir"

# Function to check if a Windows feature is enabled
function Test-WindowsFeatureInstalled {
    param (
        [string]$FeatureName
    )
    $feature = Get-WindowsFeature -Name $FeatureName -ErrorAction SilentlyContinue
    if ($feature -and $feature.Installed) {
        return $true
    }
    return $false
}

# Function to check if an optional Windows feature is enabled
function Test-OptionalFeatureEnabled {
    param (
        [string]$FeatureName
    )
    $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction SilentlyContinue
    if ($feature -and $feature.State -eq 'Enabled') {
        return $true
    }
    return $false
}

#####################################################################
# 1. INSTALL WINDOWS SERVER ROLES AND FEATURES
#####################################################################
Write-Output "--- Section 1: Installing Windows Server Roles and Features ---"

# --- Install-WindowsFeature list ---
$windowsFeatures = @(
    "Web-Server",
    "WAS",
    "Web-WHC",
    "NET-Framework-45-Features",
    "NET-HTTP-Activation",
    "NET-Framework-45-ASPNET",
    "NET-WCF-TCP-Activation45",
    "NET-WCF-HTTP-Activation45",
    "BITS-IIS-Ext" # Corrected from BITS-IIS-ExtWrite-Output
)

foreach ($feature in $windowsFeatures) {
    if (Test-WindowsFeatureInstalled -FeatureName $feature) {
        Write-Output "[SKIP] Windows Feature '$feature' is already installed."
    }
    else {
        Write-Output "Installing Windows Feature: '$feature'..."
        Install-WindowsFeature -Name $feature -IncludeManagementTools -ErrorAction Stop
        Write-Output "Successfully installed '$feature'."
    }
}

# --- Enable-WindowsOptionalFeature list ---
$optionalFeatures = @(
    "IIS-HttpRedirect",
    "IIS-ApplicationDevelopment",
    "IIS-ASP",
    "IIS-ASPNET45",
    "NetFx4Extended-ASPNET45",
    "IIS-NetFxExtensibility45",
    "IIS-WebSockets",
    "IIS-ApplicationInit",
    "IIS-LoggingLibraries",
    "IIS-RequestMonitor",
    "IIS-HttpTracing",
    "IIS-BasicAuthentication",
    "IIS-WindowsAuthentication",
    "IIS-ManagementScriptingTools",
    "IIS-ManagementService"
)

foreach ($feature in $optionalFeatures) {
    if (Test-OptionalFeatureEnabled -FeatureName $feature) {
        Write-Output "[SKIP] Optional Feature '$feature' is already enabled."
    }
    else {
        Write-Output "Enabling Optional Feature: '$feature'..."
        Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -ErrorAction Stop
        Write-Output "Successfully enabled '$feature'."
    }
}
Write-Output "--- Section 1: Complete ---"
Write-Output ""

#####################################################################
# 2. INSTALL POWERSHELL 7 LTS
#####################################################################
Write-Output "--- Section 2: Installing PowerShell 7 LTS ---"
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Write-Output "[SKIP] PowerShell 7 or newer is already installed."
}
else {
    try {
        Write-Output "Determining latest PowerShell 7 LTS version..."
        $buildinfoUrl = 'https://aka.ms/pwsh-buildinfo-lts'
        $releaseTag = (Invoke-RestMethod -UseBasicParsing -Uri $buildinfoUrl -ErrorAction Stop).ReleaseTag
        $versionNumber = $releaseTag.Trim("v")
        $architecture = "x64"
        $msiUrl = "https://github.com/PowerShell/PowerShell/releases/download/$releaseTag/PowerShell-$versionNumber-win-$architecture.msi"
        $msiPath = Join-Path -Path $downloadDir -ChildPath "PowerShell-$versionNumber-win-x64.msi"

        Write-Output "Downloading PowerShell $versionNumber to $msiPath..."
        Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath -ErrorAction Stop

        Write-Output "Installing PowerShell $versionNumber..."
        Start-Process msiexec.exe -Wait -ArgumentList "/i `"$msiPath`" /qn" -PassThru -ErrorAction Stop
        Write-Output "Successfully installed PowerShell $versionNumber."
    }
    catch {
        Write-Error "Failed to install PowerShell 7. Error: $_"
    }
}
Write-Output "--- Section 2: Complete ---"
Write-Output ""

#####################################################################
# 3. INSTALL .NET RUNTIMES (MULTIPLE VERSIONS)
#####################################################################
Write-Output "--- Section 3: Installing .NET Runtimes ---"

# Define the list of .NET installers. Each object has a specific 'CheckString' to verify if that runtime type is installed.
$dotnetVersions = @(
    @{
        Version = "6.0 Hosting Bundle";
        Url = "https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/6.0.26/dotnet-hosting-6.0.26-win.exe";
        FileName = "dotnet-hosting-6.0.26-win.exe";
        MajorVersionString = "6.0."; 
        CheckString = "Microsoft.AspNetCore.App"; # Hosting Bundles install the ASP.NET Core runtime
    },
    @{
        Version = "8.0 Hosting Bundle";
        Url = "https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/8.0.19/dotnet-hosting-8.0.19-win.exe";
        FileName = "dotnet-hosting-8.0.19-win.exe";
        MajorVersionString = "8.0."; 
        CheckString = "Microsoft.AspNetCore.App";
    },
     @{
        Version = "8.0 Windows Desktop Runtime";
        Url = "https://builds.dotnet.microsoft.com/dotnet/WindowsDesktop/8.0.19/windowsdesktop-runtime-8.0.19-win-x64.exe";
        FileName = "windowsdesktop-runtime-8.0.19-win-x64.exe";
        MajorVersionString = "8.0.";
        CheckString = "Microsoft.WindowsDesktop.App"; # This runtime has a different name
    }
)

# Check for existing runtimes once before starting the loop
$dotnetExists = Get-Command dotnet -ErrorAction SilentlyContinue
$existingRuntimes = if ($dotnetExists) { & dotnet --list-runtimes } else { "" }

foreach ($dotnetVersion in $dotnetVersions) {
    Write-Output "--- Processing .NET $($dotnetVersion.Version) ---"
    try {
        # FIXED: Refresh the list of installed runtimes at the start of each iteration to ensure the check is always accurate.
        $existingRuntimes = if (Get-Command dotnet -ErrorAction SilentlyContinue) { & dotnet --list-runtimes } else { "" }

        # This check is now specific to the type of runtime (Hosting vs. Desktop) and uses up-to-date information.
        if ($existingRuntimes -match "$($dotnetVersion.CheckString) $($dotnetVersion.MajorVersionString)") {
            Write-Output "[SKIP] .NET $($dotnetVersion.Version) appears to be already installed."
            continue # Move to the next version in the array
        }

        $installerPath = Join-Path -Path $downloadDir -ChildPath $dotnetVersion.FileName
        
        # MANUAL DOWNLOAD OVERRIDE: Check if installer exists in C:\Temp first.
        if (Test-Path -Path $installerPath) {
            Write-Output "Local .NET $($dotnetVersion.Version) installer found in $downloadDir. Skipping download."
        }
        else {
            Write-Output "Downloading .NET $($dotnetVersion.Version) to $installerPath..."
            Invoke-WebRequest -Uri $dotnetVersion.Url -OutFile $installerPath -ErrorAction Stop
        }

        Write-Output "Installing .NET $($dotnetVersion.Version)..."
        $process = Start-Process -Wait -FilePath $installerPath -ArgumentList "/install /quiet /norestart" -PassThru -ErrorAction Stop
        
        # Refresh environment variables and re-check runtimes to verify installation
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        $existingRuntimes = if (Get-Command dotnet -ErrorAction SilentlyContinue) { & dotnet --list-runtimes } else { "" }

        if ($existingRuntimes -match "$($dotnetVersion.CheckString) $($dotnetVersion.MajorVersionString)") {
            Write-Output "Successfully installed .NET $($dotnetVersion.Version)."
        } else {
            throw ".NET $($dotnetVersion.Version) was not found after installation. Installer exit code: $($process.ExitCode)"
        }
    }
    catch [System.Net.WebException] {
        Write-Error "A network error occurred while downloading the .NET $($dotnetVersion.Version). Error: $_"
        Write-Error "MANUAL ACTION REQUIRED: Please download the file from this URL: $($dotnetVersion.Url)"
        Write-Error "Then, place the file ('$($dotnetVersion.FileName)') in '$downloadDir' and run this script again."
    }
    catch {
        Write-Error "Failed to install .NET $($dotnetVersion.Version). Error: $_"
    }
    finally {
         Write-Output "--- Finished processing .NET $($dotnetVersion.Version) ---"
    }
}
Write-Output "--- Section 3: Complete ---"
Write-Output ""


#####################################################################
# 4. INSTALL LATEST VC++ REDISTRIBUTABLE
#####################################################################
Write-Output "--- Section 4: Installing Latest VC++ Redistributable ---"
try {
    $vcInstallerUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
    $vcInstallerPath = Join-Path -Path $downloadDir -ChildPath "vc_redist.x64.exe"

    Write-Output "Downloading VC++ Redistributable installer to $vcInstallerPath..."
    Invoke-WebRequest -Uri $vcInstallerUrl -OutFile $vcInstallerPath -ErrorAction Stop

    Write-Output "Installing VC++ Redistributable..."
    Start-Process -Wait -FilePath $vcInstallerPath -ArgumentList "/install /quiet /norestart" -PassThru -ErrorAction Stop
    Write-Output "Successfully installed VC++ Redistributable."
}
catch {
    Write-Error "Failed to install VC++ Redistributable. Error: $_"
}
Write-Output "--- Section 4: Complete ---"
Write-Output ""

#####################################################################
# 5. INSTALL AZURE (AZ) CLI
#####################################################################
Write-Output "--- Section 5: Installing Azure CLI ---"
if (Get-Command az -ErrorAction SilentlyContinue) {
    Write-Output "[SKIP] Azure CLI is already installed."
}
else {
    try {
        $azCliUrl = "https://aka.ms/installazurecliwindowsx64"
        $azCliPath = Join-Path -Path $downloadDir -ChildPath "AzureCLI.msi"

        Write-Output "Downloading Azure CLI installer to $azCliPath..."
        Invoke-WebRequest -Uri $azCliUrl -OutFile $azCliPath -ErrorAction Stop

        Write-Output "Installing Azure CLI..."
        Start-Process msiexec.exe -Wait -ArgumentList "/i `"$azCliPath`" /qn" -PassThru -ErrorAction Stop
        Write-Output "Successfully installed Azure CLI. You may need to restart your terminal to use the 'az' command."
    }
    catch {
        Write-Error "Failed to install Azure CLI. Error: $_"
    }
}
Write-Output "--- Section 5: Complete ---"
Write-Output ""

#####################################################################
# 7. INSTALL SQL ODBC DRIVER 17
#####################################################################
Write-Output "--- Section 6: Installing SQL ODBC Driver 17 ---"
try {
    # More reliable check: search for the driver DLL in the entire Windows folder
    $odbcDriverDll = Get-ChildItem -Path $env:SystemRoot -Recurse -Filter "msodbcsql17.dll" -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($odbcDriverDll) {
        Write-Output "[SKIP] SQL ODBC Driver 17 appears to be already installed at $($odbcDriverDll.FullName)."
    }
    else {
        $odbcUrl = "https://go.microsoft.com/fwlink/?linkid=2249004" 
        $odbcPath = Join-Path -Path $downloadDir -ChildPath "msodbcsql17.msi"
        
        Write-Output "Downloading SQL ODBC Driver 17 installer to $odbcPath..."
        Invoke-WebRequest -Uri $odbcUrl -OutFile $odbcPath -ErrorAction Stop

        Write-Output "Installing SQL ODBC Driver 17..."
        Start-Process msiexec.exe -Wait -ArgumentList "/i `"$odbcPath`" /qn IACCEPTMSODBCSQLLICENSETERMS=YES" -PassThru -ErrorAction Stop
        
        # Verification Step
        $odbcDriverDll = Get-ChildItem -Path $env:SystemRoot -Recurse -Filter "msodbcsql17.dll" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($odbcDriverDll) {
            Write-Output "Successfully installed SQL ODBC Driver 17. Found at: $($odbcDriverDll.FullName)"
        }
        else {
            throw "ODBC Driver 18 installation completed, but the driver DLL was not found."
        }
    }
}
catch {
    Write-Error "Failed to install SQL ODBC Driver 17. Error: $_"
}
Write-Output "--- Section 6: Complete ---"
Write-Output ""

#####################################################################
# 6. INSTALL SQLCMD UTILITY
#####################################################################
Write-Output "--- Section 7: Installing SQLCMD Utility ---"
try {
    # More reliable check: search for sqlcmd.exe in both Program Files directories
    $searchPaths = @( ${env:ProgramFiles}, ${env:ProgramFiles(x86)} )
    $sqlCmdExe = Get-ChildItem -Path $searchPaths -Recurse -Filter "sqlcmd.exe" -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($sqlCmdExe) {
        Write-Output "[SKIP] SQLCMD Utility appears to be already installed at $($sqlCmdExe.FullName)."
    }
    else {
        $sqlCmdUrl = "https://go.microsoft.com/fwlink/?linkid=2230791" 
        $sqlCmdPath = Join-Path -Path $downloadDir -ChildPath "MsSqlCmdLnUtils.msi"
        
        Write-Output "Downloading SQLCMD Utility installer to $sqlCmdPath..."
        Invoke-WebRequest -Uri $sqlCmdUrl -OutFile $sqlCmdPath -ErrorAction Stop

        Write-Output "Installing SQL Command Line Utility..."
        Start-Process msiexec.exe -Wait -ArgumentList "/i `"$sqlCmdPath`" /qn IACCEPTMSSQLCMDLNUTILSLICENSETERMS=YES" -PassThru -ErrorAction Stop
        
        # Verification Step
        $sqlCmdExe = Get-ChildItem -Path $searchPaths -Recurse -Filter "sqlcmd.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($sqlCmdExe) {
            Write-Output "Successfully installed SQLCMD Utility. Found at: $($sqlCmdExe.FullName)"
        }
        else {
            throw "SQLCMD installation completed, but the executable could not be found."
        }
    }
}
catch {
    Write-Error "Failed to install SQLCMD Utility. Error: $_"
}



Write-Output "--- Section 7: Complete ---"
Write-Output ""


#####################################################################
# 8. DOWNLOAD SUPPORT TOOLS (DOWNLOAD ONLY)
#####################################################################
Write-Output "--- Section 8: Downloading Support Tools ---"

# Define the list of support tools to download. Add new tools here.
$supportTools = @(
    @{
        Name = "PuTTY";
        # Note: PuTTY URLs are version-specific. This may need updating.
        Url = "https://the.earth.li/~sgtatham/putty/latest/w64/putty-64bit-0.83-installer.msi";
        FileName = "putty-64bit-installer.msi";
    },
    @{
        Name = "WinSCP";
        Url = "https://winscp.net/download/WinSCP-latest-Setup.exe";
        FileName = "WinSCP-latest-Setup.exe";
    },
    @{
        Name = "Notepad++";
        # Note: Notepad++ URLs are version-specific. This may need updating.
        Url = "https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.6.8/npp.8.6.8.Installer.x64.exe";
        FileName = "npp.installer.x64.exe";
    },
    @{
        Name = "mRemoteNG";
        # Note: mRemoteNG URLs are version-specific. This may need updating.
        Url = "https://github.com/mRemoteNG/mRemoteNG/releases/download/20250819-v1.78.2-NB-(3137)/mRemoteNG.exe";
        FileName = "mRemoteNG-Installer.msi";
    }
)

foreach ($tool in $supportTools) {
    Write-Output "--- Processing $($tool.Name) ---"
    try {
        $toolPath = Join-Path -Path $downloadDir -ChildPath $tool.FileName
        
        if (Test-Path -Path $toolPath) {
            Write-Output "[SKIP] $($tool.Name) installer already exists in $downloadDir."
        }
        else {
            Write-Output "Downloading $($tool.Name) to $toolPath..."
            Invoke-WebRequest -Uri $tool.Url -OutFile $toolPath -ErrorAction Stop
            Write-Output "Successfully downloaded $($tool.Name)."
        }
    }
    catch {
        Write-Error "Failed to download $($tool.Name). Error: $_"
    }
}
Write-Output "--- Section 8: Complete ---"
Write-Output ""

Write-Output "--- All setup tasks are complete. ---"

# Stops the transcript, finalizing the log file.
Stop-Transcript
