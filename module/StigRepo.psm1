function Initialize-StigRepo
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [string]
        $RootPath = (Get-Location).Path
    )

    Write-Output "Beginning Stig Compliance Automation Repository (SCAR) Build"

    Write-Output "`tBuilding Repository Folder Structure"

    # Systems Folder
    $systemsPath    = New-Item -Path "$RootPath\Systems" -ItemType Directory -Force
    $stagingPath    = New-Item -Path "$SystemsPath\Staging" -ItemType Directory -Force

    # Configurations Folder
    $configPath     = New-Item -Path "$RootPath\Configurations" -ItemType Directory -Force

    # Artifacts Folder
    $artifactPath   = New-Item -Path "$RootPath\Artifacts" -ItemType Directory -Force
    $dscConfigPath  = New-Item -Path "$artifactPath\DscConfigs" -ItemType Directory -Force
    $mofPath        = New-Item -Path "$artifactPath\Mofs" -ItemType Directory -Force
    $CklPath        = New-Item -Path "$artifactPath\Stig Checklists" -ItemType Directory -Force

    # Resources Folder
    $resourcePath   = New-Item -Path "$RootPath\Resources" -ItemType Directory -Force
    $modulePath     = New-Item -Path "$resourcePath\Modules" -ItemType Directory -Force
    $stigDataPath   = New-Item -Path "$resourcePath\Stig Data" -ItemType Directory -Force
    $xccdfPath      = New-Item -Path "$stigDataPath\Xccdfs" -ItemType Directory -Force
    $orgSettingPath = New-Item -Path "$stigDataPath\Organizational Settings" -ItemType Directory -Force
    $mancheckPath   = New-Item -Path "$stigDataPath\Manual Checks" -ItemType Directory -Force
    $wikiPath       = New-Item -Path "$resourcePath\Wiki" -ItemType Directory -Force

    Write-Output "`tExtracting DSC Configurations and Wiki Files"
    $stigRepoModulePath = (Get-Module StigRepo).Path
    $stigRepoRoot = Split-Path -Path (Split-Path $stigRepoModulePath -Parent) -Parent
    $configZip = "$stigRepoRoot\Resources\Configurations.zip"
    $wikiZip   = "$stigRepoRoot\Resources\wiki.zip"

    Expand-Archive $configZip -DestinationPath $RootPath -force
    Expand-Archive $wikiZip -DestinationPath $ResourcePath -force

    Update-StigRepo -RemoveBackup

    Write-Output "`n`tInstalling/Importing SCAR Modules"
    Sync-DscModules -LocalHost -Force
    Import-Module PowerSTIG -Force
    Import-Module StigRepo -Force

    Write-Output "STIG Compliance Automation Repository Build Complete."
    Write-Output "Run New-SystemData to begin System Data creation.`n`n"
}

function Update-StigRepo
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [string]
        $RootPath = (Get-Location).Path,

        [Parameter()]
        [switch]
        $RemoveBackup
    )

    Write-Output "Starting SCAR Update"
    $stigDataPath = (Resolve-Path -Path "$RootPath\Resources\Stig Data").Path
    $modulePath = (Resolve-Path -Path "$RootPath\Resources\Modules" -erroraction Stop).Path
    $modules = Get-Childitem $ModulePath

    # Update Dependent Modules
    Write-Output "`tRemoving old Dependencies"
    foreach ($module in $modules)
    {
        Write-Output "`t`tRemoving $($module.name)"
        Remove-Item $module.fullname -force -Recurse -Confirm:$false
    }

    Write-Output "`tInstalling Dependencies"
    Save-Module StigRepo -Path $ModulePath -Verbose
    Save-Module PowerSTIG -Path $ModulePath -Verbose

    #endregion Update Dependent Modules

    #region Update STIG Data Files
    Write-Output "`tUpdating STIG Data Files"

    # Backup STIG Data Folder
    Write-Output "`n`t`tBacking up current STIG Data"
    $resourcePath = Split-Path $StigDataPath -Parent
    $backupPath   = "$resourcePath\Stig Data-Backup"
    Copy-Item $stigDataPath -Destination $backupPath -Force -Recurse

    # Update Xccdfs
    Write-Output "`n`t`tUpdating STIG XCCDF Files"
    Get-Item "$StigDataPath\Xccdfs" | Remove-Item -Recurse -Force -Confirm:$false
    $currentXccdfFolders = Get-Childitem "$StigDataPath-Backup\Xccdfs\*" -Directory
    $newXccdfPath = New-Item -ItemType Directory -Path $StigDataPath -Name "Xccdfs" -Force -Confirm:$false
    $newXccdfFolders = Get-Childitem "$ModulePath\PowerSTIG\*\StigData\Archive\*" -Directory
    $newXccdfFolders | Copy-Item -Destination "$StigDataPath\Xccdfs" -Force -Recurse -Confirm:$false
    $customxccdfs = $currentXccdfFolders | where { ((Compare-Object -ReferenceObject $currentXccdfFolders.name -DifferenceObject $newXccdfFolders.name).inputobject) -contains $_.name }
    $customXccdfs.FullName | Copy-Item -Destination $newXccdfPath -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue

    # Update Org Settings
    Write-Output "`n`t`tUpdating Organizational Setting Files"
    Get-Item "$StigDataPath\Organizational Settings" | Remove-Item -Recurse -Force -Confirm:$false
    $currentOrgSettings  = Get-Childitem "$StigDataPath-Backup\Organizational Settings\*org.default.xml"
    $null = New-Item -ItemType Directory -Path $StigDataPath -Name "Organizational Settings" -Force -Confirm:$false
    $newOrgSettings = Get-Childitem "$ModulePath\PowerSTIG\*\StigData\Processed\*.org.default.xml"
    $newOrgSettings | Copy-Item -Destination "$StigDataPath\Organizational Settings" -Force -Confirm:$false

    # Manual Checks
    Write-Output "`n`t`tUpdating Manual Check Files"
    $powerStigXccdfPath = (Resolve-Path "$modulePath\PowerStig\*\StigData\Archive").Path
    $powerStigProcessedPath = (Resolve-Path "$ModulePath\PowerSTIG\*\StigData\Processed").Path
    $xccdfs = Get-Childitem "$powerStigXccdfPath\*.xml" -recurse
    $processedXccdfs = Get-Childitem "$powerStigProcessedPath\*.xml" -recurse | where {$_.name -notlike "*org.default*"}
    $newManualCheckPath = New-Item -ItemType Directory -Path $StigDataPath -Name "Manual Checks" -Force -Confirm:$False
    $oldManualCheckPath = (Resolve-Path "$StigDataPath-Backup\Manual Checks").Path
    $currentManualChecks = Get-ChildItem -Path $oldManualCheckPath
    $currentManualChecks | Copy-Item -Destination $StigDataPath -Force -Recurse -Confirm:$false

    foreach ($xccdf in $processedXccdfs)
    {

        switch -Wildcard ($xccdf.name)
        {
            "WindowsServer*2019*"   {$xccdfFolderName = "Windows.Server.2019"}
            "WindowsServer*2016*"   {$xccdfFolderName = "Windows.Server.2016"}
            "WindowsServer*2012*"   {$xccdfFolderName = "Windows.Server.2012R2"}
            "*Firewall*"            {$xccdfFolderName = "Windows.Firewall"}
            "*DNS*"                 {$xccdfFolderName = "Windows.DNS"}
            "*Defender*"            {$xccdfFolderName = "Windows.Defender"}
            "*Client*"              {$xccdfFolderName = "Windows.Client"}
            "*IISServer*"           {$xccdfFolderName = "WebServer"}
            "*IISSite*"             {$xccdfFolderName = "WebSite"}
            "*VSphere*"             {$xccdfFolderName = "VSphere"}
            "*SQL*Server*"          {$xccdfFolderName = "Sql Server"}
            "*Oracle*"              {$xccdfFolderName = "OracleJRE"}
            "*Office*"              {$xccdfFolderName = "Office"}
            "*McAfee*"              {$xccdfFolderName = "McAfee"}
            "*Ubuntu*"              {$xccdfFolderName = "Linux.Ubuntu"}
            "*RHEL*"                {$xccdfFolderName = "Linux.RHEL"}
            "*InternetExplorer*"    {$xccdfFolderName = "InternetExplorer"}
            "*Edge*"                {$xccdfFolderName = "Edge"}
            "*DotNet*"              {$xccdfFolderName = "DotNet"}
            "*Chrome*"              {$xccdfFolderName = "Chrome"}
            "*FireFox*"             {$xccdfFolderName = "FireFox"}
            "*Adobe*"               {$xccdfFolderName = "Adobe"}
        }

        [xml]$xccdfcontent = Get-Content $xccdf.FullName -Encoding UTF8
        $manualRules = $xccdfContent.DisaStig.ManualRule.Rule.id
        $manualCheckContent = New-Object System.Collections.ArrayList
        $manualCheckFolder = "$StigDataPath\Manual Checks\$xccdfFolderName"
        $stigVersion = $xccdf.basename.split("-") | Select -last 1

        if (-not(Test-Path $manualCheckFolder))
        {
            $null = New-Item -ItemType Directory -Path $manualCheckFolder
        }
        $manualCheckFilePath = "$manualCheckFolder\$($xccdfContent.DisaStig.StigId)-$stigVersion-manualChecks.psd1"

        if ($null -ne $manualRules)
        {
            Write-Output "`t`t`tGenerating Manual Check file for $($xccdf.Name)"
            foreach ($vul in $manualRules)
            {
                $null = $manualCheckContent.add("@{")
                $null = $manualCheckContent.add("    VulID       = `"$($vul)`"")
                $null = $manualCheckContent.add("    Status      = `"NotReviewed`"")
                $null = $manualCheckContent.add("    Comments    = `"EXAMPLE: This Comment was provided by the STIG Compliance Automation Repository. Modify $manualCheckFilePath to customize the status/comments for this finding.`"")
                $null = $manualCheckContent.add("}`n")
            }
            $manualCheckContent | Out-File $manualCheckFilePath -force
        }
        else 
        {
            Write-Output "`t`t`tGenerating Manual Check file for $($xccdf.Name)"
            $null = $manualCheckContent.add("@{")
            $null = $manualCheckContent.add("    VulID       = `"V-XXXX`"")
            $null = $manualCheckContent.add("    Status      = `"NotReviewed`"")
            $null = $manualCheckContent.add("    Comments    = `"EXAMPLE: This Comment was provided by the STIG Compliance Automation Repository. Modify $manualCheckFilePath to customize the status/comments for this finding.`"")
            $null = $manualCheckContent.add("}`n")
            $manualCheckContent | Out-File $manualCheckFilePath -force    
        }
    }

    if ($RemoveBackup)
    {
        Get-Item "$resourcePath\Stig Data-Backup" | Remove-Item -Force -Recurse -Confirm:$false
    }
}
function Start-DscBuild
{
    <#
    .SYNOPSIS
    Executes SCAR functions that compile dynamic configurations for each machine based on the parameters and
    parameter values provided within that VM's configuration data.

    .PARAMETER Rootpath
    Path to the root of the SCAR repository/codebase.

    .PARAMETER ValidateModules
    Executes the Sync-DscModules cmdlet and sync modules/versions with what is in the "5. resouces\Modules" folder of
    SCAR.

    .PARAMETER ArchiveFiles
    Switch parameter that archives the artifacts produced by SCAR. This switch compresses the artifacts and
    places them in the archive folder.

    .PARAMETER CleanBuild
    Switch parameter that removes files from the MOFs and Artifacts folders to create a clean slate for the SCAR build.

    .PARAMETER CleanArchive
    Switch Parameter that r$dscdataemoves files from the archive folder.

    .PARAMETER SystemFiles
    Allows users to provide an array of configdata files to target outside of the Systems folder.

    .PARAMETER PreRequisites
    Executes nodededata generation, DSC module copy, and WinRM configuration as part of the SCAR build process.

    .EXAMPLE
    Start-DscBuild -RootPath "C:\DSC Management" -CleanBuild -CleanArchive -PreRequisites

    #>

    [cmdletbinding()]
    param(

        [Parameter()]
        [string]
        $RootPath = (Get-Location).Path,

        [Parameter()]
        [string]
        $TargetFolder,

        [Parameter()]
        [switch]
        $CopyModules,

        [Parameter()]
        [switch]
        $ArchiveFiles,

        [Parameter()]
        [switch]
        $CleanBuild,

        [Parameter()]
        [System.Collections.ArrayList]
        $SystemFiles,

        [Parameter()]
        [switch]
        $PreRequisites
    )

    # Root Folder Paths
    $SystemsPath    = (Resolve-Path -Path "$RootPath\*Systems").Path
    $dscConfigPath   = (Resolve-Path -Path "$RootPath\*Configurations").Path
    $resourcePath    = (Resolve-Path -Path "$RootPath\*Resources").Path
    $artifactPath    = (Resolve-Path -Path "$RootPath\*Artifacts").Path
    $reportsPath     = (Resolve-Path -Path "$RootPath\*Artifacts\Reports").Path
    $mofPath         = (Resolve-Path -Path "$RootPath\*Artifacts\Mofs").Path

    # Begin Build
    Write-Output "Beginning Desired State Configuration Build Process`r`n"

    # Remove old Mofs/Artifacts
    if ($CleanBuild)
    {
        Remove-BuildItems -RootPath $RootPath
    }

    # Validate Modules on host and target machines
    if ($CopyModules)
    {
        Sync-DscModules -Rootpath $RootPath
    }

    # Import required DSC Resource Module
    Import-DscModules -ModulePath "$ResourcePath\Modules"

    # Combine PSD1 Files
    $allNodesDataFile = "$artifactPath\DscConfigs\AllNodes.psd1"
    $SystemFiles = New-Object System.Collections.ArrayList

    if ('' -eq $SystemFiles)
    {
        if ('' -eq $TargetFolder)
        {
            $null = Get-ChildItem -Path "$SystemsPath\*.psd1" -Recurse | Where-Object { ($_.Fullname -notmatch "Staging") -and ($_.Fullname -Notlike "Readme*")} | ForEach-Object {$null = $systemFiles.add($_)}
            Get-CombinedConfigs -RootPath $RootPath -AllNodesDataFile $allNodesDataFile -SystemFiles $SystemFiles
            Export-DynamicConfigs -SystemFiles $SystemFiles -ArtifactPath $artifactPath -DscConfigPath $dscConfigPath
            Export-Mofs -RootPath $RootPath
        }
        else
        {
            $null = Get-ChildItem -Path "$systemsPath\$TargetFolder\*.psd1" -Recurse | Where-Object { ($_.Fullname -notmatch "Staging") -and ($_.Fullname -Notlike "Readme*")} | ForEach-Object {$null = $Systemfiles.add($_)}
            Get-CombinedConfigs -RootPath $RootPath -AllNodesDataFile $allNodesDataFile -SystemFiles $SystemFiles -TargetFolder $TargetFolder
            Export-DynamicConfigs -SystemFiles $SystemFiles -ArtifactPath $artifactPath -DscConfigPath $dscConfigPath -TargetFolder $TargetFolder
            Export-Mofs -RootPath $RootPath -TargetFolder $TargetFolder
        }
    }

    # Archive generated artifacts
    if ($archiveFiles)
    {
        Compress-DscArtifacts -Rootpath $RootPath
    }

    # DSC Build Complete
    Write-Output "`n`n`t`tDesired State Configuration Build complete.`n`n"
}

function Get-CombinedConfigs
{
    <#

    .SYNOPSIS
    Generates configuration data for each node defined within a targeted folder and generates a single .psd1 for each node with
    their combined "AppliedConfigurations" and parameters to generate MOFs off of. Also generates a single configuration data file
    containing all nodes/configurations.

    .PARAMETER RootPath
    Path to the Root of the SCAR platforms

    .EXAMPLE
    Get-CombinedConfigs -RootPath "C:\SCAR"

    #>

    [cmdletBinding()]
    param (

        [Parameter()]
        [string]
        $RootPath = (Get-Location).Path,

        [Parameter()]
        [string]
        $AllNodesDataFile,

        [Parameter()]
        [array]
        $TargetFolder,

        [Parameter()]
        [System.Collections.ArrayList]
        $SystemFiles

    )
    $allconfigfiles = New-Object System.Collections.ArrayList

    if ($null -eq $SystemFiles)
    {
        $SystemsPath = (Resolve-Path -Path "$Rootpath\*Systems").Path
        if ('' -ne $targetFolder)
        {
            $null = Get-ChildItem -Path "$SystemsPath\*.psd1" -Recurse | Where-Object { ($_.Fullname -notmatch "Staging") -and ($_.Fullname -Notlike "Readme*") } | ForEach-Object {$null = $allconfigfiles.add($_)}
        }
        else
        {
            $null = Get-ChildItem -Path "$SystemsPath\$TargetFolder\*.psd1" -Recurse | Where-Object { ($_.Fullname -notmatch "Staging") -and ($_.Fullname -Notlike "Readme*") } | ForEach-Object {$null = $allconfigfiles.add($_)}
        }
    }

    foreach ($configFile in $allConfigFiles)
    {
        $data = Invoke-Expression (Get-Content $nodeConfig.FullName | Out-String)

        if ($null -ne $data.AppliedConfigurations)
        {
            $null = $SystemFiles.add($configFile)
        }
    }

    if ($SystemFiles.count -lt 1)
    {
        Write-Output "No DSC configdata files were provided."
    }
    else
    {
        Write-Output "`n`tBeginning Powershell Data File build for $($SystemFiles.count) targeted Machines.`n"
        New-Item -Path $AllNodesDataFile -ItemType File -Force | Out-Null
        $string = "@{`n`tAllNodes = @(`n"
        $string | Out-File $AllNodesDataFile -Encoding utf8
        [int]$countOfConfigurations = ($SystemFiles | Measure-object | Select-Object -expandproperty count)
        for ($i = 0; $i -lt $countOfConfigurations; $i++)
        {
            Get-Content -Path $($SystemFiles[$i].FullName) -Encoding UTF8 |
            ForEach-Object -Process {
                "`t`t" + $_ | Out-file $AllNodesDataFile -Append -Encoding utf8
            }

            if ($i -ne ($countOfConfigurations - 1) -and ($countOfConfigurations -ne 1))
            {
                "`t`t," | Out-file $allNodesDataFile -Append -Encoding utf8
            }
        }
        "`t)`n}" | Out-File $allNodesDataFile -Append -Encoding utf8
    }
}

function Export-DynamicConfigs
{
    <#

    .SYNOPSIS
    Generates DSC scripts with combined parameter and parameter values based on
    provided configuration data.

    .PARAMETER SystemFiles
    Array of configuration data files. Targets all .psd1 files under the "Systems" folder
    that are not located in the staging folder.
    Example -SystemFiles $ConfigDataArray

    .PARAMETER ArtifactPath
    Path to the Artifacts Folder. Defaults to the "4. Artifacts" folder from the Rootpath provided by
    the Start-DscBuild function.

    .EXAMPLE
    Export-DynamicConfigs -SystemFiles $SystemFiles -ArtifactPath $artifactPath

    #>

    [cmdletBinding()]
    param (

        [Parameter()]
        [System.Collections.ArrayList]
        $SystemFiles,

        [Parameter()]
        [string]
        $TargetFolder,

        [Parameter()]
        [string]
        $ArtifactPath,

        [Parameter()]
        [string]
        $DscConfigPath
    )

    $jobs = New-Object System.Collections.ArrayList
    foreach ($SystemFile in $SystemFiles)
    {
        $machinename = $SystemFile.basename
        if ('' -ne $TargetFolder -and $SystemFile.fullname -notlike "*\$TargetFolder\*")
        {
            Continue
        }
        else
        {
            Write-Output "`t`tStarting Job - Compile DSC Configuration for $($SystemFile.basename)"

            $job = Start-Job -Scriptblock {
                $SystemFile       = $using:SystemFile
                $dscConfigPath      = $using:dscConfigPath
                $artifactPath       = $using:ArtifactPath
                $machinename        = $using:machinename
                $nodeConfigScript   = "$ArtifactPath\DscConfigs\$machineName.ps1"
                $data               = Invoke-Expression (Get-Content $SystemFile.FullName | Out-String)

                if ($null -ne $data.AppliedConfigurations)
                {
                    $appliedConfigs     = $data.appliedconfigurations.Keys
                    $lcmConfig          = $data.LocalConfigurationManager.Keys
                    $nodeName           = $data.NodeName
                    Write-Output "`t$machineName - Building Customized Configuration Data`n"
                    New-Item -ItemType File -Path $nodeConfigScript -Force | Out-Null

                    foreach ($appliedConfig in $appliedConfigs)
                    {

                        if (Test-Path $SystemFile.fullname)
                        {
                            Write-Output "`t`tConfigData Import - $appliedConfig"

                            $dscConfigScript = "$DscConfigPath\$appliedConfig.ps1"
                            $fileContent = Get-Content -Path $dscConfigScript -Encoding UTF8 -ErrorAction Stop
                            $fileContent | Out-file $nodeConfigScript -Append -Encoding utf8 -ErrorAction Stop
                            . $dscConfigScript
                            Invoke-Expression ($fileContent | Out-String) #DevSkim: ignore DS104456
                        }
                        else
                        {
                            Throw "The configuration $appliedConfig was specified in the $($SystemFile.fullname) file but no configuration file with the name $appliedConfig was found in the \Configurations folder."
                        }
                    }
                    $mainConfig = New-Object System.Collections.ArrayList
                    $null = $mainConfig.add("Configuration MainConfig`n{`n`tNode `$AllNodes.Where{`$_.NodeName -eq `"$nodeName`"}.NodeName`n`t{")

                    foreach ($appliedConfig in $appliedConfigs)
                    {
                        Write-Output "`t`tParameter Import - $AppliedConfig"

                        $syntax                     = Get-Command $appliedConfig -Syntax -ErrorAction Stop
                        $appliedConfigParameters    = [Regex]::Matches($syntax, "\[{1,2}\-[a-zA-Z0-9]+") |
                        Select-Object @{l = "Name"; e = { $_.Value.Substring($_.Value.IndexOf('-') + 1) } },
                        @{l = "Mandatory"; e = { if ($_.Value.IndexOf('-') -eq 1) { $true }else { $false } } }
                        $null = $mainconfig.add("`n`t`t$appliedConfig $appliedConfig`n`t`t{`n")

                        foreach ($appliedConfigParameter in $appliedConfigParameters)
                        {
                            if ($null -ne $data.appliedconfigurations.$appliedConfig[$appliedConfigParameter.name])
                            {
                                $null = $mainConfig.add("`t`t`t$($appliedConfigParameter.name) = `$node.appliedconfigurations.$appliedConfig[`"$($appliedConfigParameter.name)`"]`n")
                            }
                            elseif ($true -eq $appliedConfigParameter.mandatory)
                            {
                                $errorMessage = New-Object System.Collections.ArrayList
                                $null = $errorMessage.add("$nodeName configuration $appliedConfig has a mandatory parameter $($appliedConfigParameter.name) and was not specified.`n`n")
                                $null = $errorMessage.add("$appliedConfig = @{`n")
                                foreach ($appliedConfigParameter in $appliedConfigParameters)
                                {
                                    $null = $errorMessage.add("`t$($appliedconfigParameter.name) = `"VALUE`"`n")
                                }
                                $null = $errorMessage.add("}")
                                Throw $errorMessage
                            }
                        }
                        $null = $mainConfig.add("`t`t}`n")
                    }
                    $null = $mainConfig.add("`t}`n}`n")
                    $mainConfig | Out-file $nodeConfigScript -nonewline -Append -Encoding utf8
                    #endregion Build configurations and generate MOFs

                    #region Generate data for meta.mof (Local Configuration Manager)

                    if ($null -ne $lcmConfig)
                    {
                        Write-Output "`t`tGenerating LCM Configuration"
                        [array]$lcmParameters = "ActionAfterReboot", "AllowModuleOverWrite", "CertificateID", "ConfigurationDownloadManagers", "ConfigurationID", "ConfigurationMode", "ConfigurationModeFrequencyMins", "DebugMode", "StatusRetentionTimeInDays", "SignatureValidationPolicy", "SignatureValidations", "MaximumDownloadSizeMB", "PartialConfigurations", "RebootNodeIfNeeded", "RefreshFrequencyMins", "RefreshMode", "ReportManagers", "ResourceModuleManagers"
                        $localConfig = New-Object System.Collections.ArrayList
                        $null = $localConfig.add("[DscLocalConfigurationManager()]`n")
                        $null = $localConfig.add("Configuration LocalConfigurationManager`n{`n`tNode `$AllNodes.Where{`$_.NodeName -eq `"$nodeName`"}.NodeName`n`t{`n`t`tSettings {`n")

                        foreach ($setting in $lcmConfig)
                        {
                            if ($null -ne ($lcmParameters | Where-Object { $setting -match $_ }))
                            {
                                $null = $localConfig.add("`t`t`t$setting = `$Node.LocalconfigurationManager.$Setting`n")
                            }
                            else
                            {
                                Write-Warning "The term `"$setting`" is not a configurable setting within the Local Configuration Manager."
                            }
                        }
                        $null = $localConfig.add("`t`t}`n`t}`n}")
                        $localConfig | Out-file $nodeConfigScript -nonewline -Append -Encoding utf8
                    }
                    Write-Output "`n`t$nodeName configuration file successfully generated.`r`n"
                }
            }
        }
        $null = $jobs.add($job.Id)
    }
    Write-Output "`n`tJob Creation complete. Waiting for $($jobs.count) Jobs to finish processing. Output from Jobs will be displayed below once complete.`n`n"
    Get-Job -ID $jobs | Wait-Job | Receive-Job
}

function Export-Mofs
{
    <#

    .SYNOPSIS

    .PARAMETER Rootpath
    Path to the root of the SCAR repository/codebase.

    .EXAMPLE
    Export-Mofs -RootPath "C:\SCAR"

    #>

    [cmdletbinding()]
    param(

        [Parameter()]
        [string]
        $RootPath = (Get-Location).Path,

        [Parameter()]
        [string]
        $TargetFolder,

        [Parameter()]
        [System.Collections.ArrayList]
        $SystemFiles

    )

    $mofPath            = (Resolve-Path -Path "$RootPath\*Artifacts\Mofs").Path
    $dscConfigPath      = (Resolve-Path -Path "$RootPath\*Artifacts\DscConfigs").Path
    $allNodesDataFile   = (Resolve-Path -Path "$dscConfigPath\Allnodes.psd1").path
    $SystemFiles      = New-Object System.Collections.ArrayList
    $dscNodeConfigs     = New-Object System.Collections.ArrayList
    $jobs               = New-Object System.Collections.ArrayList

    if ($SystemFiles.count -lt 1)
    {
        if ('' -ne $TargetFolder)
        {
            $null = Get-Childitem "$RootPath\Systems\$TargetFolder\*.psd1" -Recurse | ForEach-Object {$null = $SystemFiles.add($_)}
        }
        else
        {
            $SystemFiles      = New-Object System.Collections.ArrayList
            $null = Get-Childitem "$RootPath\Systems\*.psd1" -Recurse | ForEach-Object {$null = $SystemFiles.add($_)}
        }
    }

    foreach ($file in $SystemFiles)
    {

        $basename = $file.basename
        if (Test-Path "$dscConfigPath\$basename.ps1")
        {
            $null = Get-Item -path "$dscConfigPath\$basename.ps1" -erroraction SilentlyContinue | ForEach-Object {$null = $dscNodeConfigs.add($_)}
        }
        else
        {
            Write-Warning "No DSC Configuration script exists for $basename."
            continue
        }
    }

    foreach ($nodeConfig in $DscNodeConfigs)
    {
        $nodeName       = $nodeConfig.BaseName
        $configPath     = $nodeConfig.FullName
        $allNodesPath   = $allNodesDataFile.FullName
        $SystemFile   = (Resolve-Path -Path "$RootPath\Systems\*\$nodeName.psd1").Path
        $data           = Invoke-Expression (Get-Content $SystemFile | Out-String)

        if ($null -ne $data.AppliedConfigurations)
        {
            Write-Output "`t`tStarting MOF Export Job - $($nodeConfig.BaseName)"

            try
            {
                Write-Output "`t`tStarting Job - Generate MOF and Meta MOF for $nodeName"

                $job = Start-Job -Scriptblock {

                    $nodeConfig         = $using:nodeConfig
                    $nodeName           = $using:nodeName
                    $allNodesDataFile   = $using:allNodesDataFile
                    $mofPath            = $using:mofPath
                    $configPath         = $using:ConfigPath

                    # Execute each file into memory
                    . "$configPath"

                    # Execute each configuration with the corresponding data file
                    Write-Output "`t`tGenerating MOF for $nodeName"
                    $null = MainConfig -ConfigurationData $allNodesDataFile -OutputPath $mofPath -ErrorAction Stop 3> $null

                    # Execute each Meta Configuration with the corresponding data file
                    Write-Output "`t`tGenerating Meta MOF for $nodeName"
                    $null = LocalConfigurationManager -ConfigurationData $allNodesDataFile -Outputpath $mofPath -Erroraction Stop 3> $null
                }
                $null = $jobs.add($job.id)
            }
            catch
            {
                Throw "Error occured executing $SystemFile to generate MOF.`n $($_)"
            }
        }
    }
    Write-Output "`n`tMOF Export Job Creation Complete. Waiting for $($jobs.count) to finish processing. Output from Jobs will be displayed below once complete.`n"
    Get-Job -ID $jobs | Wait-Job | Receive-Job
}

function Remove-ScarData
{
    <#

    .SYNOPSIS
    Removes all existing artifacts the SCAR repository including System data, Compiled DSC Scripts, MOFs, and STIG Checklists
    All files removed from the following locations:
        - Systems
        - Artifacts\Mofs
        - Artifacts\DscConfigs
        - Artifacts\STIG Checklists

    .PARAMETER Rootpath
    Path to the root of the SCAR repository/codebase.

    .EXAMPLE
    Clean-ScarRepo -Rootpath "C:\SCAR"

    #>

    [cmdletBinding()]
    param (

        [Parameter()]
        [string]
        $RootPath = (Get-Location).Path

    )

    $artifactPath   = (Resolve-Path "$RootPath\*Artifacts").Path
    $mofPath        = (Resolve-Path "$ArtifactPath\Mofs").Path
    $cklPath        = (Resolve-Path "$ArtifactPath\STIG Checklists").Path
    $dscConfigPath  = (Resolve-Path "$ArtifactPath\DscConfigs").Path
    $SystemsPath   = (Resolve-Path "$RootPath\Systems").Path

    $mofs           = Get-Childitem -Path "$MofPath\*.mof" -Recurse
    $dscConfigs     = Get-Childitem -Path "$dscConfigPath\*.ps1" -Recurse
    $checklists     = Get-Childitem -Path "$cklPath\*.ckl" -Recurse
    $SystemFiles  = Get-Childitem -Path "$SystemsPath\" -Recurse | Where {$_.name -notlike "*.keep*"}

    Write-Output "`n`tRemoving all systems and artifacts from the SCAR repository."

    foreach ($item in $removeItems)
    {
        Write-Output "Removing $($item.Name)"
        Remove-Item $item.Fullname -Confirm:$false -ErrorAction SilentlyContinue
    }
    Write-Output "`r`n"
}

function Import-DscModules
{
    <#

    .SYNOPSIS
    Imports the required modules stored in the "Resources\Modules" folder on the local system.

    .PARAMETER Rootpath
    Path to the root of the SCAR repository/codebase.

    .EXAMPLE
    Import-DscModules -ModulePath "$RootPath\Resouces\Modules"

    #>

    [cmdletbinding()]
    param(

        [Parameter()]
        [String]
        $ModulePath

    )

    $modules = @(Get-ChildItem -Path $ModulePath -Directory -Depth 0)
    Write-Output "`n`tBUILD: Importing required modules onto the local system."

    foreach ($module in $modules)
    {
        Write-Output "`t`tImporting Module - $($module.name)."
        $null = Import-Module $Module.name -Force
    }

    $null = Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCEIP $false -Confirm:$false
    Write-Output "`n"
}

function Compress-DscArtifacts
{
    <#

    .SYNOPSIS
    Compresses the configuration scripts and MOFs generated by SCAR and stores them in the Archive folder

    .PARAMETER RootPath
    Path to the root of the SCAR repository/codebase.

    .EXAMPLE


    #>

    [cmdletbinding()]
    param(

        [Parameter()]
        [String]
        $RootPath = (Get-Location).Path

    )

    # Archive the current MOF and build files in MMddyyyy_HHmm_DSC folder format
    $artifactPath   = (Resolve-Path -Path "$Rootpath\*Artifacts").Path
    $datePath       = (Get-Date -format "MMddyyyy_HHmm")

    Compress-Archive -Path $artifactPath -DestinationPath ("$archivePath\{0}_DSC.zip" -f $datePath) -Update
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
    $jobs           = new-object System.Collections.ArrayList

    if ($null -eq $TargetMachines)
    {
        $TargetMachines = new-object System.Collections.ArrayList
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
    Write-Output "`n`t$($jobs.count) Module sync jobs created. Waiting for jobs to finish processing."
    do
    {
        Start-Sleep -Seconds 30
        $completedJobs  = (Get-Job -ID $jobs | where {$_.state -ne "Running"}).count
        $runningjobs    = (Get-Job -ID $jobs | where {$_.state -eq "Running"}).count
        Write-Output "`t`tSystem Data Job Status:`t$runningJobs Jobs Currently Processing`t$completedJobs/$($jobs.count) Jobs Completed"
    }
    while ((Get-Job -ID $jobs).State -contains "Running")
    Write-Output "`n`t`t$($jobs.count) System Data jobs completed. Receiving job output"
    Get-Job -ID $jobs | Wait-Job | Receive-Job
    Write-Output "`tModule Validation Complete.`n"
}

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
        $LocalHost,

        [Parameter()]
        [switch]
        $RootOrgUnit,

        [Parameter()]
        [array]
        $ComputerName,

        [Parameter()]
        [string]
        [ValidateSet("MemberServers","AllServers","Full","OrgUnit","Targeted","Local")]
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

    $SystemsPath       = (Resolve-Path -Path "$RootPath\*Systems").Path
    $targetMachineOus   = New-Object System.Collections.ArrayList
    $targetMachines     = New-Object System.Collections.ArrayList
    $orgUnits           = New-Object System.Collections.ArrayList

    Write-Output "`tBeginning DSC Configuration Data Build - Identifying Target Systems."

    if ('' -ne $SearchBase)             {$Scope = "OrgUnit"}
    elseif ($LocalHost)                 {$Scope = "Local"}
    elseif ($ComputerName.count -eq 1)  {$Scope = "Targeted"}

    switch ($Scope)
    {
        "OrgUnit"       {$targetMachines = @(Get-ADComputer -SearchBase $SearchBase -Filter * -Properties "operatingsystem", "distinguishedname");break}
        "MemberServers" {$targetMachines = @(Get-ADComputer -Filter {OperatingSystem -like "**server*"} -Properties "operatingsystem", "distinguishedname" | Where-Object {$_.DistinguishedName -Notlike "*Domain Controllers*"});break}
        "AllServers"    {$targetMachines = @(Get-ADComputer -Filter {OperatingSystem -like "**server*"} -Properties "operatingsystem", "distinguishedname");break}
        "Full"          {$targetMachines = @(Get-ADComputer -Filter * -Properties "operatingsystem", "distinguishedname");break}
        "Targeted"      {$targetMachines = @(Get-AdComputer -Identity "$ComputerName" -Properties "operatingsystem","distinguishedname");break}
        "Local"
        {
            $targetMachines = @(
                @{
                    Name = $env:computerName
                    OperatingSystem     = "Windows 10"
                    distinguishedname   = "Computers"
                }
            )
        }
    }

    Write-Output "`tIdentifying Organizational Units for $($targetMachines.count) systems."

    if (-not($Localhost))
    {
        if ($RootOrgUnit)
        {
            $orgUnits = Get-ADOrganizationalUnit -SearchBase $SearchBase -SearchScope OneLevel
        }
        else
        {
            foreach ($targetMachine in $targetMachines)
            {
                if ($targetMachine.distinguishedname -like "CN=$($targetMachine.name),OU=Servers*")
                {
                    $null = $targetMachineOus.add($targetMachine.distinguishedname.Replace("CN=$($targetMachine.name),OU=Servers,",""))
                }
                elseif ($targetMachine.distinguishedName -like "*OU=Servers*")
                {
                    $oustring = ''
                    ($targetMachine.DistinguishedName.split(',')[3..10] | ForEach-Object { $null = $oustring += "$_," })
                    $null = $targetMachineOus.add($ouString.trimend(','))
                }
                else
                {
                    $null = $targetMachineOus.add($targetMachine.distinguishedname.Replace("CN=$($targetMachine.name),",""))
                }
            }
            $targetMachineOus | Get-Unique | ForEach-Object {Get-ADOrganizationalUnit -Filter {DistinguishedName -eq $_}} | ForEach-Object {$null = $orgunits.add($_)}

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
            $ouFolder = "$SystemsPath\$env:computerName"
        }
        elseif ($ou -eq "Computers")
        {
            $computersContainer = (Get-ADDomain).ComputersContainer
            $targetMachines = (Get-ADComputer -SearchBase $computersContainer -Properties OperatingSystem -filter {OperatingSystem -like "*Windows 10*"} ).name
            $ouFolder = "$SystemsPath\Windows 10"
        }
        else
        {
            $targetMachines = (Get-ADComputer -filter * -SearchBase $ou.DistinguishedName).name
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

                    $rootPath           = $using:RootPath
                    $machine            = $using:machine
                    $LcmSettings        = $using:lcmsettings
                    $ouFolder           = $using:oufolder
                    $LocalHost          = $using:LocalHost
                    $SystemsPath       = $using:SystemsPath

                    #region Get Applicable STIGs
                    if ($LocalHost)
                    {
                        $applicableStigs = @(Get-ApplicableStigs -LocalHost)
                    }
                    else
                    {
                        $applicableStigs = @(Get-ApplicableStigs -Computername $machine)
                    }

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
                            $iisVersion = Invoke-Command -ComputerName $machine -Scriptblock {
                                $iisData = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\InetStp"
                                $localIisVersion = "$($iisData.MajorVersion).$($iisData.MinorVersion)"
                                return $localiisVersion
                            }
                            $WebsiteStigFiles = @{
                                xccdfPath      = Get-StigFiles -Rootpath $Rootpath -StigType "WebSite" -Version $iisVersion -FileType "Xccdf" -NodeName $machine
                                orgSettings    = Get-StigFiles -Rootpath $Rootpath -StigType "WebSite" -Version $iisVersion -FileType "OrgSettings" -NodeName $machine
                                manualChecks   = Get-StigFiles -Rootpath $Rootpath -StigType "WebSite" -Version $iisVersion -FileType "ManualChecks" -NodeName $machine
                            }
                        }
                        "WebServer*"
                        {
                            [decimal]$iisVersion = Invoke-Command -ComputerName $machine -Scriptblock {
                                $iisData = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\InetStp"
                                $localIisVersion = "$($iisData.MajorVersion).$($iisData.MinorVersion)"
                                return $localiisVersion
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
                                "WindowsServer*"
                                {
                                    $null = $configContent.add("`n`n`t`tPowerSTIG_WindowsServer =")
                                    $null = $configContent.add("`n`t`t@{")
                                    $null = $configContent.add("`n`t`t`tOSRole               = `"$osRole`"")
                                    $null = $configContent.add("`n`t`t`tOsVersion            = `"$osVersion`"")
                                    $null = $configContent.add("`n`t`t`tOrgSettings          = `"$($osStigFiles.orgSettings)`"")
                                    $null = $configContent.add("`n`t`t`tManualChecks         = `"$($osStigFiles.manualChecks)`"")
                                    $null = $configContent.add("`n`t`t`txccdfPath            = `"$($osStigFiles.xccdfPath)`"")
                                    $null = $configContent.add("`n`t`t}")
                                }
                                "InternetExplorer"
                                {
                                    $null = $configContent.add("`n`n`t`tPowerSTIG_InternetExplorer =")
                                    $null = $configContent.add("`n`t`t@{")
                                    $null = $configContent.add("`n`t`t`tBrowserVersion 		= `"11`"")
                                    $null = $configContent.add("`n`t`t`tOrgSettings			= `"$($ieStigFiles.orgSettings)`"")
                                    $null = $configContent.add("`n`t`t`txccdfPath			= `"$($ieStigFiles.xccdfPath)`"")
                                    $null = $configContent.add("`n`t`t`tSkipRule 			= `"V-46477`"")
                                    $null = $configContent.add("`n`t`t}")
                                }
                                "DotnetFrameWork"
                                {
                                    $null = $configContent.add("`n`n`t`tPowerSTIG_DotNetFrameWork =")
                                    $null = $configContent.add("`n`t`t@{")
                                    $null = $configContent.add("`n`t`t`tFrameWorkVersion 	= `"4`"")
                                    $null = $configContent.add("`n`t`t`txccdfPath			= `"$($dotNetStigFiles.xccdfPath)`"")
                                    $null = $configContent.add("`n`t`t`tOrgSettings			= `"$($dotNetStigFiles.orgSettings)`"")
                                    $null = $configContent.add("`n`t`t`tManualChecks 		= `"$($dotNetStigFiles.manualChecks)`"")
                                    $null = $configContent.add("`n`t`t}")
                                }
                                "WindowsClient"
                                {
                                    $null = $configContent.add("`n`n`t`tPowerSTIG_WindowsClient =")
                                    $null = $configContent.add("`n`t`t@{")
                                    $null = $configContent.add("`n`t`t`tOSVersion            = `"10`"")
                                    $null = $configContent.add("`n`t`t`tOrgSettings          = `"$($win10StigFiles.orgSettings)`"")
                                    $null = $configContent.add("`n`t`t`tManualChecks         = `"$($win10StigFiles.manualChecks)`"")
                                    $null = $configContent.add("`n`t`t`txccdfPath            = `"$($win10StigFiles.xccdfPath)`"")
                                    $null = $configContent.add("`n`t`t}")
                                }
                                "WindowsDefender"
                                {
                                    $null = $configContent.add("`n`n`t`tPowerSTIG_WindowsDefender =")
                                    $null = $configContent.add("`n`t`t@{")
                                    $null = $configContent.add("`n`t`t`tOrgSettings          = `"$($winDefenderStigFiles.orgSettings)`"")
                                    $null = $configContent.add("`n`t`t`tManualChecks         = `"$($winDefenderStigFiles.manualChecks)`"")
                                    $null = $configContent.add("`n`t`t`txccdfPath            = `"$($winDefenderStigFiles.xccdfPath)`"")
                                    $null = $configContent.add("`n`t`t}")
                                }
                                "WindowsFirewall"
                                {
                                    $null = $configContent.add("`n`n`t`tPowerSTIG_WindowsFirewall =")
                                    $null = $configContent.add("`n`t`t@{")
                                    $null = $configContent.add("`n`t`t`tOrgSettings          = `"$($winFirewallStigFiles.orgSettings)`"")
                                    $null = $configContent.add("`n`t`t`tManualChecks         = `"$($winFirewallStigFiles.manualChecks)`"")
                                    $null = $configContent.add("`n`t`t`txccdfPath            = `"$($winFirewallStigFiles.xccdfPath)`"")
                                    $null = $configContent.add("`n`t`t}")
                                }
                                "WindowsDnsServer"
                                {
                                    $null = $configContent.add("`n`n`t`tPowerSTIG_WindowsDNSServer =")
                                    $null = $configContent.add("`n`t`t@{")
                                    $null = $configContent.add("`n`t`t`tOsVersion            = `"$osVersion`"")
                                    $null = $configContent.add("`n`t`t`txccdfPath            = `"$($WindowsDnsStigFiles.xccdfPath)`"")
                                    $null = $configContent.add("`n`t`t`tOrgSettings          = `"$($WindowsDnsStigFiles.orgSettings)`"")
                                    $null = $configContent.add("`n`t`t`tManualChecks         = `"$($WindowsDnsStigFiles.manualChecks)`"")
                                    $null = $configContent.add("`n`t`t}")
                                }
                                "Office2016*"
                                {
                                    $null = $configContent.add("`n`n`t`tPowerSTIG_Office2016_Excel =")
                                    $null = $configContent.add("`n`t`t@{")
                                    $null = $configContent.add("`n`t`t`tOrgSettings  = `"$Excel2016OrgSettings`"")
                                    $null = $configContent.add("`n`t`t`tManualChecks = `"$Excel2016ManualChecks`"")
                                    $null = $configContent.add("`n`t`t`txccdfPath    = `"$Excel2016xccdfPath`"")
                                    $null = $configContent.add("`n`t`t}")
                                    $null = $configContent.add("`n`n`t`tPowerSTIG_Office2016_Outlook =")
                                    $null = $configContent.add("`n`t`t@{")
                                    $null = $configContent.add("`n`t`t`tOrgSettings  = `"$Outlook2016OrgSettings`"")
                                    $null = $configContent.add("`n`t`t`tManualChecks = `"$Outlook2016ManualChecks`"")
                                    $null = $configContent.add("`n`t`t`txccdfPath    = `"$Outlook2016xccdfPath`"")
                                    $null = $configContent.add("`n`t`t}")
                                    $null = $configContent.add("`n`n`t`tPowerSTIG_Office2016_PowerPoint =")
                                    $null = $configContent.add("`n`t`t@{")
                                    $null = $configContent.add("`n`t`t`tOrgSettings  = `"$PowerPoint2016OrgSettings`"")
                                    $null = $configContent.add("`n`t`t`tManualChecks = `"$PowerPoint2016ManualChecks`"")
                                    $null = $configContent.add("`n`t`t`txccdfPath    = `"$PowerPoint2016xccdfPath`"")
                                    $null = $configContent.add("`n`t`t}")
                                    $null = $configContent.add("`n`n`t`tPowerSTIG_Office2016_Word =")
                                    $null = $configContent.add("`n`t`t@{")
                                    $null = $configContent.add("`n`t`t`tOrgSettings  = `"$Word2016OrgSettings`"")
                                    $null = $configContent.add("`n`t`t`tManualChecks = `"$Word2016ManualChecks`"")
                                    $null = $configContent.add("`n`t`t`txccdfPath    = `"$Word2016xccdfPath`"")
                                    $null = $configContent.add("`n`t`t}")
                                }
                                "Office2013*"
                                {
                                    $null = $configContent.add("`n`n`t`tPowerSTIG_Office2013_Excel =")
                                    $null = $configContent.add("`n`t`t@{")
                                    $null = $configContent.add("`n`t`t`tOrgSettings  = `"$Excel2013OrgSettings`"")
                                    $null = $configContent.add("`n`t`t`tManualChecks = `"$Excel2013ManualChecks`"")
                                    $null = $configContent.add("`n`t`t`txccdfPath    = `"$Excel2013xccdfPath`"")
                                    $null = $configContent.add("`n`t`t}")
                                    $null = $configContent.add("`n`n`t`tPowerSTIG_Office2013_Outlook =")
                                    $null = $configContent.add("`n`t`t@{")
                                    $null = $configContent.add("`n`t`t`tOrgSettings  = `"$Outlook2013OrgSettings`"")
                                    $null = $configContent.add("`n`t`t`tManualChecks = `"$Outlook2013ManualChecks`"")
                                    $null = $configContent.add("`n`t`t`txccdfPath    = `"$Outlook2013xccdfPath`"")
                                    $null = $configContent.add("`n`t`t}")
                                    $null = $configContent.add("`n`n`t`tPowerSTIG_Office2013_PowerPoint =")
                                    $null = $configContent.add("`n`t`t@{")
                                    $null = $configContent.add("`n`t`t`tOrgSettings  = `"$PowerPoint2013OrgSettings`"")
                                    $null = $configContent.add("`n`t`t`tManualChecks = `"$PowerPoint2013ManualChecks`"")
                                    $null = $configContent.add("`n`t`t`txccdfPath    = `"$PowerPoint2013xccdfPath`"")
                                    $null = $configContent.add("`n`t`t}")
                                    $null = $configContent.add("`n`n`t`tPowerSTIG_Office2013_Word =")
                                    $null = $configContent.add("`n`t`t@{")
                                    $null = $configContent.add("`n`t`t`tOrgSettings  = `"$Word2013OrgSettings`"")
                                    $null = $configContent.add("`n`t`t`tManualChecks = `"$Word2013ManualChecks`"")
                                    $null = $configContent.add("`n`t`t`txccdfPath    = `"$Word2013xccdfPath`"")
                                    $null = $configContent.add("`n`t`t}")
                                }
                                "Website*"
                                {
                                    $websites = @(Invoke-Command -Computername $Machine -Scriptblock { Import-Module WebAdministration;Return (Get-Childitem "IIS:\Sites").name})
                                    $appPools = @(Invoke-Command -Computername $Machine -Scriptblock { Import-Module WebAdministration;Return (Get-Childitem "IIS:\AppPools").name})
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
                                    $null = $configContent.add("`n`t`t`tXccdfPath        = `"$($webSiteStigFiles.XccdfPath)`"")
                                    $null = $configContent.add("`n`t`t`tOrgSettings      = `"$($webSiteStigFiles.OrgSettings)`"")
                                    $null = $configContent.add("`n`t`t`tManualChecks     = `"$($webSiteStigFiles.ManualChecks)`"")
                                    $null = $configContent.add("`n`t`t}")
                                }
                                "WebServer*"
                                {
                                    $null = $configContent.add("`n`n`t`tPowerSTIG_WebServer =")
                                    $null = $configContent.add("`n`t`t@{")
                                    $null = $configContent.add("`n`t`t`tSkipRule         = `"V-214429`"")
                                    $null = $configContent.add("`n`t`t`tIISVersion       = `"$IISVersion`"")
                                    $null = $configContent.add("`n`t`t`tLogPath          = `"C:\InetPub\Logs`"")
                                    $null = $configContent.add("`n`t`t`tXccdfPath        = `"$($webServerStigFiles.XccdfPath)`"")
                                    $null = $configContent.add("`n`t`t`tOrgSettings      = `"$($webServerStigFiles.OrgSettings)`"")
                                    $null = $configContent.add("`n`t`t`tManualChecks     = `"$($webServerStigFiles.ManualChecks)`"")
                                    $null = $configContent.add("`n`t`t}")
                                }
                                "FireFox"
                                {
                                    $null = $configContent.add("`n`n`t`tPowerSTIG_Firefox =")
                                    $null = $configContent.add("`n`t`t@{")
                                    $null = $configContent.add("`n`t`t`tInstallDirectory      = `"C:\Program Files\Mozilla Firefox`"")
                                    $null = $configContent.add("`n`t`t`txccdfPath			= `"$($firefoxStigFiles.XccdfPath)`"")
                                    $null = $configContent.add("`n`t`t`tOrgSettings			= `"$($firefoxStigFiles.OrgSettings)`"")
                                    $null = $configContent.add("`n`t`t`tManualChecks 		= `"$($firefoxStigFiles.ManualChecks)`"")
                                    $null = $configContent.add("`n`t`t}")
                                }
                                "Edge"
                                {
                                    $null = $configContent.add("`n`n`t`tPowerSTIG_Edge =")
                                    $null = $configContent.add("`n`t`t@{")
                                    $null = $configContent.add("`n`t`t`tOrgSettings          = `"$($edgeStigFiles.orgSettings)`"")
                                    $null = $configContent.add("`n`t`t`tManualChecks         = `"$($edgeStigFiles.manualChecks)`"")
                                    $null = $configContent.add("`n`t`t`txccdfPath            = `"$($edgeStigFiles.xccdfPath)`"")
                                    $null = $configContent.add("`n`t`t}")
                                }
                                "Chrome"
                                {
                                    $null = $configContent.add("`n`n`t`tPowerSTIG_Chrome =")
                                    $null = $configContent.add("`n`t`t@{")
                                    $null = $configContent.add("`n`t`t`tOrgSettings          = `"$($chromeStigFiles.orgSettings)`"")
                                    $null = $configContent.add("`n`t`t`tManualChecks         = `"$($chromeStigFiles.manualChecks)`"")
                                    $null = $configContent.add("`n`t`t`txccdfPath            = `"$($chromeStigFiles.xccdfPath)`"")
                                    $null = $configContent.add("`n`t`t}")
                                }
                                "Adobe"
                                {
                                    $null = $configContent.add("`n`n`t`tPowerSTIG_Adobe =")
                                    $null = $configContent.add("`n`t`t@{")
                                    $null = $configContent.add("`n`t`t`tAdobeApp            = `"AcrobatReader`"")
                                    $null = $configContent.add("`n`t`t`txccdfPath			= `"$($adobeStigFiles.XccdfPath)`"")
                                    $null = $configContent.add("`n`t`t`tOrgSettings			= `"$($adobeStigFiles.OrgSettings)`"")
                                    $null = $configContent.add("`n`t`t`tManualChecks 		= `"$($adobeStigFiles.ManualChecks)`"")
                                    $null = $configContent.add("`n`t`t}")
                                }
                                "OracleJRE"
                                {
                                    $null = $configContent.add("`n`n`t`tPowerSTIG_OracleJRE =")
                                    $null = $configContent.add("`n`t`t@{")
                                    $null = $configContent.add("`n`t`t`tConfigPath       = `"$ConfigPath`"")
                                    $null = $configContent.add("`n`t`t`tPropertiesPath   = `"$PropertiesPath`"")
                                    $null = $configContent.add("`n`t`t`tXccdfPath        = `"$($oracleStigFiles.XccdfPath)`"")
                                    $null = $configContent.add("`n`t`t`tOrgSettings      = `"$($oracleStigFiles.OrgSettings)`"")
                                    $null = $configContent.add("`n`t`t`tManualChecks     = `"$($oracleStigFiles.ManualChecks)`"")
                                    $null = $configContent.add("`n`t`t}")
                                }
                                # "Mcafee"
                                # {
                                #     $null = $configContent.add("`n`n`t`tPowerSTIG_McAfee =")
                                #     $null = $configContent.add("`n`t`t@{")
                                #     $null = $configContent.add("`n`t`t`tTechnology       = `"VirusScan`"")
                                #     $null = $configContent.add("`n`t`t`tVersion          = `"8.8`"")
                                #     $null = $configContent.add("`n`t`t`tXccdfPath        = `"$($mcafeeStigFiles.XccdfPath)`"")
                                #     $null = $configContent.add("`n`t`t`tOrgSettings      = `"$($mcafeeStigFiles.OrgSettings)`"")
                                #     $null = $configContent.add("`n`t`t`tManualChecks     = `"$($mcafeeStigFiles.ManualChecks)`"")
                                #     $null = $configContent.add("`n`t`t}")
                                # }
                                # "SqlServerInstance"
                                # {
                                #     $null = $configContent.add("`n`n`t`tPowerSTIG_SQLServer_Instance =")
                                #     $null = $configContent.add("`n`t`t@{")
                                #     $null = $configContent.add("`n`t`t`tSqlRole          = `"$sqlRole`"")
                                #     $null = $configContent.add("`n`t`t`tSqlVersion       = `"$sqlVersion`"")
                                #     $null = $configContent.add("`n`t`t`tServerInstance   = `"$sqlServerInstance`"")
                                #     $null = $configContent.add("`n`t`t`tXccdfPath        = `"$($sqlinstanceStigFiles.XccdfPath)`"")
                                #     $null = $configContent.add("`n`t`t`tOrgSettings      = `"$($sqlinstanceStigFiles.OrgSettings)`"")
                                #     $null = $configContent.add("`n`t`t`tManualChecks     = `"$($sqlinstanceStigFiles.ManualChecks)`"")
                                #     $null = $configContent.add("`n`t`t}")
                                #     $null = $configContent.add("`n")
                                # }
                                # "SqlServerDatabase"
                                # {
                                #     $null = $configContent.add("`n`n`t`tPowerSTIG_SQLServer_Database =")
                                #     $null = $configContent.add("`n`t`t@{")
                                #     $null = $configContent.add("`n`t`t`tSqlRole          = `"$sqlRole`"")
                                #     $null = $configContent.add("`n`t`t`tSqlVersion       = `"$sqlVersion`"")
                                #     $null = $configContent.add("`n`t`t`tServerInstance   = `"$sqlServerInstance`"")
                                #     $null = $configContent.add("`n`t`t`tXccdfPath        = `"$($sqlDatabseStigFiles.XccdfPath)`"")
                                #     $null = $configContent.add("`n`t`t`tOrgSettings      = `"$($sqlDatabaseStigFiles.OrgSettings)`"")
                                #     $null = $configContent.add("`n`t`t`tManualChecks     = `"$($sqlDatabaseStigFiles.ManualChecks)`"")
                                #     $null = $configContent.add("`n`t`t}")
                                #     $null = $configContent.add("`n")
                                # }
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
                    Start-Sleep -Seconds 30
                }
                while ((Get-Job -ID $jobs).State -contains "Running")
                Write-Output "`t`t$($jobs.count) System Data jobs completed. Outputting Results."
                Get-Job -ID $jobs | Wait-Job | Receive-Job
            }
            else
            {
                Write-Output "`t`tNo Jobs Generated for $($ou.Name)"
            }
        }
    }
}

function Get-StigFiles
{
    param(

    [Parameter()]
    [string]
    $FileType,

    [Parameter()]
    [string]
    $StigType,

    [Parameter()]
    [string]
    $RootPath = (Get-Location).Path,

    [Parameter()]
    [string]
    $Version,

    [Parameter()]
    [string]
    $NodeName

    )

    $xccdfArchive       = (Resolve-Path -Path "$RootPath\*Resources\Stig Data\XCCDFs").Path
    $manualCheckFolder  = (Resolve-Path -Path "$RootPath\*Resources\Stig Data\Manual Checks").Path
    $orgSettingsFolder  = (Resolve-Path -Path "$RootPath\*Resources\Stig Data\Organizational Settings").Path
    $stigFilePath       = ''

    switch ($fileType)
    {
        "Xccdf"
        {
            switch -WildCard ($stigType)
            {
                "WindowsServer"
                {
                    $xccdfContainer = (Resolve-Path -Path "$xccdfArchive\Windows.Server.$version" -ErrorAction SilentlyContinue).Path
                    switch ($version)
                    {
                        "2012R2"    {$xccdfs = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -notlike "*DC*" }).Name}
                        "2016"      {$xccdfs = (Get-ChildItem -Path "$xccdfContainer\*$version`_STIG*.xml").Name}
                        "2019"      {$xccdfs = (Get-ChildItem -Path "$xccdfContainer\*$version`_STIG*.xml").Name}
                    }
                }
                "DomainController"
                {
                    $xccdfContainer = (Resolve-Path -Path "$xccdfArchive\Windows.Server.$version" -ErrorAction SilentlyContinue).Path
                    switch ($version)
                    {
                        "2012R2"    {$xccdfs = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*DC*" }).Name}
                        "2016"      {$xccdfs = (Get-ChildItem -Path "$xccdfContainer\*$version`_STIG*.xml").Name}
                        "2019"      {$xccdfs = (Get-ChildItem -Path "$xccdfContainer\*$version`_STIG*.xml").Name}
                    }
                }
                "WindowsClient"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\Windows.Client" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml").name
                }
                "DotNetFramework"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\DotNet" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*$Version*STIG*Manual-xccdf.xml"}).name
                }
                "InternetExplorer"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\$StigType" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*xccdf.xml"}).name
                }
                "WebServer"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\Web Server" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*$($Version.replace(".","-"))*Server*xccdf.xml"}).name
                }
                "WebSite"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\Web Server" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*$($Version.replace(".","-"))*Site*xccdf.xml"}).name
                }
                "FireFox"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\browser" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*FireFox*xccdf.xml"}).name
                }
                "Edge"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\Edge" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*edge*xccdf.xml"}).name
                }
                "Chrome"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\Chrome" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*chrome*xccdf.xml"}).name
                }
                "Adobe"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\adobe" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*adobe*xccdf.xml"}).name
                }
                "McAfee"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\$StigType" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*McAfee*xccdf.xml"}).name
                }
                "Office*"
                {
                    $officeApp          = $stigType.split('_')[1]
                    $officeVersion      = $stigType.split('_')[0].Replace('Office',"")
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\Office" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*$officeApp*.xml" | Where-Object { $_.name -like "*$officeversion*"}).name
                }
                "OracleJRE"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\$StigType" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*Oracle*JRE*$version*xccdf.xml"}).name
                }
                "WindowsDefender"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\Windows.Defender" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*Windows*Defender*xccdf.xml"}).name
                }
                "WindowsFirewall"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\Windows.Firewall" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*Windows*Firewall*xccdf.xml"}).name
                }
                "WindowsDNSServer"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\Windows.Dns" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*xccdf.xml"}).name
                }
                "SqlServerInstance"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\SQL Server" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*SQL*$Version*Instance*xccdf.xml"}).name
                }
                "SqlServerDatabase"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\SQL Server" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*SQL*$version*Database*xccdf.xml"}).name
                }
            }
            $stigVersions       = $xccdfs | Select-String "V(\d+)R(\d+)" -AllMatches | Foreach-Object {$_.Matches.Value}
            $latestVersion      = ($stigversions | Measure-Object -Maximum).Maximum
            $xccdfFileName      = $xccdfs | Where { $_ -like "*$latestVersion*-xccdf.xml"}
            $stigFilePath       = "$xccdfContainer\$xccdfFileName"
        }
        "ManualChecks"
        {
            switch -wildcard ($stigType)
            {
                "WindowsServer"
                {
                    $osVersion              = $version.replace('R2','')
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\Windows.Server.$Version" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object {$_.name -like "*$osVersion*MS*.psd1"}).basename
                }
                "DomainController"
                {
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\Windows`.Server`.$version" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object {$_.name -like "*$version*DC*.psd1"}).basename
                    $stigVersions           = $manualCheckFiles | Select-String "(\d+)R(\d+)" -AllMatches | Foreach-Object {$_.Matches.Value}
                    $latestVersion          = ($stigVersions | Measure-Object -Maximum).Maximum
                    $manualCheckFileName    = $manualCheckFiles | Where-Object { $_ -like "*WindowsServer*$latestVersion*" }
                    $stigFilePath           = "$manualCheckContainer\$manualCheckFileName.psd1"
                }
                "WindowsClient"
                {
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\WindowsClient" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer).basename
                }
                "DotNetFramework"
                {
                    "$manualCheckFolder\Dotnet"
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\Dotnet" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*Dot*Net*ManualChecks.psd1"}).basename
                }
                "InternetExplorer"
                {
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\InternetExplorer" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*IE*11*ManualChecks.psd1"}).basename
                }
                "WebServer"
                {
                    $iisVersion = $version.replace(".","-")
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\WebServer" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*$iisVersion*-ManualChecks.psd1"}).basename
                }
                "WebSite"
                {
                    $iisVersion = $version.replace(".","-")
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\WebSite" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*$iisVersion*ManualChecks.psd1"}).basename
                }
                "FireFox"
                {
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\FireFox" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*FireFox*ManualChecks.psd1"}).basename
                }
                "Edge"
                {
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\Edge" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*Edge*ManualChecks.psd1"}).basename
                }
                "Chrome"
                {
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\Chrome" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*Chrome*ManualChecks.psd1"}).basename
                }
                "Adobe"
                {
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\adobe" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*adobe*ManualChecks.psd1"}).basename
                }
                "McAfee"
                {
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\McAfee" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*McAfee*ManualChecks.psd1"}).basename
                }
                "Office2016*"
                {
                    $officeApp              = $stigType.split('_')[1]
                    $officeVersion          = $stigType.split('_')[0].TrimStart("office")
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\Office" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*$officeApp*ManualChecks.psd1"}).basename
                    $stigVersions           = $manualCheckFiles | Select-String "(\d+)R(\d+)" -AllMatches | Foreach-Object {$_.Matches.Value}
                    $latestVersion          = ($stigVersions | Measure-Object -Maximum).Maximum
                    $manualCheckFileName    = $manualCheckFiles | Where-Object { $_ -like "*$officeApp*$latestVersion*" }
                    $stigFilePath           = "$manualCheckContainer\$manualCheckFileName.psd1"
                }
                "Office2013*"
                {
                    $officeApp              = $stigType.split('_')[1]
                    $officeVersion          = $stigType.split('_')[0].TrimStart("office")
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\Office_2013" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*$officeApp*ManualChecks.psd1"}).basename
                    $stigVersions           = $manualCheckFiles | Select-String "(\d+)R(\d+)" -AllMatches | Foreach-Object {$_.Matches.Value}
                    $latestVersion          = ($stigVersions | Measure-Object -Maximum).Maximum
                    $manualCheckFileName    = $manualCheckFiles | Where-Object { $_ -like "*$officeApp*$latestVersion*" }
                    $stigFilePath           = "$manualCheckContainer\$manualCheckFileName.psd1"
                }
                "OracleJRE"
                {
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\OracleJRE" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*OracleJRE*$version*.psd1"}).basename
                }
                "WindowsDefender"
                {
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\Windows.Defender" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*Windows*Defender*ManualChecks.psd1"}).basename
                }
                "WindowsFirewall"
                {
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\Windows.Firewall" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*Windows*Firewall*ManualChecks.psd1"}).basename
                }
                "WindowsDNSServer"
                {
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\Windows.Dns" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*Domain*Naming*Sytem*ManualChecks.psd1"}).basename
                }
                "SqlServerInstance"
                {
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\SqlServer" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*SQL*$version*Database*ManualChecks.psd1"}).basename
                }
                "SqlServerDatabase"
                {
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\SqlServer" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*SQL*$version*Database*ManualChecks.psd1"}).basename
                }
            }

            if ("" -eq $stigFilePath)
            {
                $stigVersions           = $manualCheckFiles | Select-String "(\d+)\.(\d+)" -AllMatches | Foreach-Object {$_.Matches.Value}
                $latestVersion          = ($stigVersions | Measure-Object -Maximum).Maximum
                $manualCheckFileName    = $manualCheckFiles | Where-Object { $_ -like "*$latestVersion*" }
                $stigFilePath           = "$manualCheckContainer\$manualCheckFileName.psd1"
            }

        }
        "OrgSettings"
        {

            switch -wildcard ($stigType)
            {
                "WindowsServer"
                {
                    $orgSettingsFiles   = (Get-ChildItem $orgSettingsFolder | Where-Object {$_.name -like "$stigType-$version-MS*"}).name
                }
                "DomainController"
                {
                    $orgSettingsFiles   = (Get-ChildItem $orgSettingsFolder | Where-Object {$_.name -like "WindowsServer-$version-DC*"}).name
                    $stigVersions           = $orgSettingsFiles | Select-String "(\d+)\.(\d+)" -AllMatches | Foreach-Object {$_.Matches.Value}
                    $latestVersion          = ($stigVersions | Measure-Object -Maximum).Maximum
                    $orgSettingsFileName    = $orgSettingsFiles | Where-Object {$_ -like "*WindowsServer*$latestVersion*.xml"}
                    $stigFilePath           = "$orgSettingsFolder\$orgSettingsFileName"
                }
                "WindowsClient"
                {
                    $orgSettingsFiles   = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -Like "*$StigType*" }).name
                }
                "DotNetFramework"
                {
                    $orgSettingsFiles   = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "$stigType-$version*"}).name
                }
                "InternetExplorer"
                {
                    $orgSettingsFiles   = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "$stigType-$version*"}).name
                }
                "WebServer"
                {
                    $orgSettingsFiles   = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "IISServer*$version*"}).name
                }
                "WebSite"
                {
                    $orgSettingsFiles   = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "IISSite*$version*"}).name
                }
                "FireFox"
                {
                    $StigType           = "FireFox"
                    $orgSettingsFiles   = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "$stigType-All-*"}).name
                }
                "Edge"
                {
                    $orgSettingsFiles   = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "*$stigType*"}).name
                }
                "Chrome"
                {
                    $orgSettingsFiles   = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "*$stigType*"}).name
                }
                "Adobe"
                {
                    $StigType           = "Adobe"
                    $orgSettingsFiles   = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "$stigType-*.xml"}).name
                }
                "McAfee"
                {
                    $orgSettingsFiles   = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "$stigType-$version*"}).name
                }
                "Office*"
                {
                    $officeApp              = $stigType.split('_')[1]
                    $officeVersion          = $stigType.split('_')[0].replace('Office','')
                    $orgSettingsFiles       = (Get-ChildItem "$orgSettingsFolder" | Where-Object { $_.name -like "*$officeApp$officeVersion*"}).name
                    $stigVersions           = $orgSettingsFiles | Select-String "(\d+)\.(\d+)" -AllMatches | Foreach-Object {$_.Matches.Value}
                    $latestVersion          = ($stigVersions | Measure-Object -Maximum).Maximum
                    $orgSettingsFileName    = $orgSettingsFiles | Where-Object { $_ -like "*$officeApp*$officeVersion*$latestVersion*.xml"}
                    $stigFilePath           = "$orgSettingsFolder\$orgSettingsFileName"
                }
                "OracleJRE"
                {
                    $orgSettingsFiles   = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "$stigType-$version*"}).name
                }
                "WindowsDefender"
                {
                    $orgSettingsFiles   = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "$stigType-$version*"}).name
                }
                "WindowsFirewall"
                {
                    $orgSettingsFiles   = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "*$stigType*"}).name
                }
                "WindowsDNSServer"
                {
                    $orgSettingsFiles   = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "$stigType*"}).name
                }
                "OracleJRE"
                {
                    $orgSettingsFiles   = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "$stigType-$version"}).name
                }
            }

            if ($stigtype -like "WebSite*" -or $stigType -like "WebServer*")
            {
                $stigVersions           = $orgSettingsFiles | ForEach-Object { $_.split("-")[2] | Select-String "(\d+)\.(\d+)" -AllMatches | Foreach-Object {$_.Matches.Value} }
                $latestVersion          = ($stigVersions | Measure-Object -Maximum).Maximum
                $orgSettingsFileName    = $orgSettingsFiles | Where-Object { $_ -like "*$($stigType.replace("Web","IIS"))*$latestVersion*.xml"}
                $stigFilePath           = "$orgSettingsFolder\$orgSettingsFileName"
            }
            elseif ('' -eq $stigFilePath)
            {
                $stigVersions           = $orgSettingsFiles | Select-String "(\d+)\.(\d+)" -AllMatches | Foreach-Object {$_.Matches.Value}
                $latestVersion          = ($stigVersions | Measure-Object -Maximum).Maximum
                $orgSettingsFileName    = $orgSettingsFiles | Where-Object { $_ -like "*$stigType*$latestVersion*.xml"}
                $stigFilePath           = "$orgSettingsFolder\$orgSettingsFileName"
            }

        }
    }

    if ((Test-Path $stigFilePath) -and ( $stigFilePath -like "*.xml" -Or $stigFilePath -like "*.psd1") )
    {
        return $stigFilePath
    }
    elseif ($stigtype -notlike "*SQL*")
    {
        Write-Warning "$NodeName - Unable to find $fileType file for $stigType STIG."
        return $null
    }
}

function Get-ApplicableStigs
{
    [cmdletbinding()]
    param(

        [Parameter()]
        [string]
        $RootPath = (Get-Location).Path,

        [Parameter()]
        [string]
        $Computername = $env:COMPUTERNAME,

        [Parameter()]
        [switch]
        $LocalHost

   )

   Write-Output "`t`tGathering STIG Applicability for $ComputerName"

   # Get Windows Version from Active Directory
    try
    {
        if ($LocalHost)
        {
            $WindowsVersion = "Windows 10"
            $ComputerName   = 'LocalHost'
        }
        else
        {
            $windowsVersion = (Get-WmiObject -class win32_OperatingSystem -ComputerName $ComputerName -erroraction Stop).caption
        }

        # Get Installed Software from Target System
        $session = New-PsSession -ComputerName $Computername -ErrorAction Stop
        $installedSoftware = Invoke-Command -Session $session -ErrorAction Stop -Scriptblock {
            $localSoftwareList = New-Object System.Collections.ArrayList
            $null = (Get-ItemProperty "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate) | ForEach-Object {$null = $localSoftwareList.add($_)}
            $null = (Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate) | ForEach-Object {$null = $localSoftwareList.add($_)}
            return $localSoftwareList
        }

        # Get Installed Roles on Target System
        if ($windowsVersion -notlike "*Windows 10*")
        {
            $installedRoles = Invoke-Command -Session $session -Erroraction Stop -Scriptblock {
                $localRoleList = @(Get-WindowsFeature | Where-Object { $_.Installed -eq $True })
                return $localRoleList
            }
        }

        # Add Applicable STIGs to Array
        $applicableSTIGs = New-Object System.Collections.ArrayList

        # Windows Operating System STIGs
        switch -WildCard ($windowsVersion)
        {
            "*2012*"    {$null = $applicableStigs.add("WindowsServer-2012R2-MemberServer")}
            "*2016*"    {$null = $applicableStigs.add("WindowsServer-2016-MemberServer")}
            "*2019*"    {$null = $applicableStigs.add("WindowsServer-2019-MemberServer")}
            "*10*"      {$null = $applicableStigs.add("WindowsClient")}
        }

        # Software STIGs
        switch -Wildcard ($installedSoftware.DisplayName)
        {
            "*Adobe Acrobat*"   {$null = $applicableStigs.add("AdobeReader")}
            "*McAfee*"          {$null = $applicableStigs.add("McAfee")}
            "*Office*16*"       {$null = $applicableStigs.add("Office2016")}
            "*Office*15*"       {$null = $applicableStigs.add("Office2013")}
            "*FireFox*"         {$null = $applicableStigs.add("FireFox")}
            "*Chrome*"          {$null = $applicableStigs.add("Chrome")}
            "*Edge*"            {$null = $applicableStigs.add("Edge")}
            "*OracleJRE*"       {$null = $applicableStigs.add("OracleJRE")}
            "Microsoft SQL Server*"
            {
                $null = $applicableStigs.add("SqlServerInstance")
                $null = $applicableStigs.add("SqlServerDatabase")
            }
        }

        # Server Role-Based STIGs
        switch -WildCard ($installedRoles.Name)
        {
            "Web-Server"
            {
                $iisVersion = Invoke-Command -Session $Session -ErrorAction Stop -Scriptblock {
                    $iisData = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\InetStp"
                    $localIisVersion = "$($iisData.MajorVersion).$($iisData.MinorVersion)"
                    return $localiisVersion
                }
                $null = $applicableStigs.add("WebServer-$IISVersion")
                $null = $applicableStigs.add("Website-$IISVersion")
            }
            "Windows-Defender"
            {
                $null = $applicableStigs.add("WindowsDefender")
                $null = $applicableStigs.add("WindowsFirewall")
            }
            "DNS"                   {$null = $applicableStigs.add("WindowsDnsServer")}
            "AD-Domain-Services"    {$null = $applicableStigs.add("ActiveDirectory")}
        }

        # Always Applicable
        $null = $applicableSTIGs.add("InternetExplorer")
        $null = $applicableSTIGs.add("DotnetFramework")
        $null = $applicableStigs.add("WindowsDefender")
        $null = $applicableStigs.add("WindowsFirewall")

        Remove-PsSession $Session
        $applicableStigs = $applicableStigs | Select-Object -Unique

        return $applicableStigs
    }
    catch
    {
        Write-Output "`t`t`tUnable to determine STIG Applicability for $ComputerName. Please verify WinRM connectivity."
        return $null
        Remove-PsSession $Session
    }
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
    $parsedData | Export-Csv -Path $OutputPath\DscResults.csv -NoTypeInformation
}

function Get-OuDN
{

    [CmdletBinding()]
    param
    (
        [Parameter()]
        [string]
        $ComputerName = "$env:computername"

    )

    $dn = (Get-AdComputer -Identity $ComputerName).DistinguishedName
    return $dn.replace("CN=$Env:ComputerName,","")
}

function Clear-SystemData
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [String]
        $Rootpath = (Get-Location).Path
    )

    $SystemsPath = (Resolve-Path -Path "$RootPath\*Systems").Path
    $ConfigDataFiles = Get-Childitem $SystemsPath -Recurse | Where-Object { $_.FullName -Notlike "*Staging*" }

    Write-Output "`tRemoving $($configDataFiles.count) DSC COnfigData Files"
    Remove-Item $configDataFiles.FullName -Force -Confirm:$False -Recurse
}

function Get-ManualCheckFileFromXccdf
{
    [cmdletBinding()]
    param (

        [Parameter()]
        [string]
        $XccdfPath,

        [Parameter()]
        [string]
        $ManualCheckPath = ".\Resources\ManualChecks\New"
    )

    foreach ($path in $XccdfPath)
    {
        $file               = Get-Item $path
        [xml]$content       = Get-Content -path $file -Encoding UTF8
        $split              = $file.basename.split("_")
        $StigType           = $split[1]
        $subType            = $split[2] + $split[3] + $split[4] + $split[5]
        $Vuls               = $content.benchmark.group.id
        $outfileName        = "$subType-manualchecks.psd1"
        $manualCheckContent = New-Object System.Collections.ArrayList

        foreach ($vul in $vuls)
        {
            $null = $manualCheckContent.add("@{")
            $null = $manualCheckContent.add("    VulID       = `"$vul`"")
            $null = $manualCheckContent.add("    Status      = `"NotReviewed`"")
            $null = $manualCheckContent.add("    Comments    = `"Input Finding Comments`"")
            $null = $manualCheckContent.add("}`n")
        }
        $manualCheckContent | Out-File "$manualCheckPath\$outFileName" -force
    }
}

function Publish-SCARArtifacts
{

    Param (
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

#region Stig Checklist Functions
function Get-StigChecklists
{
    <#

    .SYNOPSIS
    This function will generate the STIG Checklists and output them to the Reports directory under SCAR.

    .PARAMETER Rootpath
    Path to the root of the SCAR repository/codebase.
    C:\Your Repo\SCAR\

    .PARAMETER OutputPath
    Path of where the checklists will be generated. Defaults to:
    Artifacts\Stig Checklist

    .PARAMETER TargetMachines
    List of target machines. If not specificied, a list will be generated from configurations present in "C:\Your Repo\SCAR\Systems"

    .PARAMETER TestConfig
    Switch parameter that allows testing against the configuration and the target machine. If switch is used, it will run test-dscconfiguration for the mof against the target machines to verify compliance.

    .EXAMPLE
    Example Get-StigChecklists -RootPath "C:\Your Repo\SCAR\"

    .EXAMPLE
    Example Get-StigChecklists -RootPath "C:\Your Repo\SCAR\" -TestConfig

    #>

    [cmdletbinding()]
    param(

        [Parameter()]
        [string]
        $RootPath = (Get-Location).Path,

        [Parameter()]
        [string]
        $OutputPath,

        [Parameter()]
        [array]
        $TargetMachines,

        [Parameter()]
        [string]
        $TargetFolder,

        [Parameter()]
        [string]
        $checklistDataPath,

        [Parameter()]
        [switch]
        $MofSettings,

        [Parameter()]
        [switch]
        $GenerateReports,

        [Parameter()]
        [switch]
        $LocalHost,

        [Parameter()]
        [string]
        $Enclave = "Unclassified"

    )

    # Initialize File Paths
    $SystemsPath       = (Resolve-Path -Path "$RootPath\*Systems").path
    $mofPath            = (Resolve-Path -Path "$RootPath\*Artifacts\Mofs").path
    $resourcePath       = (Resolve-Path -Path "$RootPath\*Resources").path
    $artifactsPath      = (Resolve-Path -Path "$RootPath\*Artifacts").path
    $cklContainer       = (Resolve-Path -Path "$artifactsPath\STIG Checklists").Path
    $allCkls            = @()

    if (-not ($LocalHost))
    {
        if ($null -eq $TargetMachines)
        {
            if ('' -eq $TargetFolder)
            {
                $targetMachines = (Get-Childitem -Path $SystemsPath -recurse | Where-object {$_.FullName -like "*.psd1" -and $_.fullname -notlike "*staging*"}).basename
            }
            else
            {
                if (Test-Path "$SystemsPath\$TargetFolder")
                {
                    $targetMachines = (Get-Childitem -Path "$SystemsPath\$TargetFolder\*.psd1" -recurse).basename
                }
                else
                {
                    Write-Output "$TargetFolder is not a valid SystemData subfolder. Please verify the folder name."
                    exit
                }
            }
        }
    }
    else
    {
        $targetMachines = @("$env:ComputerName")
    }

    $jobs       = New-Object System.Collections.ArrayList

    Write-Output "`tStarting STIG Checklist generation jobs for $($targetMachines.count) targetted machines.`n"

    foreach ($machine in $targetMachines)
    {
        $SystemFile = (Resolve-Path -Path "$SystemsPath\*\$machine.psd1").path
        $data = Invoke-Expression (Get-Content $SystemFile | Out-String)

        try
        {
            $machineFolder = (New-Item -Path $CklContainer -Name "$($data.nodeName)" -ItemType Directory -Force).FullName
        }
        catch
        {
            $machineFolder = (New-Item -Path $CklContainer -Name "$machine" -ItemType Directory -Force).FullName
        }

        Write-Output "`t`tStarting Job - Generate STIG Checklists for $machine"

        $job = Start-Job -InitializationScript {Import-Module -Name "C:\Program Files\WindowsPowershell\Modules\PowerSTIG\*\powerstig.psm1","C:\Program Files\WindowsPowershell\Modules\StigRepo\*\module\StigRepo.psm1"} -Scriptblock {

            $machine            = $using:machine
            $RootPath           = $using:RootPath
            $machineFolder      = $using:machinefolder
            $SystemsPath       = $using:SystemsPath
            $mofPath            = $using:mofPath
            $resourcePath       = $using:resourcePath
            $artifactsPath      = $using:artifactsPath
            $cklContainer       = $using:cklContainer
            $SystemFile       = $using:SystemFile
            $data               = $using:data
            $dscResult          = $null
            $remoteCklJobs      = New-Object System.Collections.ArrayList

            Write-Output "`n`n`t`t$Machine - Begin STIG Checklist Generation`n"

            if ($null -ne $data.appliedConfigurations)  {$appliedStigs = $data.appliedConfigurations.getenumerator() | Where-Object {$_.name -like "POWERSTIG*"}}
            if ($null -ne $data.manualStigs)            {$manualStigs  = $data.manualStigs.getenumerator()}
            if ($null -ne $appliedStigs)
            {
                $winRmTest  = Test-WSMan -Computername $machine -Authentication Default -Erroraction silentlycontinue
                $ps5check   = Invoke-Command -ComputerName $machine -ErrorAction SilentlyContinue -Scriptblock {return $psversiontable.psversion.major}
                $osVersion          = (Get-WmiObject Win32_OperatingSystem).caption | Select-String "(\d+)([^\s]+)" -AllMatches | Foreach-Object {$_.Matches.Value}

                if ($null -eq $winRmTest)
                {
                    Write-Warning "`t`t`tUnable to connect to $machine to Test DSC Compliance. Verify WinRM connectivity."
                    Continue
                }

                if ($ps5Check -lt 5)
                {
                    Write-Warning "The Powershell version on $machine does not support Desired State Configuration. Minimum Powershell version is 5.0"
                    Continue
                }

                try
                {
                    $referenceConfiguration = (Resolve-Path "$mofPath\*$machine.mof").Path
                    if ($machine -eq $env:computername)
                    {
                        $null = New-Item "C:\ScarData\STIG Data\ManualChecks" -ItemType Directory -Force -Confirm:$False
                        $null = New-Item "C:\ScarData\STIG Data\Xccdfs" -ItemType Directory -Force -Confirm:$False
                        $null = New-Item "C:\ScarData\STIG Checklists" -ItemType Directory -Force -Confirm:$False
                        $null = New-Item "C:\ScarData\MOF" -ItemType Directory -Force -Confirm:$False
                        $null = Copy-Item -Path $referenceConfiguration -Destination "C:\SCARData\MOF\" -Force -Confirm:$False
                    }
                    else
                    {
                        $null = New-Item "\\$machine\c$\SCAR\STIG Data\ManualChecks" -ItemType Directory -Force -Confirm:$False
                        $null = New-Item "\\$machine\c$\SCAR\STIG Data\Xccdfs" -ItemType Directory -Force -Confirm:$False
                        $null = New-Item "\\$machine\c$\SCAR\STIG Checklists" -ItemType Directory -Force -Confirm:$False
                        $null = New-Item "\\$machine\c$\SCAR\MOF" -ItemType Directory -Force -Confirm:$False
                        $null = Copy-Item -Path $referenceConfiguration -Destination "\\$machine\c$\SCAR\MOF\" -Force -Confirm:$False
                    }

                    $directoryCopy = $true
                }
                catch
                {
                    Write-Output "`t`t`t`tUnable to Copy SCAR directory to $Machine."
                    $directoryCopy = $false
                }

                if ($directoryCopy)
                {
                    $attemptCount = 0

                    do
                    {
                        try
                        {
                            $attemptCount++

                            if ($machine -eq $env:computername)
                            {
                                Write-Output "`t`tExecuting local DSC Compliance Scan (Attempt $attemptCount/3)"
                                $dscResult = Test-DscConfiguration -ReferenceConfiguration $ReferenceConfiguration -ErrorAction Stop
                                $remoteExecution = $false
                            }
                            else
                            {
                                Write-Output "`t`tExecuting remote DSC Compliance Scan (Attempt $attemptCount/3)"
                                $dscResult  = Invoke-Command -Computername $machine -ErrorAction Stop -Scriptblock {
                                    Test-DscConfiguration -ReferenceConfiguration "C:\SCAR\MOF\$env:Computername.mof"
                                }

                                $remoteExecution = $true
                            }
                        }
                        catch
                        {
                            if ($machine -eq $env:computername)
                            {
                                Stop-DscConfiguration -force -erroraction SilentlyContinue -WarningAction SilentlyContinue
                            }
                            else
                            {
                                Invoke-Command -ComputerName $machine -erroraction SilentlyContinue -WarningAction SilentlyContinue -Scriptblock {
                                    Stop-DscConfiguration -force -erroraction SilentlyContinue -WarningAction SilentlyContinue
                                }
                            }
                            Start-Sleep -Seconds 5
                            $remoteExecution = $False
                        }
                    }
                    until ($null -ne $dscResult -or $attemptCount -ge 3)
                }
                else
                {
                    Write-Warning "`t`tRemote Execution failed - Attempting compliance scan locally (Attempt $attemptCount/5)"
                    $attemptCount   = 0
                    do
                    {
                        try
                        {
                            $attemptCount++
                            $referenceConfiguration = (Resolve-Path "$mofPath\*$machine.mof").Path
                            Write-Output "`t`t`tExecuting local DSC Compliance Scan (Attempt $attemptCount/3)"

                            if (Test-Path -Path $referenceConfiguration)
                            {
                                $dscResult = Test-DscConfiguration -Computername $machine -ReferenceConfiguration $referenceConfiguration -ErrorAction Stop
                            }
                            else
                            {
                                Write-Output "`t`t`t`tNo MOF exists for $machine."
                                Continue
                            }
                        }
                        catch
                        {
                            Write-Output "`t`t`t`tError gathering DSC Status. Restarting DSC Engine and trying again in 5 Seconds."
                            if ($machine -eq $env:computername)
                            {
                                Stop-DscConfiguration -force -erroraction SilentlyContinue -WarningAction SilentlyContinue
                            }
                            else
                            {
                                Invoke-Command -ComputerName $machine -erroraction SilentlyContinue -WarningAction SilentlyContinue -Scriptblock {
                                    Stop-DscConfiguration -force -erroraction SilentlyContinue -WarningAction SilentlyContinue
                                }
                            }
                            Start-Sleep -Seconds 5
                        }
                    }
                    until ($null -ne $dscResult -or $attemptCount -ge 3)

                    if ($null -eq $dscResult)
                    {
                        Write-Output "Unable to execute compliance scan on $machine. Please verify winrm connectivity."
                        exit
                    }
                }

                if ($null -eq $dscResult)
                {
                    Write-Output "Unable to execute DSC compliance scan on $machine."
                    exit
                }
                else
                {

                    foreach ($stig in $appliedStigs)
                    {

                        $stigType       = $stig.name.tostring().replace("PowerSTIG_", "")
                        $cklPath        = "$machineFolder\$machine-$stigType.ckl"

                        if (($null -ne $stig.Value.XccdfPath) -and (Test-Path $stig.Value.XccdfPath))
                        {
                            $xccdfPath = $stig.Value.XccdfPath
                        }
                        else
                        {
                            Write-Warning "$machine - No xccdf file provided for $Stigtype"
                            continue
                        }

                        if (($null -ne $stig.value.ManualChecks) -and (Test-Path $stig.Value.ManualChecks))
                        {
                            $manualCheckFile = $stig.Value.ManualChecks
                        }
                        else
                        {
                            Write-Verbose "$machine - No Manual Check file provided for $Stigtype"
                        }

                        if ($remoteExecution)
                        {
                            Write-Output "`t`t`tSTIG Checklist - $stigType"
                            try
                            {
                                if (Test-Path $xccdfPath)
                                {
                                    $remoteXccdfPath        = (Copy-Item -Path $xccdfPath -Passthru -Destination "\\$machine\C$\Scar\STIG Data\Xccdfs" -Container -Force -Confirm:$False -erroraction Stop).fullName.Replace("\\$machine\C$\","C:\")
                                }

                                $remoteCklPath          = "C:\SCAR\STIG Checklists"

                                if ($null -ne $manualCheckFile)
                                {
                                    $remoteManualCheckFile  = (Copy-Item -Path $ManualCheckFile -Passthru -Destination "\\$machine\C$\Scar\STIG Data\ManualChecks" -Container -Force -Confirm:$False).FullName.Replace("\\$machine\C$\","C:\")
                                }

                                $remoteCklJob = Invoke-Command -ComputerName $machine -AsJob -ArgumentList $remoteXccdfPath,$remoteManualCheckFile,$remoteCklPath,$dscResult,$machineFolder,$stigType -ScriptBlock {
                                    param(
                                        [Parameter(Position=0)]$remoteXccdfPath,
                                        [Parameter(Position=1)]$remoteManualCheckFile,
                                        [Parameter(Position=2)]$remoteCklPath,
                                        [Parameter(Position=3)]$dscResult,
                                        [Parameter(Position=4)]$machineFolder,
                                        [Parameter(Position=5)]$stigType
                                    )
                                    Import-Module -Name "C:\Program Files\WindowsPowershell\Modules\PowerSTIG\*\powerstig.psm1"
                                    Import-Module -Name "C:\Program Files\WindowsPowershell\Modules\StigRepo\*\module\StigRepo.psm1"

                                    $params = @{
                                        xccdfPath       = $remotexccdfPath
                                        OutputPath      = "$remoteCklPath\$env:computername-$stigType.ckl"
                                        DscResult       = $dscResult
                                        Enclave         = $Enclave
                                    }
                                    if ($null -ne $remoteManualCheckFile)
                                    {
                                        $params += @{ManualCheckFile = $remoteManualCheckFile}
                                    }
                                    Get-StigChecklist @params -ErrorAction SilentlyContinue
                                }
                                $null = $remoteCklJobs.Add($remoteCklJob)
                            }
                            catch
                            {
                                Write-Output "Unable to generate STIG Checklists for $machine."
                            }
                        }
                        else
                        {
                            Write-Output "`t`t`tSTIG Checklist - $stigType"
                            try
                            {
                                $xccdfPath        = (Copy-Item -Path $xccdfPath -Passthru -Destination "C:\ScarData\STIG Data\Xccdfs" -Container -Force -Confirm:$False).FullName
                                $cklPath          = "C:\SCARData\STIG Checklists\$machine-$stigType.ckl"

                                if ($null -ne $manualCheckFile)
                                {
                                    $remoteManualCheckFile  = (Copy-Item -Path $ManualCheckFile -Destination "C:\ScarData\STIG Data\ManualChecks" -Container -Force -Confirm:$False).FullName
                                }

                                $params = @{
                                    XccdfPath       = $xccdfPath
                                    OutputPath      = $cklPath
                                    DSCResult       = $dscResult
                                    Enclave         = $Enclave
                                }

                                if ($null -ne $ManualCheckFile)
                                {
                                    $params += @{ManualCheckFile = $ManualCheckFile}
                                }

                                Get-StigChecklist @params -ErrorAction SilentlyContinue
                            }
                            catch
                            {
                                Write-Output "`t`t`tUnable to generate $stigType Checklist for $machine."
                            }
                        }
                    }

                    if ($remoteCklJobs.count -gt 0)
                    {
                        Get-Job -ID $remoteCklJobs.ID | Wait-Job | Receive-Job
                        Get-Job -ID $remoteCklJobs.ID | Remove-Job
                    }

                    try
                    {
                        if ($machine -eq $env:computername)
                        {
                            $stigChecklists = Get-ChildItem -Path "C:\ScarData\STIG Checklists\*.ckl" -Recurse
                        }
                        else
                        {
                            $stigChecklists = Get-Childitem -Path "\\$machine\C$\SCAR\STIG Checklists\*.ckl" -Recurse
                        }

                        if ($stigChecklists.count -gt 0)
                        {
                            Copy-Item -Path $stigChecklists.FullName -Destination $machineFolder
                        }
                        else
                        {
                            Write-Output "`t`t$machine - No STIG Checklists generated."
                        }
                    }
                    catch
                    {
                        Write-Output "`t`t$machine - Unable to copy STIG Checklists to artifacts location."
                    }
                }
            }

            if ($null -ne $manualStigs)
            {
                foreach ($manStig in $manualStigs)
                {

                    if ($null -ne $manStig.Value.Subtypes)
                    {
                        $stigType = $manStig.name.tostring().replace("StigChecklist_", "")
                        $subTypes = $manStig.value.subTypes

                        foreach ($subType in $subTypes)
                        {
                            Write-Output "`t`tGenerating Checklist - $StigType-$subtype"
                            $manCheckFileHint   = $subtype.replace("_","")
                            $xccdfHint          = $subtype
                            $manualCheckFile    = (Get-Childitem "$rootpath\Resources\Stig Data\Manual Checks\$stigType\*.psd1"      | Where {$_.name -like "*$manCheckFileHint*"}).FullName
                            $xccdfPath          = (Get-Childitem "$rootpath\Resources\Stig Data\XCCDFs\$stigType\*Manual-xccdf.xml"  | Where {$_.name -like "*$xccdfHint*"}).FullName
                            $cklPath            = "$machineFolder\$($data.nodename)-$stigType_$manCheckFileHint.ckl"

                            $params = @{
                                xccdfPath       = $xccdfPath
                                OutputPath      = $cklPath
                                ManualCheckFile = $manualCheckFile
                                NoMof           = $true
                                NodeName        = $data.nodename
                                Enclave         = $Enclave
                            }
                            Get-StigChecklist @params -ErrorAction SilentlyContinue
                        }
                    }
                    elseif ($null -ne $manstig.name)
                    {
                        $stigType = $manStig.name.tostring().replace("StigChecklist_", "")
                        Write-Output "`t`tGenerating Checklist - $stigType"

                        $manualCheckFile    = (Get-Childitem "$rootpath\Resources\Stig Data\Manual Checks\$stigType\*.psd1"     | Select -first 1).FullName
                        $xccdfPath          = (Get-Childitem "$rootpath\Resources\Stig Data\XCCDFs\$stigType\*Manual-xccdf.xml" | Select -first 1).FullName
                        $cklPath            = "$machineFolder\$($data.nodename)-$stigType.ckl"
                        $params = @{
                            xccdfPath       = $xccdfPath
                            OutputPath      = $cklPath
                            ManualCheckFile = $manualCheckFile
                            NoMof           = $true
                            NodeName        = $data.nodename
                            Enclave         = $Enclave
                        }
                        Get-StigChecklist @params -ErrorAction SilentlyContinue
                    }
                    else
                    {
                        Write-Output "`t`tUnable to generate $stigtype STIG Checklist for $machine. Please verify that STIG Data files."
                        Continue
                    }
                }
            }

            $machineCkls = (Get-ChildItem "$machineFolder\*.ckl" -recurse).count

            if ($machineCkls -lt 1)
            {
                Write-Output "`t`tNo STIG Checklists exist for $machine - Removing folder."
                Remove-Item $machineFolder -Force -Recurse -Confirm:$False
            }
            Write-Output "`t`t$machine - STIG Checklist job complete"
        }
        $null = $jobs.add($job.Id)
    }
    Write-Output "`n`tJob creation for STIG Checklists Generation is Complete. Waiting for $($jobs.count) jobs to finish processing"

    do
    {
        Start-Sleep -Seconds 60
        $completedJobs  = (Get-Job -id $jobs | where {$_.state -ne "Running"}).count
        $runningjobs    = (Get-Job -id $jobs | where {$_.state -eq "Running"}).count
        Write-Output "`t`tChecklist Job Status:`t$runningJobs Jobs Currently Processing`t$completedJobs/$($jobs.count) Jobs Completed"
    }
    while ((Get-Job -ID $jobs).State -contains "Running")
    Write-Output "`n`t$($jobs.count) STIG Checklist jobs completed. Receiving job output"
    Get-Job -ID $jobs | Wait-Job | Receive-Job

    $cklCount = (Get-ChildItem "$cklContainer\*.ckl" -Recurse).count
    Write-Output "`tSTIG Checklist generation complete. Total STIG Checklists generated - $cklCount`n"
}

function Get-StigCheckList
{
    <#
    .SYNOPSIS
        Automatically creates a Stig Viewer checklist from the DSC results or
        compiled MOF

    .PARAMETER ReferenceConfiguration
        The MOF that was compiled with a PowerStig composite

    .PARAMETER DscResult
        The results of Test-DscConfiguration

    .PARAMETER XccdfPath
        The path to the matching xccdf file. This is currently needed since we
        do not pull add xccdf data into PowerStig

    .PARAMETER OutputPath
        The location you want the checklist saved to

    .PARAMETER ManualCheckFile
        Location of a psd1 file containing the input for Vulnerabilities unmanaged via DSC/PowerSTIG.

    .EXAMPLE
        Get-StigChecklist -ReferenceConfiguration $referenceConfiguration -XccdfPath $xccdfPath -OutputPath $outputPath

    .EXAMPLE
        Get-StigChecklist -ReferenceConfiguration $referenceConfiguration -ManualCheckFile "C:\Stig\ManualChecks\2012R2-MS-1.7.psd1" -XccdfPath $xccdfPath -OutputPath $outputPath
        Get-StigChecklist -ReferenceConfiguration $referenceConfiguration -ManualCheckFile $manualCheckFilePath -XccdfPath $xccdfPath -OutputPath $outputPath
    #>
    [CmdletBinding()]
    [OutputType([xml])]
    param
    (
        [Parameter(Mandatory = $true, ParameterSetName = 'mof')]
        [string]
        $ReferenceConfiguration,

        [Parameter(Mandatory = $true, ParameterSetName = 'result')]
        [psobject]
        $DscResult,

        [Parameter(Mandatory = $true, ParameterSetName = 'noMof')]
        [switch]
        $NoMof,

        [Parameter(Mandatory = $true, ParameterSetName = 'noMof')]
        [string]
        $NodeName,

        [Parameter(Mandatory = $true)]
        [string]
        $XccdfPath,

        [Parameter(Mandatory = $true)]
        [string]
        $OutputPath,

        [Parameter()]
        [string]
        $ManualCheckFile,

        [Parameter()]
        [string]
        $Enclave = "Unclassified"
    )

    # Validate parameters before continuing
    if ($ManualCheckFile)
    {
        if (-not (Test-Path -Path $ManualCheckFile))
        {
            throw "$($ManualCheckFile) is not a valid path to a ManualCheckFile. Provide a full valid path"
        }

        $parent = Split-Path $ManualCheckFile -Parent
        $filename = Split-Path $ManualCheckFile -Leaf
        $manualCheckData = Import-LocalizedData -BaseDirectory $parent -Filename $fileName
    }

    # Values for some of these fields can be read from the .mof file or the DSC results file
    if ($PSCmdlet.ParameterSetName -eq 'mof')
    {
        if (-not (Test-Path -Path $ReferenceConfiguration))
        {
            throw "$($ReferenceConfiguration) is not a valid path to a configuration (.mof) file. Please provide a valid entry."
        }

        $MofString = Get-Content -Path $ReferenceConfiguration -Raw
        $TargetNode = Get-TargetNodeFromMof($MofString)

    }
    elseif ($PSCmdlet.ParameterSetName -eq 'result')
    {
        # Check the returned object
        if ($null -eq $DscResult)
        {
            throw 'Passed in $DscResult parameter is null. Please provide a valid result using Test-DscConfiguration.'
        }
        $TargetNode = $DscResult.PSComputerName
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'NoMof')
    {
        $SystemFile   = (Resolve-Path "$RootPath\Systems\*\$machine*").path
        $systemData       = Invoke-Expression (Get-Content $SystemFile | Out-String)
        $targetNode     = $NodeName
    }
    $TargetNodeType = Get-TargetNodeType($TargetNode)

    switch ($TargetNodeType)
    {
        "MACAddress"
        {
            $HostnameMACAddress = $TargetNode
            Break
        }
        "IPv4Address"
        {
            $HostnameIPAddress = $TargetNode
            Break
        }
        "IPv6Address"
        {
            $HostnameIPAddress = $TargetNode
            Break
        }
        "FQDN"
        {
            $HostnameFQDN = $TargetNode
            Break
        }
        default
        {
            $Hostname = $TargetNode
        }
    }

    $xmlWriterSettings = [System.Xml.XmlWriterSettings]::new()
    $xmlWriterSettings.Indent = $true
    $xmlWriterSettings.IndentChars = "`t"
    $xmlWriterSettings.NewLineChars = "`n"
    $writer = [System.Xml.XmlWriter]::Create($OutputPath, $xmlWriterSettings)

    $writer.WriteStartElement('CHECKLIST')

    #region ASSET

    $writer.WriteStartElement("ASSET")
    try
    {
        $IPAddress  = (Get-NetIPAddress -AddressFamily IPV4 | Where-Object { $_.IpAddress -notlike "127.*" } | Select-Object -First 1).IPAddress
        $MACAddress = (Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object MacAddress | Select-Object -First 1).MacAddress
        $filter     = "(&(objectCategory=computer)(objectClass=computer)(cn=$env:computername))"
        $FQDN       = ([adsisearcher]$filter).FindOne().Properties.dnshostname
    }
    catch
    {
        if (-not $PSCmdlet.ParameterSetName -eq 'NoMof')
        {
            Write-Warning -Message "Error obtaining host data for $hostname."
        }
    }

    $osVersion = (Get-WmiObject Win32_OperatingSystem -ComputerName $hostName -erroraction silentlycontinue).caption

    switch -wildcard ($osVersion)
    {
        "*Server*"
        {
            $filter = "(&(objectCategory=computer)(objectClass=computer)(cn=$hostName))"
            $distinguishedName = ([adsisearcher]$filter).FindOne().Properties.distinguishedname

            if ($distinguishedName -notlike "*Domain Controllers*")
            {
                $osRole = "Member Server"
            }
            else
            {
                $osRole = "Domain Controller"
            }
            break
        }
        "*Windows 10*"  { $osRole = "Workstation";break}
        $null           { $osRole = "None"}
    }

    $assetElements = [ordered] @{
        'ROLE'            = "$osRole"
        'ASSET_TYPE'      = 'Computing'
        'HOST_NAME'       = "$Hostname"
        'HOST_IP'         = "$IPAddress"
        'HOST_MAC'        = "$MACAddress"
        'HOST_FQDN'       = "$FQDN"
        'TECH_AREA'       = ''
        'TARGET_KEY'      = '2350'
        'WEB_OR_DATABASE' = 'false'
        'WEB_DB_SITE'     = ''
        'WEB_DB_INSTANCE' = ''
    }

    foreach ($assetElement in $assetElements.GetEnumerator())
    {
        $writer.WriteStartElement($assetElement.name)
        $writer.WriteString($assetElement.value)
        $writer.WriteEndElement()
    }

    $writer.WriteEndElement(<#ASSET#>)

    #endregion ASSET

    $writer.WriteStartElement("STIGS")
    $writer.WriteStartElement("iSTIG")

    #region STIGS/iSTIG/STIG_INFO

    $writer.WriteStartElement("STIG_INFO")

    $xccdfBenchmarkContent = Get-StigXccdfBenchmarkContent -Path $xccdfPath

    $stigInfoElements = [ordered] @{
        'version'        = $xccdfBenchmarkContent.version
        'classification' = "$Enclave"
        'customname'     = ''
        'stigid'         = $xccdfBenchmarkContent.id
        'description'    = $xccdfBenchmarkContent.description
        'filename'       = Split-Path -Path $xccdfPath -Leaf
        'releaseinfo'    = $xccdfBenchmarkContent.'plain-text'.InnerText
        'title'          = $xccdfBenchmarkContent.title
        'uuid'           = (New-Guid).Guid
        'notice'         = $xccdfBenchmarkContent.notice.InnerText
        'source'         = $xccdfBenchmarkContent.reference.source
    }

    foreach ($StigInfoElement in $stigInfoElements.GetEnumerator())
    {
        $writer.WriteStartElement("SI_DATA")

        $writer.WriteStartElement('SID_NAME')
        $writer.WriteString($StigInfoElement.name)
        $writer.WriteEndElement(<#SID_NAME#>)

        $writer.WriteStartElement('SID_DATA')
        $writer.WriteString($StigInfoElement.value)
        $writer.WriteEndElement(<#SID_DATA#>)

        $writer.WriteEndElement(<#SI_DATA#>)
    }

    $writer.WriteEndElement(<#STIG_INFO#>)

    #endregion STIGS/iSTIG/STIG_INFO

    #region STIGS/iSTIG/VULN[]

    # Pull in the processed XML file to check for duplicate rules for each vulnerability
    [xml]$xccdfBenchmark = Get-Content -Path $xccdfPath -Encoding UTF8
    $fileList = Get-PowerStigFileList -StigDetails $xccdfBenchmark
    if ($XccfdPath -like "*2016*")
    {
        $processedFolder    = "C:\Program Files\WindowsPowerShell\Modules\PowerSTIG\4.5.1\StigData\Processed"
        $processedXccdfs    = (Get-ChildItem $processedFolder | Where { $_.name -like "*WindowsServer*2016*MS*xml"}).name
        $latestVersion      = ($Versions | Measure-Object -Maximum ).maximum
        $processedFile      = (Resolve-Path "$processedFolder\$($processedXccdfs | Where { $_ -like "*$latestVersion*" })").path
    }
    else
    {
        $processedFileName = $fileList.Settings.FullName
    }
    #[xml]$processed = Get-Content -Path $processedFileName
    $vulnerabilities = Get-VulnerabilityList -XccdfBenchmark $xccdfBenchmarkContent

    foreach ($vulnerability in $vulnerabilities)
    {
        $writer.WriteStartElement("VULN")

        foreach ($attribute in $vulnerability.GetEnumerator())
        {
            $status         = $null
            $findingDetails = $null
            $comments       = $null
            $manualCheck    = $null

            if ($attribute.Name -eq 'Vuln_Num')
            {
                $vid = $attribute.Value
            }

            $writer.WriteStartElement("STIG_DATA")
            $writer.WriteStartElement("VULN_ATTRIBUTE")
            $writer.WriteString($attribute.Name)
            $writer.WriteEndElement(<#VULN_ATTRIBUTE#>)
            $writer.WriteStartElement("ATTRIBUTE_DATA")
            $writer.WriteString($attribute.Value)
            $writer.WriteEndElement(<#ATTRIBUTE_DATA#>)
            $writer.WriteEndElement(<#STIG_DATA#>)
        }

        $statusMap = @{
            NotReviewed   = 'Not_Reviewed'
            Open          = 'Open'
            NotAFinding   = 'NotAFinding'
            NotApplicable = 'Not_Applicable'
        }

        $manualCheck = $manualCheckData | Where-Object -FilterScript {$_.VulID -eq $VID}

        if ($PSCmdlet.ParameterSetName -eq 'nomof')
        {
            $status         = $statusMap["$($manualCheck.Status)"]
            $findingDetails = $manualCheck.Details
            $comments       = $manualCheck.Comments
        }
        else
        {
            if ($PSCmdlet.ParameterSetName -eq 'result')
            {
                $manualCheck = $manualCheckData | Where-Object -FilterScript {$_.VulID -eq $VID}

                if ($manualCheck)
                {
                    $status = $statusMap["$($manualCheck.Status)"]
                    $findingDetails = $manualCheck.Details
                    $comments = $manualCheck.Comments
                }
                else
                {
                    $setting = Get-SettingsFromResult -DscResult $dscResult -Id $vid

                    if ($setting)
                    {
                        if ($setting.InDesiredState -eq $true)
                        {
                            $status = $statusMap['NotAFinding']
                            $comments = "Addressed by PowerStig MOF via $setting"
                            $findingDetails = Get-FindingDetails -Setting $setting
                        }
                        elseif ($setting.InDesiredState -eq $false)
                        {
                            $status = $statusMap['Open']
                            $comments = "Configuration attempted by PowerStig MOF via $setting, but not currently set."
                            $findingDetails = Get-FindingDetails -Setting $setting
                        }
                        else
                        {
                            $status = $statusMap['Open']
                        }
                    }
                    else
                    {
                        $status = $statusMap['NotReviewed']
                    }
                }
            }
            else
            {

                if ($PSCmdlet.ParameterSetName -eq 'mof')
                {
                    $setting = Get-SettingsFromMof -ReferenceConfiguration $referenceConfiguration -Id $vid
                }

                $manualCheck = $manualCheckData | Where-Object {$_.VulID -eq $VID}

                if ($setting)
                {
                    $status = $statusMap['NotAFinding']
                    $comments = "To be addressed by PowerStig MOF via $setting"
                    $findingDetails = Get-FindingDetails -Setting $setting

                }
                elseif ($manualCheck)
                {
                    $status = $statusMap["$($manualCheck.Status)"]
                    $findingDetails = $manualCheck.Details
                    $comments = $manualCheck.Comments
                }
                else
                {
                    $status = $statusMap['NotReviewed']
                }
            }

            # Test to see if this rule is managed as a duplicate
            try {$convertedRule = $processed.SelectSingleNode("//Rule[@id='$vid']")}
            catch { }

            if ($convertedRule.DuplicateOf)
            {
                # How is the duplicate rule handled? If it is handled, then this duplicate is also covered
                if ($PSCmdlet.ParameterSetName -eq 'mof')
                {
                    $originalSetting = Get-SettingsFromMof -ReferenceConfiguration $referenceConfiguration -Id $convertedRule.DuplicateOf

                    if ($originalSetting)
                    {
                        $status = $statusMap['NotAFinding']
                        $findingDetails = 'See ' + $convertedRule.DuplicateOf + ' for Finding Details.'
                        $comments = 'Managed via PowerStigDsc - this rule is a duplicate of ' + $convertedRule.DuplicateOf
                    }
                }
                elseif ($PSCmdlet.ParameterSetName -eq 'result')
                {
                    $originalSetting = Get-SettingsFromResult -DscResult $dscResult -id $convertedRule.DuplicateOf

                    if ($originalSetting.InDesiredState -eq 'True')
                    {
                        $status = $statusMap['NotAFinding']
                        $findingDetails = 'See ' + $convertedRule.DuplicateOf + ' for Finding Details.'
                        $comments = 'Managed via PowerStigDsc - this rule is a duplicate of ' + $convertedRule.DuplicateOf
                    }
                    else
                    {
                        $status = $statusMap['Open']
                        $findingDetails = 'See ' + $convertedRule.DuplicateOf + ' for Finding Details.'
                        $comments = 'Managed via PowerStigDsc - this rule is a duplicate of ' + $convertedRule.DuplicateOf
                    }
                }
            }
        }

        if ($null -eq $status)
        {
            $status   = 'Not_Reviewed'
            $Comments = "Error gathering comments"
        }

        $writer.WriteStartElement("STATUS")
        $writer.WriteString($status)
        $writer.WriteEndElement(<#STATUS#>)
        $writer.WriteStartElement("FINDING_DETAILS")
        $writer.WriteString($findingDetails)
        $writer.WriteEndElement(<#FINDING_DETAILS#>)
        $writer.WriteStartElement("COMMENTS")
        $writer.WriteString($comments)
        $writer.WriteEndElement(<#COMMENTS#>)
        $writer.WriteStartElement("SEVERITY_OVERRIDE")
        $writer.WriteString('')
        $writer.WriteEndElement(<#SEVERITY_OVERRIDE#>)
        $writer.WriteStartElement("SEVERITY_JUSTIFICATION")
        $writer.WriteString('')
        $writer.WriteEndElement(<#SEVERITY_JUSTIFICATION#>)
        $writer.WriteEndElement(<#VULN#>)
    }

    #endregion STIGS/iSTIG/VULN[]

    $writer.WriteEndElement(<#iSTIG#>)
    $writer.WriteEndElement(<#STIGS#>)
    $writer.WriteEndElement(<#CHECKLIST#>)
    $writer.Flush()
    $writer.Close()
}

function Get-VulnerabilityList
{
    <#
    .SYNOPSIS
        Gets the vulnerability details from the rule description
    #>

    [CmdletBinding()]
    [OutputType([xml])]
    param
    (
        [Parameter()]
        [psobject]
        $XccdfBenchmark
    )

    [System.Collections.ArrayList] $vulnerabilityList = @()

    foreach ($vulnerability in $XccdfBenchmark.Group)
    {
        [xml]$vulnerabiltyDiscussionElement = "<discussionroot>$($vulnerability.Rule.description)</discussionroot>"

        [void] $vulnerabilityList.Add(
            @(
                [PSCustomObject]@{Name = 'Vuln_Num'; Value = $vulnerability.id},
                [PSCustomObject]@{Name = 'Severity'; Value = $vulnerability.Rule.severity},
                [PSCustomObject]@{Name = 'Group_Title'; Value = $vulnerability.title},
                [PSCustomObject]@{Name = 'Rule_ID'; Value = $vulnerability.Rule.id},
                [PSCustomObject]@{Name = 'Rule_Ver'; Value = $vulnerability.Rule.version},
                [PSCustomObject]@{Name = 'Rule_Title'; Value = $vulnerability.Rule.title},
                [PSCustomObject]@{Name = 'Vuln_Discuss'; Value = $vulnerabiltyDiscussionElement.discussionroot.VulnDiscussion},
                [PSCustomObject]@{Name = 'IA_Controls'; Value = $vulnerabiltyDiscussionElement.discussionroot.IAControls},
                [PSCustomObject]@{Name = 'Check_Content'; Value = $vulnerability.Rule.check.'check-content'},
                [PSCustomObject]@{Name = 'Fix_Text'; Value = $vulnerability.Rule.fixtext.InnerText},
                [PSCustomObject]@{Name = 'False_Positives'; Value = $vulnerabiltyDiscussionElement.discussionroot.FalsePositives},
                [PSCustomObject]@{Name = 'False_Negatives'; Value = $vulnerabiltyDiscussionElement.discussionroot.FalseNegatives},
                [PSCustomObject]@{Name = 'Documentable'; Value = $vulnerabiltyDiscussionElement.discussionroot.Documentable},
                [PSCustomObject]@{Name = 'Mitigations'; Value = $vulnerabiltyDiscussionElement.discussionroot.Mitigations},
                [PSCustomObject]@{Name = 'Potential_Impact'; Value = $vulnerabiltyDiscussionElement.discussionroot.PotentialImpacts},
                [PSCustomObject]@{Name = 'Third_Party_Tools'; Value = $vulnerabiltyDiscussionElement.discussionroot.ThirdPartyTools},
                [PSCustomObject]@{Name = 'Mitigation_Control'; Value = $vulnerabiltyDiscussionElement.discussionroot.MitigationControl},
                [PSCustomObject]@{Name = 'Responsibility'; Value = $vulnerabiltyDiscussionElement.discussionroot.Responsibility},
                [PSCustomObject]@{Name = 'Security_Override_Guidance'; Value = $vulnerabiltyDiscussionElement.discussionroot.SeverityOverrideGuidance},
                [PSCustomObject]@{Name = 'Check_Content_Ref'; Value = $vulnerability.Rule.check.'check-content-ref'.href},
                [PSCustomObject]@{Name = 'Weight'; Value = $vulnerability.Rule.Weight},
                [PSCustomObject]@{Name = 'Class'; Value = 'Unclass'},
                [PSCustomObject]@{Name = 'STIGRef'; Value = "$($XccdfBenchmark.title) :: $($XccdfBenchmark.'plain-text'.InnerText)"},
                [PSCustomObject]@{Name = 'TargetKey'; Value = $vulnerability.Rule.reference.identifier}

                # Some Stigs have multiple Control Correlation Identifiers (CCI)
                $(
                    # Extract only the cci entries
                    $CCIREFList = $vulnerability.Rule.ident |
                    Where-Object {$PSItem.system -eq 'http://iase.disa.mil/cci'} |
                    Select-Object 'InnerText' -ExpandProperty 'InnerText'

                    foreach ($CCIREF in $CCIREFList)
                    {
                        [PSCustomObject]@{Name = 'CCI_REF'; Value = $CCIREF}
                    }
                )
            )
        )
    }

    return $vulnerabilityList
}

function Get-MofContent
{
    <#
    .SYNOPSIS
        Converts the mof into an array of objects
    #>

    [CmdletBinding()]
    [OutputType([psobject])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $ReferenceConfiguration
    )

    if (-not $script:mofContent)
    {
        $script:mofContent = [Microsoft.PowerShell.DesiredStateConfiguration.Internal.DscClassCache]::ImportInstances($referenceConfiguration, 4)
    }

    return $script:mofContent
}

function Get-SettingsFromMof
{
    <#
    .SYNOPSIS
        Gets the stig details from the mof
    #>

    [CmdletBinding()]
    [OutputType([psobject])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $ReferenceConfiguration,

        [Parameter(Mandatory = $true)]
        [string]
        $Id
    )

    $mofContent = Get-MofContent -ReferenceConfiguration $referenceConfiguration
    $mofContentFound = $mofContent.Where({$PSItem.ResourceID -match $Id})
    return $mofContentFound
}

function Get-SettingsFromResult
{
    <#
    .SYNOPSIS
        Gets the stig details from the Test\Get-DscConfiguration output
    #>

    [CmdletBinding()]
    [OutputType([psobject])]
    param
    (
        [Parameter(Mandatory = $true)]
        [psobject]
        $DscResult,

        [Parameter(Mandatory = $true)]
        [string]
        $Id
    )

    $allResources = $dscResult.ResourcesNotInDesiredState + $dscResult.ResourcesInDesiredState
    return $allResources.Where({$PSItem.ResourceID -match $id})
}

function Get-FindingDetails
{
    <#
    .SYNOPSIS
        Gets the value from a STIG setting
    #>

    [OutputType([string])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [AllowNull()]
        [psobject]
        $Setting
    )

    switch ($setting.ResourceID)
    {
        # Only add custom entries if specific output is more valuable than dumping all properties
        {$PSItem -match "^\[None\]"}
        {
            return "No DSC resource was leveraged for this rule (Resource=None)"
        }
        {$PSItem -match "^\[(x)?Registry\]"}
        {
            return "Registry Value = $($setting.ValueData)"
        }
        {$PSItem -match "^\[UserRightsAssignment\]"}
        {
            return "UserRightsAssignment Identity = $($setting.Identity)"
        }
        default
        {
            return Get-FindingDetailsString -Setting $setting
        }
    }
}


function Get-FindingDetailsString
{
    <#

    .SYNOPSIS
        Formats properties and values with standard string format.

    #>

    [OutputType([string])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [AllowNull()]
        [psobject]
        $Setting
    )

    foreach ($property in $setting.PSobject.properties) {
        if ($property.TypeNameOfValue -Match 'String')
        {
            $returnString += $($property.Name) + ' = '
            $returnString += $($setting.PSobject.properties[$property.Name].Value) + "`n"
        }
    }
    return $returnString
}

function Get-TargetNodeFromMof
{
    [OutputType([string])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [string]
        $MofString
    )

    $pattern = "((?<=@TargetNode=')(.*)(?='))"
    $TargetNodeSearch = $mofstring | Select-String -Pattern $pattern
    $TargetNode = $TargetNodeSearch.matches.value
    return $TargetNode
}

function Get-TargetNodeType
{
    [OutputType([string])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [string]
        $TargetNode
    )

    switch ($TargetNode)
    {
        # Do we have a MAC address?
        {
            $_ -match '(([0-9a-f]{2}:){5}[0-9a-f]{2})'
        }
        {
            return 'MACAddress'
        }

        # Do we have an IPv6 address?
        {
            $_ -match '(([0-9a-f]{0,4}:){7}[0-9a-f]{0,4})'
        }
        {
            return 'IPv4Address'
        }

        # Do we have an IPv4 address?
        {
            $_ -match '(([0-9]{1,3}\.){3}[0-9]{1,3})'
        }
        {
            return 'IPv6Address'
        }

        # Do we have a Fully-qualified Domain Name?
        {
            $_ -match '([a-zA-Z0-9-.\+]{2,256}\.[a-z]{2,256}\b)'
        }
        {
            return 'FQDN'
        }
    }

    return ''
}

function Get-StigXccdfBenchmarkContent
{
    [CmdletBinding()]
    [OutputType([xml])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    if (-not (Test-Path -Path $path))
    {
        Throw "The file $path was not found"
    }

    if ($path -like "*.zip")
    {
        [xml] $xccdfXmlContent = Get-StigContentFromZip -Path $path
    }
    else
    {
        [xml] $xccdfXmlContent = Get-Content -Path $path -Encoding UTF8
    }

    $xccdfXmlContent.Benchmark
}
