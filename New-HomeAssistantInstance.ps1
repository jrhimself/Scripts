<#
.SYNOPSIS
    This script creates a new VM in Hyper-V for Home Assistant. 
    It will download the latest version from Github and mount the hard disk file (.vhdx) to the VM. 
    Use the parameters in the example to specify location, memory size and network of the VM.
 
.NOTES
    Name: New-HomeAssistantInstance
    Author: jr_himself
    Version: 1.0
    DateCreated: 2022-Jun-02
 
.EXAMPLE
    New-HomeAssistantInstance -Path "C:\Hyper-V\" -Memory 4096MB -Switchname "Bridged Network"
 
.LINK
    https://github.com/jrhimself

#>
 
[CmdletBinding()]
param(
    [Parameter(
        Mandatory = $false,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        Position = 0
        )]
    [string] $Path = "C:\Hyper-V\",
    [Parameter(
        Mandatory = $false
        )]
    [string] $Memory = 4096MB,
    [Parameter(
        Mandatory = $false
        )]
    [string] $Switchname = "Bridged Network"
)

Clear-Host

$VerbosePreference = "continue"

$randomStr = -join ((48..57) + (97..122) | Get-Random -Count 8 | ForEach-Object {[char]$_})
$hostname = "vm-homeassistant-" + $randomStr
$generation = 2
$fullFolderPath = $Path + $hostname

# Create new VM
Write-Verbose "Creating new VM"
New-VM -Name $hostname -Generation $generation -MemoryStartupBytes $memory -Path $path | Out-Null

do {
$vmIsCreated = Get-VM $hostname
Start-Sleep 1
} until ($vmIsCreated)

Write-Verbose "New VM is created"
Write-Verbose "Hostname is $hostname"

# Disable dynamic memory
$vmIsCreated | Set-VMMemory -DynamicMemoryEnabled $false 
Write-Verbose "Dynamic memory disabled"

# Disable secure boot
$vmIsCreated | Set-VMFirmware -EnableSecureBoot Off
Write-Verbose "Secure boot disabled"

# Create vhdx folder
$vhdxFolderName = "Virtual Hard Disks" 
New-Item -Name $vhdxFolderName -ItemType Directory -Path $fullFolderPath | Out-Null
Write-Verbose "Created folder Virtual Hard Disks"

# Download vhdx file 
$tempFile = $fullFolderPath + "\" + $vhdxFolderName + "\" + $randomStr + ".zip"
$repo = "home-assistant/operating-system"
$releases = "https://api.github.com/repos/$repo/releases"

Write-Verbose "Determining latest release"
$tag = (Invoke-WebRequest $releases | ConvertFrom-Json)[0].tag_name
Write-Verbose "Latest release = $tag"

$url = "https://github.com/home-assistant/operating-system/releases/download/$tag/haos_ova-$tag.vhdx.zip"

try{
    Invoke-WebRequest -Uri $url -OutFile $tempFile
}
catch{
    Write-warning "Download failed!"
}

# Unzip vhdx file
$unzipDestination = $fullFolderPath + "\" + $vhdxFolderName
Expand-Archive -LiteralPath $tempFile -DestinationPath $unzipDestination

# Connect virtual hard drive to VM
$vhdxFile = (Get-ChildItem $unzipDestination -File | Where-Object {$_.Name -like '*.vhdx'}).FullName
$vmIsCreated | Add-VMHardDiskDrive -Path $vhdxFile
Write-Verbose "Mounted VHDX file"

# Set first boot to hard disk
$vmIsCreated | Set-VMFirmware -FirstBootDevice (Get-VMHardDiskDrive -VMName $hostname)
Write-Verbose "First boot device set to hard disk drive"

# Connect to network
if ($switchName){
    $vmIsCreated | Get-VMNetworkAdapter | Connect-VMNetworkAdapter -SwitchName $switchName
    Write-Verbose "Connected network adapter to $switchName"
}

# Enable auto start and disable auto checkpoints
$vmIsCreated | Set-VM -AutomaticStartAction Start -AutomaticCheckpointsEnabled $false
Write-Verbose "Enabled automatic start"
Write-Verbose "Disabled automatic checkpoints"

# Clean up temp files
Remove-Item $tempFile -Force
Write-Verbose "Cleaned up temp files"