Clear-Host

$VerbosePreference = "continue"

$randomStr = -join ((48..57) + (97..122) | Get-Random -Count 8 | ForEach-Object {[char]$_})
$hostname = "vm-homeassistant-" + $randomStr
$generation = 2
$memory = 4096MB
$switchName = "Bridged Network"
$installPath = "C:\Hyper-V\"
$fullFolderPath = $installPath + $hostname
$url = "https://github.com/home-assistant/operating-system/releases/download/8.1/haos_ova-8.1.vhdx.zip"

#Create new VM
Write-Verbose "Creating new VM"
New-VM -Name $hostname -Generation $generation -MemoryStartupBytes $memory -Path $installPath | Out-Null

do {
$vmIsCreated = Get-VM $hostname
Start-Sleep 1
} until ($vmIsCreated)

Write-Verbose "New VM is created"
Write-Verbose "Hostname is $hostname"

#Disable dynamic memory
$vmIsCreated | Set-VMMemory -DynamicMemoryEnabled $false 
Write-Verbose "Dynamic memory disabled"

#Disable secure boot
$vmIsCreated | Set-VMFirmware -EnableSecureBoot Off
Write-Verbose "Secure boot disabled"

# create vhdx folder
$vhdxFolderName = "Virtual Hard Disks" 
New-Item -Name $vhdxFolderName -ItemType Directory -Path $fullFolderPath | Out-Null
Write-Verbose "Created folder Virtual Hard Disks"

# download vhdx file 
$tempFile = "c:\temp\" + $randomStr + ".zip"

if (-not(Test-Path "c:\temp\")){New-Item -Name "Temp" -ItemType Directory -Path "C:\" | Out-Null}

try{
    Invoke-WebRequest -Uri $url -OutFile $tempFile
}
catch{
    Write-warning "Download failed!"
    pause
}

# unzip vhdx file to VM folder
$unzipDestination = $fullFolderPath + "\" + $vhdxFolderName
Expand-Archive -LiteralPath $tempFile -DestinationPath $unzipDestination

#Connect virtual hard drive to VM
$vhdxFile = (Get-ChildItem $unzipDestination -File).FullName
$vmIsCreated | Add-VMHardDiskDrive -Path $vhdxFile
Write-Verbose "Mounted VHDX file"

# Set first boot to hard disk
$vmIsCreated | Set-VMFirmware -FirstBootDevice (Get-VMHardDiskDrive -VMName $hostname)
Write-Verbose "First boot device set to hard disk drive"

# Connect to bridged network
$vmIsCreated | Get-VMNetworkAdapter | Connect-VMNetworkAdapter -SwitchName $switchName
Write-Verbose "Connected network adapter to $switchName"

# Enable auto start and disable auto checkpoints
$vmIsCreated | Set-VM –AutomaticStartAction Start -AutomaticCheckpointsEnabled $false
Write-Verbose "Enabled automatic start"
Write-Verbose "Disabled automatic checkpoints"

#clean up temp files
Remove-Item $tempFile -Force
Write-Verbose "Cleaned up temp files"