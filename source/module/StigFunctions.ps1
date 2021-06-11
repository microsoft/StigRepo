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
    $SystemsPath    = (Resolve-Path -Path "$RootPath\*Systems").path
    $mofPath        = (Resolve-Path -Path "$RootPath\*Artifacts\Mofs").path
    $resourcePath   = (Resolve-Path -Path "$RootPath\*Resources").path
    $artifactsPath  = (Resolve-Path -Path "$RootPath\*Artifacts").path
    $cklContainer   = (Resolve-Path -Path "$artifactsPath\STIG Checklists").Path
    $allCkls        = @()

    # Import PowerSTIG Checklist Functions 
    try
    {
        $powerStigPath = Split-Path -Path (Get-Module PowerStig).Path -Parent
        "$powerStigPath\Module\STIG\Functions.Checklist.ps1"
    }
    catch
    {
        Write-Output "PowerSTIG Module is not imported and is required to generate STIG Checklists."
        exit
    }

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

        $job = Start-Job -Scriptblock {

            Import-Module PowerSTIG -Force
            Import-Module StigRepo -Force

            $machine            = $using:machine
            $RootPath           = $using:RootPath
            $machineFolder      = $using:machinefolder
            $SystemsPath        = $using:SystemsPath
            $mofPath            = $using:mofPath
            $resourcePath       = $using:resourcePath
            $artifactsPath      = $using:artifactsPath
            $cklContainer       = $using:cklContainer
            $SystemFile         = $using:SystemFile
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
        "*Windows 10*"  { $osRole = "Workstation" ; break }
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

function Get-StigFiles
{
    param(

    [Parameter()]
    [string]
    $RootPath = (Get-Location).Path,

    [Parameter(Mandatory=$true)]
    [string]
    $FileType,

    [Parameter(Mandatory=$true)]
    [string]
    $StigType,

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

    if (($StigType -eq "WindowsServer") -or ($StigType -eq "DomainController"))
    {
        switch -WildCard ($version)
        {
            "*2012*" {$osVersion = '2012R2'}
            "*2016*" {$osVersion = '2016'}
            "*2019*" {$osVersion = '2019'}
        }
    }

    switch ($FileType)
    {
        "Xccdf"
        {
            switch -WildCard ($StigType)
            {
                {($_ -eq "WindowsServer") -or ($_ -eq "DomainController")}
                {
                    $xccdfContainer = (Resolve-Path -Path "$xccdfArchive\Windows.Server.$osVersion").Path

                    switch -WildCard ($osVersion)
                    {
                        "*2012R2"
                        {
                            if     ($StigType -eq 'WindowsServer')    {$xccdfs = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object Name -Notlike "*DC*").Name}
                            elseif ($StigType -eq 'DomainController') {$xccdfs = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object Name -Like "*DC*").Name}
                            break
                        }
                        "*2016*" {$xccdfs = (Get-ChildItem -Path "$xccdfContainer\*$osVersion`_STIG*.xml").Name ; break }
                        "*2019*" {$xccdfs = (Get-ChildItem -Path "$xccdfContainer\*$osVersion`_STIG*.xml").Name ; break }
                    }
                    break
                }
                "WindowsClient"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\Windows.Client" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml").name
                    break
                }
                "DotNetFramework"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\DotNet" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*$Version*STIG*Manual-xccdf.xml"}).name
                     break
                }
                "InternetExplorer"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\$StigType" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*xccdf.xml"}).name
                    break
                }
                "WebServer"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\Web Server" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*$($Version.replace(".","-"))*Server*xccdf.xml"}).name
                    break
                }
                "WebSite"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\Web Server" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*$($Version.replace(".","-"))*Site*xccdf.xml"}).name
                    break
                }
                "FireFox"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\browser" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*FireFox*xccdf.xml"}).name
                    break
                }
                "Edge"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\Edge" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*edge*xccdf.xml"}).name
                    break
                }
                "Chrome"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\Chrome" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*chrome*xccdf.xml"}).name
                    break
                }
                "Adobe"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\adobe" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*adobe*xccdf.xml"}).name
                    break
                }
                "McAfee"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\$StigType" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*McAfee*xccdf.xml"}).name
                    break
                }
                "Office*"
                {
                    $officeApp          = $stigType.split('_')[1]
                    $officeVersion      = $stigType.split('_')[0].Replace('Office',"")
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\Office" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*$officeApp*.xml" | Where-Object { $_.name -like "*$officeversion*"}).name
                    break
                }
                "OracleJRE"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\$StigType" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*Oracle*JRE*$version*xccdf.xml"}).name
                    break
                }
                "WindowsDefender"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\Windows.Defender" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*Windows*Defender*xccdf.xml"}).name
                    break
                }
                "WindowsFirewall"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\Windows.Firewall" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*Windows*Firewall*xccdf.xml"}).name
                    break
                }
                "WindowsDNSServer"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\Windows.Dns" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*xccdf.xml"}).name
                    break
                }
                "SqlServerInstance"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\SQL Server" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*SQL*$Version*Instance*xccdf.xml"}).name
                    break
                }
                "SqlServerDatabase"
                {
                    $xccdfContainer     = (Resolve-Path -Path "$xccdfArchive\SQL Server" -ErrorAction SilentlyContinue).Path
                    $xccdfs             = (Get-ChildItem -Path "$xccdfContainer\*.xml" | Where-Object { $_.name -like "*SQL*$version*Database*xccdf.xml"}).name
                    break
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
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object {$_.name -like "*$osVersion*MS*.psd1"}).BaseName
                    break
                }
                "DomainController"
                {
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\Windows`.Server`.$version" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object {$_.name -like "*$version*DC*.psd1"}).basename
                    $stigVersions           = $manualCheckFiles | Select-String "(\d+)R(\d+)" -AllMatches | Foreach-Object {$_.Matches.Value}
                    $latestVersion          = ($stigVersions | Measure-Object -Maximum).Maximum
                    $manualCheckFileName    = $manualCheckFiles | Where-Object { $_ -like "*WindowsServer*$latestVersion*" }
                    $stigFilePath           = "$manualCheckContainer\$manualCheckFileName.psd1"
                    break
                }
                "WindowsClient"
                {
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\WindowsClient" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer).basename 
                    break
                }
                "DotNetFramework"
                {
                    "$manualCheckFolder\Dotnet"
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\Dotnet" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*Dot*Net*ManualChecks.psd1"}).basename 
                    break
                }
                "InternetExplorer"
                {
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\InternetExplorer" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*IE*11*ManualChecks.psd1"}).basename 
                    break
                }
                "WebServer"
                {
                    $iisVersion = $version.replace(".","-")
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\WebServer" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*$iisVersion*-ManualChecks.psd1"}).basename 
                    break
                }
                "WebSite"
                {
                    $iisVersion = $version.replace(".","-")
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\WebSite" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*$iisVersion*ManualChecks.psd1"}).basename 
                    break
                }
                "FireFox"
                {
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\FireFox" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*FireFox*ManualChecks.psd1"}).basename 
                    break
                }
                "Edge"
                {
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\Edge" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*Edge*ManualChecks.psd1"}).basename 
                    break
                }
                "Chrome"
                {
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\Chrome" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*Chrome*ManualChecks.psd1"}).basename 
                    break
                }
                "Adobe"
                {
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\adobe" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*adobe*ManualChecks.psd1"}).basename 
                    break
                }
                "McAfee"
                {
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\McAfee" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*McAfee*ManualChecks.psd1"}).basename 
                    break
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
                    break
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
                    break
                }
                "OracleJRE"
                {
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\OracleJRE" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*OracleJRE*$version*.psd1"}).basename 
                    break
                }
                "WindowsDefender"
                {
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\Windows.Defender" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*Windows*Defender*ManualChecks.psd1"}).basename 
                    break
                }
                "WindowsFirewall"
                {
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\Windows.Firewall" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*Windows*Firewall*ManualChecks.psd1"}).basename 
                    break
                }
                "WindowsDNSServer"
                {
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\Windows.Dns" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*Domain*Naming*Sytem*ManualChecks.psd1"}).basename 
                    break
                }
                "SqlServerInstance"
                {
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\SqlServer" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*SQL*$version*Database*ManualChecks.psd1"}).basename 
                    break
                }
                "SqlServerDatabase"
                {
                    $manualCheckContainer   = (Resolve-Path -Path "$manualCheckFolder\SqlServer" -ErrorAction SilentlyContinue).Path
                    $manualCheckFiles       = (Get-ChildItem -Path $manualCheckContainer | Where-Object { $_.name -like "*SQL*$version*Database*ManualChecks.psd1"}).basename 
                    break
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
                "WindowsServer"     { $orgSettingsFiles = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "$stigType-$osVersion-MS*"}).name ; break }
                "WindowsClient"     { $orgSettingsFiles = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -Like "*$StigType*" }).name ; break }
                "DotNetFramework"   { $orgSettingsFiles = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "$stigType-$version*"}).name ; break }
                "InternetExplorer"  { $orgSettingsFiles = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "$stigType-$version*"}).name ; break }
                "WebServer"         { $orgSettingsFiles = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "IISServer*$version*"}).name ; break }
                "WebSite"           { $orgSettingsFiles = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "IISSite*$version*"}).name ; break }
                "Edge"              { $orgSettingsFiles = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "*$stigType*"}).name ; break }
                "Chrome"            { $orgSettingsFiles = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "*$stigType*"}).name ; break }
                "McAfee"            { $orgSettingsFiles = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "$stigType-$version*"}).name ; break }
                "OracleJRE"         { $orgSettingsFiles = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "$stigType-$version*"}).name ; break }
                "WindowsDefender"   { $orgSettingsFiles = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "$stigType-$version*"}).name ; break }
                "WindowsFirewall"   { $orgSettingsFiles = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "*$stigType*"}).name ; break }
                "WindowsDNSServer"  { $orgSettingsFiles = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "$stigType*"}).name ; break }
                "OracleJRE"         { $orgSettingsFiles = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "$stigType-$version"}).name ; break }
                "DomainController"  { $orgSettingsFiles = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "WindowsServer-$version-DC*"}).name ; break }
                "FireFox"           { $orgSettingsFiles = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "*firefox*"}).name ; break }
                "Adobe"             { $orgSettingsFiles = (Get-ChildItem $orgSettingsFolder | Where-Object { $_.name -like "$stigType-*.xml"}).name ; break }
                "Office*"
                {
                    $officeApp              = $stigType.split('_')[1]
                    $officeVersion          = $stigType.split('_')[0].replace('Office','')
                    $orgSettingsFiles       = (Get-ChildItem "$orgSettingsFolder" | Where-Object { $_.name -like "*$officeApp$officeVersion*"}).name
                    $stigVersions           = $orgSettingsFiles | Select-String "(\d+)\.(\d+)" -AllMatches | Foreach-Object {$_.Matches.Value}
                    $latestVersion          = ($stigVersions | Measure-Object -Maximum).Maximum
                    $orgSettingsFileName    = $orgSettingsFiles | Where-Object { $_ -like "*$officeApp*$officeVersion*$latestVersion*.xml"}
                    $stigFilePath           = "$orgSettingsFolder\$orgSettingsFileName"
                    break
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
                $orgSettingsFileName    = $orgSettingsFiles | Where-Object { $_ -like "*$latestVersion*.xml"}
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
