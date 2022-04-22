$CPUProperties = "manufacturer", "numberOfCores", "NumberOfLogicalProcessors"
$CPU = Get-WmiObject -class win32_processor -Property  $CPUProperties
$HyperVService = Get-Service vmcompute -ErrorAction SilentlyContinue

#Updates the Registry for the values passed in.
Function UpdateSpectreKeys() {
    param (
        [Parameter(Mandatory=$true)][uint32]$FeatureSettingsOverride,
        [Parameter(Mandatory=$true)][uint32]$FeatureSettingsOverrideMask,
        [Parameter(Mandatory=$false)][bool]$IsHyperV = $false
    )

    process {
        $MemoryManagementKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
        if ((Test-Path $MemoryManagementKey)) {
            Set-ItemProperty -Path $MemoryManagementKey -Name "FeatureSettingsOverride" -Value $FeatureSettingsOverride -Type DWord -Force | Out-Null
            Set-ItemProperty -Path $MemoryManagementKey -Name "FeatureSettingsOverrideMask" -Value $FeatureSettingsOverrideMask -Type DWORD -Force | Out-Null
            if ($IsHyperV) {
                $HyperVVirtualizationKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization"
                if ((Test-Path $HyperVVirtualizationKey)) {
                    Write-Host "Writing Reg Key Values for Hyper-V"
                    Set-ItemProperty -Path $HyperVVirtualizationKey -Name "MinVmVersionForCpuBasedMitigations" -Value "1.0" -Type STRING -Force | Out-Nulll
                }
            }
        }
    }
}

#Tests if the HyperV service is running
if ($null -ne $HyperVService) {
    Write-Host "Hyper-V Host"
    UpdateSpectreKeys -FeatureSettingsOverride 0 -FeatureSettingsOverrideMask 3 -IsHyperV $true
}
else {
    if (($CPU.manufacturer.ToLower() -like "*intel*") -or ($CPU.manufacturer.ToLower() -like "*amd*") ) {
        $IsHyperThreadingEnabled = ($CPU.NumberOfLogicalProcessors -gt $CPU.numberOfCores)
        if ($IsHyperThreadingEnabled) {
            Write-Host "Intel or AMD processor with Hyperthreading"
            UpdateSpectreKeys -FeatureSettingsOverride 72 -FeatureSettingsOverrideMask 3
        }
        elseif ($CPU.manufacturer.ToLower() -like "*intel*" -and $IsHyperThreadingEnabled -eq $false) {
            Write-Host "Intel processor without Hyperthreading"
            UpdateSpectreKeys -FeatureSettingsOverride 6254 -FeatureSettingsOverrideMask 3
        }
    }
}

