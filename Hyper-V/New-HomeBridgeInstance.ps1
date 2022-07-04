Clear-Host

$VerbosePreference = "continue"

$randomStr = -join ((48..57) + (97..122) | Get-Random -Count 8 | ForEach-Object {[char]$_})
$hostname = "vm-homebridge-" + $randomStr
$generation = 1
$diskname = "disk-homebridge-" + $randomStr + ".vhdx"
$disksize = 8GB
$memory = 1024MB
$switchName = "Bridged Network"
$installPath = "C:\Hyper-V\"
$fullFolderPath = $installPath + $hostname
$url = "https://github.com/oznu/homebridge-vm-image/releases/latest/download/homebridge-vm-image.iso"

#Create new VM
Write-Verbose "Creating new VM"
New-VM -Name $hostname -Generation $generation -MemoryStartupBytes $memory -Path $installPath | Out-Null

# create vhdx folder
$vhdxFolderName = "Virtual Hard Disks" 
New-Item -Name $vhdxFolderName -ItemType Directory -Path $fullFolderPath | Out-Null
Write-Verbose "Created folder Virtual Hard Disks"

do {
$vmIsCreated = Get-VM $hostname
Start-Sleep 1
} until ($vmIsCreated)

Write-Verbose "New VM is created"
Write-Verbose "Hostname is $hostname"

# Create new vhdx
$vhdxFile = $fullFolderPath + "\" + $vhdxFolderName + "\" + $diskname
$createdDisk = New-VHD -Path $vhdxFile -SizeBytes $disksize -Dynamic
Write-Verbose "Created disk $($createdDisk.Path)"

#Connect virtual hard drive to VM
$vmIsCreated | Add-VMHardDiskDrive -Path $createdDisk.Path
Write-Verbose "Mounted VHDX file"

#Disable dynamic memory
$vmIsCreated | Set-VMMemory -DynamicMemoryEnabled $false 
Write-Verbose "Dynamic memory disabled"

# Create ISO folder
$newFolder = New-Item -Name "ISO" -ItemType Directory -Path $fullFolderPath
Write-Verbose "Created folder $($newFolder.FullName)"

# Download ISO file
$ISO = $fullFolderPath + "\" + "ISO\homebridge-vm-image.iso"

try{
    Invoke-WebRequest -Uri $url -OutFile $ISO
}
catch{
    Write-Warning "Download failed!"
    pause
}

# Mount ISO file
Set-VMDvdDrive -VMName $hostname -ControllerNumber 1 -Path $ISO

# Connect to bridged network
$vmIsCreated | Get-VMNetworkAdapter | Connect-VMNetworkAdapter -SwitchName $switchName
Write-Verbose "Connected network adapter to $switchName"

# Enable auto start and disable auto checkpoints
$vmIsCreated | Set-VM –AutomaticStartAction Start -AutomaticCheckpointsEnabled $false
Write-Verbose "Enabled automatic start"
Write-Verbose "Disabled automatic checkpoints"

Write-Verbose "Done!"