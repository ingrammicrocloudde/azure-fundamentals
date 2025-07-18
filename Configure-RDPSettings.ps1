# filepath: c:\Users\dezapc00\Repositories\AVD-to-Go\scripts\Configure-RDPSettings.ps1
<#
.SYNOPSIS
    Configures RDP settings including timezone redirection for AVD session hosts
.DESCRIPTION
    This script configures various RDP settings including timezone redirection,
    audio redirection, clipboard redirection, and other optimizations for Azure Virtual Desktop
.NOTES
    Version: 1.0
#>

# Ensure running with administrative privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

Write-Host "Configuring RDP settings for optimal AVD experience..." -ForegroundColor Green

# Define registry paths
$RDPSettingsPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'
$RDPClientSettingsPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'

# Create registry paths if they don't exist
if (!(Test-Path $RDPSettingsPath)) {
    New-Item -Path $RDPSettingsPath -Force | Out-Null
}

# Enable timezone redirection
Write-Host "Enabling timezone redirection..." -ForegroundColor Yellow
Set-ItemProperty -Path $RDPSettingsPath -Name "fEnableTimeZoneRedirection" -Value 1 -Type DWord -Force

# Configure other useful RDP settings
Write-Host "Configuring additional RDP settings..." -ForegroundColor Yellow

# Enable clipboard redirection
Set-ItemProperty -Path $RDPSettingsPath -Name "fDisableClip" -Value 0 -Type DWord -Force

# Enable drive redirection
Set-ItemProperty -Path $RDPSettingsPath -Name "fDisableCdm" -Value 0 -Type DWord -Force

# Enable printer redirection
Set-ItemProperty -Path $RDPSettingsPath -Name "fDisablePNPRedir" -Value 0 -Type DWord -Force

# Enable audio redirection (play on this computer)
Set-ItemProperty -Path $RDPSettingsPath -Name "fDisableAudioCapture" -Value 0 -Type DWord -Force
Set-ItemProperty -Path $RDPSettingsPath -Name "fDisableAudio" -Value 0 -Type DWord -Force

# Set keep-alive interval to prevent timeouts
Set-ItemProperty -Path $RDPSettingsPath -Name "KeepAliveInterval" -Value 1 -Type DWord -Force
Set-ItemProperty -Path $RDPSettingsPath -Name "MaxIdleTime" -Value 0 -Type DWord -Force

# Display connection info in title bar
Set-ItemProperty -Path $RDPSettingsPath -Name "DisplayConnectionInformation" -Value 1 -Type DWord -Force

# Configure session settings
Set-ItemProperty -Path $RDPSettingsPath -Name "fEnableWinStation" -Value 1 -Type DWord -Force

# Allow multiple sessions per user
Set-ItemProperty -Path $RDPSettingsPath -Name "fSingleSessionPerUser" -Value 0 -Type DWord -Force

# Optimize performance settings for RDP
Write-Host "Optimizing system performance for RDP..." -ForegroundColor Yellow

# Set visual effects to best performance
$perfSettings = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
if (!(Test-Path $perfSettings)) {
    New-Item -Path $perfSettings -Force | Out-Null
}
Set-ItemProperty -Path $perfSettings -Name "VisualFXSetting" -Value 2 -Type DWord -Force

# Disable screen saver
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "ScreenSaveActive" -Value "0" -Type String -Force

# Configure Group Policy settings if available
$groupPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
if (!(Test-Path $groupPolicyPath)) {
    New-Item -Path $groupPolicyPath -Force | Out-Null
}

# Allow clipboard synchronization across devices
Set-ItemProperty -Path $groupPolicyPath -Name "AllowClipboardHistory" -Value 1 -Type DWord -Force

Write-Host "RDP settings configured successfully!" -ForegroundColor Green