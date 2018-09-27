#Set-ConfigMgrMachineVariable
#SCCMOG.com Richie Schuster - 27/09/18
#Gets the value of a ConfigMgr Objects Variable
#E.g <Set-ConfigMgrMachineVariable -Siteserver ROARY-CM-01 -SiteCode ROR -MachineName TUDOR -VarName Hello2 -VarValue Really -VarMasked $false>
#Sets ConfigMgr Variable - will add a new variable if others already set.
Function Set-ConfigMgrMachineVariable {
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

		[parameter(Mandatory=$true, HelpMessage="Variable Name")]
		[ValidateNotNullOrEmpty()]
		[string]$VarName,

		[parameter(Mandatory=$true, HelpMessage="Variable Value")]
		[ValidateNotNullOrEmpty()]
		[string]$VarValue,

		[parameter(Mandatory=$false, HelpMessage="Mask variable - `$true or `$false - Default is `$false")]
		[ValidateNotNullOrEmpty()]
		[bool]$VarMasked = $false
	)
    #Set to null
    $objMachineSettings = $null
    #Get machine resource id
    $objComputer = gwmi -computername $($Siteserver) -namespace "root\sms\site_$($SiteCode)" -class "sms_r_system" | where{$_.Name -eq $MachineName}
    #Get SMS Machine Settings Class
    $objSMSMachineSettings = [WmiClass]"\\$($Siteserver)\ROOT\SMS\site_$($SiteCode):SMS_MachineSettings"
    #Get SMS Machine settings Instances
    $objSMSMachineSettings.GetInstances() | Out-Null
    #Get Machine Settings
    $objMachineSettings = gwmi -computername $($Siteserver) -namespace "root\sms\site_$($SiteCode)" -class "sms_machinesettings" | where{$_.ResourceID -eq $objComputer.ResourceID}

    #test if variables already present
    If ($objMachineSettings -ne $null){
        $objMachineSettings.Get()  
        #Get new array index
        if ($objMachineSettings.MachineVariables.length -ne 0){
            $i = 0
            $newVarIndex = $i
            DO {
            $newVarIndex = $i + 1
            $i++
            } While ($i -le $objMachineSettings.MachineVariables.length - 1)
            $newVarIndex
        }
        else {
            $newVarIndex = 0
        }
        #Create the new emty variable
        $objMachineSettings.MachineVariables = $objMachineSettings.MachineVariables += [WmiClass]"\\$($Siteserver)\ROOT\SMS\site_$($SiteCode):SMS_MachineVariable"
        #get array of variables
        $arrayMachineVariables = $objMachineSettings.MachineVariables
        #set new variable
        $arrayMachineVariables[$newVarIndex].name=$varName
        $arrayMachineVariables[$newVarIndex].value=$VarValue
        $arrayMachineVariables[$newVarIndex].ismasked = $VarMasked
    }
    Else {
        #Create Machine instance
        $objMachineSettings = $objSMSMachineSettings.CreateInstance()
        #Create base properties
        $objMachineSettings.psbase.properties["ResourceID"].value = $($objComputer.ResourceID)
        $objMachineSettings.psbase.properties["SourceSite"].value = $($SiteCode)
        $objMachineSettings.psbase.properties["LocaleID"].value = 1033
        #Create empty variable
        $objMachineSettings.MachineVariables = $objMachineSettings.MachineVariables + [WmiClass]"\\$($Siteserver)\ROOT\SMS\site_$($SiteCode):SMS_MachineVariable"
        #get array of variables
        $arrayMachineVariables = $objMachineSettings.MachineVariables
        #set the new variable
        $arrayMachineVariables[0].name=$varName
        $arrayMachineVariables[0].value=$VarValue
        $arrayMachineVariables[0].ismasked = $VarMasked
    }
    # write the variables back to the machine object 
    $objMachineSettings.MachineVariables = $arrayMachineVariables
    #Save the new Variable
    $objMachineSettings.put()
}


