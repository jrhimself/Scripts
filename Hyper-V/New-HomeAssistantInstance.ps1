<#
.SYNOPSIS
    This script creates a new VM in Hyper-V for Home Assistant. 
    It will download the latest version from Github and mount the hard disk file (.vhdx) to the VM. 

    By default, the script will generate a hostname and creates a VM with 4GB memory in folder C:\Hyper-V\. 
    The first external network will be selected if no network is specified.

    Use the parameters in the example to specify hostname, memory size, location and network of the VM.
 
.NOTES
    Name: New-HomeAssistantInstance
    Author: jrhimself
    Version: 1.0
    DateCreated: 2022-Jun-02
 
.EXAMPLE
    .\New-HomeAssistantInstance.ps1 
    .\New-HomeAssistantInstance.ps1 "Homeassistant"
    .\New-HomeAssistantInstance.ps1 -Hostname "HomeAssistant" -Memory 4096MB -Path "C:\Hyper-V\" -Switchname "Some Network"
 
.LINK
    https://github.com/jrhimself

#>
 
[CmdletBinding()]
param(
    [Parameter(
        Mandatory = $false,
        Position=0
        )]
    [string] $hostname,
    [Parameter(
        Mandatory = $false
        )]
    [string] $memory = 4096MB,
    [Parameter(
        Mandatory = $false
        )]
    [string] $path = "C:\Hyper-V\",
    [Parameter(
        Mandatory = $false
        )]
    [string] $switchname = (Get-VMSwitch -SwitchType External)[0].Name
)

Clear-Host

$VerbosePreference = "continue"

# Generate random string and default hostname
$randomStr = -join ((48..57) + (97..122) | Get-Random -Count 8 | ForEach-Object {[char]$_})
if (!$hostname){$hostname = "vm-homeassistant-" + $randomStr}

# Fix missing character
if ($path.Substring($path.Length - 1) -ne "\"){
    $path = $path + "\"
}

# Create folder if not exist
if (-not(Test-Path $path)){
    New-Item -Path $path -ItemType Directory | Out-Null
    Write-Verbose "Created folder $path"
}

# Create new VM
$generation = 2
Write-Verbose "Creating new VM"
New-VM -Name $hostname -Generation $generation -MemoryStartupBytes $memory -Path $path | Out-Null

do {
$createdVM = Get-VM $hostname -ErrorAction SilentlyContinue
Write-Verbose "Waiting for VM to be created"
Start-Sleep 1
} until ($createdVM)

Write-Verbose "New VM is created"
Write-Verbose "Hostname is $hostname"

# Disable dynamic memory
$createdVM | Set-VMMemory -DynamicMemoryEnabled $false 
Write-Verbose "Dynamic memory disabled"

# Disable secure boot
$createdVM | Set-VMFirmware -EnableSecureBoot Off
Write-Verbose "Secure boot disabled"

# Create vhdx folder
$vhdxFolderName = "Virtual Hard Disks"
$fullFolderPath = $path + $hostname
New-Item -Name $vhdxFolderName -ItemType Directory -Path $fullFolderPath | Out-Null
Write-Verbose "Created folder $vhdxFolderName"

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
$unzipDestination = $fullFolderPath + "\" + $vhdxFolderName + "\"
Expand-Archive -LiteralPath $tempFile -DestinationPath $unzipDestination

# Connect virtual hard drive to VM
$vhdxFile = (Get-ChildItem $unzipDestination -File | Where-Object {$_.Name -like '*.vhdx'}).FullName
$createdVM | Add-VMHardDiskDrive -Path $vhdxFile
Write-Verbose "Mounted VHDX file"

# Set first boot to hard disk
$createdVM | Set-VMFirmware -FirstBootDevice (Get-VMHardDiskDrive -VMName $hostname)
Write-Verbose "First boot device set to hard disk drive"

# Connect to network
if ($switchName){
    $createdVM | Get-VMNetworkAdapter | Connect-VMNetworkAdapter -SwitchName $switchName
    Write-Verbose "Connected network adapter to $switchName"
}

# Enable auto start and disable auto checkpoints
$createdVM | Set-VM -AutomaticStartAction Start -AutomaticCheckpointsEnabled $false
Write-Verbose "Enabled automatic start"
Write-Verbose "Disabled automatic checkpoints"

# Clean up temp files
Remove-Item $tempFile -Force
Write-Verbose "Cleaned up temp files"


