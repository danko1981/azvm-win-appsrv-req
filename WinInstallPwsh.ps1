Set-ExecutionPolicy Bypass

#####################################################################
#INSTALL POWERSHELL 7 LTS
#####################################################################
#Generate dowload link for latest LTS release.
$buildinfoUrl = 'https://aka.ms/pwsh-buildinfo-lts'
Write-Output "`$buildinfoUrl`t$buildinfoUrl"
$releaseTag = (Invoke-RestMethod -UseBasicParsing -Uri $buildinfoUrl -ErrorAction Stop -Verbose:$false).ReleaseTag
$versionNumber = $releaseTag.trim("v")
$architecture = "x64"
$ZipUrl = "https://github.com/PowerShell/PowerShell/releases/download/$($releaseTag)/PowerShell-$($versionNumber)-win-$architecture.msi"
Write-Output $ZipUrl  

#Download the PowerShell 7 installer
Invoke-WebRequest -Uri $ZipUrl -OutFile "$env:TEMP\PowerShell-7-x64.msi"

#Install PowerShell 7
try {
    Start-Process -Wait -FilePath "$env:TEMP\PowerShell-7-x64.msi" -ArgumentList "/qn" -PassThru  
    Write-Output "Powershell $versionNumber installed"
}
catch {
    Write-Output "Error while installing powershell $versionNumber"
}

#####################################################################
#INSTALL Latest .NetCore
#####################################################################
# Define the URL for the .NetCore script installer
$vcInstallerUrl = "https://dot.net/v1/dotnet-install.ps1"

# Download the script
Invoke-WebRequest -Uri $vcInstallerUrl -OutFile "$env:TEMP\dotnet-install.ps1"

#Install .NetCore
try {
    & "$env:TEMP\dotnet-install.ps1" -Channel 5.0 -Version latest -Runtime aspnetcore 
    Write-Output "dotnet core 5.0 aspenetcore installed"
    & "$env:TEMP\dotnet-install.ps1" -Channel 5.0 -Version latest -Runtime windowsdesktop 
    Write-Output "dotnet core 5.0 desktopruntime installed"
    & "$env:TEMP\dotnet-install.ps1" -Channel 6.0 -Version latest -Runtime aspnetcore
    Write-Output "dotnet core 6.0 aspenetcore installed"
    & "$env:TEMP\dotnet-install.ps1" -Channel 6.0 -Version latest -Runtime windowsdesktop     
    Write-Output "dotnet core 6.0 desktopruntime installed"
}
catch {
    Write-Output "Error while installing .NetCore: $_"
}

#list installed:
Write-Output "Otuput of query: dotnet --list-runtimes"
& dotnet --list-runtimes

#####################################################################
#INSTALL Latest VCRedist
#####################################################################
# Define the URL for the VcRedist.x64 installer
$vcInstallerUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"

# Download the installer
Invoke-WebRequest -Uri $vcInstallerUrl -OutFile "$env:TEMP\vc_redist.x64.exe"

#Install VcRedistr
try {
    Start-Process -Wait -FilePath "$env:TEMP\vc_redist.x64.exe" -ArgumentList "/install /quiet /norestart" -PassThru  
    Write-Host "Visual C++ Redistributable successfully Installed "
}
catch {
    Write-Host "Error while installing Visual C++ Redistributable: $_"
}

#####################################################################
#WINDOWS SERVER ROLES AND FEATURES
#####################################################################

Install-WindowsFeature -Name Web-Server -IncludeManagementTools
Install-WindowsFeature -Name WAS
Install-WindowsFeature -Name Web-WHC
Install-WindowsFeature -Name NET-Framework-45-Features
Install-WindowsFeature -Name NET-HTTP-Activation
Install-WindowsFeature -Name NET-Framework-45-ASPNET
Install-WindowsFeature -Name NET-WCF-TCP-Activation45
Install-WindowsFeature -Name NET-WCF-HTTP-Activation45
Install-WindowsFeature -Name BITS-IIS-Ext

Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpRedirect -All
Enable-WindowsOptionalFeature -Online -FeatureName IIS-ApplicationDevelopment -All

Enable-WindowsOptionalFeature -Online -FeatureName IIS-ASP -All
Enable-WindowsOptionalFeature -Online -FeatureName IIS-ASPNET45 -All
Enable-WindowsOptionalFeature -Online -FeatureName NetFx4Extended-ASPNET45 -All
Enable-WindowsOptionalFeature -Online -FeatureName IIS-NetFxExtensibility45 -All
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebSockets -All
Enable-WindowsOptionalFeature -Online -FeatureName IIS-ApplicationInit -All

Enable-WindowsOptionalFeature -Online -FeatureName IIS-LoggingLibraries -All
Enable-WindowsOptionalFeature -Online -FeatureName IIS-RequestMonitor -All
Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpTracing -All

Enable-WindowsOptionalFeature -Online -FeatureName IIS-BasicAuthentication -All
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WindowsAuthentication -All





