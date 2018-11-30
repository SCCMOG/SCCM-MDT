##################################################################################################################
#Author: Richie Schuster - C5 Alliance - SCCMOG.com
#Date:   24/11/2018
#Script: Action-OSD_Windows10_CommonTasks.ps1
#Usage: Powershell.exe -ExecutionPolicy Bypass -File .\Action-OSD_InjectStartMenu_Offline.ps1
#
##################################################################################################################
# Load Microsoft.SMS.TSEnvironment COM object
try {
    $TSEnvironment = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction Stop
}
catch [System.Exception] {
    Write-Warning -Message "Unable to construct Microsoft.SMS.TSEnvironment object" ; exit 1
}
try {
    Write-Host -Value "Getting OS Disk Location."
    $OSDisk = $TSEnvironment.Value("OSDISK")
    Write-Host -Value "OS Disk Location. $($OSDisk)"
    Write-Host -Value "Importing Default Start Layout."
    Copy-Item "$($PSScriptRoot)\DefaultStart.xml" -Destination "$OSDisk\Users\Default\AppData\Local\Microsoft\Windows\Shell\LayoutModification.xml" -ErrorAction SilentlyContinue -Force
    Write-Host "Successfully Imported Default Start Layout..."
    Write-Host "Removing Cached Default Start Layout..."
    Remove-Item -Path "$OSDisk\Users\Default\AppData\Local\Microsoft\Windows\Shell\DefaultLayouts.xml" -Force
    Write-Host "Successfully removed Cached Default Start Layout..."
}
catch [System.Exception] {
    Write-Host "FAILED Applying - Importing Default start Layout. Error message: $($_.Exception.Message)"
}