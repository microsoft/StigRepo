function Initialize-StigRepo
{
    <#

    .SYNOPSIS
    Initalizes/builds the Stig Compliance Automation Repository (SCAR). 
    Creates repository folders, installs latest dependent module versions, and generates StigData files required
    for SCAR functionality.

    .PARAMETER RootPath
    Path to the root of the SCAR repository/codebase.

    .EXAMPLE
    Build the STIG Compliance Automation Repository within a specified folderpath
    Initialize-StigRepo -RootPath "C:\StigRepo"

    #>

    [CmdletBinding()]
    param
    (
        [Parameter()]
        [string]
        $RootPath
    )

    if ('' -eq $RootPath)
    {
        $currentLocation = (Get-Location).Path
        $prompt = Read-Host -Prompt "The `$RootPath Parameter was not provided.`n`tCurrent Location: $currentLocation`n`tDo you want to build the STIG Repository in this location? Y/N"

        if ($prompt -like "y*")
        {
            $RootPath = (Get-Location).Path
        }
        else 
        {
            Write-Output "`nRepository Initialization Cancelled."
            return
        }
    }

    Write-Output "Beginning StigRepo Build"
    Write-Output "`tBuilding Repository Folder Structure"

    # Systems Folder
    $systemsPath    = New-Item -Path "$RootPath\Systems" -ItemType Directory -Force
    $stagingPath    = New-Item -Path "$SystemsPath\Staging" -ItemType Directory -Force
    $keepFile       = New-Item -Path "$SystemsPath\Staging\.keep" -ItemType File -Force

    # Configurations Folder
    $configPath     = New-Item -Path "$RootPath\Configurations" -ItemType Directory -Force
    
    # Artifacts Folder
    $artifactPath   = New-Item -Path "$RootPath\Artifacts" -ItemType Directory -Force
    $dscConfigPath  = New-Item -Path "$artifactPath\DscConfigs" -ItemType Directory -Force
    $mofPath        = New-Item -Path "$artifactPath\Mofs" -ItemType Directory -Force
    $cklPath        = New-Item -Path "$artifactPath\Stig Checklists" -ItemType Directory -Force
    
    # Add .keep files to empty folders
    $null = New-Item -Path "$mofPath\.keep" -ItemType File -Force
    $null = New-Item -Path "$cklPath\.keep" -ItemType File -Force
    $null = New-Item -Path "$dscConfigPath\.keep" -ItemType File -Force
    $null = New-Item -Path "$SystemsPath\Staging\.keep" -ItemType File -Force

    # Resources Folder
    $resourcePath   = New-Item -Path "$RootPath\Resources" -ItemType Directory -Force
    $modulePath     = New-Item -Path "$resourcePath\Modules" -ItemType Directory -Force
    $stigDataPath   = New-Item -Path "$resourcePath\Stig Data" -ItemType Directory -Force
    $xccdfPath      = New-Item -Path "$stigDataPath\Xccdfs" -ItemType Directory -Force
    $orgSettingPath = New-Item -Path "$stigDataPath\Organizational Settings" -ItemType Directory -Force
    $mancheckPath   = New-Item -Path "$stigDataPath\Manual Checks" -ItemType Directory -Force
    $wikiPath       = New-Item -Path "$resourcePath\Wiki" -ItemType Directory -Force

    Write-Output "`tExtracting Resource Files"
    
    try
    {
        $moduleRoot = Split-Path -Path (Get-Module StigRepo).Path -Parent
        $configZip = "$moduleRoot\Resources\Configurations.zip"
        $wikiZip   = "$moduleRoot\Resources\wiki.zip"
        Expand-Archive $configZip -DestinationPath $RootPath -force
        Expand-Archive $wikiZip -DestinationPath $ResourcePath -force
    }
    catch
    {
        Write-Output "The StigRepo Module is not imported. Please re-import the module and try again."
        return
    }

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

    <#

    .SYNOPSIS
    Updates an existing/established Stig Compliance Automation Repository (SCAR).
    Downloads/installs the latest dependent module versions
    Creates a backup of existing StigData files and generates new files from the lastest version of the PowerSTIG module

    .PARAMETER RootPath
    Path to the root of the SCAR repository/codebase.

    .PARAMETER SkipStigRepoModule
    Skips downloading/updating the StigRepo module

    .PARAMETER SkipPowerStigModules
    Skips downloading/updating PowerSTIG and dependent modules

    .EXAMPLE

    Update the STIG Compliance Automation Repository in the current filepath
    Update-StigRepo

    .EXAMPLE

    Update the STIG Compliance Automation Repository within a specified folderpath
    Initialize-StigRepo -RootPath "C:\StigRepo"

    #>

    [CmdletBinding()]
    param
    (
        [Parameter()]
        [string]
        $RootPath = (Get-Location).Path,

        [Parameter()]
        [switch]
        $RemoveBackup,

        [Parameter()]
        [switch]
        $SkipStigRepoModule,

        [Parameter()]
        [switch]
        $SkipPowerSTIGModules

    )

    Write-Output "Beginning StigRepo Update"
    
    $stigDataPath   = (Resolve-Path -Path "$RootPath\Resources\Stig Data").Path
    $modulePath     = (Resolve-Path -Path "$RootPath\Resources\Modules" -erroraction Stop).Path
    $modules        = Get-Childitem $ModulePath

    # Update Dependent Modules
    Write-Output "`tUpdating Powershell Module Dependencies"
    foreach ($module in $modules)
    {
        Write-Verbose "`t`tRemoving $($module.name)"
        Remove-Item $module.fullname -force -Recurse -Confirm:$false
    }

    if (-not ($SkipStigRepoModule))
    {
        Write-Verbose "`t`tUpdating StigRepo Module"
        try
        {
            if ($verbose)
            {
                Save-Module StigRepo -Path $ModulePath -Verbose
            }
            else 
            {
                Save-Module StigRepo -Path $ModulePath
            }
        }
        catch
        {
            Write-Host -ForegroundColor Red "`t`tUnable to install StigRepo Module from the PS Gallery"
            throw $_
        }
    }

    if (-not ($SkipPowerSTIGModules))
    {
        Write-Output "`t`tUpdating PowerSTIG Module and Dependencies"
        try
        {
            if ($verbose)
            {
                Save-Module PowerSTIG -Path $ModulePath -Verbose
            }
            else 
            {
                Save-Module PowerSTIG -Path $ModulePath
            }
        }
        catch
        {
            Write-Host -ForegroundColor Red "`t`tUnable to install StigRepo Module from the PS Gallery."
            throw $_
        }
    }

    #endregion Update Dependent Modules

    #region Update STIG Data Files

    Write-Output "`tUpdating STIG Data Files"

    # Backup STIG Data Folder
    Write-Output "`t`tBacking up current STIG Data"

    $resourcePath = Split-Path $StigDataPath -Parent
    $backupPath   = "$resourcePath\Stig Data-Backup"
    Copy-Item $stigDataPath -Destination $backupPath -Force -Recurse

    # Update Xccdfs
    Write-Output "`t`tUpdating STIG XCCDF Files"
    Get-Item "$StigDataPath\Xccdfs" | Remove-Item -Recurse -Force -Confirm:$false
    $currentXccdfFolders    = Get-Childitem "$StigDataPath-Backup\Xccdfs\*" -Directory
    $newXccdfPath           = New-Item -ItemType Directory -Path $StigDataPath -Name "Xccdfs" -Force -Confirm:$false
    $newXccdfFolders        = Get-Childitem "$ModulePath\PowerSTIG\*\StigData\Archive\*" -Directory
    $newXccdfFolders        | Copy-Item -Destination "$StigDataPath\Xccdfs" -Force -Recurse -Confirm:$false
    $customxccdfs           = $currentXccdfFolders | where { ((Compare-Object -ReferenceObject $currentXccdfFolders.name -DifferenceObject $newXccdfFolders.name).inputobject) -contains $_.name }
    $customXccdfs.FullName  | Copy-Item -Destination $newXccdfPath -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue

    # Update Org Settings
    Write-Output "`t`tUpdating Organizational Setting Files"
    Get-Item "$StigDataPath\Organizational Settings" | Remove-Item -Recurse -Force -Confirm:$false
    $currentOrgSettings = Get-Childitem "$StigDataPath-Backup\Organizational Settings\*org.default.xml"
    $null               = New-Item -ItemType Directory -Path $StigDataPath -Name "Organizational Settings" -Force -Confirm:$false
    $newOrgSettings     = Get-Childitem "$ModulePath\PowerSTIG\*\StigData\Processed\*.org.default.xml"
    $newOrgSettings | Copy-Item -Destination "$StigDataPath\Organizational Settings" -Force -Confirm:$false

    # Manual Checks
    Write-Output "`t`tUpdating Manual Check Files"

    $powerStigXccdfPath     = (Resolve-Path "$modulePath\PowerStig\*\StigData\Archive").Path
    $powerStigProcessedPath = (Resolve-Path "$ModulePath\PowerSTIG\*\StigData\Processed").Path
    $xccdfs                 = Get-Childitem "$powerStigXccdfPath\*.xml" -recurse
    $processedXccdfs        = Get-Childitem "$powerStigProcessedPath\*.xml" -recurse | where {$_.name -notlike "*org.default*"}
    $newManualCheckPath     = New-Item -ItemType Directory -Path "$StigDataPath\Manual Checks" -Force -Confirm:$False
    $oldManualCheckPath     = (Resolve-Path "$StigDataPath-Backup\Manual Checks").Path
    $currentManualChecks    = Get-ChildItem -Path $oldManualCheckPath
    $currentManualChecks | Copy-Item -Destination $newManualCheckPath -Force -Recurse -Confirm:$false

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

        [xml]$xccdfcontent  = Get-Content $xccdf.FullName -Encoding UTF8
        $manualRules        = $xccdfContent.DisaStig.ManualRule.Rule.id
        $manualCheckContent = New-Object System.Collections.ArrayList
        $manualCheckFolder  = "$StigDataPath\Manual Checks\$xccdfFolderName"
        $stigVersion        = $xccdf.basename.split("-") | Select -last 1

        if (-not(Test-Path $manualCheckFolder))
        {
            $null = New-Item -ItemType Directory -Path $manualCheckFolder
        }
        $manualCheckFilePath = "$manualCheckFolder\$($xccdfContent.DisaStig.StigId)-$stigVersion-manualChecks.psd1"

        if ($null -ne $manualRules)
        {
            Write-Verbose "`t`t`tGenerating Manual Check file for $($xccdf.Name)"
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
            Write-Verbose "`t`t`tGenerating Manual Check file for $($xccdf.Name)"
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

    .PARAMETER SyncModules
    Executes the Sync-DscModules cmdlet and sync modules/versions with what is in the "5. resouces\Modules" folder of
    SCAR.

    .PARAMETER CompressArtifacts
    Switch parameter that archives the artifacts produced by SCAR. This switch compresses the artifacts and
    places them in the archive folder.

    .PARAMETER CleanBuild
    Switch parameter that removes files from the MOFs and Artifacts folders to create a clean slate for the SCAR build.

    .PARAMETER SystemFiles
    Allows users to provide an array of configdata files to target outside of the Systems folder.

    .PARAMETER ImportModules
    Imports Required/Dependent Modules - Modules must be synced for proper functionality.

    .EXAMPLE
    Start-DscBuild -RootPath "C:\DSC Management" -CleanBuild -PreRequisites

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
        [string]
        $ComputerName,
        
        [Parameter()]
        [switch]
        $SyncModules,

        [Parameter()]
        [switch]
        $CompressArtifacts,

        [Parameter()]
        [switch]
        $CleanBuild,

        [Parameter()]
        [System.Collections.ArrayList]
        $SystemFiles,

        [Parameter()]
        [switch]
        $ImportModules
    )

    # Root Folder Paths
    try {
        $SystemsPath     = (Resolve-Path -Path "$RootPath\Systems" -ErrorAction Stop).Path
        $dscConfigPath   = (Resolve-Path -Path "$RootPath\Configurations" -ErrorAction Stop).Path
        $resourcePath    = (Resolve-Path -Path "$RootPath\Resources" -ErrorAction Stop).Path
        $artifactPath    = (Resolve-Path -Path "$RootPath\Artifacts" -ErrorAction Stop).Path
        $mofPath         = (Resolve-Path -Path "$RootPath\Artifacts\Mofs" -ErrorAction Stop).Path      
    }
    catch 
    {
        Write-Output "The provided RootPath is not not a Valid Stig Repository Location - $RootPath"
        return
    }

    # Begin Build
    Write-Output "Beginning Desired State Configuration Build Process`r`n"

    # Remove old Mofs/Artifacts
    if ($CleanBuild)
    {
        Remove-StigRepoData -RootPath $RootPath
    }

    # Validate Modules on host and target machines
    if ($SyncModules)
    {
        Sync-DscModules -Rootpath $RootPath
    }

    # Import required DSC Resource Module
    if ($ImportModules)
    {
        Import-DscModules -RootPath $RootPath
    }

    # Combine PSD1 Files
    $allNodesDataFile = "$artifactPath\DscConfigs\AllNodes.psd1"

    if ($SystemFiles.count -lt 1)
    {
        $SystemFiles = New-Object System.Collections.ArrayList
        if ('' -ne $ComputerName)
        {
            $null = Get-ChildItem -Path "$systemsPath\*.psd1" -Recurse | Where-Object { ($_.Fullname -NotLike "*Staging*") -and ($_.Fullname -Notlike "*Readme*") -and ($_.FullName -like "*$ComputerName*")} | ForEach-Object {$null = $Systemfiles.add($_)}
            Get-CombinedConfigs -RootPath $RootPath -AllNodesDataFile $allNodesDataFile -SystemFiles $SystemFiles
            Export-DynamicConfigs -SystemFiles $SystemFiles -ArtifactPath $artifactPath -DscConfigPath $dscConfigPath
            Export-Mofs -RootPath $RootPath -ComputerName $ComputerName
        }
        elseif ('' -eq $TargetFolder)
        {
            $null = Get-ChildItem -Path "$SystemsPath\*.psd1" -Recurse | Where-Object { ($_.Fullname -notmatch "Staging") -and ($_.Fullname -Notlike "Readme*")} | ForEach-Object {$null = $systemFiles.add($_)}
            Get-CombinedConfigs -RootPath $RootPath -AllNodesDataFile $allNodesDataFile -SystemFiles $SystemFiles
            Export-DynamicConfigs -SystemFiles $SystemFiles -ArtifactPath $artifactPath -DscConfigPath $dscConfigPath
            Export-Mofs -RootPath $RootPath
        }
        elseif ('' -ne $TargetFolder)
        {
            $null = Get-ChildItem -Path "$systemsPath\$TargetFolder\*.psd1" -Recurse | Where-Object { ($_.Fullname -notmatch "Staging") -and ($_.Fullname -Notlike "Readme*")} | ForEach-Object {$null = $Systemfiles.add($_)}
            Get-CombinedConfigs -RootPath $RootPath -AllNodesDataFile $allNodesDataFile -SystemFiles $SystemFiles -TargetFolder $TargetFolder
            Export-DynamicConfigs -SystemFiles $SystemFiles -ArtifactPath $artifactPath -DscConfigPath $dscConfigPath -TargetFolder $TargetFolder
            Export-Mofs -RootPath $RootPath -TargetFolder $TargetFolder
        }
    }
    else
    {
        Get-CombinedConfigs -RootPath $RootPath -AllNodesDataFile $allNodesDataFile -SystemFiles $SystemFiles
        Export-DynamicConfigs -SystemFiles $SystemFiles -ArtifactPath $artifactPath -DscConfigPath $dscConfigPath
        Export-Mofs -RootPath $RootPath
    }

    # Archive generated artifacts
    if ($CompressArtifacts)
    {
        Compress-DscArtifacts -Rootpath $RootPath
    }

    # DSC Build Complete
    Write-Output "`n`nDesired State Configuration Build complete.`n`n"
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

    try
    {
        $systemsPath    = Resolve-Path -Path "$Rootpath\*Systems"
        $artifactPath   = (Resolve-Path -Path "$Rootpath\*Artifacts" -ErrorAction Stop).Path
        if ("" -eq $AllNodesDataFile) { $AllNodesDataFile = "$artifactPath\DscConfigs\AllNodes.psd1" }
    }
    catch
    {
        Write-Output "$RootPath is not a valid repository."
        break
    }

    Write-Output "`tBeginning System Data Processing"
    if ($null -eq $SystemFiles)
    {
        if ('' -ne $targetFolder)
        {
            $systemFiles = Get-ChildItem -Path "$SystemsPath\*.psd1" -Recurse | Where-Object { ($_.Fullname -notmatch "Staging") -and ($_.Fullname -Notlike "Readme*") }
        }
        else
        {
            $systemFiles = Get-ChildItem -Path "$SystemsPath\$TargetFolder\*.psd1" -Recurse | Where-Object { ($_.Fullname -notmatch "Staging") -and ($_.Fullname -Notlike "Readme*") }
        }
    }

    foreach ($systemFile in $systemFiles)
    {
        $data = Invoke-Expression (Get-Content $systemFile.FullName | Out-String)

        if ($null -ne $data.AppliedConfigurations)
        {
            [array]$buildFiles += $systemFile
        }
    }

    if ($buildFiles.count -lt 1)
    {
        Write-Output "`t`tNo DSC configdata files were provided."
        break
    }
    else
    {
        New-Item -Path $AllNodesDataFile -ItemType File -Force | Out-Null
        $configCount = $buildFiles.count
        $iteration = 0
        "@{`n`tAllNodes = @(`n" | Out-File $AllNodesDataFile -Encoding utf8

        foreach ($buildFile in $buildFiles)
        {
            Write-Output "`t`t$($buildFile.BaseName) - Processing System Data"
            $iteration++
            $configDataContent = Get-Content -Path $buildFile.FullName -encoding UTF8
            $configDataContent | ForEach-Object -Process {
                "`t`t" + $_ | Out-file $AllNodesDataFile -Append -Encoding utf8
            }

            if (($iteration -ne $configCount) -and ($counfigCount -ne 1))
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

    Write-Output "`n`tStarting DSC Compilation"
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
            Write-Output "`t`t$($SystemFile.basename) - Starting DSC Compilation Job"

            $job = Start-Job -Scriptblock {
                try
                {
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
                    }
                    Write-Output "`t$nodeName configuration file successfully generated.`r`n"
                }
                catch
                {
                    Write-Warning "`t$nodeName configuration file failed.`r`n"
                    throw $_
                }
            }
        }
        $null = $jobs.add($job.Id)
    }
    Write-Output "`n`tDSC Compilation job(s) started. Checking status every 30 seconds and output will be displayed once complete."
    do
    {
        $completedJobs  = (Get-Job -ID $jobs | where {$_.state -ne "Running"}).count
        $runningjobs    = (Get-Job -ID $jobs | where {$_.state -eq "Running"}).count
        Write-Output "`t`tCompilation Job Status:`t$runningJobs Jobs Currently Processing`t$completedJobs/$($jobs.count) Jobs Completed"
        Start-Sleep -Seconds 30
    }
    while ((Get-Job -ID $jobs).State -contains "Running")
    Write-Output "`n`t`tCompilation jobs completed. Receiving job output"
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
        [string]
        $ComputerName,

        [Parameter()]
        [System.Collections.ArrayList]
        $SystemFiles

    )

    Write-Output "`tStarting jobs to generate Managed Object Files."
    $mofPath            = (Resolve-Path -Path "$RootPath\*Artifacts\Mofs").Path
    $dscConfigPath      = (Resolve-Path -Path "$RootPath\*Artifacts\DscConfigs").Path
    $allNodesDataFile   = (Resolve-Path -Path "$dscConfigPath\Allnodes.psd1").path
    $dscNodeConfigs     = New-Object System.Collections.ArrayList
    $jobs               = New-Object System.Collections.ArrayList

    if ($SystemFiles.count -lt 1)
    {
        $SystemFiles        = New-Object System.Collections.ArrayList

        if ('' -ne $TargetFolder)
        {
            $null = Get-Childitem "$RootPath\Systems\$TargetFolder\*.psd1" -Recurse | Where-Object fullname -notlike "*staging*" | ForEach-Object {$null = $SystemFiles.add($_)}
        }
        elseif ('' -ne $ComputerName)
        {
            $null = Get-Childitem "$RootPath\Systems\*.psd1" -Recurse | Where-Object {$_.fullname -notlike "*staging*" -and $_.BaseName -eq $ComputerName} | ForEach-Object {$null = $SystemFiles.add($_)}
        }
        else
        {
            $null = Get-Childitem "$RootPath\Systems\*.psd1" -Recurse | Where-Object fullname -notlike "*staging*" | ForEach-Object {$null = $SystemFiles.add($_)}
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
        $systemFile     = (Resolve-Path -Path "$RootPath\Systems\*\$nodeName.psd1").Path
        $data           = Invoke-Expression (Get-Content $SystemFile | Out-String)

        if ($null -ne $data.AppliedConfigurations)
        {
            Write-Output "`t`t$($nodeConfig.BaseName) - Generating Managed Object File(s)"

            try
            {

                $job = Start-Job -Scriptblock {

                    $nodeConfig         = $using:nodeConfig
                    $nodeName           = $using:nodeName
                    $allNodesDataFile   = $using:allNodesDataFile
                    $mofPath            = $using:mofPath
                    $configPath         = $using:ConfigPath
                    $data               = $using:data
                    # Execute each file into memory
                    . "$configPath"

                    # Execute each configuration with the corresponding data file
                    try
                    {
                        $null = MainConfig -ConfigurationData $allNodesDataFile -OutputPath $mofPath -ErrorAction Stop 3> $null
                        Write-Output "`t`tMOF Generated for $nodeName"

                    }
                    catch
                    {
                        Write-Output "MOF Generation Failed for $nodeName"
                    }
                    # Execute each Meta Configuration with the corresponding data file
                    if ($null -ne $data.LocalConfigurationManager)
                    {
                        try
                        {
                            $null = LocalConfigurationManager -ConfigurationData $allNodesDataFile -Outputpath $mofPath -Erroraction Stop 3> $null
                            Write-Output "`t`tLocalConfigurationManager MOF Generated for $nodeName"
                        }
                        catch
                        {
                            Write-Output "LocalConfigurationManager Generation Failed for $nodeName"
                        }
                    }
                }
                $null = $jobs.add($job.id)
            }
            catch
            {
                Throw "Error occured executing $SystemFile to generate MOF.`n $($_)"
            }
        }
    }
    
    Write-Output "`n`tMOF Export Job(s) are currently running. Checking status every 30 seconds and output will be displayed once complete."
    
    do
    {
        $completedJobs  = (Get-Job -ID $jobs | where {$_.state -ne "Running"}).count
        $runningjobs    = (Get-Job -ID $jobs | where {$_.state -eq "Running"}).count
        Write-Output "`t`tMOF export Job Status:`t$runningJobs Jobs Currently Processing`t$completedJobs/$($jobs.count) Jobs Completed"
        Start-Sleep -Seconds 30
    }
    while ((Get-Job -ID $jobs).State -contains "Running")
    Write-Output "`n`t$($jobs.count) MOF Export Job(s) completed. Receiving job output"
    Get-Job -ID $jobs | Wait-Job | Receive-Job
}

function Remove-StigRepoData
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
    Remove-StigRepoData -Rootpath "C:\SCAR"

    #>

    [cmdletBinding()]
    param (

        [Parameter()]
        [string]
        $RootPath = (Get-Location).Path

    )

    Write-Host "Starting StigRepo Cleanup"

    try
    {
        $artifactPath   = (Resolve-Path "$RootPath\Artifacts" -ErrorAction 'Stop').Path
        $mofPath        = (Resolve-Path "$ArtifactPath\Mofs" -ErrorAction 'Stop').Path
        $cklPath        = (Resolve-Path "$ArtifactPath\STIG Checklists" -ErrorAction 'Stop').Path
        $dscConfigPath  = (Resolve-Path "$ArtifactPath\DscConfigs" -ErrorAction 'Stop').Path
        $systemsPath    = (Resolve-Path "$RootPath\Systems" -ErrorAction 'Stop').Path
    }
    catch
    {
        Write-Output "`t$RootPath is not a valid Stig Compliance Automation Repository."
        return
    }

    Write-Output "`tGathing StigRepo Files to remove"
    $mofs           = Get-Childitem -Path "$MofPath\*.mof" -Recurse
    $dscConfigs     = Get-Childitem -Path "$dscConfigPath\*.ps1" -Recurse
    $checklists     = Get-Childitem -Path "$cklPath\*.ckl" -Recurse
    $SystemFiles    = Get-Childitem -Path "$SystemsPath\" -Recurse | Where {$_.name -notlike "*.keep*"}

    Write-Output "`tAdding Files to removal array."
    $removeItems = New-Item System.Collections.Arraylist
    $mofs        | ForEach-Object { $removeItems.Add($_.FullName) }
    $dscConfigs  | ForEach-Object { $removeItems.Add($_.FullName) }
    $checklists  | ForEach-Object { $removeItems.Add($_.FullName) }
    $systemFiles | ForEach-Object { $removeItems.Add($_.FullName) }

    Write-Output "`tRemoving files from the Stig Complaince Automation Repository."

    foreach ($item in $removeItems)
    {
        Write-Output "`t`tRemoving $($item.Name)"
        Remove-Item $item.Fullname -Confirm:$false -ErrorAction SilentlyContinue
    }
    Write-Output "`r`nStig Repo cleanup complete."
}

function Compress-StigRepoArtifacts
{
    <#

    .SYNOPSIS
    Compresses the artifacts folder of the StigRepo. Resulting Zip file will also be stored in artifacts.

    .PARAMETER RootPath
    Path to the root of the SCAR repository/codebase.

    .EXAMPLE

    Compress-StigRepoArtifacts -RootPath "C:\StigRepo"
    #>

    [cmdletbinding()]
    param(

        [Parameter()]
        [String]
        $RootPath = (Get-Location).Path

    )

    # Archive the current MOF and build files in MMddyyyy_HHmm_DSC folder format
    $artifactPath   = (Resolve-Path -Path "$Rootpath\*Artifacts").Path
    $dateStamp      = (Get-Date -format "ddMMMyyyy")

    Compress-Archive -Path $artifactPath -DestinationPath "$artifactPath\RepoArtifacts-$dateStamp.zip" -Update
}

function Import-DscModules
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

    [cmdletbinding()]
    param(

        [Parameter()]
        [String]
        $RootPath

    )

    try
    {
        $modulePath = (Resolve-Path -Path "$RootPath\Resources\Modules" -ErrorAction 'Stop')
    }
    catch
    {
        Write-Output "`t$RootPath is not a valid STIG Complaince Automation Repository"
        return
    }

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
