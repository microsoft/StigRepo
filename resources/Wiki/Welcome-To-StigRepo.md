# Welcome to the STIG Repository!

## Overview

The [StigRepo module](https://www.powershellgallery.com/packages/StigRepo/1.4) accelerates cloud readiness and system hardening through building a repository to automate and customize configurations that are compliant with [Security Technical Implementation Guides (STIGs)](https://public.cyber.mil/stigs/) owned and released by the [Defense Information Systems Agency (DISA)](https://www.disa.mil/About). StigRepo identifies the systems in your Active Directory and/or Azure environment, identifies which software needs to be secured according to STIG requirements/recommendations, builds a customizable Infrastructure as Code (IaC) repository that leverages [PowerSTIG](https://github.com/microsoft/PowerStig) to automate enforcement, auditing, and documentation of STIG requirements through [Desired State Configuration](https://docs.microsoft.com/en-us/powershell/scripting/dsc/overview/overview?view=powershell-7.1). The STIG Repository can be imported into and driven through [Azure DevOps](https://azure.microsoft.com/en-us/services/devops/) or [Github Enterprise](https://github.com/enterprise) for continuous STIG enforcement, auditing, monitoring, and compliance documentation. 

The StigRepo Module empowers system integrators to:
- Quickly establish DevOps repositories customized for existing Active Directory environments
- Enforce and/or audit STIG Compliance for existing Active Directory/Azure environments
- Customize STIG configurations and easily implement/document exceptions to STIG requirements
- Develop and integrate custom DSC configurations to manage desired state at enterprise scale
- Generate documentation for Authority to Operate (ATO) renewals and Cyber Security Inspections

## Problem Statement

United States Government organizations must adhere to STIG requirements established by the Defense Information Systems Agency (DISA). Periodic inspections for STIG compliance are conducted in which government organizations must enforce, audit, and provide documentation that shows that their environment(s) are secure up to DISA’s standards. This is a massive undertaking that requires a large amount of manpower to complete, especially for large enterprise environments, as the time it takes to audit, enforce, and document STIG compliance on a single Windows Server can take 4-8 hours depending on the complexity of the system. This means that in an environment containing 100 servers, 400-800 man-hours required just to meet STIG requirements. With the StigRepo module, that time is reduced to a matter of ~10 hours. STIG compliance can be enforced, maintained, and documented across the entire environment on-demand, ensuring the organization is in an always-ready state for cyber inspections and that their systems are hardened to prevent cyber-attacks.

## Solution

The StigRepo module scans an existing Active Directory/Azure environment and builds a repository for managing, enforcing, and documenting STIG compliance. System data is customized to each system based on Operating System, software, and installed roles/features and can be further customized by customers that require exceptions to STIG requirements and/or custom configurations. The StigRepo module is a repeatable solution that can be universally implemented to quickly harden system security and establish STIG compliance. The repository that is built by the StigRepo module can easily be placed into an Azure DevOps or Github enterprise project to provide continuous enforcement, auditing, and documentation of STIG Compliance across the environment.

## Benefits

- Reduce risk – Systems are hardened according to DISA STIG required configuration standards
- Optimize cost + resources – StigRepo simplifies the process of enforcing, auditing, and documenting STIG compliance and provides a quick and easy solution for establishing a DevOps repository. 
- Increase efficiency – Even within large enterprise environments, StigRepo can build the repository, enforce STIG compliance, and generate documentation for all systems within a matter of hours. 

## Get Started with STIG Repo

### On-Prem Active Directory Environments

**Prerequisites**
- Must be executed from an internet-connected system to install module dependencies or required modules must be installed manually 
- For On-Prem Active Directory environments, StigRepo must be executed from a system with the Active Directory/RSAT Tools installed.
- Powershell Version 5.1 or greater

Execute the commands below to install the StigRepo Module, build the STIG repository, and generate STIG Checklists for On-Prem Active Directory environments:
|Cmdlet                   | Description |
|-------------------------|-------------|
| Install-Module StigRepo | Installs the StigRepo module from the Powershell Gallery |
| Initialize-StigRepo     | Builds the STIG Compliance Automation Repository and installs dependencies on the local system |
| New-SystemData          | Scans the Active Directory Environment for targetted systems, determines applicable STIGs, and generates DSC configuration data |
| Start-DscBuild          | Generates DSC Configuration scripts and MOF files for all DSC Nodes |
| Sync-DscModules         | Syncs DSC module dependencies across all DSC Nodes |
| Set-WinRMConfig         | Expands MaxEnvelopSize on all DSC nodes |
| Get-StigChecklists      | Generates STIG Checklists for all applicable STIGs for each DSC Node |

### Azure Environments 

**Prerequisites**
- Powershell session must be connected to an Azure Subscription (Connect-AzAccount)
- Azure Automation account must already exist within the subscription to leverage the StigRepo module

Execute the commands below to install the StigRepo Module, build your Stig Repository, and prepare an Azure Automation account to enforce/report STIG compliance for Azure Infrastructure.
|Cmdlet                            | Description |
|----------------------------------|-------------|
| Install-Module StigRepo          | Installs the StigRepo module from the Powershell Gallery.
| Initialize-StigRepo              | Builds the STIG Compliance Automation Repository and installs dependencies on the local system
| New-AzSystemData                 | Builds System Data for Azure VMs
| Publish-AzAutomationModules      | Uploads Modules to an Azure Automation Account
| Export-AzDscConfigurations       | Generates DSC Configuration Scripts for each SystemData file that are constucted for Azure Automation in the "Artifacts\AzDscConfigs" folder
| Import-AzDscConfigurations       | Imports generated STIG Configurations to Azure Automation Account
| Register-AzAutomationNodes       | Registers Systems with System Data to an Azure Automation Account

## STIG Repository Structure

StigRepo organizes the repository to deploy and document STIGs using the folders listed below:
- Systems: Folders for each identified Organizational Unit in Active Directory and a Powershell Data file for each identified system.
- Configurations: Dynamic PowerSTIG Configurations for that are customized by paremeters provided within system data files.
- Artifacts: Consumable items produced by StigRepo. StigRepo produces DSCConfigs, MOFS, and STIG Checklists out of the box.
- Resources: Dependendencies leveraged by StigRepo to generate SystemData and Artifacts. StigRepo has Modules, Stig Data, and Wiki resources out of the box.

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

## Contributor's list

* Jake Dean [@JakeDean3631](https://github.com/JakeDean3631)
* Ken Johnson   [@kenjohnson03](https://github.com/kenjohnson03)
* Cody Aldrich  [@coaldric](https://github.com/coaldric)
* Will Wellington [@wwellington2](https://github.com/wwellington2)

## Additional Resources

1. [PowerShell Gallery](https://www.powershellgallery.com/packages/StigRepo/)
2. [GitHub](https://github.com/microsoft/StigRepo)
3. [PowerSTIG](https://github.com/microsoft/PowerStig)
4. [Stig Coverage Summary](https://github.com/Microsoft/PowerStig/wiki/StigCoverageSummary)
5. [DISA Website](https://www.disa.mil/)
6. [STIG Website](https://public.cyber.mil/stigs/)
