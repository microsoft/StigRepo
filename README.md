# What is the StigRepo Module?

___

The Stig-Repo module leverages PowerSTIG and Desired State Configuration to build and drive the STIG Compliance Automation Repository (SCAR) - an automated Infrastructure as Code framework for Security Technical Implementation Guide (STIG) Compliance.

SCAR accelerates Azure readiness and ATO/CCRI processes through automated STIG compliance and digital transformation by establishing an infrastructure as code platform that organizations can customize build on top of to quickly establish and deploy Azure baselines.

## Get Started with StigRepo

___

### Active Directory Infrastructure

Execute the seven Powershell commands below to install the StigRepo module, build your Stig Repository, create PowerSTIG configurations, and generate STIG Checklists for Systems joined to an Active Directory Domain.

Prerequisites - WinRM access into the target systems, ActiveDirectory module must be installed, and target systems must be running Powershell version 5.1 or greater.

1. Install-Module StigRepo     # Installs the StigRepo module from the Powershell Gallery.
2. Initialize-StigRepo         # Builds the STIG Compliance Automation Repository and installs dependencies on the local system
3. New-SystemData              # Scans the Active Directory Environment for targetted systems, determines applicable STIGs, and generates DSC configuration data
4. Start-DscBuild              # Generates DSC Configuration scripts and MOF files for all DSC Nodes
5. Sync-DscModules             # Syncs DSC module dependencies across all DSC Nodes
6. Set-WinRMConfig             # Expands MaxEnvelopSize on all DSC nodes
7. Get-StigChecklists          # Generates STIG Checklists for all applicable STIGs for each DSC Node

### Azure Infrastructure

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

## The STIG Repository Structure

The StigRepo module organizes Systems, Configurations, Artifacts, and Resources (SCAR) into the folder structure below:

1. Systems: Folders for each identified Organizational Unit in Active Directory and a Powershell Data file for each identified system.
2. Configurations: Dynamic PowerSTIG Configurations for that are customized by paremeters provided within system data files.
3. Artifacts: Consumable items produced by SCAR. SCAR produces DSCConfigs, MOFS, and STIG Checklists out of the box.
4. Resources: Dependendencies leveraged by SCAR to generate SystemData and Artifacts. SCAR has Modules, Stig Data, and Wiki resources out of the box.

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

To request modifications or submit bug reports for the StigRepo Module, submit an issue through the Github page.
To contribute - submit an issue, create a branch named GithubUser_IssueNumber, and submit a pull request to have your changes merged.

### Contributor's list

* Jake Dean [@JakeDean3631](https://github.com/JakeDean3631)
* Ken Johnson   [@kenjohnson03](https://github.com/kenjohnson03)
* Cody Aldrich  [@coaldric](https://github.com/coaldric)
* Will Wellington [@wwellington2](https://github.com/wwellington2)

## Additional Resources

___

1. [PowerShell Gallery]("https://www.powershellgallery.com/packages/StigRepo/")
2. [GitHub]("https://github.com/microsoft/StigRepo")
3. [PowerSTIG](https://github.com/microsoft/PowerStig)
4. [Stig Coverage Summary](https://github.com/Microsoft/PowerStig/wiki/StigCoverageSummary)

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
