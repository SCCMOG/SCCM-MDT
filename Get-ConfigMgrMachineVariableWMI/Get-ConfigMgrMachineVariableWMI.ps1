#Get-ConfigMgrMachineVariableWMI
#SCCMOG.com Richie Schuster - 27/09/18
#Gets the value of a ConfigMgr Objects Variable
#E.g <Get-ConfigMgrMachineVariable -Siteserver $Siteserver -SiteCode $SiteCode -MachineName TUDOR -VarName "Hello2">
#Returns blank string if not found and value if found.
Function Get-ConfigMgrMachineVariable{
	param(
		[parameter(Mandatory=$true, HelpMessage="Site server FQDN")]
		[ValidateNotNullOrEmpty()]
		[string]$Siteserver,

		[parameter(Mandatory=$true, HelpMessage="SCCM Site Code")]
		[ValidateNotNullOrEmpty()]
		[string]$SiteCode,

		[parameter(Mandatory=$true, HelpMessage="ConfigMgr Machine Object to add Variable to")]
		[ValidateNotNullOrEmpty()]
		[string]$MachineName,

		[parameter(Mandatory=$true, HelpMessage="Variable Name to query for.")]
		[ValidateNotNullOrEmpty()]
		[string]$VarName
	)
    #Set to null
    $objMachineSettings = $null
    #Get machine object from ConfigMgr
    $objComputer = gwmi -computername $($Siteserver) -namespace "root\sms\site_$($SiteCode)" -class "sms_r_system" | where{$_.Name -eq $MachineName}
    #Get settings from ConfigMgr
    $objMachineSettings = gwmi -computername $($Siteserver) -namespace "root\sms\site_$($SiteCode)" -class "sms_machinesettings" | where{$_.ResourceID -eq $objComputer.ResourceID}
    If ($objMachineSettings -ne $null){
        $objMachineSettings.get()
        If ($objMachineSettings.MachineVariables | where{$_.Name -eq "$VarName"}) {
            $variable = (($objMachineSettings.MachineVariables | where{$_.Name -eq "$VarName"}).Value).Trim()
            return $variable
        }
        Else {
            $variable = ""
            return $variable
        }
    }
    else {
        $variable = ""
        return $variable
    }   
}