function New-AzureDevOpsAgent
{
    <#
    .SYNOPSIS
    Configures Azure DevOps Self-Hosted agent(s) for Azure Pipeline Automation  
    
    .PARAMETER AgentPath
    File Path Location where the Self-Hosted Agent(s) will be built/hosted
    Ex: "C:\PipelineAgents"  

    .PARAMETER AgentZip
    Path to the Self-Hosted Agent Zip file. The self-hosted agent zip file can be downloaded using the following path within the Azure DevOps website:
    Project Settings -> Agent Pools ->   

    .PARAMETER AgentPoolName
    Name of the Agent Pool to build the new self-hosted agents in. 

    .PARAMETER DevOpsUrl
    Website URL for your organizations Azure DevOps website

    .PARAMETER AccessToken
    Personal Access Token (PAT) to be used by the Self-Hosted DevOps Agent(s) 

    .PARAMETER AgentName
    Name/Prefix of the Self-Hosted DevOps Agent(s). A number will be added to the agent name if multiple agents are being built.

    .PARAMETER AgentCount
    Number of self-hosted agents to build. 

    .EXAMPLE
    New-ADOAgent -AgentPath "C:\BuildAgents" -AgentZip "C:\Agent.zip" -AgentPoolName "MyAgentPool" -DevOpsUrl "https://MyDevOpsServer.com/MyOrganization" -AccessToken $myAccessToken -AgentName "StigAgent" -AgentCount 5
    #>
    
    [cmdletbinding()]
    param(

        [Parameter()]
        [string]
        $AccessToken,

        [Parameter()]
        [string]
        $AgentPoolName,
        
        [Parameter()]
        [string]
        $AgentPath,
        
        [Parameter()]
        [string]
        $AgentName = "StigRepo-Agent",

        [Parameter()]
        [string]
        $DevOpsUrl,

        [Parameter()]
        [string]
        $AgentZip,
        
        [Parameter()]
        [int]
        $AgentCount = 1

    )

    if ('' -eq $DevOpsUrl)
    {
        Write-Output "Azure DevOps URL was not provided.`n`tExample: https://MyDevOpsServer.Com/MyOrganization"
        $DevOpsURL = Read-Host "`tProvide the URL of your Azure DevOps website"
        Write-Output "`n"
    }

    if ('' -eq $AgentPoolName)
    {
        Write-Output "Agent Pool Name was not provided."
        Write-Output "`tFollow the link to the Azure DevOps Wiki below for instructions on how to create an Agent Pool:"
        Write-Output "`thttps://docs.microsoft.com/en-us/azure/devops/pipelines/agents/pools-queues"
        $DevOpsURL = Read-Host "`tProvide the name of an existing Agent Pool or press `"CTRL+C`" to cancel"
        Write-Output "`n"
    }

    if ('' -eq $AccessToken)
    {
        Write-Output "Personal Access Token (PAT) must be provided. Follow the link to the Azure DevOps Wiki below for instructions on how to create a PAT:"
        Write-Output "`thttps://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate"
        $AccessToken = Read-Host "`tProvide your Personal Access Token or press `"CTRL+C`" to cancel"
        Write-Output "`n"
    }
    
    if (-not (Test-Path $AgentPath) -or '' -eq $AgentPath)
    {
        Write-Output "Agent Directory was not provided."
        $AgentPath = Read-Host "`tSpecify the Agent Path. Example `"C:\MyAgents`""
        $null = New-Item $AgentPath -ItemType Directory -Force -Confirm:$false
        Write-Output "`n"
    }

    if ('' -eq $AgentZip)
    {
        Write-Output "Azure DevOps Agent Zip File path wasn't provided."
        $prompt = Read-Host "`tDownload the Agent Zip File? (Internet Connection Required) Y/N"

        if ($prompt -like "y*")
        {
            Write-Output "`tDownloading Azure DevOps Agent Zip Package"
            $null = New-Item -ItemType "Directory" -Path "C:\StigRepo-Temp" -Force
            Invoke-WebRequest "https://vstsagentpackage.azureedge.net/agent/2.194.0/vsts-agent-win-x64-2.194.0.zip" -OutFile "$AgentPath\AzDevOpsAgent.zip"
            $AgentZip = "$AgentPath\AzDevOpsAgent.zip"
            $cleanup = $true
        }
        Write-Output "`n"
    }
    
    Write-Output "Building Azure DevOps Agents"

    foreach ($iteration in 1..$AgentCount)
    {
        Write-Output "`tBuilding $AgentName$iteration"
        $AgentFolder = New-Item "$AgentPath\$AgentName$iteration" -ItemType Directory -Force -Confirm:$false
        $null = Expand-Archive -Path $AgentZip -DestinationPath $AgentFolder -Force
        . $agentFolder\config remove --unattended --url $DevOpsUrl --auth Pat --token $AccessToken --pool $AgentPoolName --Agent $AgentName$iteration --acceptTeeEula --runAsService --runAsAutoLogon --noRestart
    }

    if ($cleanup)
    {
        Remove-Item $AgentZip -Force -Recurse -Confirm:$false
    }
}

function New-AgentCommit
{
    <#

    .SYNOPSIS
    This command is used to commit code changes to the repository directly from an Azure Pipelines Build Agent.
    New-AgentCommit can only be used within an Azure DevOps pipeline.  

    .PARAMETER AgentName
    Name of the Build Agent. Set to $(Agent.Name) within pipeline script

    .PARAMETER RepoUrl
    Name of the Build Agent. Set to $(Build.Repository.Name) within pipeline script
    
    .PARAMETER RepoName
    Name of the DevOps Repository. Set to $(Build.Repository.Name) within pipeline script 

    .PARAMETER AccessToken
    Personal Access Token of the Build Agent. Set to $(System.AccessToken) within a pipeline script

    .EXAMPLE
    This command should be used within the Powershell Task in Azure Pipelines and should be formatted as shown below:
    $params = @{
        AgentName = "$(Agent.Name)"
        RepoURL = "$(Build.Repository.Uri)"
        RepoName = "$(Build.Repository.Name)"
        AccessToken = "$(System.AccessToken)"
    }
    New-AgentCommit @params

    #>
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [string]
        $AgentName,

        [Parameter()]
        [string]
        $RepoUrl,
        
        [Parameter()]
        [string]
        $RepoName,

        [Parameter()]
        [string]
        $AccessToken
    )

    # Get items to copy
    $files = (Get-Childitem).fullname 

    # Set Git Config
    git config --global user.email "$AgentName@CONTOSO.COM"
    git config --global user.name "$AgentName"
    #$env:GIT_REDIRECT_STDERR = '2>&1'

    # Clone Repo 
    git -c http.extraheader="AUTHORIZATION: bearer $AccessToken" clone  $RepoURL -v
    Set-Location ".\$RepoName"

    # Copy items to clone repo
    foreach ($file in $files)
    {
        Copy-Item $file -Destination (Get-Location).Path -Recurse -Force -Confirm:$False
    }

    # Push Changes to Master/Main branch
    git add --all
    git commit -m "Automated Commit"
    git -c http.extraheader="AUTHORIZATION: bearer $AccessToken" push
}