function New-AzSystemData
{
    <#
    .SYNOPSIS
    Generates system data for Azure Virtual Machines

    .PARAMETER RootPath
    Root path of the Stig Compliance Automation Repository. Initialize by running Initialize-StigRepo

    .PARAMETER ResourceGroupName
    Name of the ResourceGroup containing targeted Virtual Machines

    .PARAMETER IncludeLcmSettings
    Adds LocalConfigurationManager Settings to the System Data File for each Virtual Machine.

    .PARAMETER LcmSettings
    Hashtable of Local Configuration Manager Settings

    .EXAMPLE
    New-AzSystemData -RootPath "C:\StigRepo" -ResourceGroupName "My-Azure-ResourceGroup"

    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $RootPath = (Get-Location).Path,

        [Parameter()]
        [string]
        $ResourceGroupName,

        [Parameter()]
        [switch]
        $DomainControllers,

        # [Parameter()]
        # [switch]
        # $IncludeFilePaths,

        [Parameter()]
        [switch]
        $IncludeLCMSettings,

        [Parameter()]
        [HashTable]
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

    Write-Output "Starting Azure System Data Creation"
    $IncludeFilePaths = $true
    $systemsPath      = (Resolve-Path "$RootPath\Systems").Path
    $resourceGroups   = New-Object System.Collections.ArrayList
    $virtualMachines  = New-Object System.Collections.ArrayList

    Write-Output "`tGetting Virtual Machine Resource Groups"
    if ("" -eq $ResourceGroupName) { Get-AzVM | ForEach-Object { $null = $virtualMachines.Add($_) } }
    else { Get-AzVM -ResourceGroupName $ResourceGroupName | ForEach-Object { $null = $virtualMachines.Add($_) } }

    $virtualMachines.ResourceGroupName | Get-Unique | Foreach-Object { $null = $resourceGroups.Add($_) }

    foreach ($resourceGroup in $ResourceGroups)
    {
        Write-Output "`n`tBeginning ResourceGroup System Data Generation - $ResourceGroup"

        $jobs               = New-Object System.Collections.ArrayList
        $rgFolder           = (New-Item -ItemType Directory -Path "$SystemsPath\$resourceGroup" -Force).FullName
        $resourceGroupVMs   = $virtualMachines | Where-Object ResourceGroupName -eq $resourceGroup

        #region VirtualMachine Jobs
        foreach ($virtualMachine in $resourceGroupVms)
        {
            Write-Output "`t`tStarting Job - $($virtualMachine.name)"
            $osType = $virtualMachine.StorageProfile.ImageReference.Offer
            $osVersion = $virtualMachine.StorageProfile.ImageReference.Sku
            $vmName = $virtualMachine.Name

            $job = Start-Job -ScriptBlock {

                $RootPath           = $using:rootPath
                $resourceGroup      = $using:resourceGroup
                $rgFolder           = $using:rgFolder
                $osType             = $using:osType
                $osVersion          = $using:osVersion
                $vmName             = $using:vmName
                $LcmSettings        = $using:LcmSettings
                $dataFilePath       = New-Item "$rgFolder\$vmName.psd1" -Force
                $applicableStigs    = New-Object System.Collections.ArrayList

                #region STIG Applicability

                switch -wildcard ($osType)
                {
                    "*WindowsServer"
                    {
                        if ($DomainControllers)
                        {
                            $osRole = 'DC'
                            $null = $applicableStigs.add("DomainController")
                        }
                        else
                        {
                            $osRole = 'MS'
                            $null   = $applicableStigs.add("WindowsServer")
                        }

                        $null = $applicableStigs.add("InternetExplorer")
                        $null = $applicableStigs.add("WindowsFirewall")
                        $null = $applicableStigs.add("WindowsDefender")
                        $null = $applicableStigs.add("DotnetFramework")
                    }
                    "Windows-10"
                    {
                        $null = $applicableStigs.add("WindowsClient")
                        $null = $applicableStigs.add("InternetExplorer")
                        $null = $applicableStigs.add("WindowsFirewall")
                        $null = $applicableStigs.add("WindowsDefender")
                        $null = $applicableStigs.add("DotnetFramework")
                    }
                    "RHEL"    {$null = $applicableStigs.add("RHEL")}
                    "CentOS"  {$null = $applicableStigs.add("CentOS")}
                    "Ubuntu*" {$null = $applicableStigs.add("Ubuntu")}
                }
                #endRegion

                #region Get STIG Files
                if ($IncludeFilePaths)
                {
                    Write-Output "`tFinding STIG Data File Paths"
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

                            switch -Wildcard ($osVersion)
                            {
                                "*2016*"
                                {
                                    $null = $configContent.add("`n`t`t`tSkipRule             = @('V-224866','V-224867','V-224868')")
                                    $null = $configContent.add("`n`t`t`tException = @{")
                                    $null = $configContent.add("`n`t`t`t    'V-225019' = @{Identity = 'Guests'}")
                                    $null = $configContent.add("`n`t`t`t    'V-225016' = @{Identity = 'Guests'}")
                                    $null = $configContent.add("`n`t`t`t    'V-225018' = @{Identity = 'Guests'}")
                                    $null = $configContent.add("`n`t`t`t}")
                                    $null = $configContent.add("`n`t`t`tOrgSettings = @{")
                                    $null = $configContent.add("`n`t`t`t    'V-225015' = @{Identity     = 'Guests'}")
                                    $null = $configContent.add("`n`t`t`t    'V-225027' = @{OptionValue  = 'xGuest'}")
                                    $null = $configContent.add("`n`t`t`t    'V-225063' = @{ValueData      = '2'}")
                                    $null = $configContent.add("`n`t`t`t}")
                                }
                                "*2019*"
                                {
                                    $null = $configContent.add("`n`t`t`tSkipRule             = @('V-205737')")
                                    $null = $configContent.add("`n`t`t`tException = @{")
                                    $null = $configContent.add("`n`t`t`t    'V-205733' = @{Identity = 'Guests'}")
                                    $null = $configContent.add("`n`t`t`t    'V-205672' = @{Identity = 'Guests'}")
                                    $null = $configContent.add("`n`t`t`t    'V-205673' = @{Identity = 'Guests'}")
                                    $null = $configContent.add("`n`t`t`t    'V-205675' = @{Identity = 'Guests'}")
                                    $null = $configContent.add("`n`t`t`t}")
                                    $null = $configContent.add("`n`t`t`tOrgSettings = @{")
                                    $null = $configContent.add("`n`t`t`t    'V-205910' = @{OptionValue = 'xGuest'}")
                                    $null = $configContent.add("`n`t`t`t    'V-205717' = @{ValueData   = '2'}")
                                    $null = $configContent.add("`n`t`t`t}")
                                }
                            }
                            if ($IncludeFilePaths)
                            {
                                $null = $configContent.add("`n`t`t`txccdfPath            = `"$($osStigFiles.xccdfPath)`"")
                                $null = $configContent.add("`n`t`t`tOrgSettings          = `"$($osStigFiles.orgSettings)`"")
                                $null = $configContent.add("`n`t`t`tManualChecks         = `"$($osStigFiles.manualChecks)`"")
                                $null = $configContent.add("`n`t`t}")
                            }
                            else { $null = $configContent.add("`n`t`t}") }
                        }
                        "WindowsClient"
                        {
                            $null = $configContent.add("`n`n`t`tPowerSTIG_WindowsClient =")
                            $null = $configContent.add("`n`t`t@{")
                            $null = $configContent.add("`n`t`t`tOSVersion            = `"10`"")
                            $null = $configContent.add("`n`t`t`tSkipRule             = @('V-220740','V-220739','V-220741','V-220908')")
                            $null = $configContent.add("`n`t`t`tOrgSettings          = @{")
                            $null = $configContent.add("`n`t`t`t    'V-220912' = @{OptionValue = 'xGuest'}")
                            $null = $configContent.add("`n`t`t`t}")
                            $null = $configContent.add("`n`t`t`tException            = @{")
                            $null = $configContent.add("`n`t`t`t    'V-220972' = @{Identity = 'Guests'}")
                            $null = $configContent.add("`n`t`t`t    'V-220968' = @{Identity = 'Guests'}")
                            $null = $configContent.add("`n`t`t`t    'V-220969' = @{Identity = 'Guests'}")
                            $null = $configContent.add("`n`t`t`t    'V-220971' = @{Identity = 'Guests'}")
                            $null = $configContent.add("`n`t`t`t}")

                            if ($IncludeFilePaths)
                            {
                                $null = $configContent.add("`n`t`t`txccdfPath            = `"$($win10StigFiles.xccdfPath)`"")
                                $null = $configContent.add("`n`t`t`tOrgSettings          = `"$($win10StigFiles.orgSettings)`"")
                                $null = $configContent.add("`n`t`t`tManualChecks         = `"$($win10StigFiles.manualChecks)`"")
                                $null = $configContent.add("`n`t`t}")
                            }
                            else { $null = $configContent.add("`n`t`t}") }
                        }
                        "RHEL"
                        {
                            $null = $configContent.add("`n`n`t`tPowerSTIG_RHEL =")
                            $null = $configContent.add("`n`t`t@{")

                            if      ($osVersion -like "7*")
                            {
                                $null = $configContent.add("`n`t`t`tOSVersion            = `"7`"")
                                $null = $configContent.add("`n`t`t`tSkipRule             = @('V-204623','V-204399.a','V-204399.b','V-204400','V-204403')")
                            }
                            elseif  ($osVersion -like "8*")
                            {
                                $null = $configContent.add("`n`t`t`tOSVersion            = `"8`"")
                            }

                            if ($IncludeFilePaths)
                            {
                                $null = $configContent.add("`n`t`t`txccdfPath            = `"$($win10StigFiles.xccdfPath)`"")
                                $null = $configContent.add("`n`t`t`tOrgSettings          = `"$($win10StigFiles.orgSettings)`"")
                                $null = $configContent.add("`n`t`t`tManualChecks         = `"$($win10StigFiles.manualChecks)`"")
                                $null = $configContent.add("`n`t`t}")
                            }
                            else { $null = $configContent.add("`n`t`t}") }
                        }
                        "Ubuntu*"
                        {
                            $null = $configContent.add("`n`n`t`tPowerSTIG_Ubuntu =")
                            $null = $configContent.add("`n`t`t@{")
                            $null = $configContent.add("`n`t`t`tOSVersion            = `"18.04`"")
                            $null = $configContent.add("`n`t`t`tSkipRule             = @('V-219159','V-219167.a','V-219167.b','V-219167.c')")

                            if ($IncludeFilePaths)
                            {
                                $null = $configContent.add("`n`t`t`txccdfPath            = `"$($win10StigFiles.xccdfPath)`"")
                                $null = $configContent.add("`n`t`t`tOrgSettings          = `"$($win10StigFiles.orgSettings)`"")
                                $null = $configContent.add("`n`t`t`tManualChecks         = `"$($win10StigFiles.manualChecks)`"")
                                $null = $configContent.add("`n`t`t}")
                            }
                            else { $null = $configContent.add("`n`t`t}") }
                        }
                        "CentOS*"
                        {
                            $null = $configContent.add("`n`n`t`tPowerSTIG_RHEL =")
                            $null = $configContent.add("`n`t`t@{")
                            $null = $configContent.add("`n`t`t`tOSVersion            = `"7`"")
                            $null = $configContent.add("`n`t`t`tSkipRule             = @('V-204623','V-204399.a','V-204399.b','V-204400','V-204403')")
                            if ($IncludeFilePaths)
                            {
                                $null = $configContent.add("`n`t`t`txccdfPath            = `"$($win10StigFiles.xccdfPath)`"")
                                $null = $configContent.add("`n`t`t`tOrgSettings          = `"$($win10StigFiles.orgSettings)`"")
                                $null = $configContent.add("`n`t`t`tManualChecks         = `"$($win10StigFiles.manualChecks)`"")
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
                        "WindowsDefender"
                        {
                            $null = $configContent.add("`n`n`t`tPowerSTIG_WindowsDefender =")
                            $null = $configContent.add("`n`t`t@{")
                            $null = $configContent.add("`n`t`t`tOrgSettings = @{'V-213450' = @{ValueData = '1' }}")
                            if ($IncludeFilePaths)
                            {
                                $null = $configContent.add("`n`t`t`txccdfPath            = `"$($winDefenderStigFiles.xccdfPath)`"")
                                $null = $configContent.add("`n`t`t`tOrgSettings          = `"$($winDefenderStigFiles.orgSettings)`"")
                                $null = $configContent.add("`n`t`t`tManualChecks         = `"$($winDefenderStigFiles.manualChecks)`"")
                                $null = $configContent.add("`n`t`t}")
                            }
                            else { $null = $configContent.add("`n`t`t}") }
                        }
                        "WindowsFirewall"
                        {
                            $null = $configContent.add("`n`n`t`tPowerSTIG_WindowsFirewall =")
                            $null = $configContent.add("`n`t`t@{")
                            $null = $configContent.add("`n`t`t`tSkiprule             = @('V-17443', 'V-17442')")
                            if ($IncludeFilePaths)
                            {
                                $null = $configContent.add("`n`t`t`txccdfPath            = `"$($winFirewallStigFiles.xccdfPath)`"")
                                $null = $configContent.add("`n`t`t`tOrgSettings          = `"$($winFirewallStigFiles.orgSettings)`"")
                                $null = $configContent.add("`n`t`t`tManualChecks         = `"$($winFirewallStigFiles.manualChecks)`"")
                                $null = $configContent.add("`n`t`t}")
                            }
                            else { $null = $configContent.add("`n`t`t}") }
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

        Write-Output "`tResource Group System Data Generation Complete - $resourceGroup"
    }

    Write-Output "`nSystem Data Generation Complete"
}

function Publish-AzAutomationModules
{
    <#
    .SYNOPSIS
    Publishes modules stored in the SCAR repository into an Azure Automation Account

    .PARAMETER RootPath
    Root path of the Stig Compliance Automation Repository. Initialize by running Initialize-StigRepo

    .PARAMETER ResourceGroupName
    Name of the ResourceGroup containing the targeted Azure Automation Account

    .PARAMETER AutomationAccountName
    Name of the Azure Automation Account

    .PARAMETER PSGallery
    Switch to install modules directly from the powershell gallary instead of using the modules stored in the local Stig Repository.

    .EXAMPLE
    Publish-AzAutomationModules -Rootpath "C:\StigRepo" -ResourceGroupName "My-AzAutomation-ResourceGroup" -AutomationAccountName "MyAutomationAccount"
    #>

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

function Publish-RepoToBlob
{
    <#
    .SYNOPSIS
    Publishes the STIG Compliance Automation Repository to Azure Blob Storage

    .PARAMETER RootPath
    Root path of the Stig Compliance Automation Repository. Initialize by running Initialize-StigRepo

    .PARAMETER ResourceGroupName
    Name of the ResourceGroup containing the targetted Azure Storage Account

    .PARAMETER ContainerName
    Name of the targetted Azure Storage Container

    .EXAMPLE
    Publish-RepoToBlob -RootPath "C:\StigRepo" -ResourceGroupName "My-Azure-ResourceGroup" -ContainerName "SCAR"
    #>

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
    <#
    .SYNOPSIS
    Registers Virtual Machines with generated System Data in SCAR as Azure Automation Nodes

    .PARAMETER ResourceGroupName
    Name of the Azure Resource Group containing the Automation Account

    .PARAMETER AutomationAccountName
    Name of the Azure Automation Account

    .PARAMETER TargetFolder
    System Data Folder to target for Azure Automation registration

    .EXAMPLE
    Register-AzAutomationNodes -ResourceGroupName "AzAutomationRG" -AutomationAccountName "MyAutomationAccount"

    #>
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
        $AutomationAccountName,

        [Parameter()]
        [string]
        $TargetFolder,

        [Parameter()]
        [string]
        $ConfigurationMode = 'ApplyAndMonitor',

        [Parameter()]
        [string]
        $ConfigurationModeFrequencyMins = '15',

        [Parameter()]
        [string]
        $RefreshFrequencyMins = '30',

        [Parameter()]
        [string]
        $ActionAfterReboot = 'ContinueConfiguration',

        [Parameter()]
        [bool]
        $RebootNodeIfNeeded = $true,

        [Parameter()]
        [bool]
        $AllowModuleOverwrite = $true,

        [Parameter()]
        [switch]
        $Force

    )

    Write-Output "Preparing environment for Azure Automation Registration"
    $virtualMachines = New-Object System.Collections.ArrayList
    $jobs            = New-Object System.Collections.ArrayList

    # Validate Repository
    try
    {
        $null = Resolve-Path "$RootPath\Systems" -ErrorAction 'Stop'
        $null = Resolve-Path "$Rootpath\Configurations" -ErrorAction 'Stop'
        $null = Resolve-Path "$Rootpath\Artifacts" -ErrorAction 'Stop'
        $null = Resolve-Path "$Rootpath\Resources" -ErrorAction 'Stop'
        Write-OutPut "`tSTIG Repository Path is Valid:`t`t$RootPath"
    }
    catch
    {
        Write-Output "`n$Rootpath is not a valid STIG Repository"
        Write-Output "Please provide a valid path or build a new repository using the Initialize-StigRepo function"
    }

    # Validate Connection to Azure Subscription
    $azContext = Get-AzContext
    if ($null -ne $azContext)
    {
        $azSubscription = $azContext.Name.Split(" ")[0]
        Write-Output "`tConnected to Azure Subscription:`t$azSubscription"
    }
    else
    {
        Write-Output "`tPowershell session is not connected to an Azure Subscription. Follow the prompt to login."
        Connect-AzAccount
    }

    # Validate Azure Automation Account
    try
    {
        $null = Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -ErrorAction 'Stop'
        Write-Output "`tAzure Automation Account is valid:`t$AutomationAccountName"
    }
    catch
    {
        Write-Output "`nAutomation Account is invalid or cannot be found."
        Write-Output "Verify the Automation Account Exists and that your session is connect to the correct Azure Subscription and try again."
        exit
    }

    # Get Azure Virtual Machines
    if ('' -ne $TargetFolder)
    {
        if (Test-Path "$Rootpath\Systems\$TargetFolder")
        {
            Write-Output "`tGetting Virtual Machines from Folder:`t$RootPath\Systems\$TargetFolder"
            $vmNames = (Get-Childitem "$RootPath\Systems\$TargetFolder\*.psd1" -Recurse).BaseName
        }
        else
        {
            Write-Output "`tCould not find path - $RootPath\Systems\$TargetFolder"
            Write-Output "`tPlease Validate RootPath and TargetFolder name and try again"
            Write-Output "`nVirtualMachine Registration Cancelled"
            exit
        }
    }
    else
    {
        Write-Output "`tGetting Virtual Machines from Folder:`t$RootPath\Systems"
        $vmNames = (Get-Childitem "$RootPath\Systems\*.psd1" -Recurse).BaseName
    }

    Write-Output "`tGetting Azure Virtual Machine objects"

    foreach ($vmName in $vmNames)
    {
        $vmObject = Get-AzVM -Name $vmName -Status
        $null = $virtualMachines.Add($vmObject)
    }

    # Check for Linux Machines and generate registration Script
    Write-Output "`tChecking for Linux VMs"

    if ($virtualMachines.StorageProfile.OSDisk.OSType -contains 'linux')
    {
        Write-Output "`tLinux VMs identified - Getting registration data"
        $registrationData = Get-AzAutomationRegistrationInfo -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName
        $registrationKey = $registrationData.PrimaryKey
        $registrationUrl = $registrationData.Endpoint

        Write-Output "`tGenerating Linux Registration Script"
        $linuxRegContent = "/opt/microsoft/dsc/Scripts/Register.py $registrationKey $registrationUrl"
        $linuxRegScript  = (New-Item -ItemType 'File' -Path "$RootPath\LinuxRegistration.sh" -Value $linuxRegContent -Force).FullName
    }
    else
    {
        $linuxRegScript  = $null
    }

    # Register Virtual Machines to Automation Acocunt
    if ($virtualMachines.Count -gt 0)
    {
        Write-Output "`nBeginning Azure Automation Registration for $($virtualMachines.Count) identified Virtual Machine(s)"
    }
    else
    {
        Write-Output "`nNo Virtual Machines were identified for registration."
        Write-Output "Ensure that System Data exists for the targetted Azure VMs and try again."
        exit
    }

    foreach ($virtualMachine in $virtualMachines)
    {
        Write-Output "`tStarting Node Registration Job - $($virtualMachine.Name)"
        [string]$osType = $virtualMachine.StorageProfile.OSDisk.OSType

        $job = Start-Job -ScriptBlock {

            $virtualMachine                 = $using:VirtualMachine
            $linuxRegScript                 = $using:linuxRegScript
            $ResourceGroupName              = $using:ResourceGroupName
            $AutomationAccountName          = $using:AutomationAccountName
            $ConfigurationMode              = $using:ConfigurationMode
            $ConfigurationModeFrequencyMins = $using:ConfigurationModeFrequencyMins
            $RefreshFrequencyMins           = $using:RefreshFrequencyMins
            $RebootNodeIfNeeded             = $using:RebootNodeIfNeeded
            $ActionAfterReboot              = $using:ActionAfterReboot
            $AllowModuleOverwrite           = $using:AllowModuleOverwrite
            $Force                          = $using:Force
            $RootPath                       = $using:RootPath
            $osType                         = $using:osType
            $vmName                         = $virtualMachine.Name
            $vmResourceGroup                = $virtualMachine.ResourceGroupName
            $vmPowerState                   = $virtualMachine.PowerState

            Write-OutPut "`n`tBeginning Registration:`t$($virtualMachine.Name)"

            # Start VM if deallocated
            Write-Output "`t`tChecking VM Running State"

            if ($vmPowerState -ne 'VM running')
            {
                Write-Output "`t`tVM is Deallocated - Starting VM"
                $null = $virtualMachine | Start-AzVM
            }
            else
            {
                Write-Output "`t`tVirtual machine is currently running"
            }

            # Check the VM for existing extensions
            Write-Output "`t`tChecking for Existing DSC Extension"
            $dscExtension = Get-AzVmExtension -ResourceGroupName $vmResourceGroup -VMName $vmName | Where-Object {$_.ExtensionType -like "*DSC*"}

            if ($dscExtension)
            {
                Write-OutPut "`t`tExisting DSC Extension Found"
                $dscExtensionName = $dscExtension.Name

                if ($Force)
                {
                    try
                    {
                        # Remove DSC Extension
                        Write-Output "`t`tRemoving `'$dscExtensionName`' from $vmName"
                        $null = $dscExtension | Remove-AzVMExtension -Force -Confirm:$false -ErrorAction 'Stop'

                        # Reboot VM
                        Write-Output "`t`tRestarting $vmName"
                        $null = $virtualMachine | Restart-AzVM
                    }
                    catch
                    {
                        Write-Output "`t`tRemoving `'$dscExtensionName`' failed - Remove the extension manually via the Azure Portal."
                        continue
                    }
                }
                else
                {
                    Write-OutPut "`t`tDSC Extension Name: $dscExtensionName"
                    Write-OutPut "`t`tRun the Register-AzAutomationNodes command using -Force to forcibly remove existing DSC extensions/Automation Account registration."
                    Write-Output "`t$vmName - Registration Cancelled"
                    continue
                }
            }
            else
            {
                Write-Output "`t`tNo Existing DSC Extensions Found"
            }

            # Register Azure Automation Node
            try
            {

                switch ($osType)
                {
                    'Windows'
                    {
                        Write-Output "`t`tRegistering Windows VM - $vmName"

                        $params = @{
                            AzureVMName                     = $virtualMachine.Name
                            AzureVMLocation                 = $virtualMachine.Location
                            AzureVMResourceGroup            = $virtualMachine.ResourceGroupName
                            ResourceGroupName               = $ResourceGroupName
                            AutomationAccountName           = $AutomationAccountName
                            ConfigurationMode               = $ConfigurationMode
                            ConfigurationModeFrequencyMins  = $ConfigurationModeFrequencyMins
                            RefreshFrequencyMins            = $RefreshFrequencyMins
                            RebootNodeIfNeeded              = $RebootNodeIfNeeded
                            ActionAfterReboot               = $ActionAfterReboot
                            AllowModuleOverwrite            = $AllowModuleOverwrite
                        }
                        Register-AzAutomationDscNode @params -Erroraction 'Stop'
                        Write-Output "`t`tRegistration Status - Succeeded"
                    }
                    'Linux'
                    {
                        Write-Output "`t`tRegistering Linux VM - $vmName"

                        $params = @{
                            ResourceGroupName   = $VirtualMachine.ResourceGroupName
                            VmName              = $vmName
                            ScriptPath          = $linuxRegScript
                            Commandid           = 'runshellscript'
                        }
                        $regResult = (Invoke-AzVmRunCommand @params -ErrorAction 'Stop').Status
                        Write-Output "`t`tRegistration Status - $regResult"
                    }
                }
            }
            catch
            {
                Write-Output "`t`t`tRegistration Status - Failure"
            }

            Write-Output "`t$($VirtualMachine.Name) - Registration Complete"
        }
        $null = $jobs.add($job.Id)
    }

    if ($jobs.count -ge 1)
    {
        Write-Output "`nAzure Automation Node Registration jobs created. Checking status every 30 seconds until all jobs are complete."

        do
        {
            $completedJobs = (Get-Job -ID $jobs | Where-Object {$_.state -ne "Running"}).count
            $runningjobs   = (Get-Job -ID $jobs | Where-Object {$_.state -eq "Running"}).count
            Write-Output "`tNode Registration Job Status:`t$runningJobs Jobs Currently Processing`t$completedJobs/$($jobs.count) Jobs Completed"
            Start-Sleep -Seconds 30
        }
        while ((Get-Job -ID $jobs).State -contains "Running")
        Write-Output "`n$($jobs.count) Azure Automation Node Registration jobs completed. Outputting Results.`n"
        Get-Job -ID $jobs | Wait-Job | Receive-Job
    }

    # Cleanup Linux Registration Script if present
    if (Test-Path -Path $linuxRegScript -ErrorAction SilentlyContinue)
    {
        Remove-Item -Path $linuxRegScript -Force -Confirm:$False
    }
    Write-Output "`nAzure Automation Registration Complete."
}

function Start-AzDscBuild
{
    <#
    .SYNOPSIS
    Generates PowerSTIG Configurations for system data files that are compatible with Azure Automation

    .PARAMETER RootPath
    Path to the Stig Compliance Automation Repository

    .EXAMPLE
    Export-AzDscConfigurations -RootPath "C:\StigRepo"
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $RootPath = (Get-Location).Path

    )

    Write-Output "Beginning Azure Automation DSC Configuration Script Creation"

    $systemFiles        = Get-Childitem "$Rootpath\Systems\*.psd1" -Recurse | Where-Object FullName -notlike "*Staging*"
    $azConfigFolderPath = "$RootPath\Artifacts\AzConfigs"

    Write-Output "`tCreating Azure Configuration Folder - $azConfigFolderPath"
    $azConfigPath   = (New-Item -Path $azConfigFolderPath -ItemType Directory -Force).FullName

    foreach ($systemFile in $systemFiles)
    {
        Write-Output "`tGenerating Azure DSC Configuration - $($systemFile.BaseName)"
        $azConfigName   = "STIG_" + $systemFile.BaseName.Replace("-","_")
        $azConfigFile   = New-Item -ItemType File -Path "$azConfigPath\$azConfigName.ps1" -Force
        $systemData     = Invoke-Expression (Get-Content $systemFile | Out-String)
        [array]$configs = $systemData.AppliedConfigurations
        $nodeName       = $systemData.NodeName
        $azConfigString = "Configuration $($azConfigName)`n{"
        $azConfigString += "`n`tImport-DscResource -ModuleName `'PowerSTIG`'`n"
        $azConfigString += "`n`tNode '$nodeName'`n`t{"

        foreach ($resource in $configs.keys)
        {
            $resourceName = $resource.Replace("PowerSTIG_","")
            $azConfigString += "`n`t`t$resourceName STIG_$resourceName`n`t`t{"
            $resourceParams = $configs.$resource.keys
            if ($null -ne $resourceParams)
            {
                foreach ($param in $resourceParams)
                {
                    $name = $param
                    $value = $configs.$resource.$param
                    $dataType = $value.gettype().name

                    switch ($dataType)
                    {
                        'HashTable' {
                            $azConfigString += "`n`t`t`t$name = @{"
                            $keys = $configs.$resource.$param.keys

                            foreach ($vulID in $keys)
                            {
                                $valueTypes = $configs.$resource.$param.$vulID.keys

                                foreach ($valuetype in $valueTypes)
                                {
                                    $valuedata = $configs.$resource.$param.$vulID | Select-Object -expandproperty $valueType
                                }
                                $azConfigString += "`n`t`t`t`t'$vulID' = @{'$valueType' = '$valuedata'}"
                            }
                            $azConfigString += "`n`t`t`t}"
                        }
                        'Object[]'
                        {
                            $arrayString = ""
                            $vulIDs      = $configs.$resource.$param
                            $i           = 0

                            foreach ($vulID in $vulIDs)
                            {
                                $i++

                                if ($i -ne $vulIDs.Count)
                                {
                                    [string]$arrayString += "'$vulID',"
                                }
                                else
                                {
                                    [string]$arrayString += "'$vulID'"
                                }
                            }
                            $arrayString = $arrayString
                            $azConfigString += "`n`t`t`t$name = @($arrayString)"
                        }
                        default
                        {
                            $value = $configs.$resource.$param
                            $azConfigString += "`n`t`t`t$name = `'$value`'"
                        }
                    }

                }
                $azConfigString += "`n`t`t}`n"
            }
            else
            {
                $azConfigString += "}`n"
            }
        }

        $azConfigString += "`t}`n}"
        Set-Content $azConfigFile.FullName -Value $azConfigString -Force
    }
    Write-Output "`tAzure Automation DSC Configuration Generation Complete"
}

function Publish-AzAutomationNodeConfigs
{
    <#
    .SYNOPSIS
    Imports files generated by Export-AzDscConfigurations to an Azure Automation Account

    .PARAMETER ResourceGroupName
    Name of the Autmation Account ResourceGroup

    .PARAMETER AutomationAccountName
    Name of the Azure Automation Account

    .PARAMETER RootPath
    Path to the Stig Compliance Automation Repository

    .EXAMPLE
    Import-DscConfigurations -Rootpath "C:\StigRepo" -ResourceGroupName "MyAutomationAccountRG" -AutomationAccountName "MyAutomationAccount"
    #>

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

    Write-Output "Starting Azure Automation import - $AutomationAccountName"

    # Validate Repository
    try
    {
        $null = Resolve-Path "$RootPath\Systems" -ErrorAction 'Stop'
        $null = Resolve-Path "$Rootpath\Configurations" -ErrorAction 'Stop'
        $null = Resolve-Path "$Rootpath\Artifacts" -ErrorAction 'Stop'
        $null = Resolve-Path "$Rootpath\Resources" -ErrorAction 'Stop'
        Write-Output "`tSTIG Repository Path is valid:`t`t$RootPath"
    }
    catch
    {
        Write-Output "`n$Rootpath is not a valid STIG Repository"
        Write-Output "Please provide a valid path or build a new repository using the Initialize-StigRepo function"
    }

    # Validate Azure Context
    $azContext = Get-AzContext

    if ($null -ne $azContext)
    {
        $azSubscription = $azContext.Name.Split(" ")[0]
        Write-Output "`tConnected to Azure Subscription:`t$azSubscription"
    }
    else
    {
        Write-Output "`tPowershell session is not connected to an Azure Subscription. Follow the prompt to login."
        Connect-AzAccount
    }

    # Validate Azure Automation Account
    try
    {
        $null = Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -ErrorAction 'Stop'
        Write-Output "`tAzure Automation Account is valid:`t$AutomationAccountName"
    }
    catch
    {
        Write-Output "`nAutomation Account is invalid or cannot be found."
        Write-Output "Verify the Automation Account Exists and that your session is connect to the correct Azure Subscription and try again."
        exit
    }

    # Get DSC Configuration Scripts
    try
    {
        $azConfigPath   = (Resolve-Path -Path "$RootPath\Artifacts\AzConfigs" -ErrorAction 'Stop').Path
        $azConfigFiles  = Get-Childitem "$azConfigPath\*.ps1"
    }
    catch
    {
        Write-Output "`tNo Azure DscConfiguration Files Present. Exporting Azure Automation Configuration Files."
        Export-AzDscConfigurations -RootPath $RootPath
        $azConfigPath   = (Resolve-Path -Path "$RootPath\Artifacts\AzConfigs" -ErrorAction 'Stop').Path
        $azConfigFiles  = Get-Childitem "$azConfigPath\*.ps1"
    }

    Write-Output "`nStarting Jobs to publish STIG configurations to Azure Automation"
    $jobs = New-Object System.Collections.ArrayList

    foreach ($azConfigFile in $azConfigFiles)
    {
        Write-Output "`tStarting Node Configuration Publish Job - $($azConfigFile.BaseName)"

        $job = Start-Job -ScriptBlock {

            $azConfigFile           = $using:azConfigFile
            $ResourceGroupName      = $using:ResourceGroupName
            $AutomationAccountName  = $using:AutomationAccountName
            $azConfigPath           = $azConfigFile.FullName
            $azConfigName           = (Get-Item $azConfigPath).BaseName

            try
            {
                $params = @{
                    Path                    = $azConfigPath
                    ConfigurationName       = $azConfigName
                    ResourceGroupName       = $ResourceGroupName
                    AutomationAccountName   = $AutomationAccountName
                    Force = $true
                }
                $null = Import-AzAutomationDscNodeConfiguration @params -ErrorAction 'Stop'
                Write-Output "`t$azConfigName - Publishing job Succeeded"
            }
            catch
            {
                Write-Output "`t$azConfigName - Publishing Job Failed"
                continue
            }
        }
        $null = $jobs.add($job.ID)
    }

    if ($jobs.count -ge 1)
    {
        Write-Output "Publish Node Configuration Jobs created. Checking status every 30 seconds until all jobs are complete."

        do
        {
            $completedJobs = (Get-Job -ID $jobs | Where-Object {$_.state -ne "Running"}).count
            $runningjobs   = (Get-Job -ID $jobs | Where-Object {$_.state -eq "Running"}).count
            Write-Output "`tPublish Node Configuration Job Status:`t$runningJobs Jobs Currently Processing`t$completedJobs/$($jobs.count) Jobs Completed"
            Start-Sleep -Seconds 30
        }
        while ((Get-Job -ID $jobs).State -contains "Running")
        Write-Output "`n$($jobs.count) Jobs Completed. Outputting Results."
        Get-Job -ID $jobs | Wait-Job | Receive-Job
    }
    else
    {
        Write-Output "`n`tNo Jobs Generated."
    }
    Write-Output "Azure Automation import complete"
}

function Set-AzAutomationNodeConfigs
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
        $AutomationAccountName,

        [Parameter()]
        [switch]
        $SkipValidation
    )

    if (-not $SkipValidation)
    {

        Write-Output "Validating Environment for DSC Node Configuration Assignments"
        # Validate Repository
        try
        {
            $null = Resolve-Path "$RootPath\Systems" -ErrorAction 'Stop'
            $null = Resolve-Path "$Rootpath\Configurations" -ErrorAction 'Stop'
            $null = Resolve-Path "$Rootpath\Artifacts" -ErrorAction 'Stop'
            $null = Resolve-Path "$Rootpath\Resources" -ErrorAction 'Stop'
            Write-Output "`tSTIG Repository Path is valid:`t`t$RootPath"
        }
        catch
        {
            Write-Output "`n$Rootpath is not a valid STIG Repository"
            Write-Output "Please provide a valid path or build a new repository using the Initialize-StigRepo function"
        }

        # Validate Azure Context
        $azContext = Get-AzContext

        if ($null -ne $azContext)
        {
            $azSubscription = $azContext.Name.Split(" ")[0]
            Write-Output "`tConnected to Azure Subscription:`t$azSubscription"
        }
        else
        {
            Write-Output "`tPowershell session is not connected to an Azure Subscription. Follow the prompt to login."
            Connect-AzAccount
        }

        # Validate Azure Automation Account
        try
        {
            $null = Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -ErrorAction 'Stop'
            Write-Output "`tAzure Automation Account is valid:`t$AutomationAccountName"
        }
        catch
        {
            Write-Output "`tAutomation Account is invalid or cannot be found."
            Write-Output "`tVerify the Automation Account Exists and that your session is connect to the correct Azure Subscription and try again."
            exit
        }
    }

    # Start Configuration Assignments
    Write-Output "`nStarting DSC Node Configuration Assignments"

    # Get DSC Nodes
    Write-Output "`tGetting Azure Automation DSC Nodes"
    $nodes = Get-AzAutomationDscNode -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName

    if ($nodes.count -eq 0)
    {
        Write-Output "`tNo DSC Nodes Found"
        exit
    }

    # Get DSC Node Configs
    Write-Output "`tGetting Azure Automation DSC Node Configurations"
    $nodeConfigs = Get-AzAutomationDscNodeConfiguration -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName

    if ($nodeConfigs.count -eq 0)
    {
        Write-Output "`tNo DSC Node Configurations Found"
        exit
    }

    foreach ($node in $nodes)
    {
        Write-Output "`tAssiging Node Configuration to $($node.Name)"
        $tryNodeConfig = $false
        $configName = "STIG_" + $node.Name.Replace("-","_")

        try
        {
            $nodeConfig = $nodeConfigs | Where-Object {$_.Name -like "*$configName*"}
            $null = $node | Set-AzAutomationDscNode -NodeConfigurationName $nodeConfig -Force -ErrorAction 'Stop'
        }
        catch
        {
            Write-Output "`t`tDscNodeConfiguration Assignment Failed. Trying DscConfiguration."
            $tryDscConfig = $true
        }

        if ($tryDscConfig)
        {
            try
            {
                $nodeConfig = Get-AzAutomationDscConfiguration -Name $configName -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -ErrorAction 'Stop'
                $null = $node | Set-AzAutomationDscNode -NodeConfigurationName $nodeConfig.Name -Force
            }
            catch
            {
                Write-Warning "$($node.Name) - Configuration Assignment Failed. Confirm that a DSC configuration has been published and try again.`n"
                continue
            }
        }
    }
    Write-Output "DSC Node Configuration Assignment Complete."
}