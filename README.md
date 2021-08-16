## What is the StigRepo Module?

The StigRepo module accelerates cloud readiness and system hardening through building a repository to automate and customize configurations that are compliant with Security Technical Implementation Guides (STIGs) owned and released by the Defense Information Systems Agency (DISA). StigRepo identifies the systems in your Active Directory and/or Azure environment, identifies which software needs to be secured according to STIG requirements/recommendations, builds a customizable infrastructure as code (IaC) repository that leverages [PowerSTIG](https://github.com/microsoft/PowerStig) to automate enforcement and/or monitoring of STIG compliance ensuring your systems remain secured and even generating documentation to report compliance through STIG Checklists.

## Get Started with STIG Repo

### On-Prem Active Directory Environments

**Prerequisites**
- Must be executed from an internet-connected system to install module dependencies or required modules must be installed manually 
- For On-Prem Active Directory environments, StigRepo must be executed from a system with the Active Directory/RSAT Tools installed.
- Powershell Version 5.1 or greater

Execute the commands below to install the StigRepo Module, build the STIG repository, and generate STIG Checklists for On-Prem Active Directory environments:
1. Install-Module StigRepo
2. Initialize-StigRepo: # Builds the STIG Compliance Automation Repository and installs dependencies on the local system
3. New-SystemData:      # Scans the Active Directory Environment for targetted systems, determines applicable STIGs, and generates DSC configuration data
4. Start-DscBuild:      # Generates DSC Configuration scripts and MOF files for all DSC Nodes.
5. Sync-DscModules:     # Syncs DSC module dependencies across all DSC Nodes
6. Set-WinRMConfig:     # Expands MaxEnvelopSize on all DSC nodes
7. Get-StigChecklists:  # Generates STIG Checklists for all applicable STIGs for each DSC Node

Additional Commands:
- Start-DscConfiguration -Path "$StigRepoLocation\Artifacts\MOFs" # Enforces STIG configurations on all systems with generated MOF files. 
- Update-StigRepo # Updates dependent modules to and StigRepo to the latest versions available on the PoSH marketplace and updates STIG Data Files

### Azure Environments 

**Prerequisites**
- Powershell session must be connected to an Azure Subscription (Connect-AzAccount) and 
- Azure Automation account must already exist within the subscription to leverage the StigRepo module

Execute the commands below to install the StigRepo Module, build your Stig Repository, and prepare an Azure Automation account to enforce/report STIG compliance for Azure Infrastructure.
1. Install-Module StigRepo          # Installs the StigRepo module from the Powershell Gallery.
2. Initialize-StigRepo              # Builds the STIG Compliance Automation Repository and installs dependencies on the local system
3. New-AzSystemData                 # Builds System Data for Azure VMs
4. Publish-AzAutomationModules      # Uploads Modules to an Azure Automation Account
5. Export-AzDscConfigurations       # Generates DSC Configuration Scripts for each SystemData file that are constucted for Azure Automation in the "Artifacts\AzDscConfigs" folder
6. Import-AzDscConfigurations       # Imports generated STIG Configurations to Azure Automation Account
7. Register-AzAutomationNodes       # Registers Systems with System Data to an Azure Automation Account

Additional Commands:
- Start-DscConfiguration -Path "$StigRepoLocation\Artifacts\MOFs" # Enforces STIG configurations on all systems with generated MOF files. 
- Update-StigRepo # Updates dependent modules to and StigRepo to the latest versions available on the PoSH marketplace and updates STIG Data Files

## STIG Repository Structure

StigRepo organizes the repository to deploy and document STIGs using the folders listed below:
1. Systems: Folders for each identified Organizational Unit in Active Directory and a Powershell Data file for each identified system.
2. Configurations: Dynamic PowerSTIG Configurations for that are customized by paremeters provided within system data files.
3. Artifacts: Consumable items produced by StigRepo. StigRepo produces DSCConfigs, MOFS, and STIG Checklists out of the box.
4. Resources: Dependendencies leveraged by StigRepo to generate SystemData and Artifacts. StigRepo has Modules, Stig Data, and Wiki resources out of the box.

## Code of Conduct

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/)
or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions
or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

### Contributor's list

* Jake Dean [@JakeDean3631](https://github.com/JakeDean3631)
* Ken Johnson   [@kenjohnson03](https://github.com/kenjohnson03)
* Cody Aldrich  [@coaldric](https://github.com/coaldric)
* Will Wellington [@wwellington2](https://github.com/wwellington2)

## Additional Resources

1. [PowerShell Gallery]("https://www.powershellgallery.com/packages/StigRepo/")
2. [GitHub]("https://github.com/microsoft/StigRepo")
3. [PowerSTIG](https://github.com/microsoft/PowerStig)
4. [Stig Coverage Summary](https://github.com/Microsoft/PowerStig/wiki/StigCoverageSummary)
