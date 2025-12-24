#Requires -RunAsAdministrator

param()

$LogPath = "$PSScriptRoot\create_ubuntu_vm_clean_log.txt"
Start-Transcript -Path $LogPath -Append

# Determine next VM name
$existingVMs = Get-VM | Where-Object { $_.Name -like "ubuntu*" }
$numbers = @()
foreach ($vm in $existingVMs) {
    if ($vm.Name -match '^ubuntu(\d+)$') {
        $numbers += [int]$matches[1]
    }
}
$nextNum = if ($numbers.Count -gt 0) { ($numbers | Measure-Object -Maximum).Maximum + 1 } else { 1 }
$VMName = "ubuntu$nextNum"
Write-Host "Creating VM: $VMName"

# Paths
$VMPath = "C:\VMs\$VMName"
$ImageUrl = "https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-amd64.img"
$ImageCache = "C:\VMs\images\ubuntu-24.04-cloud.img"
$OsVHDXPath = "$VMPath\os.vhdx"
$CidVHDXPath = "$VMPath\cidata.vhdx"
$DataVHDXPath = "$VMPath\data.vhdx"
# Switch configuration - try to find an existing switch
$SwitchName = "Default Switch"
$existingSwitches = Get-VMSwitch
if ($existingSwitches.Name -contains "New Virtual Switch") {
    $SwitchName = "New Virtual Switch"
}
elseif ($existingSwitches.Count -gt 0) {
    # Prefer external switch if available, otherwise take the first one found
    $extSwitch = $existingSwitches | Where-Object { $_.SwitchType -eq 'External' } | Select-Object -First 1
    if ($extSwitch) { $SwitchName = $extSwitch.Name }
    else { $SwitchName = $existingSwitches[0].Name }
}
Write-Host "Using Virtual Switch: $SwitchName"


# Create directories
if (!(Test-Path $VMPath)) { New-Item -ItemType Directory -Path $VMPath }
if (!(Test-Path "C:\VMs\images")) { New-Item -ItemType Directory -Path "C:\VMs\images" }

# Download image if needed
$downloadImage = $false
if (!(Test-Path $ImageCache)) {
    $downloadImage = $true
}
elseif ((Get-Item $ImageCache).LastWriteTime -lt (Get-Date).AddDays(-30)) {
    $downloadImage = $true
}

if ($downloadImage) {
    Write-Host "Downloading Ubuntu cloud image..."
    Invoke-WebRequest -Uri $ImageUrl -OutFile $ImageCache -ErrorAction Stop
}

# Convert to VHDX
Write-Host "Converting image to VHDX..."
if (Test-Path $OsVHDXPath) { Remove-Item $OsVHDXPath -Force }
Start-Process -FilePath "C:\Program Files\qemu\qemu-img.exe" -ArgumentList "convert", "-O", "vhdx", "-o", "subformat=dynamic", $ImageCache, $OsVHDXPath -Wait -NoNewWindow

# Ensure VHDX is uncompressed and not sparse
Write-Host "Optimizing VHDX file..."
& compact.exe /u $OsVHDXPath | Out-Null
& fsutil.exe sparse setflag $OsVHDXPath 0 | Out-Null

Resize-VHD -Path $OsVHDXPath -SizeBytes 50GB

# Create user-data and meta-data - using simple version for reliable SSH
$userData = Get-Content "$PSScriptRoot\user-data-simple" -Raw
$metaData = "instance-id: $VMName`nlocal-hostname: $VMName"

# Copy build scripts to a temporary location for cloud-init
$buildScripts = @(
    "$PSScriptRoot\build-selector.sh",
    "$PSScriptRoot\docker-setup.sh",
    "$PSScriptRoot\post-ssh-setup.sh"
)

# Create cidata VHDX
Write-Host "Creating cidata VHDX..."
if (Test-Path $CidVHDXPath) { Remove-Item $CidVHDXPath -Force }
New-VHD -Path $CidVHDXPath -SizeBytes 100MB -Fixed -ErrorAction Stop | Out-Null
$mounted = Mount-VHD -Path $CidVHDXPath -Passthru
$disk = $mounted | Get-Disk | Initialize-Disk -PartitionStyle MBR -PassThru
$partition = $disk | New-Partition -UseMaximumSize -AssignDriveLetter
Format-Volume -DriveLetter $partition.DriveLetter -FileSystem FAT32 -NewFileSystemLabel "cidata" -Confirm:$false | Out-Null
$drive = "$($partition.DriveLetter):"
$userData | Out-File "$drive\user-data" -Encoding ASCII
$metaData | Out-File "$drive\meta-data" -Encoding ASCII

# Copy build scripts to cloud-init drive
foreach ($script in $buildScripts) {
    if (Test-Path $script) {
        $scriptName = Split-Path $script -Leaf
        Copy-Item $script "$drive\$scriptName" -Force
    }
}

Dismount-VHD -Path $CidVHDXPath

# Create VM
Write-Host "Creating VM..."
New-VM -Name $VMName -MemoryStartupBytes 2GB -Generation 1 -VHDPath $OsVHDXPath -Path "C:\VMs" -SwitchName $SwitchName -ErrorAction Stop
Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $true -MinimumBytes 512MB -StartupBytes 2GB -MaximumBytes 4GB
Set-VMProcessor -VMName $VMName -Count 2
Add-VMHardDiskDrive -VMName $VMName -ControllerType IDE -Path $CidVHDXPath
Get-VM -Name $VMName | Get-VMNetworkAdapter | Set-VMNetworkAdapter -MacAddressSpoofing On

# Add data disk
Write-Host "Adding data disk..."
if (Test-Path $DataVHDXPath) { Remove-Item $DataVHDXPath -Force }
New-VHD -Path $DataVHDXPath -SizeBytes 1TB -Dynamic -ErrorAction Stop | Out-Null
Add-VMScsiController -VMName $VMName
Add-VMHardDiskDrive -VMName $VMName -ControllerType SCSI -Path $DataVHDXPath

# Start VM
Write-Host "Starting VM..."
Start-VM -Name $VMName

# Wait for VM to boot and initialize
Write-Host "VM started. Waiting for initial boot (30 seconds)..."
Start-Sleep -Seconds 30

# Enable enhanced session mode for better VM access
Write-Host "Configuring enhanced VM services..."
Set-VM -Name $VMName -EnhancedSessionTransportType HvSocket

# Quick IP detection
Write-Host "Detecting VM IP address..."
$mac = (Get-VM -Name $VMName | Get-VMNetworkAdapter).MacAddress
$macFormatted = $mac -replace '(.{2})(.{2})(.{2})(.{2})(.{2})(.{2})', '$1:$2:$3:$4:$5:$6'
$macDashed = $mac -replace '(.{2})(.{2})(.{2})(.{2})(.{2})(.{2})', '$1-$2-$3-$4-$5-$6'

# Try ARP table lookup
$arp = arp -a | Select-String -Pattern $macFormatted
if (-not $arp) {
    $arp = arp -a | Select-String -Pattern $macDashed
}

$ip = $null
if ($arp) {
    $arpParts = $arp -split '\s+'
    if ($arpParts.Count -ge 2 -and $arpParts[1] -match '^\d+\.\d+\.\d+\.\d+$') {
        $ip = $arpParts[1]
    }
}

# Display results
Write-Host "`n🎉 === VM CREATION COMPLETE ==="
Write-Host "VM Name: $VMName"
if ($ip) {
    Write-Host "IP Address: $ip"
    Write-Host "SSH Command: ssh root@$ip"
}
else {
    Write-Host "IP Address: Check Hyper-V Manager or use: arp -a | findstr $macFormatted"
    Write-Host "SSH Command: ssh root@<VM_IP>"
}
Write-Host "Username: root"
Write-Host "Password: Passw0rd"
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. SSH to your VM: ssh root@$(if ($ip) { $ip } else { '<VM_IP>' })"
Write-Host "2. Docker is pre-installed and ready!"
Write-Host "3. Choose your Docker build (Personal/Business/Custom)"
Write-Host "4. Access your web services via the displayed URLs"
Write-Host ""
Write-Host "The VM is ready with SSH and Docker!"

Stop-Transcript