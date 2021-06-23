# What is the StigRepo Module?

___

The Stig-Repo module leverages PowerSTIG and Desired State Configuration to build and drive the STIG Compliance Automation Repository (SCAR) - an automated Infrastructure as Code framework for Security Technical Implementation Guide (STIG) Compliance.

SCAR accelerates Azure readiness and ATO/CCRI processes through automated STIG compliance and digital transformation by establishing an infrastructure as code platform that organizations can customize build on top of to quickly establish and deploy Azure baselines.

## Get Started with StigRepo

___

## Active Directory Infrastructure

Execute the seven Powershell commands below to install the StigRepo module, build your Stig Repository, create PowerSTIG configurations, and generate STIG Checklists for Systems joined to an Active Directory Domain.

Prerequisites - WinRM access into the target systems, ActiveDirectory module must be installed, and target systems must be running Powershell version 5.1 or greater.

1. Install-Module StigRepo     # Installs the StigRepo module from the Powershell Gallery.
2. Initialize-StigRepo         # Builds the STIG Compliance Automation Repository and installs dependencies on the local system
3. New-SystemData              # Scans the Active Directory Environment for targetted systems, determines applicable STIGs, and generates DSC configuration data
4. Start-DscBuild              # Generates DSC Configuration scripts and MOF files for all DSC Nodes
5. Sync-DscModules             # Syncs DSC module dependencies across all DSC Nodes
6. Set-WinRMConfig             # Expands MaxEnvelopSize on all DSC nodes
7. Get-StigChecklists          # Generates STIG Checklists for all applicable STIGs for each DSC Node

## Azure Infrastructure

Execute the __ Powershell commands below to install the StigRepo Module, build your Stig Repository, and prepare an Azure Automation account to enforce/report STIG compliance for Azure Infrastructure.

Prerequisites - Powershell session must be connected to an Azure Subscription (Connect-AzAccount) and an Azure Automation account must already exist within the subscription.

1. Install-Module StigRepo # Installs the StigRepo module from the Powershell Gallery.
2. Initialize-StigRepo # Builds the STIG Compliance Automation Repository and installs dependencies on the local system
3. New-AzSystemData -ResourceGroupName "VM-RG-Name" # Builds System Data for Azure VMs
4. Publish-AzAutomationModules -ResourceGroupName "AutomationAcct-RG" -AutomationAccountName "My-AutomationAcct" # Uploads Modules located in "Resources\Modules" folder to an Azure Automation Account
5. Register-AzAutomationNodes -ResourceGroupName "AutomationAcct-RG" -AutomationAccountName "My-AutomationAcct" # Registers Systems with System Data to an Azure Automation Account
6. Export-AzDscConfigurations # Generates DSC Configuration Scripts for each SystemData file that are constucted for Azure Automation in the "Artifacts\AzDscConfigs" folder
7. Import-AzDscConfigurations -ResourceGroupName "AutomationAcct-RG" -AutomationAccountName "My-AutomationAcct" # Imports generated STIG Configurations to Azure Automation Account

## Release Cycle

___

StigRepo minor versions will be released each quarter with possible patch changes released in-between minor releases if/as needed. Submit bugs/feature requests to have fixes/recommended changes implemented into the StigRepo module.

### The STIG Repository Structure

The StigRepo module organizes Systems, Configurations, Artifacts, and Resources (SCAR) into the folder structure below:

1. Systems: Folders for each identified Organizational Unit in Active Directory and a Powershell Data file for each identified system.
2. Configurations: Dynamic PowerSTIG Configurations for that are customized by paremeters provided within system data files.
3. Artifacts: Consumable items produced by SCAR. SCAR produces DSCConfigs, MOFS, and STIG Checklists out of the box.
4. Resources: Dependendencies leveraged by SCAR to generate SystemData and Artifacts. SCAR has Modules, Stig Data, and Wiki resources out of the box.

### Contributing

To request modifications or submit bug reports for the StigRepo Module, submit an issue through the Github page.
To contribute - submit an issue, create a branch named GithubUser_IssueNumber, and submit a pull request to have your changes merged.

### Additional Resources

1. [PowerShell Gallery]("https://www.powershellgallery.com/packages/StigRepo/")
2. [GitHub]("https://github.com/microsoft/StigRepo")
3. [PowerSTIG](https://github.com/microsoft/PowerStig)
4. [Stig Coverage Summary](https://github.com/Microsoft/PowerStig/wiki/StigCoverageSummary)

___

## Repository Structure

___

### Systems

The NodeData folder stores Powershell Data files that represent the end nodes that you are targetting. Each NodeData .psd1 file should contain the following:

#### Active Directory Systems

* NodeName - The Active Directory Computer Name of the target node. This is used by DSC to push the configuration MOF to that machine.
* LocalConfigurationManager Hashtable - Define the Local Configuration Manager settings for your end node(s).
* AppliedConfigurations Array - Define which configurations you want to apply to your end node(s).
* Parameter Hashtables - Use hashtables with Parameter values for each configuration you're applying.
* Example:

<pre>
    @{
        NodeName = "vm-jump-001"

        AppliedConfigurations  =
        @{

            PowerSTIG_WindowsServer =
            @{
                OSRole           = "MS"
                OsVersion        = "2016"
                OrgSettings      = "C:\DevOpsAgents\AzDevOpsAgent1\_work\2\s\Resources\Stig Data\Organizational Settings\WindowsServer-2016-MS-2.1.org.default.xml"
                ManualChecks     = "C:\DevOpsAgents\AzDevOpsAgent1\_work\2\s\Resources\Stig Data\Manual Checks\WindowsServer\WindowsServer-2016-MS-2R1-ManualChecks.psd1"
                xccdfPath        = "C:\DevOpsAgents\AzDevOpsAgent1\_work\2\s\Resources\Stig Data\XCCDFs\Windows.Server.2016\U_MS_Windows_Server_2016_STIG_V2R1_Manual-xccdf.xml"
            }

            PowerSTIG_Edge =
            @{
                OrgSettings      = "C:\DevOpsAgents\AzDevOpsAgent1\_work\2\s\Resources\Stig Data\Organizational Settings\Microsoft-Edge-1.1.org.default.xml"
                ManualChecks     = "C:\DevOpsAgents\AzDevOpsAgent1\_work\2\s\Resources\Stig Data\Manual Checks\Edge\Edge-1R1-ManualChecks.psd1"
                xccdfPath        = "C:\DevOpsAgents\AzDevOpsAgent1\_work\2\s\Resources\Stig Data\XCCDFs\Edge\U_MS_Edge_V1R1_STIG_Manual-xccdf.xml"
            }

            PowerSTIG_WebServer =
            @{
                SkipRule         = "V-214429"
                IISVersion       = "10.0"
                LogPath          = "C:\InetPub\Logs"
                XccdfPath        = "C:\DevOpsAgents\AzDevOpsAgent1\_work\2\s\Resources\Stig Data\XCCDFs\Web Server\U_MS_IIS_10-0_Server_STIG_V2R1_Manual-xccdf.xml"
                OrgSettings      = "C:\DevOpsAgents\AzDevOpsAgent1\_work\2\s\Resources\Stig Data\Organizational Settings\IISServer-10.0-2.1.org.default.xml"
                ManualChecks     = "C:\DevOpsAgents\AzDevOpsAgent1\_work\2\s\Resources\Stig Data\Manual Checks\WebServer\WebServer-10.0-2R1-ManualChecks.psd1"
            }

            PowerSTIG_WebSite =
            @{
                IISVersion       = "10.0"
                WebsiteName      = "Default Web Site"
                WebAppPool       = "DefaultAppPool"
                XccdfPath        = "C:\DevOpsAgents\AzDevOpsAgent1\_work\2\s\Resources\Stig Data\XCCDFs\Web Server\U_MS_IIS_10-0_Site_STIG_V2R1_Manual-xccdf.xml"
                OrgSettings      = "C:\DevOpsAgents\AzDevOpsAgent1\_work\2\s\Resources\Stig Data\Organizational Settings\IISSite-10.0-2.1.org.default.xml"
                ManualChecks     = "C:\DevOpsAgents\AzDevOpsAgent1\_work\2\s\Resources\Stig Data\Manual Checks\WebSite\WebSite-10.0-2R1-ManualChecks.psd1"
            }

            PowerSTIG_WindowsDefender =
            @{
                OrgSettings      = "C:\DevOpsAgents\AzDevOpsAgent1\_work\2\s\Resources\Stig Data\Organizational Settings\WindowsDefender-All-2.1.org.default.xml"
                ManualChecks     = "C:\DevOpsAgents\AzDevOpsAgent1\_work\2\s\Resources\Stig Data\Manual Checks\WindowsDefender\WindowsDefender-1R4-ManualChecks.psd1"
                xccdfPath        = "C:\DevOpsAgents\AzDevOpsAgent1\_work\2\s\Resources\Stig Data\XCCDFs\Windows.Defender\U_MS_Windows_Defender_Antivirus_STIG_V2R1_Manual-xccdf.xml"
            }

            PowerSTIG_WindowsFirewall =
            @{
                OrgSettings      = "C:\DevOpsAgents\AzDevOpsAgent1\_work\2\s\Resources\Stig Data\Organizational Settings\WindowsFirewall-All-1.7.org.default.xml"
                ManualChecks     = "C:\DevOpsAgents\AzDevOpsAgent1\_work\2\s\Resources\Stig Data\Manual Checks\WindowsFirewall\WindowsFirewall-1R7-ManualChecks.psd1"
                xccdfPath        = "C:\DevOpsAgents\AzDevOpsAgent1\_work\2\s\Resources\Stig Data\XCCDFs\Windows.Firewall\U_Windows_Firewall_STIG_V1R7_Manual-xccdf.xml"
            }

            PowerSTIG_InternetExplorer =
            @{
                BrowserVersion   = "11"
                OrgSettings      = "C:\DevOpsAgents\AzDevOpsAgent1\_work\2\s\Resources\Stig Data\Organizational Settings\InternetExplorer-11-1.19.org.default.xml"
                xccdfPath        = "C:\DevOpsAgents\AzDevOpsAgent1\_work\2\s\Resources\Stig Data\XCCDFs\InternetExplorer\U_MS_IE11_STIG_V1R19_Manual-xccdf.xml"
                SkipRule         = "V-46477"
            }

            PowerSTIG_DotNetFrameWork =
            @{
                FrameWorkVersion = "4"
                xccdfPath        = "C:\DevOpsAgents\AzDevOpsAgent1\_work\2\s\Resources\Stig Data\XCCDFs\DotNet\U_MS_DotNet_Framework_4-0_STIG_V2R1_Manual-xccdf.xml"
                OrgSettings      = "C:\DevOpsAgents\AzDevOpsAgent1\_work\2\s\Resources\Stig Data\Organizational Settings\DotNetFramework-4-1.9.org.default.xml"
                ManualChecks     = "C:\DevOpsAgents\AzDevOpsAgent1\_work\2\s\Resources\Stig Data\Manual Checks\DotnetFramework\DotNetFramework-4-V1R9-ManualChecks.psd1"
            }
        }

        LocalConfigurationManager =
        @{
            refreshFrequencyMins= "30"
            refreshMode= "PUSH"
            allowModuleOverwrite= $True
            configurationMode= "ApplyAndAutoCorrect"
            rebootNodeIfNeeded= $False
            maximumDownloadSizeMB= "500"
            configurationModeFrequencyMins= "15"
            statusRetentionTimeInDays       = "10"
        }
    }
</pre>

#### Non-Active Directory Systems

* NodeName - Specifies the name of the system.
* ManualStigs Array - Specify STIGs that cannot be automated via PowerSTIG. Example: Cisco STIGs.
* StigChecklist_Type Hashtables - Use hashtables starting with "StigChecklist_" and specify the folder name(s) containing the xccdf(s) and Manual Check files of those STIGs, and use a "Subtypes" array to specify multiple STIGs within those folders. 
* Example:

<pre>

    @{
        NodeName = "CiscoSwitch"

        ManualStigs =
        @{

            StigChecklist_Cisco  =
            @{
                SubTypes = $(
                    "IOS_XE_Switch_NDM",
                    "IOS_XE_Switch_L2S"
                )
            }
        }
    }
</pre>

### Configurations

Standardized configuration scripts should be located in the Configurations folder. Follow these guidlines for your configurations:

* Each configuration should be named the exact same as the file name.
* Use parameters for settings that allow for variance.

### Artifacts

* DscConfigs: Running Start-DscBuild will generate a custom/compiled DSC Configuration script for each system with a nodedata file.
* MOFs: Start-DscBuild also executes each compiled script in the DSCConfigs folder to generate a cutomized MOF for each system.
* Stig Checklists: Get-StigChecklists will execute a compliance SCAN for every system in the nodedata folder and will generate a STIG Checklist (.ckl) file for each PowerSTIG configuration defined in the system's nodedata.

### Resources

The resources folder is used to store Powershell Modules, DSC Resource Modules, helper functions, etc that are relevent to your organization.

Build/Release functions for DSCSM are also stored in the resources folder.

___

## Code of Conduct

___
This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/)
or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions
or comments.

## Trademarks

___

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.

## Contributing

___

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Project Contributors

___

* Jake Dean [@JakeDean3631](https://github.com/JakeDean3631)
* Ken Johnson   [@kenjohnson03](https://github.com/kenjohnson03)
* Cody Aldrich  [@coaldric](https://github.com/coaldric)
* Will Wellington [@wwellington2](https://github.com/wwellington2)