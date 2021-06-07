# How to guide for adding new systems to the SCAR repository

This topic will cover the process of adding STIG Exeptions to NodeData in SCAR.

## Create a Git Branch

---

### Determine Existing STIG Exceptions

Review existing Group Policy to determine STIG exceptions 

1. Log into a Server and open Powershell as Administrator
2. Run the following command - **GPResult /h $env:Userprofile\Desktop\GPResult.HTML**
3. Review the Group Policy results and look for any STIG Exception GPOs being applied

### Map Existing STIG Exceptions to Vulnerability IDs

1. Open the [STIG Checklist PowerBI Dashboard](https://powerbi.usafricom.mil/reports/powerbi/J6/Operation%20Dashboards/Stig-CKLDashboard-V2)
2. Select the **CKL View** tab
3. Use the filters to drill down to your system(s)
4. Set the Status filter to **Open**
5. Review the STIG Exception settings within the GPResult and use the Checklist Content to determine which Vulnerability ID each setting maps to

### Incorporate STIG exceptions in SCAR 

1. Follow the guidance to [Create a development branch](https://devops.usafricom.mil/USAFRICOM/SCAR/_wiki/wikis/SCAR-Wiki/15/How-To-Work-With-Git-Branches)
2. Open the nodedata file(s) for your system(s) under the "NodeData" folder within your development branch 
3. Add a "Skiprule" entry for each STIG exception that is required for each STIG type seperated by commas: 
Single Exception:       **SkipRule = 'V-0000'**
Multiple Exceptions:    **SkipRule = 'V-0000','V-1111'**

### Example: Adding a STIG exception for FIPS on NAIT03CMV70 

1. I've reviewed my STIG Exceptions Group Policy the following setting is in the policy:

Computer Configuration\Windows Settings\Security Settings\Local Policies\Security Options\
System cryptography: Use FIPS compliant algorithms for encryption, hashing, and signing: **Disabled**
 
2. Look at the STIG Checklist PowerBI Dashboard and filter down to open findings on my system to find the Vulnerability ID for FIPS
3. The Vulnerability ID for FIPs on server 2016 is **V-205842**
4. Create a branch in SCAR called **FipsStigException-DevOps**
5. Find the nodedata file for my system - **Nodedata\DevOps\NAIT04CMV70.psd1**
6. Add a **SkipRule** line under the PowerSTIG_WindowsServer scriptblock as follows:
7. Prior to adding the skiprule for FIPS, the PowerSTIG_WindowsServer scriptblock with the nodedata file looks like the following example:

<pre>
    PowerSTIG_WindowsServer =
    @{
        OSRole       = "MS"
        OsVersion    = "2016"
        DomainName   = "usafricom"
        ForestName   = "usafricom"
        OrgSettings  = "C:\DevOps_Agents\StigAgent01\_work\3\s\Resources\Stig Data\Organizational Settings\WindowsServer-2016-MS-2.1.org.default.xml"
        ManualChecks = "C:\DevOps_Agents\StigAgent01\_work\3\s\Resources\Stig Data\Manual Checks\WindowsServer\WindowsServer-2016-MS-1R12-ManualChecks.psd1"
        xccdfPath    = "C:\DevOps_Agents\StigAgent01\_work\3\s\Resources\Stig Data\XCCDFs\Windows.Server.2016\U_MS_Windows_Server_2016_STIG_V2R1_Manual-xccdf.xml"
    }
</pre>

8. Click the "edit" button and add the skiprule. After Adding the STIG Exception for FIPS, the PowerSTIG_WindowsServer scriptblock should look like the following:

<pre>
    PowerSTIG_WindowsServer =
    @{
        OSRole       = "MS"
        OsVersion    = "2016"
        DomainName   = "usafricom"
        ForestName   = "usafricom"
        OrgSettings  = "C:\DevOps_Agents\StigAgent01\_work\3\s\Resources\Stig Data\Organizational Settings\WindowsServer-2016-MS-2.1.org.default.xml"
        ManualChecks = "C:\DevOps_Agents\StigAgent01\_work\3\s\Resources\Stig Data\Manual Checks\WindowsServer\WindowsServer-2016-MS-1R12-ManualChecks.psd1"
        xccdfPath    = "C:\DevOps_Agents\StigAgent01\_work\3\s\Resources\Stig Data\XCCDFs\Windows.Server.2016\U_MS_Windows_Server_2016_STIG_V2R1_Manual-xccdf.xml"
        SkipRule     = "V-205842"
    }
</pre>

9. Click the **Commit** button and click **Commit** again in the menu that pops up. This saves (or commits) your changes to the branch.
10. Once your changes are committed to the branch, [create a pull request](https://devops.usafricom.mil/USAFRICOM/SCAR/_wiki/wikis/SCAR-Wiki/14/How-To-Submit-A-Pull-Request) to merge your changes into the Master branch.
11. If your pull request requires additional/modifications, a reviewer will add comments for you to address. Once all Comments have been completed in the PR, it can be approved/merged into the Master branch.   