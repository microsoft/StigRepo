function Publish-AzAutomationModules
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [string]
        $RootPath = (Get-Location).Path,

        [Parameter(Mandatory=$true)]
        [string]
        $ResourceGroupName,

        [Parameter(Mandatory=$true)]
        [string]
        $AutomationAccountName,

        [Parameter()]
        [switch]
        $PSGallery
    )

    Write-Output "Starting Azure Automation Module Sync"

    # Check for Az Context
    $azContext = Get-AzContext -ErrorAction SilentlyContinue
    if ($null -eq $azContext)
    {
        Write-Output "`tAzure Subscription not connected - Follow prompt to login."
        Connect-AzAccount
    }

    # Get local PowerSTIG Module Version
    Import-Module PowerSTIG -ErrorAction SilentlyContinue
    $installedversion = (Get-Module PowerSTIG -ErrorAction SilentlyContinue).version.ToString()

    switch ($PSGallery)
    {
        $false
        {
            # Check for valid Stig-Repo
            Write-Output "`tChecking for valid StigRepo location at $RootPath"
            $modulePath = "$Rootpath\Resources\Modules"

            if (Test-Path "$modulePath")
            {
                Write-Output "`t`tStigRepo Location is valid"
            }
            else
            {
                Write-Output "`t`t$Rootpath is not a SCAR repository. Please point to the SCAR directory or run Initialize-StigRepo to build it."
                exit
            }

            # Sync DSC Modules Locally
            Write-Output "`tValidating local PowerSTIG Modules"

            Import-Module PowerSTIG -ErrorAction SilentlyContinue
            $stigRepoVersion = (Get-Childitem "$modulePath\PowerSTIG" -ErrorAction SilentlyContinue).name
            $installedversion = (Get-Module PowerSTIG -ErrorAction SilentlyContinue).version.ToString()

            if (($installedVersion -ne $stigRepoVersion) -or ($null -eq $installedversion))
            {
                Write-Output "`t`tSyncing PowerSTIG Modules on localhost"
                Sync-DscModules -LocalHost -Force
                Import-Module PowerSTIG
                $installedVersion = (Get-Module PowerSTIG).version.tostring()
            }

            if ($null -ne $installedVersion)
            {
                Write-Output "`t`tPowerSTIG Module is valid."
            }
            else
            {
                Write-Output "`t`tError - Unable to install PowerSTIG module on the local system."
                exit
            }
            break
        }
        $true
        {
            Write-Output "`tValidating local PowerSTIG Modules"
            Import-Module StigRepo -ErrorAction SilentlyContinue
            $stigRepoModule = Get-Module -Name StigRepo -ErrorAction SilentlyContinue

            try 
            {
                if ($null -ne $stigRepoModule)
                {
                    Write-Output "`t`tStigRepo module is valid"
                }
                else
                {
                    Write-Output "`t`tStigRepo Module not installed - Downloading from PS Gallery"
                    Save-Module -Name StigRepo -Path "$env:SystemDrive\Program Files\WindowsPowershell\Modules" -Force
                    Import-Module StigRepo -Force
                }

                if ($null -ne $installedVersion)
                {
                    Write-Output "`t`tPowerSTIG Module is valid"
                }
                else
                {
                    Write-Output "PowerSTIG Module not installed - Installing from PowerShell gallery"
                    Save-Module -Name PowerSTIG -Path "$env:SystemDrive\Program Files\WindowsPowershell\Modules" -Force
                    Import-Module PowerSTIG,StigRepo -Force
                }
            }
            catch
            {
                Write-Output "`t`tUnable to install PowerSTIG Module"
                Throw $_
                exit
            }
        }
    }

    # Publish Modules to Azure Automation
    Write-Output "`tPublishing Modules to Azure Automation"

    # Import Modules w/ dependencies
    $keyModules = "PowerSTIG","VMWare.Vim","VMWare.VimAutomation.Common","StigRepo"
    Import-Module $keyModules
    $importedKeyModules = Get-Module $keyModules

    # Add dependent modules to array
    $moduleList = New-Object System.Collections.ArrayList
    (Get-Module VMWare.VimAutomation.Common).RequiredModules | Foreach-Object { $null = $moduleList.Add($_) }
    (Get-Module VMWare.Vim).RequiredModules | Foreach-Object { $null = $moduleList.Add($_) }
    (Get-Module PowerSTIG ).requiredModules | Foreach-Object { $null = $moduleList.Add($_) }

    # Add key modules to array after dependencies
    $importedKeyModules | Foreach-Object { $null = $moduleList.Add($_) }

    foreach ($module in $moduleList)
    {
        $moduleName    = $module.name
        $moduleversion = $module.version.tostring()

        try
        {
            Write-Output "`t`tPublishing $moduleName Version $moduleVersion"
            $null = New-AzAutomationModule -Name $moduleName -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -ContentLinkUri "https://www.powershellgallery.com/api/v2/package/$moduleName/$moduleVersion" -ErrorAction Stop
        }
        catch
        {
            Write-Output "Publishing $moduleName Failed"
            Throw $_
        }
    }
    Write-Output "`n`n`tAzure Automation Module Sync complete."
}

function New-AzSystemData
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $RootPath = (Get-Location).Path,

        [Parameter()]
        [string]
        $ResourceGroupName,

        [Parameter()]
        [string]
        $StorageAccountName = "scarstorage",

        [Parameter()]
        [string]
        $ContainerName = "Systems",

        [Parameter()]
        [switch]
        $IncludeFilePaths,

        [Parameter()]
        [switch]
        $IncludeLCMSettings,

        $LcmSettings = @{
            actionAfterReboot              = ""
            agentId                        = ""
            allowModuleOverwrite           = $True
            certificateID                  = ""
            configurationDownloadManagers  = ""
            configurationID                = ""
            configurationMode              = "ApplyAndAutoCorrect"
            configurationModeFrequencyMins = "15"
            credential                     = ""
            debugMode                      = ""
            downloadManagerCustomData      = ""
            downloadManagerName            = ""
            lcmStateDetail                 = ""
            maximumDownloadSizeMB          = "500"
            partialConfigurations          = ""
            rebootNodeIfNeeded             = $False
            refreshFrequencyMins           = "30"
            refreshMode                    = "PUSH"
            reportManagers                 = "{}"
            resourceModuleManagers         = "{}"
            signatureValidationPolicy      = ""
            signatureValidations           = "{}"
            statusRetentionTimeInDays      = "10"
        }
    )

    Write-Output "Starting Azure SystemData Creation"

    $systemsPath     = (Resolve-Path "$RootPath\Systems").Path
    $resourceGroups  = New-Object System.Collections.ArrayList
    $virtualMachines = New-Object System.Collections.ArrayList

    if ("" -eq $ResourceGroupName) { Get-AzVM | ForEach-Object { $null = $virtualMachines.Add($_) } }
    else { Get-AzVM -ResourceGroupName $ResourceGroupName | ForEach-Object { $null = $virtualMachines.Add($_) } }

    $virtualMachines.ResourceGroupName | Get-Unique | Foreach-Object { $null = $resourceGroups.Add($_) }

    foreach ($resourceGroup in $ResourceGroups)
    {
        Write-Output "`t$ResourceGroup - Generating System Data"

        $jobs               = New-Object System.Collections.ArrayList
        $rgFolder           = (New-Item -ItemType Directory -Path "$SystemsPath\$resourceGroup" -Force).FullName
        $resourceGroupVMs   = $virtualMachines | Where-Object ResourceGroupName -eq $resourceGroup

        #region VirtualMachine Jobs
        foreach ($virtualMachine in $resourceGroupVms)
        {
            Write-Output "`t`tStarting Job - $($virtualMachine.name)"
            $osVersion = $virtualMachine.StorageProfile.ImageReference.Sku
            $vmName = $virtualMachine.Name

            $job = Start-Job -ScriptBlock {

                $RootPath           = $using:rootPath
                $resourceGroup      = $using:resourceGroup
                $rgFolder           = $using:rgFolder
                $osVersion          = $using:osVersion
                $vmName             = $using:vmName
                $LcmSettings        = $using:LcmSettings
                $dataFilePath       = New-Item "$rgFolder\$vmName.psd1" -Force
                $applicableStigs    = New-Object System.Collections.ArrayList

                #region STIG Applicability
                if ($DomainControllers)
                {
                    $osRole = 'DC'
                    $null = $applicableStigs.add("DomainController")
                }
                else
                {
                    $osRole = 'MS'
                    $null = $applicableStigs.add("WindowsServer")
                }

                $null = $applicableStigs.add("InternetExplorer")
                $null = $applicableStigs.add("WindowsFirewall")
                $null = $applicableStigs.add("WindowsDefender")
                $null = $applicableStigs.add("DotnetFramework")
                #endRegion

                #region Get STIG Files
                if ($IncludeFilePaths)
                {
                    switch -Wildcard ($applicableStigs)
                    {
                        "WindowsServer*"
                        {
                            $osStigFiles = @{
                                orgSettings  = Get-StigFiles -Rootpath $RootPath -StigType "WindowsServer" -Version $osVersion -FileType "OrgSettings" -NodeName $vmName
                                xccdfPath    = Get-StigFiles -Rootpath $RootPath -StigType "WindowsServer" -Version $osVersion -FileType "Xccdf" -NodeName $vmName
                                manualChecks = Get-StigFiles -Rootpath $RootPath -StigType "WindowsServer" -Version $osVersion -FileType "ManualChecks" -NodeName $vmName
                            }
                        }
                        "DotNetFramework"
                        {
                            $dotNetStigFiles = @{
                                orgsettings  = Get-StigFiles -Rootpath $Rootpath -StigType "DotNetFramework" -Version 4 -FileType "OrgSettings" -NodeName $vmName
                                xccdfPath    = Get-StigFiles -Rootpath $Rootpath -StigType "DotNetFramework" -Version 4 -FileType "Xccdf" -NodeName $vmName
                                manualChecks = Get-StigFiles -Rootpath $Rootpath -StigType "DotNetFramework" -Version 4 -FileType "ManualChecks" -NodeName $vmName
                            }
                        }
                        "InternetExplorer"
                        {
                            $ieStigFiles = @{
                                xccdfPath      = Get-StigFiles -Rootpath $Rootpath -StigType "InternetExplorer" -Version 11 -FileType "Xccdf" -NodeName $vmName
                                orgSettings    = Get-StigFiles -Rootpath $Rootpath -StigType "InternetExplorer" -Version 11 -FileType "OrgSettings" -NodeName $vmName
                                manualChecks   = Get-StigFiles -Rootpath $Rootpath -StigType "InternetExplorer" -Version 11 -FileType "ManualChecks" -NodeName $vmName
                            }
                        }
                        "WindowsClient"
                        {
                            $Win10StigFiles = @{
                                orgSettings  = Get-StigFiles -Rootpath $RootPath -StigType "WindowsClient" -Version $osVersion -FileType "OrgSettings" -NodeName $vmName
                                xccdfPath    = Get-StigFiles -Rootpath $RootPath -StigType "WindowsClient" -Version $osVersion -FileType "Xccdf" -NodeName $vmName
                                manualChecks = Get-StigFiles -Rootpath $RootPath -StigType "WindowsClient" -Version $osVersion -FileType "ManualChecks" -NodeName $vmName
                            }
                        }
                        "WindowsDefender"
                        {
                            $WinDefenderStigFiles = @{
                                orgSettings  = Get-StigFiles -Rootpath $RootPath -StigType "WindowsDefender" -FileType "OrgSettings" -NodeName $vmName
                                xccdfPath    = Get-StigFiles -Rootpath $RootPath -StigType "WindowsDefender" -FileType "Xccdf" -NodeName $vmName
                                manualChecks = Get-StigFiles -Rootpath $RootPath -StigType "WindowsDefender" -FileType "ManualChecks" -NodeName $vmName
                            }
                        }
                        "WindowsFirewall"
                        {
                            $WinFirewallStigFiles = @{
                                orgSettings  = Get-StigFiles -Rootpath $RootPath -StigType "WindowsFirewall" -FileType "OrgSettings" -NodeName $vmName
                                xccdfPath    = Get-StigFiles -Rootpath $RootPath -StigType "WindowsFirewall" -FileType "Xccdf" -NodeName $vmName
                                manualChecks = Get-StigFiles -Rootpath $RootPath -StigType "WindowsFirewall" -FileType "ManualChecks" -NodeName $vmName
                            }
                        }
                        "WindowsDnsServer"
                        {
                            $WindowsDnsStigFiles = @{
                                orgSettings  = Get-StigFiles -Rootpath $RootPath -StigType "WindowsDnsServer" -FileType "OrgSettings" -NodeName $vmName
                                xccdfPath    = Get-StigFiles -Rootpath $RootPath -StigType "WindowsDnsServer" -FileType "Xccdf" -NodeName $vmName
                                manualChecks = Get-StigFiles -Rootpath $RootPath -StigType "WindowsDnsServer" -FileType "ManualChecks" -NodeName $vmName
                            }
                        }
                        "Office2016"
                        {
                            $word2016xccdfPath          = Get-StigFiles -Rootpath $Rootpath -StigType "Office2016_Word" -Version 16 -FileType "Xccdf" -NodeName $vmName
                            $word2016orgSettings        = Get-StigFiles -Rootpath $Rootpath -StigType "Office2016_Word" -Version 16 -FileType "OrgSettings" -NodeName $vmName
                            $word2016manualChecks       = Get-StigFiles -Rootpath $Rootpath -StigType "Office2016_Word" -Version 16 -FileType "ManualChecks" -NodeName $vmName
                            $powerpoint2016xccdfPath    = Get-StigFiles -Rootpath $Rootpath -StigType "Office2016_PowerPoint" -Version 16 -FileType "Xccdf" -NodeName $vmName
                            $powerpoint2016orgSettings  = Get-StigFiles -Rootpath $Rootpath -StigType "Office2016_PowerPoint" -Version 16 -FileType "OrgSettings" -NodeName $vmName
                            $powerpoint2016manualChecks = Get-StigFiles -Rootpath $Rootpath -StigType "Office2016_PowerPoint" -Version 16 -FileType "ManualChecks" -NodeName $vmName
                            $outlook2016xccdfPath       = Get-StigFiles -Rootpath $Rootpath -StigType "Office2016_Outlook" -Version 16 -FileType "Xccdf" -NodeName $vmName
                            $outlook2016orgSettings     = Get-StigFiles -Rootpath $Rootpath -StigType "Office2016_Outlook" -Version 16 -FileType "OrgSettings" -NodeName $vmName
                            $outlook2016manualChecks    = Get-StigFiles -Rootpath $Rootpath -StigType "Office2016_Outlook" -Version 16 -FileType "ManualChecks" -NodeName $vmName
                            $excel2016xccdfPath         = Get-StigFiles -Rootpath $Rootpath -StigType "Office2016_Excel" -Version 16 -FileType "Xccdf" -NodeName $vmName
                            $excel2016orgSettings       = Get-StigFiles -Rootpath $Rootpath -StigType "Office2016_Excel" -Version 16 -FileType "OrgSettings" -NodeName $vmName
                            $excel2016manualChecks      = Get-StigFiles -Rootpath $Rootpath -StigType "Office2016_Excel" -Version 16 -FileType "ManualChecks" -NodeName $vmName
                        }
                        "Office2013"
                        {
                            $word2013xccdfPath          = Get-StigFiles -Rootpath $Rootpath -StigType "Office2013_word" -Version 15 -FileType "Xccdf" -NodeName $vmName
                            $word2013orgSettings        = Get-StigFiles -Rootpath $Rootpath -StigType "Office2013_word" -Version 15 -FileType "OrgSettings" -NodeName $vmName
                            $word2013manualChecks       = Get-StigFiles -Rootpath $Rootpath -StigType "Office2013_word" -Version 15 -FileType "ManualChecks" -NodeName $vmName
                            $powerpoint2013xccdfPath    = Get-StigFiles -Rootpath $Rootpath -StigType "Office2013_powerpoint" -Version 15 -FileType "Xccdf" -NodeName $vmName
                            $powerpoint2013orgSettings  = Get-StigFiles -Rootpath $Rootpath -StigType "Office2013_powerpoint" -Version 15 -FileType "OrgSettings" -NodeName $vmName
                            $powerpoint2013manualChecks = Get-StigFiles -Rootpath $Rootpath -StigType "Office2013_powerpoint" -Version 15 -FileType "ManualChecks" -NodeName $vmName
                            $outlook2013xccdfPath       = Get-StigFiles -Rootpath $Rootpath -StigType "Office2013_outlook" -Version 15 -FileType "Xccdf" -NodeName $vmName
                            $outlook2013orgSettings     = Get-StigFiles -Rootpath $Rootpath -StigType "Office2013_outlook" -Version 15 -FileType "OrgSettings" -NodeName $vmName
                            $outlook2013manualChecks    = Get-StigFiles -Rootpath $Rootpath -StigType "Office2013_outlook" -Version 15 -FileType "ManualChecks" -NodeName $vmName
                            $excel2013xccdfPath         = Get-StigFiles -Rootpath $Rootpath -StigType "Office2013_excel" -Version 15 -FileType "Xccdf" -NodeName $vmName
                            $excel2013orgSettings       = Get-StigFiles -Rootpath $Rootpath -StigType "Office2013_excel" -Version 15 -FileType "OrgSettings" -NodeName $vmName
                            $excel2013manualChecks      = Get-StigFiles -Rootpath $Rootpath -StigType "Office2013_excel" -Version 15 -FileType "ManualChecks" -NodeName $vmName
                        }
                        "SQLServerInstance"
                        {
                            $version = "2016"
                            $sqlInstanceStigFiles = @{
                                xccdfPath      = Get-StigFiles -Rootpath $Rootpath -Version $Version -StigType "SqlServerInstance" -FileType "Xccdf" -NodeName $vmName
                                orgSettings    = Get-StigFiles -Rootpath $Rootpath -Version $Version -StigType "SqlServerInstance" -FileType "OrgSettings" -NodeName $vmName
                                manualChecks   = Get-StigFiles -Rootpath $Rootpath -Version $Version -StigType "SqlServerInstance" -FileType "ManualChecks" -NodeName $vmName
                            }
                        }
                        "SqlServerDatabase"
                        {
                            $sqlDatabaseStigFiles = @{
                                xccdfPath      = Get-StigFiles -Rootpath $Rootpath -Version $Version -StigType "SqlServerDataBase" -FileType "Xccdf" -NodeName $vmName
                                orgSettings    = Get-StigFiles -Rootpath $Rootpath -Version $Version -StigType "SqlServerDataBase" -FileType "OrgSettings" -NodeName $vmName
                                manualChecks   = Get-StigFiles -Rootpath $Rootpath -Version $Version -StigType "SqlServerDataBase" -FileType "ManualChecks" -NodeName $vmName
                            }
                        }
                        "WebSite*"
                        {
                            $iisVersion = Invoke-Command -ComputerName $vmName -Scriptblock {
                                $iisData = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\InetStp"
                                $localIisVersion = "$($iisData.MajorVersion).$($iisData.MinorVersion)"
                                return $localiisVersion
                            }
                            $WebsiteStigFiles = @{
                                xccdfPath      = Get-StigFiles -Rootpath $Rootpath -StigType "WebSite" -Version $iisVersion -FileType "Xccdf" -NodeName $vmName
                                orgSettings    = Get-StigFiles -Rootpath $Rootpath -StigType "WebSite" -Version $iisVersion -FileType "OrgSettings" -NodeName $vmName
                                manualChecks   = Get-StigFiles -Rootpath $Rootpath -StigType "WebSite" -Version $iisVersion -FileType "ManualChecks" -NodeName $vmName
                            }
                        }
                        "WebServer*"
                        {
                            [decimal]$iisVersion = Invoke-Command -ComputerName $vmName -Scriptblock {
                                $iisData = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\InetStp"
                                $localIisVersion = "$($iisData.MajorVersion).$($iisData.MinorVersion)"
                                return $localiisVersion
                            }
                            $webServerStigFiles = @{
                                xccdfPath      = Get-StigFiles -Rootpath $Rootpath -StigType "WebServer" -Version $iisVersion -FileType "Xccdf" -NodeName $vmName
                                orgSettings    = Get-StigFiles -Rootpath $Rootpath -StigType "WebServer" -Version $iisVersion -FileType "OrgSettings" -NodeName $vmName
                                manualChecks   = Get-StigFiles -Rootpath $Rootpath -StigType "WebServer" -Version $iisVersion -FileType "ManualChecks" -NodeName $vmName
                            }
                        }
                        "McAfee"
                        {
                            $mcafeeStigFiles = @{
                                xccdfPath      = Get-StigFiles -Rootpath $Rootpath -StigType "McAfee" -FileType "Xccdf" -NodeName $vmName
                                orgSettings    = Get-StigFiles -Rootpath $Rootpath -StigType "McAfee" -FileType "OrgSettings" -NodeName $vmName
                                manualChecks   = Get-StigFiles -Rootpath $Rootpath -StigType "McAfee" -FileType "ManualChecks" -NodeName $vmName
                            }
                        }
                        "FireFox"
                        {
                            $fireFoxStigFiles = @{
                                xccdfPath      = Get-StigFiles -Rootpath $Rootpath -StigType "FireFox" -FileType "Xccdf" -NodeName $vmName
                                orgSettings    = Get-StigFiles -Rootpath $Rootpath -StigType "FireFox" -FileType "OrgSettings" -NodeName $vmName
                                manualChecks   = Get-StigFiles -Rootpath $Rootpath -StigType "FireFox" -FileType "ManualChecks" -NodeName $vmName
                            }
                        }
                        "Edge"
                        {
                            $edgeStigFiles = @{
                                xccdfPath      = Get-StigFiles -Rootpath $Rootpath -StigType "Edge" -FileType "Xccdf" -NodeName $vmName
                                orgSettings    = Get-StigFiles -Rootpath $Rootpath -StigType "Edge" -FileType "OrgSettings" -NodeName $vmName
                                manualChecks   = Get-StigFiles -Rootpath $Rootpath -StigType "Edge" -FileType "ManualChecks" -NodeName $vmName
                            }
                        }
                        "Chrome"
                        {
                            $chromeStigFiles = @{
                                xccdfPath      = Get-StigFiles -Rootpath $Rootpath -StigType "Chrome" -FileType "Xccdf" -NodeName $vmName
                                orgSettings    = Get-StigFiles -Rootpath $Rootpath -StigType "Chrome" -FileType "OrgSettings" -NodeName $vmName
                                manualChecks   = Get-StigFiles -Rootpath $Rootpath -StigType "Chrome" -FileType "ManualChecks" -NodeName $vmName
                            }
                        }
                        "Adobe"
                        {
                            $adobeStigFiles = @{
                                orgsettings  = Get-StigFiles -Rootpath $Rootpath -StigType "Adobe" -FileType "OrgSettings" -NodeName $vmName
                                xccdfPath    = Get-StigFiles -Rootpath $Rootpath -StigType "Adobe" -FileType "Xccdf" -NodeName $vmName
                                manualChecks = Get-StigFiles -Rootpath $Rootpath -StigType "Adobe" -FileType "ManualChecks" -NodeName $vmName
                            }
                        }
                        "OracleJRE"
                        {
                            $oracleStigFiles = @{
                                xccdfPath      = Get-StigFiles -Rootpath $Rootpath -StigType "OracleJRE" -FileType "Xccdf" -NodeName $vmName
                                orgSettings    = Get-StigFiles -Rootpath $Rootpath -StigType "OracleJRE" -FileType "OrgSettings" -NodeName $vmName
                                manualChecks   = Get-StigFiles -Rootpath $Rootpath -StigType "OracleJRE" -FileType "ManualChecks" -NodeName $vmName
                            }
                        }
                    }
                }
                #endRegion

                #region Build NodeData
                $configContent = New-Object System.Collections.ArrayList
                $null = $configContent.add("@{`n`tNodeName = `"$vmName`"")

                if ($null -ne $applicableSTIGs)
                {
                    $null = $configContent.add("`n`n`tAppliedConfigurations  =")
                    $null = $configContent.add("`n`t@{")

                    switch -Wildcard ($applicableSTIGs)
                    {
                        {$_ -like "WindowsServer*" -or $_ -like "DomainController"}
                        {
                            switch -Wildcard ($osVersion)
                            {
                                "*2012*" {$osVersion = "2012R2";break}
                                "*2016*" {$osVersion = "2016";break}
                                "*2019*" {$osVersion = "2019";break}
                            }
                            $null = $configContent.add("`n`n`t`tPowerSTIG_WindowsServer =")
                            $null = $configContent.add("`n`t`t@{")
                            $null = $configContent.add("`n`t`t`tOSRole               = `"$osRole`"")
                            $null = $configContent.add("`n`t`t`tOsVersion            = `"$osVersion`"")

                            if ($IncludeFilePaths)
                            {
                                $null = $configContent.add("`n`t`t`txccdfPath            = `"$($osStigFiles.xccdfPath)`"")
                                $null = $configContent.add("`n`t`t`tOrgSettings          = `"$($osStigFiles.orgSettings)`"")
                                $null = $configContent.add("`n`t`t`tManualChecks         = `"$($osStigFiles.manualChecks)`"")
                                $null = $configContent.add("`n`t`t}")
                            }
                            else { $null = $configContent.add("`n`t`t}") }
                        }
                        "InternetExplorer"
                        {
                            $null = $configContent.add("`n`n`t`tPowerSTIG_InternetExplorer =")
                            $null = $configContent.add("`n`t`t@{")
                            $null = $configContent.add("`n`t`t`tBrowserVersion 		= `"11`"")
                            $null = $configContent.add("`n`t`t`tSkipRule			= `"V-46477`"")

                            if ($IncludeFilePaths)
                            {
                                $null = $configContent.add("`n`t`t`txccdfPath           = `"$($ieStigFiles.xccdfPath)`"")
                                $null = $configContent.add("`n`t`t`tOrgSettings	        = `"$($ieStigFiles.orgSettings)`"")
                                $null = $configContent.add("`n`t`t}")
                            }
                            else { $null = $configContent.add("`n`t`t}") }
                        }
                        "DotnetFrameWork"
                        {
                            $null = $configContent.add("`n`n`t`tPowerSTIG_DotNetFrameWork =")
                            $null = $configContent.add("`n`t`t@{")
                            $null = $configContent.add("`n`t`t`tFrameWorkVersion 	= `"4`"")

                            if ($IncludeFilePaths)
                            {
                                $null = $configContent.add("`n`t`t`txccdfPath           = `"$($dotNetStigFiles.xccdfPath)`"")
                                $null = $configContent.add("`n`t`t`tOrgSettings			    = `"$($dotNetStigFiles.orgSettings)`"")
                                $null = $configContent.add("`n`t`t`tManualChecks 		    = `"$($dotNetStigFiles.manualChecks)`"")
                                $null = $configContent.add("`n`t`t}")
                            }
                            else { $null = $configContent.add("`n`t`t}") }
                        }
                        "WindowsClient"
                        {
                            $null = $configContent.add("`n`n`t`tPowerSTIG_WindowsClient =")
                            $null = $configContent.add("`n`t`t@{")
                            $null = $configContent.add("`n`t`t`tOSVersion            = `"10`"")
                            if ($IncludeFilePaths)
                            {
                                $null = $configContent.add("`n`t`t`txccdfPath            = `"$($win10StigFiles.xccdfPath)`"")
                                $null = $configContent.add("`n`t`t`tOrgSettings          = `"$($win10StigFiles.orgSettings)`"")
                                $null = $configContent.add("`n`t`t`tManualChecks         = `"$($win10StigFiles.manualChecks)`"")
                                $null = $configContent.add("`n`t`t}")
                            }
                            else { $null = $configContent.add("`n`n`t`t}") }
                        }
                        "WindowsDefender"
                        {
                            $null = $configContent.add("`n`n`t`tPowerSTIG_WindowsDefender =")
                            $null = $configContent.add("`n`t`t@{")
                            if ($IncludeFilePaths)
                            {
                                $null = $configContent.add("`n`t`t`txccdfPath            = `"$($winDefenderStigFiles.xccdfPath)`"")
                                $null = $configContent.add("`n`t`t`tOrgSettings          = `"$($winDefenderStigFiles.orgSettings)`"")
                                $null = $configContent.add("`n`t`t`tManualChecks         = `"$($winDefenderStigFiles.manualChecks)`"")
                                $null = $configContent.add("`n`t`t}")
                            }
                            else { $null = $configContent.add("`n`n`t`t}") }
                        }
                        "WindowsFirewall"
                        {
                            $null = $configContent.add("`n`n`t`tPowerSTIG_WindowsFirewall =")
                            $null = $configContent.add("`n`t`t@{")

                            if ($IncludeFilePaths)
                            {
                                $null = $configContent.add("`n`t`t`txccdfPath            = `"$($winFirewallStigFiles.xccdfPath)`"")
                                $null = $configContent.add("`n`t`t`tOrgSettings          = `"$($winFirewallStigFiles.orgSettings)`"")
                                $null = $configContent.add("`n`t`t`tManualChecks         = `"$($winFirewallStigFiles.manualChecks)`"")
                                $null = $configContent.add("`n`t`t}")
                            }
                            else { $null = $configContent.add("`n`n`t`t}") }
                        }
                        "WindowsDnsServer"
                        {
                            $null = $configContent.add("`n`n`t`tPowerSTIG_WindowsDNSServer =")
                            $null = $configContent.add("`n`t`t@{")
                            $null = $configContent.add("`n`t`t`tOsVersion            = `"$osVersion`"")

                            if ($IncludeFilePaths)
                            {
                                $null = $configContent.add("`n`t`t`txccdfPath            = `"$($WindowsDnsStigFiles.xccdfPath)`"")
                                $null = $configContent.add("`n`t`t`tOrgSettings          = `"$($WindowsDnsStigFiles.orgSettings)`"")
                                $null = $configContent.add("`n`t`t`tManualChecks         = `"$($WindowsDnsStigFiles.manualChecks)`"")
                                $null = $configContent.add("`n`t`t}")
                            }
                            else { $null = $configContent.add("`n`t`t}") }
                        }
                        "Office2016*"
                        {
                            $null = $configContent.add("`n`n`t`tPowerSTIG_Office2016_Excel =")
                            $null = $configContent.add("`n`t`t@{")

                            if ($IncludeFilePaths)
                            {
                                $null = $configContent.add("`n`t`t`txccdfPath    = `"$Excel2016xccdfPath`"")
                                $null = $configContent.add("`n`t`t`tOrgSettings  = `"$Excel2016OrgSettings`"")
                                $null = $configContent.add("`n`t`t`tManualChecks = `"$Excel2016ManualChecks`"")
                            }
                            $null = $configContent.add("`n`t`t}")
                            $null = $configContent.add("`n`n`t`tPowerSTIG_Office2016_Outlook =")
                            $null = $configContent.add("`n`t`t@{")

                            if ($IncludeFilePaths)
                            {
                                $null = $configContent.add("`n`t`t`txccdfPath    = `"$Outlook2016xccdfPath`"")
                                $null = $configContent.add("`n`t`t`tOrgSettings  = `"$Outlook2016OrgSettings`"")
                                $null = $configContent.add("`n`t`t`tManualChecks = `"$Outlook2016ManualChecks`"")
                                $null = $configContent.add("`n`t`t}")
                            }
                            else { $null = $configContent.add("`n`n`t`t}") }

                            $null = $configContent.add("`n`n`t`tPowerSTIG_Office2016_PowerPoint =")
                            $null = $configContent.add("`n`t`t@{")

                            if ($IncludeFilePaths)
                            {
                                $null = $configContent.add("`n`t`t`txccdfPath    = `"$PowerPoint2016xccdfPath`"")
                                $null = $configContent.add("`n`t`t`tOrgSettings  = `"$PowerPoint2016OrgSettings`"")
                                $null = $configContent.add("`n`t`t`tManualChecks = `"$PowerPoint2016ManualChecks`"")
                                $null = $configContent.add("`n`t`t}")
                            }
                            else { $null = $configContent.add("`n`n`t`t}") }

                            $null = $configContent.add("`n`n`t`tPowerSTIG_Office2016_Word =")
                            $null = $configContent.add("`n`t`t@{")

                            if ($IncludeFilePaths)
                            {
                                $null = $configContent.add("`n`t`t`txccdfPath    = `"$Word2016xccdfPath`"")
                                $null = $configContent.add("`n`t`t`tOrgSettings  = `"$Word2016OrgSettings`"")
                                $null = $configContent.add("`n`t`t`tManualChecks = `"$Word2016ManualChecks`"")
                                $null = $configContent.add("`n`t`t}")
                            }
                            else { $null = $configContent.add("`n`n`t`t}") }
                        }
                        "Office2013*"
                        {
                            $null = $configContent.add("`n`n`t`tPowerSTIG_Office2013_Excel =")
                            $null = $configContent.add("`n`t`t@{")

                            if ($IncludeFilePaths)
                            {
                                $null = $configContent.add("`n`t`t`txccdfPath    = `"$Excel2013xccdfPath`"")
                                $null = $configContent.add("`n`t`t`tOrgSettings  = `"$Excel2013OrgSettings`"")
                                $null = $configContent.add("`n`t`t`tManualChecks = `"$Excel2013ManualChecks`"")
                                $null = $configContent.add("`n`t`t}")
                            }
                            else { $null = $configContent.add("`n`n`t`t}") }

                            $null = $configContent.add("`n`n`t`tPowerSTIG_Office2013_Outlook =")
                            $null = $configContent.add("`n`t`t@{")

                            if ($IncludeFilePaths)
                            {
                                $null = $configContent.add("`n`t`t`txccdfPath    = `"$Outlook2013xccdfPath`"")
                                $null = $configContent.add("`n`t`t`tOrgSettings  = `"$Outlook2013OrgSettings`"")
                                $null = $configContent.add("`n`t`t`tManualChecks = `"$Outlook2013ManualChecks`"")
                                $null = $configContent.add("`n`t`t}")
                            }
                            else { $null = $configContent.add("`n`n`t`t}") }

                            $null = $configContent.add("`n`n`t`tPowerSTIG_Office2013_PowerPoint =")
                            $null = $configContent.add("`n`t`t@{")

                            if ($IncludeFilePaths)
                            {
                                $null = $configContent.add("`n`t`t`txccdfPath    = `"$PowerPoint2013xccdfPath`"")
                                $null = $configContent.add("`n`t`t`tOrgSettings  = `"$PowerPoint2013OrgSettings`"")
                                $null = $configContent.add("`n`t`t`tManualChecks = `"$PowerPoint2013ManualChecks`"")
                                $null = $configContent.add("`n`t`t}")
                            }
                            else { $null = $configContent.add("`n`n`t`t}") }

                            $null = $configContent.add("`n`n`t`tPowerSTIG_Office2013_Word =")
                            $null = $configContent.add("`n`t`t@{")

                            if ($IncludeFilePaths)
                            {
                                $null = $configContent.add("`n`t`t`txccdfPath    = `"$Word2013xccdfPath`"")
                                $null = $configContent.add("`n`t`t`tOrgSettings  = `"$Word2013OrgSettings`"")
                                $null = $configContent.add("`n`t`t`tManualChecks = `"$Word2013ManualChecks`"")
                                $null = $configContent.add("`n`t`t}")
                            }
                            else { $null = $configContent.add("`n`n`t`t}") }
                        }
                        "Website*"
                        {
                            $websites = @(Invoke-Command -Computername $vmName -Scriptblock { Import-Module WebAdministration;Return (Get-Childitem "IIS:\Sites").name})
                            $appPools = @(Invoke-Command -Computername $vmName -Scriptblock { Import-Module WebAdministration;Return (Get-Childitem "IIS:\AppPools").name})
                            [string]$allWebSites = ''
                            [string]$allAppPools = ''
                            if ($websites.count -gt 1)
                            {
                                foreach ($site in $websites)
                                {
                                    $allWebsites += "`"$site`","
                                }
                                $websiteString = $allWebsites.TrimEnd(",")
                            }
                            else
                            {
                                $websiteString = "`"$websites`""
                            }

                            if ($appPools.count -gt 1)
                            {
                                foreach ($appPool in $appPools)
                                {
                                    $allAppPools += "`"$appPool`","
                                }
                                $appPoolString = $allAppPools.TrimEnd(",")
                            }
                            else
                            {
                                $appPoolString = "`"$appPools`""
                            }

                            $null = $configContent.add("`n`n`t`tPowerSTIG_WebSite =")
                            $null = $configContent.add("`n`t`t@{")
                            $null = $configContent.add("`n`t`t`tIISVersion       = `"$IISVersion`"")
                            $null = $configContent.add("`n`t`t`tWebsiteName      = $websiteString")
                            $null = $configContent.add("`n`t`t`tWebAppPool       = $appPoolString")

                            if ($IncludeFilePaths)
                            {
                                $null = $configContent.add("`n`t`t`txccdfPath        = `"$($webSiteStigFiles.XccdfPath)`"")
                                $null = $configContent.add("`n`t`t`tOrgSettings      = `"$($webSiteStigFiles.OrgSettings)`"")
                                $null = $configContent.add("`n`t`t`tManualChecks     = `"$($webSiteStigFiles.ManualChecks)`"")
                                $null = $configContent.add("`n`t`t}")
                            }
                            else { $null = $configContent.add("`n`t`t}") }
                        }
                        "WebServer*"
                        {
                            $null = $configContent.add("`n`n`t`tPowerSTIG_WebServer =")
                            $null = $configContent.add("`n`t`t@{")
                            $null = $configContent.add("`n`t`t`tSkipRule         = `"V-214429`"")
                            $null = $configContent.add("`n`t`t`tIISVersion       = `"$IISVersion`"")
                            $null = $configContent.add("`n`t`t`tLogPath          = `"C:\InetPub\Logs`"")

                            if ($IncludeFilePaths)
                            {
                                $null = $configContent.add("`n`t`t`txccdfPath        = `"$($webServerStigFiles.XccdfPath)`"")
                                $null = $configContent.add("`n`t`t`tOrgSettings      = `"$($webServerStigFiles.OrgSettings)`"")
                                $null = $configContent.add("`n`t`t`tManualChecks     = `"$($webServerStigFiles.ManualChecks)`"")
                                $null = $configContent.add("`n`t`t}")
                            }
                            else { $null = $configContent.add("`n`n`t`t}") }
                        }
                        "FireFox"
                        {
                            $null = $configContent.add("`n`n`t`tPowerSTIG_Firefox =")
                            $null = $configContent.add("`n`t`t@{")
                            $null = $configContent.add("`n`t`t`tInstallDirectory      = `"C:\Program Files\Mozilla Firefox`"")

                            if ($IncludeFilePaths)
                            {
                                $null = $configContent.add("`n`t`t`txccdfPath			= `"$($firefoxStigFiles.XccdfPath)`"")
                                $null = $configContent.add("`n`t`t`tOrgSettings			= `"$($firefoxStigFiles.OrgSettings)`"")
                                $null = $configContent.add("`n`t`t`tManualChecks 		= `"$($firefoxStigFiles.ManualChecks)`"")
                                $null = $configContent.add("`n`t`t}")
                            }
                            else { $null = $configContent.add("`n`t`t}") }
                        }
                        "Edge"
                        {
                            $null = $configContent.add("`n`n`t`tPowerSTIG_Edge =")
                            $null = $configContent.add("`n`t`t@{")

                            if ($IncludeFilePaths)
                            {
                                $null = $configContent.add("`n`t`t`txccdfPath            = `"$($edgeStigFiles.xccdfPath)`"")
                                $null = $configContent.add("`n`t`t`tOrgSettings          = `"$($edgeStigFiles.orgSettings)`"")
                                $null = $configContent.add("`n`t`t`tManualChecks         = `"$($edgeStigFiles.manualChecks)`"")
                                $null = $configContent.add("`n`t`t}")
                            }
                            else { $null = $configContent.add("`n`n`t`t}") }
                        }
                        "Chrome"
                        {
                            $null = $configContent.add("`n`n`t`tPowerSTIG_Chrome =")
                            $null = $configContent.add("`n`t`t@{")
                            if ($IncludeFilePaths)
                            {
                                $null = $configContent.add("`n`t`t`txccdfPath            = `"$($chromeStigFiles.xccdfPath)`"")
                                $null = $configContent.add("`n`t`t`tOrgSettings          = `"$($chromeStigFiles.orgSettings)`"")
                                $null = $configContent.add("`n`t`t`tManualChecks         = `"$($chromeStigFiles.manualChecks)`"")
                                $null = $configContent.add("`n`t`t}")
                            }
                            else { $null = $configContent.add("`n`n`t`t}") }
                        }
                        "Adobe"
                        {
                            $null = $configContent.add("`n`n`t`tPowerSTIG_Adobe =")
                            $null = $configContent.add("`n`t`t@{")
                            $null = $configContent.add("`n`t`t`tAdobeApp            = `"AcrobatReader`"")

                            if ($IncludeFilePaths)
                            {
                                $null = $configContent.add("`n`t`t`txccdfPath			= `"$($adobeStigFiles.XccdfPath)`"")
                                $null = $configContent.add("`n`t`t`tOrgSettings			= `"$($adobeStigFiles.OrgSettings)`"")
                                $null = $configContent.add("`n`t`t`tManualChecks 		= `"$($adobeStigFiles.ManualChecks)`"")
                                $null = $configContent.add("`n`t`t}")
                            }
                            else { $null = $configContent.add("`n`t`t}") }
                        }
                        "OracleJRE"
                        {
                            $null = $configContent.add("`n`n`t`tPowerSTIG_OracleJRE =")
                            $null = $configContent.add("`n`t`t@{")
                            $null = $configContent.add("`n`t`t`tConfigPath       = `"$ConfigPath`"")
                            $null = $configContent.add("`n`t`t`tPropertiesPath   = `"$PropertiesPath`"")

                            if ($IncludeFilePaths)
                            {
                                $null = $configContent.add("`n`t`t`txccdfPath        = `"$($oracleStigFiles.XccdfPath)`"")
                                $null = $configContent.add("`n`t`t`tOrgSettings      = `"$($oracleStigFiles.OrgSettings)`"")
                                $null = $configContent.add("`n`t`t`tManualChecks     = `"$($oracleStigFiles.ManualChecks)`"")
                                $null = $configContent.add("`n`t`t}")
                            }
                            else { $null = $configContent.add("`n`n`t`t}") }
                        }
                    }
                    $null = $configContent.add("`n`t}")
                }

                if ($IncludeLcmSettings)
                {
                $null = $configContent.add("`n`n`tLocalConfigurationManager =")
                $null = $configContent.add("`n`t@{")

                    foreach ($setting in $LcmSettings.Keys)
                    {

                            if (($Null -ne $LcmSettings.$setting) -and ("{}" -ne $lcmsettings.$setting) -and ("" -ne $LcmSettings.$setting))
                            {
                                $null = $configContent.add("`n`t`t$($setting)")

                                if ($setting.Length -lt 8)      {$null = $configContent.add("`t`t`t`t`t`t`t= ")}
                                elseif ($setting.Length -lt 12) {$null = $configContent.add("`t`t`t`t`t`t= ")}
                                elseif ($setting.Length -lt 16) {$null = $configContent.add("`t`t`t`t`t= ")}
                                elseif ($setting.Length -lt 20) {$null = $configContent.add("`t`t`t`t= ")}
                                elseif ($setting.Length -lt 24) {$null = $configContent.add("`t`t`t= ")}
                                elseif ($setting.Length -lt 28) {$null = $configContent.add("`t`t= ")}
                                elseif ($setting.Length -lt 32) {$null = $configContent.add("`t= ")}

                                if (($LcmSettings.$setting -eq $true) -or ($LcmSettings.$setting -eq $false))
                                {
                                    $null = $configContent.add("`$$($LcmSettings.$setting)")
                                }
                                else
                                {
                                    $null = $configContent.add("`"$($LcmSettings.$setting)`"")
                                }
                            }
                    }
                    $null = $configContent.add("`n`t}")
                }
                $null = $configContent.add("`n}")

                $null = Set-Content -NoNewLine -Path $dataFilePath.FullName -Value $configContent
                Write-Output "`t`t$vmName - System data successfully generated."
                #endregion Build NodeData
            }
            $null = $jobs.add($job.Id)
        }
        #endregion
        if ($jobs.count -ge 1)
        {
            Write-Output "`t$resourceGroup - System data jobs created. Checking status every 30 seconds until all jobs are complete."

            do
            {
                $completedJobs = (Get-Job -ID $jobs | Where-Object {$_.state -ne "Running"}).count
                $runningjobs   = (Get-Job -ID $jobs | Where-Object {$_.state -eq "Running"}).count
                Write-Output "`t`tSystem Data Build Status:`t$runningJobs Jobs Currently Processing`t$completedJobs/$($jobs.count) Jobs Completed"
                Start-Sleep -Seconds 30
            }
            while ((Get-Job -ID $jobs).State -contains "Running")
            Write-Output "`n`t$($jobs.count) System data jobs completed. Outputting Results."
            Get-Job -ID $jobs | Wait-Job | Receive-Job
        }
        else
        {
            Write-Output "`t`tNo Jobs Generated for $resourceGroup"
        }
    }
}

function Publish-RepoToBlob
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $RootPath = (Get-Location).Path,

        [Parameter(Mandatory=$true)]
        [string]
        $ResourceGroupName,

        [Parameter(Mandatory=$true)]
        [string]
        $StorageAccountName = "stigstorage",

        [Parameter(Mandatory=$true)]
        [string]
        $ContainerName = "Scar"

    )

    try
    {
        $systemsPath  = (Resolve-Path "$rootPath\Systems").Path
        $configPath   = (Resolve-Path "$rootPath\Configurations").Path
        $artifactPath = (Resolve-Path "$rootPath\Artifacts").Path
        $resourcePath = (Resolve-Path "$rootPath\Resources").Path
    }
    catch
    {
        Write-Output "$Rootpath is not a valid SCAR repository. Run Initialize-StigRepo to configure the repo or Set-Location to the path where it exists."
        exit
    }
    $context = (Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName).Context

    # detect specified container name, create it if it does not exist
    if (-not(Get-AzStorageContainer -Context $context -Prefix $ContainerName))
    {
        Write-Verbose -Message "Specified container does not exist, creating $ContainerName"
        New-AzStorageContainer -Context $context -Name $ContainerName -Permission Off | Out-Null
    }

    $scarFiles = Get-Childitem $RootPath -Recurse
    $scarFiles | ForEach-Object { Set-AzStorageBlobContent -Context $context -Container $ContainerName -Force }

}

function Register-AzAutomationNodes
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $RootPath = (Get-Location).Path,

        [Parameter(Mandatory=$true)]
        [string]
        $ResourceGroupName,

        [Parameter(Mandatory=$true)]
        [string]
        $VMResourceGroup,

        [Parameter(Mandatory=$true)]
        [string]
        $AutomationAccountName

    )
    
    if ('' -ne $VMResourceGroup)
    {
        $virtualMachines = Get-AzVM -ResourceGroupName $VMResourceGroup
    }
    else
    {
        $virtualMachines = Get-AzVM
    }
    
    foreach ($virtualMachine in $virtualMachines)
    {
        Register-AzAutomationDscNode -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -AzureVMName $virtualMachine.Name
    }
}

function Import-AzDscConfigurations
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $RootPath = (Get-Location).Path,

        [Parameter(Mandatory=$true)]
        [string]
        $ResourceGroupName,

        [Parameter(Mandatory=$true)]
        [string]
        $AutomationAccountName

    )

    Write-Output "Publishing DSC Configurations"
    $dscConfigurations = Get-Childitem "$RootPath\Artifacts\DscConfigs\*.ps1" | Where-Object { $_.name -notlike "*allnodes*" }
    $azConfigPath = (New-Item -Path "$RootPath\Artifacts\AzConfigs" -ItemType Directory -Force).FullName

    foreach ($config in $dscConfigurations)
    {
        Write-Output "`tPublishing $($config.BaseName) Configuration to Azure Automation Account"

        Write-Output "`t`tCopying/Reformating Configuration for Azure Automation"
        Copy-Item $config.FullName -Destination $azConfigPath -Force
        $newName = $config.name.replace("-","_")
        Rename-Item "$azConfigPath\$($config.Name)" -NewName $newName -Force
        $azConfig = Get-Item -Path "$azConfigPath\$NewName"

        try
        {
            Import-AzAutomationDscConfiguration -SourcePath $azConfig.FullName -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Published
        }
        catch
        {
            Write-Output "`t`tAzure Automation Import failed"
            throw $_
        }

        Write-Output "`tStarting CompilationJob - $($config.BaseName)"
        try
        {
            Start-AzAutomationDscCompilationJob -ConfigurationName $configName -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName
        }
        catch
        {
            Write-Output "`t`tAzure Automation Import failed"
            throw $_
        }
    }
}
