function New-BuildAgent
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

    .PARAMETER AgentPool
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
    New-SystemData -Rootpath "C:\SCAR" -SearchBase "CN=Servers,CN=Enterprise Management,DC=contoso,DC=com"
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
        $AgentPath = "$env:SystemDrive\StigRepo-Agents",
        
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
        Write-Output "Azure DevOps URL was not provided."
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

    if ('' -eq $AgentZip)
    {
        Write-Output "Azure DevOps Agent Zip File path wasn't provided."
        $prompt = Read-Host "`tDownload the Agent Zip File? (Internet Connection Required) Y/N"

        if ($prompt -like "y*")
        {
            Write-Output "`tDownloading Azure DevOps Agent Zip Package"
            $null = New-Item -ItemType "Directory" -Path "C:\StigRepo-Temp" -Force
            Invoke-WebRequest "https://vstsagentpackage.azureedge.net/agent/2.194.0/vsts-agent-win-x64-2.194.0.zip" -OutFile "C:\StigRepo-Temp\AzDevOpsAgent.zip"
            $AgentZip = "C:\StigRepo-Temp\AzDevOpsAgent.zip"
            $cleanup = $true
        }
        Write-Output "`n"
    }

    if (-not (Test-Path $AgentPath) -or '' -eq $AgentPath)
    {
        Write-Output "Agent Directory was not provided."
        $prompt = Read-Host "Built Agents in $AgentPath? Y/N"

        if ($prompt -like "y*")
        {
            Write-Output "Creating Agent Directory - $AgentPath"
            $null = New-Item $AgentPath -ItemType Directory -Force -Confirm:$false
        }
        else 
        {
            $AgentPath = Read-Host "Specify the Agent Path. Example `"C:\MyAgents`""
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
        Remove-Item "C:\StigRepo-Temp" -Force -Recurse -Confirm:$false
    }
}