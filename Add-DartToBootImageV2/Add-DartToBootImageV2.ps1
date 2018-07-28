##################################################################################################################
#
#  Original Author: Johan Arwidmark <https://deploymentresearch.com/Research/Post/670/Adding-DaRT-to-ConfigMgr-Boot-Images-And-starting-it-earlier-than-early> 
#  Updated By: Richie Schuster - C5 Alliance - SCCMOG.com
#  Date:   28/07/2018
#  Script: Add-DartToBootImageV2.ps1
#  Usage: Powershell.exe -ExecutionPolicy Bypass -File .\Add-DartToBootImageV2.ps1 -EventServiceLocation http://roary-cm-01.roary.local:9800 -BootImageName 'MDT 8450 x64' -MountDrive J -SiteServer ROARY-CM-01.ROARY.LOCAL -SiteCode ROR
#
##################################################################################################################

param(
    [parameter(Mandatory=$true, HelpMessage="Please enter the FQDN of the Server that host the MDT Monitoring Service")]
    [ValidateNotNullOrEmpty()]
    [string]$EventServiceLocation,
    [parameter(Mandatory=$true, HelpMessage="Please enter the name of the bootimage you would like to inject DaRT into.")]
    [ValidateNotNullOrEmpty()]
    [string]$BootImageName,
    [parameter(Mandatory=$true, HelpMessage="Please select the Mount Drive i.e <J>")]
    [ValidateNotNullOrEmpty()]
    [string]$MountDrive,
    [parameter(Mandatory=$true, HelpMessage="Please enter the FQDN of your Site Server")]
    [ValidateNotNullOrEmpty()]
    [string]$SiteServer,
    [parameter(Mandatory=$true, HelpMessage="Please enter you Site Code.")]
    [ValidateNotNullOrEmpty()]
    [string]$SiteCode
)

# Check for elevation
Write-Host "Checking for elevation"

If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "Oupps, you need to run this script from an elevated PowerShell prompt!`nPlease start the PowerShell prompt as an Administrator and re-run the script."
    Write-Warning "Aborting script..."
    Break
}

# Connect to ConfigMgr
if((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
}
if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $SiteServer 
}
Set-Location "$($SiteCode):\" 

# Get Boot image from ConfigMgr
$BootImage = Get-CMBootImage -Name $BootImageName
$BootImagePath = $BootImage.ImagePath
$XMLPath = "$PSScriptRoot\Unattend.xml"
$EnableDart = "$PSScriptRoot\EnableDart.wsf"
$SampleFiles = "$PSScriptroot"
$MountPath = "$($MountDrive):\DartMount"
$MDTFolderName = "Microsoft Deployment Toolkit\Templates"
$REGUninstall = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
$DartDispName = 'Microsoft Dart 10'
$DartFolderName = "Microsoft DaRT"
$DartMSI = "$PSScriptroot\MSDaRT100.msi"

#Function to find folders
Function FindFolder($FolderName){
    $Drives = Get-PSDrive -p FileSystem | Select-Object -ExpandProperty Name
    $InstallPath = $null
    :findfolder Foreach ($drive in $Drives) {
        If ($InstallPath -eq $null) {
            $Counter++
            Write-host "Searching drive $($drive):\ for folder: '$($FolderName)' Drive count is $($Counter) out of $($Drives.Count)" -ForegroundColor Yellow
            $InstallPath = Get-ChildItem -Recurse -Force "$($drive):\" -ErrorAction SilentlyContinue | Where-Object { ($_.PSIsContainer -eq $true) -and ( $_.FullName -like "*$FolderName") } | Select-Object -ExpandProperty FullName
        }
        Else {
                Write-Host "Found folder at: $($InstallPath)" -ForegroundColor Green
                return $InstallPath
                break findfolder
        }
    }
    #Write-Warning "Could not find the install Folder $Foldername exiting";break
    $InstallPath = "NotFound"
    return $InstallPath
}

# Check for PRE Reqs
Set-Location C:
if (!(Test-Path -Path "$XMLPath")) {Write-Warning "Could not find Unattend.xml path, check it is in script root and retry. aborting...";Break}
if (!(Test-Path -Path "$BootImagePath")) {Write-Warning "Could not find boot image, aborting...";Break}
if (!(Test-Path -Path "$DartMSI")) {Write-Warning "Could not DaRT MSI, Please place MSDaRT100.msi in script root folder, aborting...";Break}
if (!(Test-Path -Path "$MountPath")) {
    Write-Warning "Could not find mount path, Creating..."
    try {
        New-item -Path "$MountPath" -ItemType Directory -ErrorAction SilentlyContinue -Force
        Write-Host "Successfully Created Mount Path at:  $($MountPath)" -ForegroundColor Green
    }
    catch [System.Exception]{
        Write-Host "Failed to create Mount Path at:  $($MountPath) Error Message:  $($_.Exception.Message)";Break
    }
    }
#Check if dart is installed - If not install it.
$DaRT10 = Get-ItemProperty "$REGUninstall\*" | Where-Object DisplayName -Like $DartDispName
if($DaRT10.VersionMajor -eq “10”){
    Write-Host "Dart is installed searching for CAB file location"
    $DartInstallPath = FindFolder($DartFolderName)
    $DartCab = $DartInstallPath + "\v10\Toolsx64.cab"
    if (Test-Path -Path "$DartCab"){
        Write-Host "Found DaRT x64 CAB at: $($DartCab)" -ForegroundColor Green
    } 
    else {
        Write-Warning "Could not find DaRT 10 Toolsx64.cab, Please remove older version of DaRT and retry. aborting...";
        Break
    }
}
else{
# Add your way of deploying the application. I.e.:
    Write-Warning "Could not find any DaRT version installed. Installing DaRT MSI in root of folder."
    $DartArgs = "/i $DartMSI /qb /norestart /L*v $env:windir\temp\MSDaRT100_Install.Log"
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $DartArgs -Wait -NoNewWindow -PassThru
    If ($process.ExitCode -ne 0) {
        Write-Warning "Failed to install DaRT 10 please check the log at $($env:windir)\temp\MSDaRT100_Install.Log Install EXITCODE: $process.ExitCode";break
    }
    Else {
        Write-Host "DaRT 10 installed at: $ENV:ProgramFiles\$DartFolderName" -ForegroundColor Green

    }
    $DartCab = "$ENV:ProgramFiles\$DartFolderName" + "\v10\Toolsx64.cab"
    if (!(Test-Path -Path "$DartCab")) {Write-Warning "Could not find DaRT Toolsx64.cab, aborting...";Break}
}
$MDTInstallationPath = FindFolder($MDTFolderName)
if (!(Test-Path -Path "$MDTInstallationPath" -ErrorAction SilentlyContinue)) {Write-Warning "Could not find MDT, please install MDT and re run script, aborting...";Break}
if (!(Test-Path -Path "$EnableDart")) {Write-Warning "Could not find EnableDart.wsf, aborting...";Break}
if (!(Test-Path -Path "$XMLPath")) {Write-Warning "Could not find Unattend.xml, aborting...";Break}

Write-Host "##################################################################################" -ForegroundColor Green
Write-Host "All Pre Reqs found starting continuing..." -ForegroundColor Green
Write-Host "##################################################################################" -ForegroundColor Green

Write-Host "Updating Unattend.XML with new Event Service Location: $($EventServiceLocation)..." -ForegroundColor Green
#Update Unattend.xml with new event service location.
#Get the XML
[xml]$XML = (Get-Content $XMLPath)
#Set the base new command
$UpdateCMD = 'wscript.exe X:\Deploy\Scripts\EnableDart.wsf ','/EventService:',' /_SMSTSCurrentActionName:"Booted into WinPE"'
Write-Host "New CMD will be: $($UpdateCMD[0])$($UpdateCMD[1])$($EventServiceLocation)$($UpdateCMD[2])" -ForegroundColor Yellow
$CMD = $XML.unattend.settings.component.RunSynchronous.RunSynchronousCommand
$CMD.Path = $UpdateCMD[0] + $UpdateCMD[1] + $EventServiceLocation + $UpdateCMD[2]
try {
    $XML.Save($XMLPath)
    Write-Host "Successfully Saved new command line to XML: $($UpdateCMD[0])$($UpdateCMD[1])$($EventServiceLocation)$($UpdateCMD[2])"-ForegroundColor Green
}
Catch [System.Exception]{
    Write-Warning "Failed to Save new command line: '$($UpdateCMD[0])$($UpdateCMD[1])$($EventServiceLocation)$($UpdateCMD[2])' Error Message: '$($_.Exception.Message)' aborting..."
    Break;
}

# Mount the boot image
Mount-WindowsImage -ImagePath $BootImagePath -Index 1 -Path $MountPath  

# Add the needed files to the boot image
expand.exe $DartCab -F:* $MountPath
Remove-Item $MountPath\etfsboot.com -Force
Copy-Item $MDTInstallationPath\DartConfig8.dat $MountPath\Windows\System32\DartConfig.dat


if (!(Test-Path -Path "$MountPath\Deploy\Scripts")) {New-Item -ItemType directory $MountPath\Deploy\Scripts}
if (!(Test-Path -Path "$MountPath\Deploy\Scripts\x64")) {New-Item -ItemType directory $MountPath\Deploy\Scripts\x64}
Copy-Item $EnableDart $MountPath\Deploy\Scripts
Copy-Item $XMLPath $MountPath
Copy-Item "$MDTInstallationPath\Distribution\Scripts\ZTIDataAccess.vbs" $MountPath\Deploy\Scripts
Copy-Item "$MDTInstallationPath\Distribution\Scripts\ZTIUtility.vbs" $MountPath\Deploy\Scripts
Copy-Item "$MDTInstallationPath\Distribution\Scripts\ZTIGather.wsf" $MountPath\Deploy\Scripts
Copy-Item "$MDTInstallationPath\Distribution\Scripts\ZTIGather.xml" $MountPath\Deploy\Scripts
Copy-Item "$MDTInstallationPath\Distribution\Scripts\ztiRunCommandHidden.wsf" $MountPath\Deploy\Scripts
Copy-Item "$MDTInstallationPath\Distribution\Scripts\ZTIDiskUtility.vbs" $MountPath\Deploy\Scripts
Copy-Item "$MDTInstallationPath\Distribution\Tools\x64\Microsoft.BDD.Utility.dll" $MountPath\Deploy\Scripts\x64

# Save changes to the boot image
Dismount-WindowsImage -Path $MountPath -Save
Start-Sleep -Seconds 2
#Cleanup Mount folder
Remove-Item -Path $MountPath -ErrorAction SilentlyContinue -Force

# Update the boot image in ConfigMgr
Set-Location "$($SiteCode):\" 
$GetDistributionStatus = $BootImage | Get-CMDistributionStatus
$OriginalUpdateDate = $GetDistributionStatus.LastUpdateDate
Write-Host "Updating distribution points for the boot image..." -ForegroundColor Yellow
Write-Host "Last update date was: $OriginalUpdateDate" -ForegroundColor Yellow
$BootImage | Update-CMDistributionPoint

# Wait until distribution is done
Write-Output ""
Write-Output "Waiting for distribution status to update..."

Do { 
$GetDistributionStatus = $BootImage | Get-CMDistributionStatus
$NewUpdateDate = $GetDistributionStatus.LastUpdateDate
 if ($NewUpdateDate -gt $OriginalUpdateDate) {
  Write-Output ""
  Write-Host "Yay, boot image distribution status updated. New update date is: $NewUpdateDate" -ForegroundColor Green
  Write-Host "Happy Deployment!" -ForegroundColor Green
 } else {
  Write-Host "Boot image distribution status not yet updated, waiting 10 more seconds"  -ForegroundColor Cyan
 }
 Start-Sleep -Seconds 10
}
Until ($NewUpdateDate -gt $OriginalUpdateDate)