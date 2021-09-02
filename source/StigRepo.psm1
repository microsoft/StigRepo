# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

$FunctionScripts = Get-ChildItem -Path "$PSScriptRoot\module\*.ps1"

foreach ($File in $FunctionScripts)
{
    Write-Verbose "Loading $($File.FullName)"
    . $File.FullName
}
Export-ModuleMember -Function @(
    'Initialize-StigRepo',
    'Compress-StigRepoArtifacts',
    'Get-ManualCheckFileFromXccdf',
    'Get-StigChecklists',
    'Import-DscModules',
    'New-AzSystemData',
    'New-SystemData',
    'Publish-AzAutomationModules',
    'Publish-RepoToBlob',
    'Publish-SCARArtifacts',
    'Remove-ScarData',
    'Set-WinRMConfig',
    'Start-DscBuild',
    'Sync-DscModules',
    'Update-StigRepo',
    'Get-ApplicableStigs',
    'Import-AzDscConfigurations',
    'Register-AzAutomationNodes',
    'Export-AzDscConfigurations',
    'Remove-StigRepoData',
    'Get-StigChecklist',
    'Get-StigFiles',
    'Get-CombinedConfigs',
    'Export-DynamicConfigs',
    'Export-Mofs'
)
