function New-SystemData
{

    <#
    .SYNOPSIS
    Generates configuration data based on a provided Organizational Unit
    DistinguishedName searchbase.

    .PARAMETER SearchBase
    Distringuised Name of the Active Directory Security Group you want to target for Node Data generation.
    Example -searchbase "CN=SCAR Target Machines,OU=_Domain Administration,DC=corp,DC=contoso,DC=com"

    .PARAMETER SystemsPath
    Path to the SCAR Node Data folder.
    Example -SystemsPath "C:\SCAR\Systems"

    .PARAMETER DomainName
    DomainName should be set to the domain name of your domain. Defaults to local system's Domain.
    Example -DomainName "corp.contoso"

    .PARAMETER ForestName
    ForestName should be set to the forest name of your domain. Defaults to local system's Forest.
    Example -ForestName "com"

    .EXAMPLE
    New-SystemData -Rootpath "C:\SCAR" -SearchBase "CN=Servers,CN=Enterprise Management,DC=contoso,DC=com"
    #>

    [cmdletbinding()]
    param(

        [Parameter()]
        [string]
        $SearchBase,

        [Parameter()]
        [switch]
        $IncludeFilePaths,

        [Parameter()]
        [switch]
        $LocalHost,

        [Parameter()]
        [switch]
        $RootOrgUnit,

        [Parameter()]
        [array]
        $ComputerName,

        [Parameter()]
        [string]
        [ValidateSet(
            "MemberServers",
            "AllServers",
            "Full",
            "OrgUnit",
            "Targeted",
            "Local"
        )]
        $Scope = "MemberServers",

        [Parameter()]
        [string]
        $RootPath = (Get-Location).path,

        [Parameter()]
        [hashtable]
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
    $IncludeFilePaths   = $true
    $SystemsPath        = (Resolve-Path -Path "$RootPath\Systems").Path
    $targetMachineOus   = New-Object System.Collections.ArrayList
    $targetMachines     = New-Object System.Collections.ArrayList
    $orgUnits           = New-Object System.Collections.ArrayList
    $osVersion          = (Get-WmiObject Win32_OperatingSystem).caption

    Write-Output "`tBeginning DSC Configuration Data Build - Identifying Target Systems."

    if ('' -ne $SearchBase)             {$Scope = "OrgUnit"}
    elseif ($LocalHost)                 {$Scope = "Local"}
    elseif ($ComputerName.count -eq 1)  {$Scope = "Targeted"}

    switch ($Scope)
    {
        "OrgUnit"       {$targetMachines = @(Get-ADComputer -SearchBase $SearchBase -Filter * -Properties "operatingsystem", "distinguishedname") ; break }
        "MemberServers" {$targetMachines = @(Get-ADComputer -Filter {OperatingSystem -like "**server*"} -Properties "operatingsystem", "distinguishedname" | Where-Object {$_.DistinguishedName -Notlike "*Domain Controllers*"}) ; break }
        "AllServers"    {$targetMachines = @(Get-ADComputer -Filter {OperatingSystem -like "**server*"} -Properties "operatingsystem", "distinguishedname") ; break }
        "Full"          {$targetMachines = @(Get-ADComputer -Filter * -Properties "operatingsystem", "distinguishedname") ; break }
        "Targeted"      {$targetMachines = @(Get-AdComputer -Identity "$ComputerName" -Properties "operatingsystem","distinguishedname") ; break }
        "Local" 
        {
            if ($osVersion -like '*Server*') 
            {           
                $targetMachines = @(
                    @{
                        Name              = $env:computerName
                        OperatingSystem   = $osVersion
                        distinguishedname = "Servers"
                    }
                )
            }    
            else 
            {
                $targetMachines = @(
                    @{
                        Name              = $env:computerName
                        OperatingSystem   = $osVersion
                        distinguishedname = "Computers"
                    }
                )
            }
        }
    }

    if (-not($Localhost))
    {
        Write-Output "`tIdentifying Organizational Units for $($targetMachines.count) systems."
        
        if ($RootOrgUnit)
        {
            $orgUnits = Get-ADOrganizationalUnit -SearchBase $SearchBase -SearchScope OneLevel
        }
        else
        {
            foreach ($targetMachine in $targetMachines)
            {
                $targetMachineOUs += $targetMachine.DistinguishedName.Split(',')[1].split('=')[1]
            }

            $uniqueOUs = $targetMachineOus | Get-Unique 
            
            foreach ($ouName in $uniqueOUs)
            {
                $filter = [scriptblock]::Create("Name -eq `"$ouName`"")
                $ouObject = Get-ADOrganizationalUnit -Filter $filter
                $null = $orgUnits.add($ouObject)
            }

            if ($Scope -eq "Full")
            {
                $null = $orgUnits.add("Computers")
            }
        }
        Write-Output "`tSystem Count - $($targetMachines.Count)"
    }
    else
    {
        Write-Output "`tGenerating System Data for LocalHost."
        [array]$orgUnits = "LocalHost"
    }

    foreach ($ou in $orgUnits)
    {

        if ($LocalHost -or ($scope -eq "Local"))
        {
            $targetMachines = $env:ComputerName
            $ou = "LocalHost"
            $ouFolder = "$SystemsPath\$env:computerName"
        }
        elseif ($scope -eq "Targeted")
        {
            $targetMachines = $targetMachines.Name
            $ouFolder = "$SystemsPath\$($ou.name)"
        }
        elseif ($ou -eq "Computers")
        {
            $computersContainer = (Get-ADDomain).ComputersContainer
            $targetMachines     = (Get-ADComputer -SearchBase $computersContainer -Properties OperatingSystem -filter {OperatingSystem -like "*Windows 10*"} ).name
            $ouFolder           = "$SystemsPath\Windows 10"
        }
        else
        {
            $targetMachines = (Get-ADComputer -filter * -SearchBase "$($ou.DistinguishedName)").name
            $ouFolder = "$SystemsPath\$($ou.name)"
        }
        $jobs = New-Object System.Collections.ArrayList
        $ouMachineCount = $targetMachines.Count
        $currentMachineCount = 0

        if ($targetMachines.Count -gt 0)
        {
            if (-not (Test-Path $ouFolder))
            {
                $null = New-Item -Path $ouFolder -ItemType Directory -Force
            }

            if   ($ou -eq "Computers")
            {
                Write-Output "`n`t$ou - $ouMachineCount Node(s) identified"
            }
            else
            {
                Write-Output "`n`t$($ou.name) - $ouMachineCount Node(s) identified"
            }

            foreach ($machine in $TargetMachines)
            {
                $currentMachineCount++
                try
                {
                    $null = Test-WsMan -Computername $machine -Authentication Default -ErrorAction Stop
                    Write-Output "`t`tStarting Job ($currentMachineCount/$ouMachineCount) - Generate System Data for $machine"
                }
                catch
                {
                    Write-Output "`t`tError - Unable to connect to $machine via WinRM."
                    continue
                }

                $job = Start-Job -Scriptblock {

                    Import-Module StigRepo -Force

                    $rootPath           = $using:RootPath
                    $machine            = $using:machine
                    $LcmSettings        = $using:lcmsettings
                    $ouFolder           = $using:oufolder
                    $LocalHost          = $using:LocalHost
                    $SystemsPath        = $using:SystemsPath
                    $IncludeFilePaths   = $using:IncludeFilePaths

                    #region Get Applicable STIGs

                     $applicableStigs = @(Get-ApplicableStigs -Computername $machine)
                    
                    
                    if ($IncludeFilePaths)
                    {
                        switch -Wildcard ($applicableStigs)
                        {
                            "WindowsServer*"
                            {
                                $filter = "(&(objectCategory=computer)(objectClass=computer)(cn=$machine))"
                                $distinguishedName = ([adsisearcher]$filter).FindOne().Properties.distinguishedname
                                switch -Wildcard ($distinguishedName)
                                {
                                    "*Domain Controllers*"  {$StigType = "DomainController";    $osRole = "DC"}
                                    default                 {$StigType = "WindowsServer";       $osRole = "MS"}
                                }

                                $osVersion = ($ApplicableStigs | Where-Object {$_ -like "WindowsServer*"}).split("-")[1]
                                $osStigFiles = @{
                                    orgSettings  = Get-StigFiles -Rootpath $RootPath -StigType $stigType -Version $osVersion -FileType "OrgSettings" -NodeName $machine
                                    xccdfPath    = Get-StigFiles -Rootpath $RootPath -StigType $stigType -Version $osVersion -FileType "Xccdf" -NodeName $machine
                                    manualChecks = Get-StigFiles -Rootpath $RootPath -StigType $stigType -Version $osVersion -FileType "ManualChecks" -NodeName $machine
                                }
                            }
                            "DotNetFramework"
                            {
                                $dotNetStigFiles = @{
                                    orgsettings  = Get-StigFiles -Rootpath $Rootpath -StigType "DotNetFramework" -Version 4 -FileType "OrgSettings" -NodeName $machine
                                    xccdfPath    = Get-StigFiles -Rootpath $Rootpath -StigType "DotNetFramework" -Version 4 -FileType "Xccdf" -NodeName $machine
                                    manualChecks = Get-StigFiles -Rootpath $Rootpath -StigType "DotNetFramework" -Version 4 -FileType "ManualChecks" -NodeName $machine
                                }
                            }
                            "InternetExplorer"
                            {
                                $ieStigFiles = @{
                                    xccdfPath      = Get-StigFiles -Rootpath $Rootpath -StigType "InternetExplorer" -Version 11 -FileType "Xccdf" -NodeName $machine
                                    orgSettings    = Get-StigFiles -Rootpath $Rootpath -StigType "InternetExplorer" -Version 11 -FileType "OrgSettings" -NodeName $machine
                                    manualChecks   = Get-StigFiles -Rootpath $Rootpath -StigType "InternetExplorer" -Version 11 -FileType "ManualChecks" -NodeName $machine
                                }
                            }
                            "WindowsClient"
                            {
                                $Win10StigFiles = @{
                                    orgSettings  = Get-StigFiles -Rootpath $RootPath -StigType "WindowsClient" -Version $osVersion -FileType "OrgSettings" -NodeName $machine
                                    xccdfPath    = Get-StigFiles -Rootpath $RootPath -StigType "WindowsClient" -Version $osVersion -FileType "Xccdf" -NodeName $machine
                                    manualChecks = Get-StigFiles -Rootpath $RootPath -StigType "WindowsClient" -Version $osVersion -FileType "ManualChecks" -NodeName $machine
                                }
                            }
                            "WindowsDefender"
                            {
                                $WinDefenderStigFiles = @{
                                    orgSettings  = Get-StigFiles -Rootpath $RootPath -StigType "WindowsDefender" -FileType "OrgSettings" -NodeName $machine
                                    xccdfPath    = Get-StigFiles -Rootpath $RootPath -StigType "WindowsDefender" -FileType "Xccdf" -NodeName $machine
                                    manualChecks = Get-StigFiles -Rootpath $RootPath -StigType "WindowsDefender" -FileType "ManualChecks" -NodeName $machine
                                }
                            }
                            "WindowsFirewall"
                            {
                                $WinFirewallStigFiles = @{
                                    orgSettings  = Get-StigFiles -Rootpath $RootPath -StigType "WindowsFirewall" -FileType "OrgSettings" -NodeName $machine
                                    xccdfPath    = Get-StigFiles -Rootpath $RootPath -StigType "WindowsFirewall" -FileType "Xccdf" -NodeName $machine
                                    manualChecks = Get-StigFiles -Rootpath $RootPath -StigType "WindowsFirewall" -FileType "ManualChecks" -NodeName $machine
                                }
                            }
                            "WindowsDnsServer"
                            {
                                $WindowsDnsStigFiles = @{
                                    orgSettings  = Get-StigFiles -Rootpath $RootPath -StigType "WindowsDnsServer" -FileType "OrgSettings" -NodeName $machine
                                    xccdfPath    = Get-StigFiles -Rootpath $RootPath -StigType "WindowsDnsServer" -FileType "Xccdf" -NodeName $machine
                                    manualChecks = Get-StigFiles -Rootpath $RootPath -StigType "WindowsDnsServer" -FileType "ManualChecks" -NodeName $machine
                                }
                            }
                            "Office2016"
                            {
                                $word2016xccdfPath          = Get-StigFiles -Rootpath $Rootpath -StigType "Office2016_Word" -Version 16 -FileType "Xccdf" -NodeName $machine
                                $word2016orgSettings        = Get-StigFiles -Rootpath $Rootpath -StigType "Office2016_Word" -Version 16 -FileType "OrgSettings" -NodeName $machine
                                $word2016manualChecks       = Get-StigFiles -Rootpath $Rootpath -StigType "Office2016_Word" -Version 16 -FileType "ManualChecks" -NodeName $machine
                                $powerpoint2016xccdfPath    = Get-StigFiles -Rootpath $Rootpath -StigType "Office2016_PowerPoint" -Version 16 -FileType "Xccdf" -NodeName $machine
                                $powerpoint2016orgSettings  = Get-StigFiles -Rootpath $Rootpath -StigType "Office2016_PowerPoint" -Version 16 -FileType "OrgSettings" -NodeName $machine
                                $powerpoint2016manualChecks = Get-StigFiles -Rootpath $Rootpath -StigType "Office2016_PowerPoint" -Version 16 -FileType "ManualChecks" -NodeName $machine
                                $outlook2016xccdfPath       = Get-StigFiles -Rootpath $Rootpath -StigType "Office2016_Outlook" -Version 16 -FileType "Xccdf" -NodeName $machine
                                $outlook2016orgSettings     = Get-StigFiles -Rootpath $Rootpath -StigType "Office2016_Outlook" -Version 16 -FileType "OrgSettings" -NodeName $machine
                                $outlook2016manualChecks    = Get-StigFiles -Rootpath $Rootpath -StigType "Office2016_Outlook" -Version 16 -FileType "ManualChecks" -NodeName $machine
                                $excel2016xccdfPath         = Get-StigFiles -Rootpath $Rootpath -StigType "Office2016_Excel" -Version 16 -FileType "Xccdf" -NodeName $machine
                                $excel2016orgSettings       = Get-StigFiles -Rootpath $Rootpath -StigType "Office2016_Excel" -Version 16 -FileType "OrgSettings" -NodeName $machine
                                $excel2016manualChecks      = Get-StigFiles -Rootpath $Rootpath -StigType "Office2016_Excel" -Version 16 -FileType "ManualChecks" -NodeName $machine
                            }
                            "Office2013"
                            {
                                $word2013xccdfPath          = Get-StigFiles -Rootpath $Rootpath -StigType "Office2013_word" -Version 15 -FileType "Xccdf" -NodeName $machine
                                $word2013orgSettings        = Get-StigFiles -Rootpath $Rootpath -StigType "Office2013_word" -Version 15 -FileType "OrgSettings" -NodeName $machine
                                $word2013manualChecks       = Get-StigFiles -Rootpath $Rootpath -StigType "Office2013_word" -Version 15 -FileType "ManualChecks" -NodeName $machine
                                $powerpoint2013xccdfPath    = Get-StigFiles -Rootpath $Rootpath -StigType "Office2013_powerpoint" -Version 15 -FileType "Xccdf" -NodeName $machine
                                $powerpoint2013orgSettings  = Get-StigFiles -Rootpath $Rootpath -StigType "Office2013_powerpoint" -Version 15 -FileType "OrgSettings" -NodeName $machine
                                $powerpoint2013manualChecks = Get-StigFiles -Rootpath $Rootpath -StigType "Office2013_powerpoint" -Version 15 -FileType "ManualChecks" -NodeName $machine
                                $outlook2013xccdfPath       = Get-StigFiles -Rootpath $Rootpath -StigType "Office2013_outlook" -Version 15 -FileType "Xccdf" -NodeName $machine
                                $outlook2013orgSettings     = Get-StigFiles -Rootpath $Rootpath -StigType "Office2013_outlook" -Version 15 -FileType "OrgSettings" -NodeName $machine
                                $outlook2013manualChecks    = Get-StigFiles -Rootpath $Rootpath -StigType "Office2013_outlook" -Version 15 -FileType "ManualChecks" -NodeName $machine
                                $excel2013xccdfPath         = Get-StigFiles -Rootpath $Rootpath -StigType "Office2013_excel" -Version 15 -FileType "Xccdf" -NodeName $machine
                                $excel2013orgSettings       = Get-StigFiles -Rootpath $Rootpath -StigType "Office2013_excel" -Version 15 -FileType "OrgSettings" -NodeName $machine
                                $excel2013manualChecks      = Get-StigFiles -Rootpath $Rootpath -StigType "Office2013_excel" -Version 15 -FileType "ManualChecks" -NodeName $machine
                            }
                            "SQLServerInstance"
                            {
                                $version = "2016"
                                $sqlInstanceStigFiles = @{
                                    xccdfPath      = Get-StigFiles -Rootpath $Rootpath -Version $Version -StigType "SqlServerInstance" -FileType "Xccdf" -NodeName $machine
                                    orgSettings    = Get-StigFiles -Rootpath $Rootpath -Version $Version -StigType "SqlServerInstance" -FileType "OrgSettings" -NodeName $machine
                                    manualChecks   = Get-StigFiles -Rootpath $Rootpath -Version $Version -StigType "SqlServerInstance" -FileType "ManualChecks" -NodeName $machine
                                }
                            }
                            "SqlServerDatabase"
                            {
                                $sqlDatabaseStigFiles = @{
                                    xccdfPath      = Get-StigFiles -Rootpath $Rootpath -Version $Version -StigType "SqlServerDataBase" -FileType "Xccdf" -NodeName $machine
                                    orgSettings    = Get-StigFiles -Rootpath $Rootpath -Version $Version -StigType "SqlServerDataBase" -FileType "OrgSettings" -NodeName $machine
                                    manualChecks   = Get-StigFiles -Rootpath $Rootpath -Version $Version -StigType "SqlServerDataBase" -FileType "ManualChecks" -NodeName $machine
                                }
                            }
                            "WebSite*"
                            {
                                if ($env:computername -eq $machine)
                                {
                                    $iisInfo = Get-ItemProperty HKLM:\SOFTWARE\Microsoft\InetStp\
                                    $iisVersion = "$($iisInfo.MajorVersion).$($iisInfo.MinorVersion)"
                                }
                                else 
                                {
                                    $iisVersion = Invoke-Command -ComputerName $machine -Scriptblock {
                                        $iisData = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\InetStp"
                                        $localIisVersion = "$($iisData.MajorVersion).$($iisData.MinorVersion)"
                                        return $localiisVersion
                                    }
                                }
                                $WebsiteStigFiles = @{
                                    xccdfPath      = Get-StigFiles -Rootpath $Rootpath -StigType "WebSite" -Version $iisVersion -FileType "Xccdf" -NodeName $machine
                                    orgSettings    = Get-StigFiles -Rootpath $Rootpath -StigType "WebSite" -Version $iisVersion -FileType "OrgSettings" -NodeName $machine
                                    manualChecks   = Get-StigFiles -Rootpath $Rootpath -StigType "WebSite" -Version $iisVersion -FileType "ManualChecks" -NodeName $machine
                                }
                            }
                            "WebServer*"
                            {
                                if ($env:computername -eq $machine)
                                {
                                    $iisInfo = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\InetStp"
                                    $iisVersion = "$($iisInfo.MajorVersion).$($iisInfo.MinorVersion)"
                                }
                                else 
                                {
                                    $iisVersion = Invoke-Command -ComputerName $machine -Scriptblock {
                                        $iisData = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\InetStp"
                                        $localIisVersion = "$($iisData.MajorVersion).$($iisData.MinorVersion)"
                                        return $localiisVersion
                                    }
                                }
                                $webServerStigFiles = @{
                                    xccdfPath      = Get-StigFiles -Rootpath $Rootpath -StigType "WebServer" -Version $iisVersion -FileType "Xccdf" -NodeName $machine
                                    orgSettings    = Get-StigFiles -Rootpath $Rootpath -StigType "WebServer" -Version $iisVersion -FileType "OrgSettings" -NodeName $machine
                                    manualChecks   = Get-StigFiles -Rootpath $Rootpath -StigType "WebServer" -Version $iisVersion -FileType "ManualChecks" -NodeName $machine
                                }
                            }
                            "McAfee"
                            {
                                $mcafeeStigFiles = @{
                                    xccdfPath      = Get-StigFiles -Rootpath $Rootpath -StigType "McAfee" -FileType "Xccdf" -NodeName $machine
                                    orgSettings    = Get-StigFiles -Rootpath $Rootpath -StigType "McAfee" -FileType "OrgSettings" -NodeName $machine
                                    manualChecks   = Get-StigFiles -Rootpath $Rootpath -StigType "McAfee" -FileType "ManualChecks" -NodeName $machine
                                }
                            }
                            "FireFox"
                            {
                                $fireFoxStigFiles = @{
                                    xccdfPath      = Get-StigFiles -Rootpath $Rootpath -StigType "FireFox" -FileType "Xccdf" -NodeName $machine
                                    orgSettings    = Get-StigFiles -Rootpath $Rootpath -StigType "FireFox" -FileType "OrgSettings" -NodeName $machine
                                    manualChecks   = Get-StigFiles -Rootpath $Rootpath -StigType "FireFox" -FileType "ManualChecks" -NodeName $machine
                                }
                            }
                            "Edge"
                            {
                                $edgeStigFiles = @{
                                    xccdfPath      = Get-StigFiles -Rootpath $Rootpath -StigType "Edge" -FileType "Xccdf" -NodeName $machine
                                    orgSettings    = Get-StigFiles -Rootpath $Rootpath -StigType "Edge" -FileType "OrgSettings" -NodeName $machine
                                    manualChecks   = Get-StigFiles -Rootpath $Rootpath -StigType "Edge" -FileType "ManualChecks" -NodeName $machine
                                }
                            }
                            "Chrome"
                            {
                                $chromeStigFiles = @{
                                    xccdfPath      = Get-StigFiles -Rootpath $Rootpath -StigType "Chrome" -FileType "Xccdf" -NodeName $machine
                                    orgSettings    = Get-StigFiles -Rootpath $Rootpath -StigType "Chrome" -FileType "OrgSettings" -NodeName $machine
                                    manualChecks   = Get-StigFiles -Rootpath $Rootpath -StigType "Chrome" -FileType "ManualChecks" -NodeName $machine
                                }
                            }
                            "Adobe"
                            {
                                $adobeStigFiles = @{
                                    orgsettings  = Get-StigFiles -Rootpath $Rootpath -StigType "Adobe" -FileType "OrgSettings" -NodeName $machine
                                    xccdfPath    = Get-StigFiles -Rootpath $Rootpath -StigType "Adobe" -FileType "Xccdf" -NodeName $machine
                                    manualChecks = Get-StigFiles -Rootpath $Rootpath -StigType "Adobe" -FileType "ManualChecks" -NodeName $machine
                                }
                            }
                            "OracleJRE"
                            {
                                $oracleStigFiles = @{
                                    xccdfPath      = Get-StigFiles -Rootpath $Rootpath -StigType "OracleJRE" -FileType "Xccdf" -NodeName $machine
                                    orgSettings    = Get-StigFiles -Rootpath $Rootpath -StigType "OracleJRE" -FileType "OrgSettings" -NodeName $machine
                                    manualChecks   = Get-StigFiles -Rootpath $Rootpath -StigType "OracleJRE" -FileType "ManualChecks" -NodeName $machine
                                }
                            }

                        }
                    }
                    #endregion

                    #region Generate Configuration Data
                    try
                    {

                        #region LocalHost Data
                        if ($LocalHost)
                        {
                            $compName       = $env:ComputerName
                            $configContent  = New-Object System.Collections.ArrayList
                            $null = $configContent.add("@{`n`tNodeName = `"$compName`"`n`n")
                        }
                        else
                        {
                            $configContent  = New-Object System.Collections.ArrayList
                            $null = $configContent.add("@{`n`tNodeName = `"$machine`"")
                        }

                        #endregion Localhost Data

                        #region AppliedConfigurations
                        if ($null -ne $applicableSTIGs)
                        {
                            $null = $configContent.add("`n`n`tAppliedConfigurations  =")
                            $null = $configContent.add("`n`t@{")

                            switch -Wildcard ($applicableSTIGs)
                            {
                                {$_ -like "*WindowsServer*" -or $_ -like "*DomainController*"}
                                {
                                    $filter = "(&(objectCategory=computer)(objectClass=computer)(cn=$machine))"
                                    $distinguishedName = ([adsisearcher]$filter).FindOne().Properties.distinguishedname
                                    $osVersion = ($ApplicableStigs | Where-Object {$_ -like "WindowsServer*"}).split("-")[1]
                                    switch -Wildcard ($distinguishedName)
                                    {
                                        "*Domain Controllers*"  {$StigType = "DomainController";    $osRole = "DC"}
                                        default                 {$StigType = "WindowsServer";       $osRole = "MS"}
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
                                    $null = $configContent.add("`n`t`t`tBrowserVersion      = `"11`"")
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
                                        $null = $configContent.add("`n`t`t`tOrgSettings		    = `"$($dotNetStigFiles.orgSettings)`"")
                                        $null = $configContent.add("`n`t`t`tManualChecks        = `"$($dotNetStigFiles.manualChecks)`"")
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

                                    if ($IncludeFilePaths)
                                    {
                                        $null = $configContent.add("`n`n`t`tPowerSTIG_WindowsDefender =")
                                        $null = $configContent.add("`n`t`t@{")
                                        $null = $configContent.add("`n`t`t`txccdfPath            = `"$($winDefenderStigFiles.xccdfPath)`"")
                                        $null = $configContent.add("`n`t`t`tOrgSettings          = `"$($winDefenderStigFiles.orgSettings)`"")
                                        $null = $configContent.add("`n`t`t`tManualChecks         = `"$($winDefenderStigFiles.manualChecks)`"")
                                        $null = $configContent.add("`n`t`t}")
                                    }
                                    else { $null = $configContent.add("`n`n`t`tPowerSTIG_WindowsDefender = @{}") }
                                }
                                "WindowsFirewall"
                                {

                                    if ($IncludeFilePaths)
                                    {
                                        $null = $configContent.add("`n`n`t`tPowerSTIG_WindowsFirewall =")
                                        $null = $configContent.add("`n`t`t@{")
                                        $null = $configContent.add("`n`t`t`txccdfPath            = `"$($winFirewallStigFiles.xccdfPath)`"")
                                        $null = $configContent.add("`n`t`t`tOrgSettings          = `"$($winFirewallStigFiles.orgSettings)`"")
                                        $null = $configContent.add("`n`t`t`tManualChecks         = `"$($winFirewallStigFiles.manualChecks)`"")
                                        $null = $configContent.add("`n`t`t}")
                                    }
                                    else { $null = $configContent.add("`n`n`t`tPowerSTIG_WindowsFirewall = @{}") }
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
                                        $null = $configContent.add("`n`t`t`txccdfPath           = `"$Excel2016xccdfPath`"")
                                        $null = $configContent.add("`n`t`t`tOrgSettings         = `"$Excel2016OrgSettings`"")
                                        $null = $configContent.add("`n`t`t`tManualChecks        = `"$Excel2016ManualChecks`"")
                                    }
                                    $null = $configContent.add("`n`t`t}")
                                    $null = $configContent.add("`n`n`t`tPowerSTIG_Office2016_Outlook =")
                                    $null = $configContent.add("`n`t`t@{")

                                    if ($IncludeFilePaths)
                                    {
                                        $null = $configContent.add("`n`t`t`txccdfPath           = `"$Outlook2016xccdfPath`"")
                                        $null = $configContent.add("`n`t`t`tOrgSettings         = `"$Outlook2016OrgSettings`"")
                                        $null = $configContent.add("`n`t`t`tManualChecks        = `"$Outlook2016ManualChecks`"")
                                        $null = $configContent.add("`n`t`t}")
                                    }
                                    else { $null = $configContent.add("`n`n`t`t}") }

                                    $null = $configContent.add("`n`n`t`tPowerSTIG_Office2016_PowerPoint =")
                                    $null = $configContent.add("`n`t`t@{")

                                    if ($IncludeFilePaths)
                                    {
                                        $null = $configContent.add("`n`t`t`txccdfPath           = `"$PowerPoint2016xccdfPath`"")
                                        $null = $configContent.add("`n`t`t`tOrgSettings         = `"$PowerPoint2016OrgSettings`"")
                                        $null = $configContent.add("`n`t`t`tManualChecks        = `"$PowerPoint2016ManualChecks`"")
                                        $null = $configContent.add("`n`t`t}")
                                    }
                                    else { $null = $configContent.add("`n`n`t`t}") }

                                    $null = $configContent.add("`n`n`t`tPowerSTIG_Office2016_Word =")
                                    $null = $configContent.add("`n`t`t@{")

                                    if ($IncludeFilePaths)
                                    {
                                        $null = $configContent.add("`n`t`t`txccdfPath           = `"$Word2016xccdfPath`"")
                                        $null = $configContent.add("`n`t`t`tOrgSettings         = `"$Word2016OrgSettings`"")
                                        $null = $configContent.add("`n`t`t`tManualChecks        = `"$Word2016ManualChecks`"")
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
                                        $null = $configContent.add("`n`t`t`txccdfPath           = `"$Excel2013xccdfPath`"")
                                        $null = $configContent.add("`n`t`t`tOrgSettings         = `"$Excel2013OrgSettings`"")
                                        $null = $configContent.add("`n`t`t`tManualChecks        = `"$Excel2013ManualChecks`"")
                                        $null = $configContent.add("`n`t`t}")
                                    }
                                    else { $null = $configContent.add("`n`n`t`t}") }

                                    $null = $configContent.add("`n`n`t`tPowerSTIG_Office2013_Outlook =")
                                    $null = $configContent.add("`n`t`t@{")

                                    if ($IncludeFilePaths)
                                    {
                                        $null = $configContent.add("`n`t`t`txccdfPath           = `"$Outlook2013xccdfPath`"")
                                        $null = $configContent.add("`n`t`t`tOrgSettings         = `"$Outlook2013OrgSettings`"")
                                        $null = $configContent.add("`n`t`t`tManualChecks        = `"$Outlook2013ManualChecks`"")
                                        $null = $configContent.add("`n`t`t}")
                                    }
                                    else { $null = $configContent.add("`n`n`t`t}") }

                                    $null = $configContent.add("`n`n`t`tPowerSTIG_Office2013_PowerPoint =")
                                    $null = $configContent.add("`n`t`t@{")

                                    if ($IncludeFilePaths)
                                    {
                                        $null = $configContent.add("`n`t`t`txccdfPath           = `"$PowerPoint2013xccdfPath`"")
                                        $null = $configContent.add("`n`t`t`tOrgSettings         = `"$PowerPoint2013OrgSettings`"")
                                        $null = $configContent.add("`n`t`t`tManualChecks        = `"$PowerPoint2013ManualChecks`"")
                                        $null = $configContent.add("`n`t`t}")
                                    }
                                    else { $null = $configContent.add("`n`n`t`t}") }

                                    $null = $configContent.add("`n`n`t`tPowerSTIG_Office2013_Word =")
                                    $null = $configContent.add("`n`t`t@{")

                                    if ($IncludeFilePaths)
                                    {
                                        $null = $configContent.add("`n`t`t`txccdfPath           = `"$Word2013xccdfPath`"")
                                        $null = $configContent.add("`n`t`t`tOrgSettings         = `"$Word2013OrgSettings`"")
                                        $null = $configContent.add("`n`t`t`tManualChecks        = `"$Word2013ManualChecks`"")
                                        $null = $configContent.add("`n`t`t}")
                                    }
                                    else { $null = $configContent.add("`n`n`t`t}") }
                                }
                                "Website*"
                                {

                                    if ($env:computername -eq $machine)
                                    {
                                        $iisInfo = Get-ItemProperty HKLM:\SOFTWARE\Microsoft\InetStp\
                                        $iisVersion = "$($iisInfo.MajorVersion).$($iisInfo.MinorVersion)"
                                        
                                        try
                                        {
                                            Import-Module WebAdministration -WarningAction SilentlyContinue

                                            if (Test-Path -Path "IIS:\Sites")
                                            {
                                                $webSites = (Get-Childitem "IIS:\Sites" -ErrorAction stop).name
                                                $appPools = (Get-Childitem "IIS:\AppPools" -ErrorAction stop).name
                                            }
                                            else 
                                            {
                                                Import-Module IISAdministration -WarningAction SilentlyContinue
                                                $webSites = (Get-IISSite).Name
                                                $AppPools = (Get-IISAppPool).Name    
                                            }
                                        }
                                        catch
                                        {
                                            Write-Warning "Unable to list Websites and AppPools for $machine"
                                        }
                                    }
                                    else 
                                    {
                                        $iisVersion = Invoke-Command -ComputerName $machine -Scriptblock {
                                            $iisData = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\InetStp"
                                            $localIisVersion = "$($iisData.MajorVersion).$($iisData.MinorVersion)"
                                            return $localIisVersion
                                        }
                                        [array]$websites = Invoke-Command -Computername $machine -Scriptblock { 
                                            try
                                            {
                                                Import-Module WebAdministration
                                                $webSites = (Get-Childitem "IIS:\Sites").name
                                            }
                                            catch
                                            {
                                                Import-Module IISAdministration
                                                $webSites = (Get-IISSite).Name
                                            }
                                            return $webSites
                                        }
                                        [array]$appPools = Invoke-Command -Computername $machine -Scriptblock { 
                                            try
                                            {
                                                Import-Module WebAdministration
                                                $appPools = (Get-Childitem "IIS:\AppPools").name
                                            }
                                            catch
                                            {
                                                Import-Module IISAdministration
                                                $appPools = (Get-IISAppPool).Name
                                            }
                                            return $appPools
                                        }
                                    }
                                    
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
                                    $null = $configContent.add("`n`t`t`tIISVersion          = `"$IISVersion`"")
                                    $null = $configContent.add("`n`t`t`tWebsiteName         = $websiteString")
                                    $null = $configContent.add("`n`t`t`tWebAppPool          = $appPoolString")

                                    if ($IncludeFilePaths)
                                    {
                                        $null = $configContent.add("`n`t`t`txccdfPath           = `"$($webSiteStigFiles.XccdfPath)`"")
                                        $null = $configContent.add("`n`t`t`tOrgSettings         = `"$($webSiteStigFiles.OrgSettings)`"")
                                        $null = $configContent.add("`n`t`t`tManualChecks        = `"$($webSiteStigFiles.ManualChecks)`"")
                                        $null = $configContent.add("`n`t`t}")
                                    }
                                    else { $null = $configContent.add("`n`t`t}") }
                                }
                                "WebServer*"
                                {
                                    if ($env:computername -eq $machine)
                                    {
                                        $iisInfo = Get-ItemProperty HKLM:\SOFTWARE\Microsoft\InetStp\
                                        $iisVersion = "$($iisInfo.MajorVersion).$($iisInfo.MinorVersion)"
                                    }
                                    else
                                    {
                                        $iisVersion = Invoke-Command -ComputerName $machine -Scriptblock {
                                            $iisData = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\InetStp"
                                            $localIisVersion = "$($iisData.MajorVersion).$($iisData.MinorVersion)"
                                            return $localiisVersion
                                        }   
                                    }
                                    $null = $configContent.add("`n`n`t`tPowerSTIG_WebServer =")
                                    $null = $configContent.add("`n`t`t@{")
                                    $null = $configContent.add("`n`t`t`tSkipRule            = `"V-214429`"")
                                    $null = $configContent.add("`n`t`t`tIISVersion          = `"$iisVersion`"")
                                    $null = $configContent.add("`n`t`t`tLogPath             = `"C:\InetPub\Logs`"")

                                    if ($IncludeFilePaths)
                                    {
                                        $null = $configContent.add("`n`t`t`txccdfPath           = `"$($webServerStigFiles.XccdfPath)`"")
                                        $null = $configContent.add("`n`t`t`tOrgSettings         = `"$($webServerStigFiles.OrgSettings)`"")
                                        $null = $configContent.add("`n`t`t`tManualChecks        = `"$($webServerStigFiles.ManualChecks)`"")
                                        $null = $configContent.add("`n`t`t}")
                                    }
                                    else { $null = $configContent.add("`n`n`t`t}") }
                                }
                                "FireFox"
                                {
                                    $null = $configContent.add("`n`n`t`tPowerSTIG_Firefox =")
                                    $null = $configContent.add("`n`t`t@{")
                                    try 
                                    {
                                        $installDirectory = Invoke-Comand $machine -scriptblock {
                                            if (Test-Path "$env:systemDrive\Program Files\Mozilla Firefox")
                                            {
                                                $firefoxDirectory = "$env:systemDrive\Program Files\Mozilla Firefox"
                                            }
                                            elseif (Test-Path "$env:systemDrive\Program Files (x86)\Mozilla Firefox")
                                            {
                                                $firefoxDirectory = "$env:systemDrive\Program Files (x86)\Mozilla Firefox"
                                            }
                                            return $firefoxDirectory
                                        }
                                    }
                                    catch
                                    {
                                        $installDirectory = "C:\Program Files\Mozilla Firefox"
                                    }
                                    $null = $configContent.add("`n`t`t`tInstallDirectory    = `"$installDirectory`"")

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

                                    if ($IncludeFilePaths)
                                    {
                                        $null = $configContent.add("`n`n`t`tPowerSTIG_Edge = @{")
                                        $null = $configContent.add("`n`t`t`txccdfPath            = `"$($edgeStigFiles.xccdfPath)`"")
                                        $null = $configContent.add("`n`t`t`tOrgSettings          = `"$($edgeStigFiles.orgSettings)`"")
                                        $null = $configContent.add("`n`t`t`tManualChecks         = `"$($edgeStigFiles.manualChecks)`"")
                                        $null = $configContent.add("`n`t`t}")
                                    }
                                    else { $null = $configContent.add("`n`n`t`tPowerSTIG_Edge = @{}") }
                                }
                                "Chrome"
                                {
                                    if ($IncludeFilePaths)
                                    {
                                        $null = $configContent.add("`n`n`t`tPowerSTIG_Chrome = @{")
                                        $null = $configContent.add("`n`t`t`txccdfPath            = `"$($chromeStigFiles.xccdfPath)`"")
                                        $null = $configContent.add("`n`t`t`tOrgSettings          = `"$($chromeStigFiles.orgSettings)`"")
                                        $null = $configContent.add("`n`t`t`tManualChecks         = `"$($chromeStigFiles.manualChecks)`"")
                                        $null = $configContent.add("`n`t`t}")
                                    }
                                    else { $null = $configContent.add("`n`n`t`tPowerSTIG_Chrome = @{}") }
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
                        #endregion AppliedConfigurations

                        #region LocalConfigurationManager
                        $null = $configContent.add("`n`n`tLocalConfigurationManager =")
                        $null = $configContent.add("`n`t@{")

                        foreach ($setting in $LcmSettings.Keys)
                        {

                            if (($Null -ne $LcmSettings.$setting) -and ("{}" -ne $lcmsettings.$setting) -and ("" -ne $LcmSettings.$setting))
                            {
                                $null = $null = $configContent.add("`n`t`t$($setting)")

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
                        #endregion LocalConfigurationManager

                        #region Hardware Resources

                        # Network Interfaces
                        $nics = Get-CimInstance -ComputerName $machine -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 'True'" | select -property *
                        $null = $configContent.add("`n`n`tNetworkInterfaces = `n`t@(")
                        $nicCount = 0
                        foreach ($nic in $nics)
                        {
                            $nicCount++
                            $nicName        = "$machine-nic-0$nicCount"
                            $nicIP          = $nic.ipaddress | Select -first 1
                            $nicGateway     = $nic.DefaultIpGateway | Select -first 1
                            $nicMacAddress  = $nic.MacAddress | Select -first 1
                            $nicSubnet      = $nic.IPSubnet | Select -first 1

                            if ($nicCount -gt 1)
                            {
                                $null = $configContent.add("`n")
                            }

                            $null = $configContent.add("`n`t`t@{")
                            $null = $configContent.add("`n`t`t`tName           = `"$nicName`"")
                            $null = $configContent.add("`n`t`t`tIpAddress      = `"$nicIP`"")
                            $null = $configContent.add("`n`t`t`tDefaultGateway = `"$nicGateway`"")
                            $null = $configContent.add("`n`t`t`tMacAddress     = `"$nicMacAddress`"")
                            $null = $configContent.add("`n`t`t}")
                        }
                        $null = $configContent.add("`n`t)")

                        # Disks
                        $disks = Get-CimInstance -ComputerName $machine -ClassName Win32_DiskDrive | select -property *
                        $null = $configContent.add("`n`n`tDisks = `n`t@(")
                        $diskcount = 0
                        foreach ($disk in $disks)
                        {
                            $diskCount++
                            $diskName  = "$machine-disk-0$diskCount"
                            $diskSize  = [math]::Round($disk.Size/1GB).tostring() + "GB"

                            if ($diskCount -gt 1)
                            {
                                $null = $configContent.add("`n")
                            }

                            $null = $configContent.add("`n`t`t@{")
                            $null = $configContent.add("`n`t`t`tName  = `"$diskName`"")
                            $null = $configContent.add("`n`t`t`tSize  = `"$diskSize`"")
                            $null = $configContent.add("`n`t`t}")
                        }
                        $null = $configContent.add("`n`t)")

                        #endregion Hardware Resources

                        $null = $configContent.add("`n}")

                        if ($LocalHost)
                        {
                            $compName = $env:ComputerName
                            $SystemFile = New-Item -Path "$SystemsPath\$CompName\$CompName.psd1" -Force
                        }
                        else
                        {
                            $SystemFile = New-Item -Path "$ouFolder\$machine.psd1" -Force
                        }
                        $null = Set-Content -nonewline -path $SystemFile $configContent
                        Write-Output "`t`t$machine - System Data successfully generated."
                    }
                    catch
                    {
                        Write-Output "`t`t$machine - Error Generating System Data."
                        throw $_
                    }
                }
                $null = $jobs.add($job.Id)
            }
            
            Write-Output "`t`tJob creation for $($ou.name) System Data is complete. Waiting on $($jobs.count) jobs to finish processing."
            
            if ($jobs.count -ge 1)
            {
                do
                {
                    $completedJobs  = (Get-Job -ID $jobs | Where-Object {$_.state -ne "Running"}).count
                    $runningjobs    = (Get-Job -ID $jobs | Where-Object {$_.state -eq "Running"}).count
                    Write-Output "`t`t$($ou.Name) System Data Status:`t$runningJobs Jobs Currently Processing`t$completedJobs/$($jobs.count) Jobs Completed"
                    Start-Sleep -Seconds 15
                }
                while ((Get-Job -ID $jobs).State -contains "Running")
                Write-Output "`t`t$($jobs.count) System Data jobs completed. Outputting Results."
                Get-Job -ID $jobs | Wait-Job | Receive-Job
            }
            else
            {
                Write-Output "`t`tNo Jobs Generated for $($ou.Name)"
                Remove-Item $ouFolder -Force
            }
        }
    }
}

function Sync-DscModules
{
    <#

    .SYNOPSIS
    This function validates the modules on the target machines. If the modules are not preset or are the incorrect version, the function will copy them to the target machines.

    .PARAMETER TargetMachines
    List of target machines. If not specificied, a list will be generated from configurations present in "C:\Your Repo\SCAR\Systems"

    .PARAMETER Rootpath
    Path to the root of the SCAR repository/codebase.

    .PARAMETER ModuleName
    Specify a single module to sync across target machines.

    .PARAMETER LocalHost
    Restrict Module sync to local computer/server.

    .EXAMPLE
    Example Sync-DscModules -rootpath "C:\SCAR"

    #>

    [cmdletbinding()]
    param(

        [Parameter()]
        [array]
        $TargetMachines,

        [Parameter()]
        [string]
        $RootPath = (Get-Location).Path,

        [Parameter()]
        [string]
        $ModuleName,

        [Parameter()]
        [switch]
        $LocalHost,

        [Parameter()]
        [switch]
        $Force

    )

    $ModulePath = "$RootPath\Resources\Modules"
    $SystemsPath = "$RootPath\Systems"
    $jobs = @()

    if ($LocalHost)
    {
        $TargetMachines = "LocalHost"
    }
    elseif ($TargetMachines.count -lt 1)
    {
        $targetMachines = @(Get-ChildItem -Path "$SystemsPath\*.psd1" -Recurse | Where-Object { ($_.Fullname -notmatch "Staging") -and ($_.Fullname -Notlike "Readme*") }).basename
    }

    Write-Output "`tPerforming DSC Module Sync."

    foreach ($machine in $TargetMachines)
    {
        Write-Output "`t`tStarting Job - Syncing DSC Modules on $machine."

        $job = Start-Job -Scriptblock {
            $machine                = $using:machine
            $RootPath               = $using:RootPath
            $ModulePath             = $using:ModulePath
            $Force                  = $using:Force
            $currentMachineCount    += 1

            if ($machine -eq 'localhost' -or $machine -eq $env:ComputerName)
            {
                $destinationPath = "C:\Program Files\WindowsPowershell\Modules"
                $destinationModulePaths = @(
                    "C:\Program Files\WindowsPowershell\Modules"
                    "C:\Program Files(x86)\WindowsPowershell\Modules"
                    "C:\Windows\System32\WindowsPowershell\1.0\Modules"
                )
            }
            else
            {
                $destinationPath = "\\$Machine\C$\Program Files\WindowsPowershell\Modules"
                $destinationModulePaths = @(
                    "\\$Machine\C$\Program Files\WindowsPowershell\Modules"
                    "\\$Machine\C$\Program Files(x86)\WindowsPowershell\Modules"
                    "\\$Machine\C$\Windows\System32\WindowsPowershell\1.0\Modules"
                )
            }
            $modulePathTest      = Test-Path $ModulePath -ErrorAction SilentlyContinue
            $destinationPathTest = Test-Path $destinationPath -ErrorAction SilentlyContinue

            if ($destinationPathTest -and $modulePathTest)
            {
                if ("" -eq $ModuleName)
                {
                    $modules = Get-Childitem -Path $modulePath -Directory -Depth 0 | Where-Object { $_.Name -match $ModuleName }
                }
                else
                {
                    $modules = Get-Childitem -Path $modulePath -Directory -Depth 0
                }

                foreach ($module in $modules)
                {

                    [int]$completedChecks = 0
                    $moduleVersion = (Get-ChildItem -Path $Module.Fullname -Directory -Depth 0).name

                    foreach ($destinationModulePath in $destinationModulePaths)
                    {
                        $modulecheck = Test-Path "$destinationPath\$($Module.name)" -ErrorAction SilentlyContinue

                        if ($force)
                        {
                            Write-Output "`t`t[Force] Installing $($Module.name) on $machine."
                            try
                            {
                                if ($moduleCheck)
                                {
                                    Write-Output "`t`t[Force] Removing $($module.Name) from $machine"
                                }

                                $null = Copy-Item -Path $Module.Fullname -Destination $destinationPath -Container -Recurse -force -erroraction SilentlyContinue
                            }
                            catch
                            {
                                Write-Output "`t`tThere was an issue installing DSC Modules on $machine."
                                throw $_
                                exit
                            }
                            continue
                        }
                        else
                        {
                            if ($moduleCheck)
                            {
                                $versionCheck = Test-Path "$destinationPath\$($Module.name)\$moduleVersion" -ErrorAction SilentlyContinue
                            }
                            else
                            {
                                $completedChecks += 1
                            }

                            if ($modulecheck -and $versioncheck)
                            {
                                $copyModule = $false
                            }
                            elseif ($True -eq $moduleCheck -and ($false -eq $versionCheck))
                            {
                                $destinationVersion = Get-Childitem "$destinationPath\$($Module.name)" -Depth 0
                                Write-Output "`t`t$($Module.name) found with version mismatch."
                                Write-Output "`t`tRequired verion - $moduleVersion."
                                Write-Output "`t`tInstalled version - $destinationVersion."
                                Write-Output "`t`tRemoving $($Module.name) from $machine."
                                $null = Remove-Item "$destinationModulePath\$($module.name)" -Confirm:$false -Recurse -Force -ErrorAction SilentlyContinue
                                $copyModule = $true
                            }
                        }
                    }

                    if ($completedChecks -ge 3)
                    {
                        $copyModule = $true
                    }

                    if ($copyModule)
                    {
                        Write-Output "`t`tInstalling $($Module.name) on $Machine."
                        $null = Copy-Item -Path $Module.Fullname -Destination $destinationPath -Container -Recurse -force -erroraction SilentlyContinue
                    }
                }
            }
            else
            {
                Write-Output "`t`tThere was an issue connecting to $machine to transfer the required modules."
                Continue
            }
        }
        [array]$jobs += $job.ID
    }
    Write-Output "`n`t$($jobs.count) Module sync jobs created. Checking status every 30 seconds and output will be displayed once complete."
    do
    {
        Start-Sleep -Seconds 30
        $completedJobs  = (Get-Job -ID $jobs | where {$_.state -ne "Running"}).count
        $runningjobs    = (Get-Job -ID $jobs | where {$_.state -eq "Running"}).count
        Write-Output "`t`tModule Sync Job Status:`t$runningJobs Jobs Currently Processing`t$completedJobs/$($jobs.count) Jobs Completed"
    }
    while ((Get-Job -ID $jobs).State -contains "Running")
    Write-Output "`n`t`t$($jobs.count) Module Sync jobs completed. Receiving job output"
    Get-Job -ID $jobs | Wait-Job | Receive-Job
    Write-Output "`tModule Validation Complete.`n"
}

function Set-WinRMConfig
{
    <#

    .SYNOPSIS
    This function will validate that the WinRM Service is running on target machines, that the MaxEnevelopeSize is set to 10000, and has a switch parameter to include the staging directory.

    .PARAMETER Rootpath
    Path to the root of the SCAR repository/codebase.

    .PARAMETER MaxEnevelopeSize
    MaxEnevelopeSize is a configuration setting in WinRM. SCAR requires this setting to be at (10000). This parameter allows you to set it to any number which easily allows you to reset WinRM to the default value (500).
    The default setting of this parameter is set to 10000.

    .PARAMETER IncludeStaging
    Switch Parameter that also includes the target machines in the Staging directory under 1.\Node Data

    .EXAMPLE
    Example Set-WinRmConfig -RootPath "C:\Your Repo\SCAR"
        In this example, the target machines (not including staging) would be validated that WinRM is running and the value of MaxEnvelopeSize is set to 10000. If it is set to a number other than 10000, it would be modified to match 10000.

    Example Set-WinRmConfig -RootPath "C:\Your Repo\SCAR" -MaxEnvelopeSize "500"
        In this example, the target machines (not including staging) would be validated that WinRM is running and the value of MaxEnvelopeSize is set to 500. If it is set to a number other than 500, it would be modified to match 500.

    Example Set-WinRmConfig -RootPath "C:\Your Repo\SCAR" -MaxEnvelopeSize "500" -IncludeStaging
        In this example, the target machines (including staging) would be validated that WinRM is running and the value of MaxEnvelopeSize is set to 500. If it is set to a number other than 500, it would be modified to match 500.

    #>

    [cmdletbinding()]
    param(

        [Parameter()]
        [array]
        $RootPath = (Get-Location).Path,

        [Parameter()]
        [string]
        $MaxEnvelopeSize = "10000",

        [Parameter()]
        [switch]
        $IncludeStaging,

        [Parameter()]
        [System.Collections.ArrayList]
        $TargetMachines

    )

    $SystemsPath   = (Resolve-Path -Path "$RootPath\Systems").Path
    $jobs           = New-Object System.Collections.ArrayList

    if ($null -eq $TargetMachines)
    {
        $TargetMachines = New-Object System.Collections.ArrayList
        $null = (Get-Childitem -Path $SystemsPath -recurse | Where-Object { $_.FullName -like "*.psd1" -and $_.fullname -notlike "*staging*" }).basename | ForEach-Object {$null = $targetmachines.add($_)}
    }

    Write-Output "`tBUILD: Performing WinRM Validation and configuration."

    if ($IncludeStaging)
    {
        $null = (Get-ChildItem -Path $SystemsPath -recurse | Where-Object { $_.FullName -like "*.psd1" }).basename | ForEach-Object {$null = $targetmachines.add($_)}
    }

    foreach ($machine in $TargetMachines)
    {
        # Test for whether WinRM is enabled or not
        Write-Output "`t`tStarting Job - Configure WinRM MaxEnvelopeSizeKB on $machine"

        $job = Start-Job -Scriptblock {
            $machine                = $using:machine
            $RootPath               = $using:rootPath
            $MaxEnvelopeSize        = $using:MaxEnvelopeSize

            try
            {
                $remoteEnvelopeSize = Invoke-Command $machine -ErrorAction Stop -Scriptblock {
                    Return (Get-Item -Path WSMan:\localhost\MaxEnvelopeSizeKb).value
                }
            }
            catch
            {
                Write-Warning "`t`tUnable to connect to $machine. Ensure WinRM access is enabled."
                Continue
            }

            if ($MaxEnvelopeSize -eq $remoteEnvelopeSize)
            {
                Write-Output "`t`tCurrent MaxEnvelopSize size for $machine matches Desired State"
                Continue
            }
            else
            {
                Write-Output "`t`tCurrent MaxEnvelopSizeKB for $machine is $remoteEnvelopeSize. Updating to $MaxEnvelopeSize"

                try
                {
                    $remoteEnvelopeSize = Invoke-Command $machine -ErrorAction Stop -ArgumentList $MaxEnvelopeSize -Scriptblock {
                        param ($RemoteMaxEnvelopeSize)
                        $machineEnvSize = (Get-Item -Path WSMan:\localhost\MaxEnvelopeSizeKb).value
                        if ($machineEnvSize -ne $RemoteMaxEnvelopeSize)
                        {
                            Set-Item -Path WSMan:\localhost\MaxEnvelopeSizeKb -Value $RemoteMaxEnvelopeSize
                        }
                        return (Get-Item -Path WSMan:\localhost\MaxEnvelopeSizeKb).value
                    }
                }
                catch
                {
                    Write-Warning "Unable to set MaxEnvelopSize on $machine."
                    continue
                }
            }
        }
        $null = $jobs.add($job.ID)
    }
    Get-Job -ID $jobs | Wait-Job | Receive-Job
    Write-Output "`tBUILD: WinRM Validation Complete.`n"
}

function Get-DscComplianceReports
{
    [cmdletbinding()]
    param(

        [Parameter()]
        [string]
        $RootPath = (Get-Location).Path,

        [Parameter()]
        [string]
        $MofPath = (Resolve-Path -Path "$RootPath\*Artifacts\Mofs").Path,

        [Parameter()]
        [string]
        $LogsPath = (Resolve-Path -Path "$Rootpath\*Artifacts\Logs").Path,

        [Parameter()]
        [string]
        $OutputPath = (Resolve-Path -Path "$Rootpath\*Artifacts\Reports").Path,

        [Parameter()]
        [array]
        $DscResults
   )
    if ($DSCResults.count -lt 1)
    {
        $DscResults = Test-DSCConfiguration -Path $MofPath
    }

    $DscResults | Export-Clixml -Path "$OutputPath\DscResults.xml" -Force

    $results = Import-CliXml "$OutputPath\DscResults.xml"
    $newdata = $results | ForEach-Object {
        if ($_.ResourcesInDesiredState)
        {
            $_.ResourcesInDesiredState | ForEach-Object {
                $_
            }
        }
        if ($_.ResourcesNotInDesiredState)
        {
            $_.ResourcesNotInDesiredState | ForEach-Object {
                $_
            }
        }
    }
    $parsedData = $newdata | Select-Object PSComputerName, ResourceName, InstanceName, InDesiredState, ConfigurationName, StartDate
    $parsedData | Export-Csv -Path $OutputPath\DscResults.csv -NoTypeInformation -Force
}

function Publish-SCARArtifacts
{

    param (
        [string]$repoUrl,
        [string]$repoName,
        [string]$repoFolderLocation,
        [string]$pathOfFolderToCopy,
        [string]$accessToken,
        [string]$targetPath
    )
    
    $env:GIT_REDIRECT_STDERR = '2>&1'
    $startingPath = (Get-Location).Path
    Write-Host "Checking out $repoUrl."

    if($accessToken.Length -gt 0) {git clone $repoUrl -c http.extraheader="AUTHORIZATION: bearer $accessToken" -v}
    else {git clone $repoUrl -v}

    if(Test-Path $pathOfFolderToCopy){$publishArtifacts = Get-Item $pathOfFolderToCopy}
    else {Write-Host "Invalid Path Of Folder Copy Location: $pathOfFolderToCopy";exit}

    if(Test-Path $repoFolderLocation){Set-Location $repoFolderLocation}
    else {Write-Host "Invalid Folder Repo Location: $repoFolderLocation";exit}

    $sourcePath     = $publishArtifacts.FullName+"\*"
    if (Test-Path $targetPath) {Remove-Item $targetPath -Recurse -Force}
    if(!(Test-Path $targetPath)) {New-Item -Path $targetPath -ItemType Directory}

    Copy-Item $sourcePath $targetPath -Recurse -Force
    git config --global user.email "SYSTEM@CONTOSO.COM"
    git config --global user.name "SYSTEM"
    git add --all
    git commit -m "Automated Commit"
    git push
    cd $startingPath

    if(Test-Path $repoName){
        Remove-Item $repoName -Recurse -Force
    }
}