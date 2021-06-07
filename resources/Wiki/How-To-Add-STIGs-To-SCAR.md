# Adding New STIGs to SCAR

SCAR is capable of automating the generation of any STIG checklist, but need the STIG XCCDF file to be uploaded to the repository, and a manual check file must be generated for that functionality to work. 
This doc covers uploading new XCCDFs and generating the manual check files needed to automate STIG Checklist generation 

## What is an "XCCDF?"

STIG XCCDFs are the actual STIG XML files released by DISA containing all of the STIG rules/data. 
All STIGs XCCDFs can be found here - [DISA STIG Compilation Library](https://public.cyber.mil/stigs/compilations/)

## What is a "Manual Check File?"

Manual Check files are Powershell Data (.psd1) files that are used to "inject" manual checklist data into STIG Checklists. 
Each STIG Finding within a manual check file is formatted as shown below:

<pre>
@{
	VulID		= "V-205624"
	Status		= "NotAFinding"
	Comments	= "AFRICOM: Built-in and temporary user acounts are disabled via Desired State Configuration."
}
</pre>

**VulID**       - The vulnerability ID of the STIG Finding <br />
**Comments**    - Comments around how this Vulnerability is or is not addressed. <br>
**Status**      - The status of that finding. Acceptable Options: <br />
>**Open**            - The Vulnerability has not been addresses/resolved <br />
**NotAFinding**     - The Vulnerability is addresses/resolved <br />
**NotApplicable**   - The Vulnerability is not applicable to the system. Example - In the Windows Server STIG, several findings are only applicable to Domain Controllers. These vulnerabilities are marked as **Not Applicable** on member servers.<br />
**NotReviewed**     - The Vulnerability has not yet been reviewed.

## Add a STIG to SCAR 
1. [Create a branch](https://devops.usafricom.mil/USAFRICOM/SCAR/_wiki/wikis/SCAR-Wiki/15/How-To-Work-With-Git-Branches) for your changes
2. Create a folder under **Resources\STIG Data\XCCDFs** for the new STIG. 
3. Name the STIG based on whatever is after the first underscore (_) in the XCCDF Filename <br />
>Example - the Red Hat Linux STIG XCCDF filename is **U_RHEL_7_STIG_V3R1_Manual-xccdf.xml** so you would create a folder called **RHEL** and upload the STIG XML to the new folder
4. Once the STIG XML is uploaded to the folder, navigate to **Pipelines** and select the **Import New STIG** pipeline. 
5. Click **Run**, select **variables**, and input the filename of the new folder for the XCCDF to Manual Check conversion to target
6. Once the pipeline runs and completes, manual check files should be created within your branch
7. Fill in the status/comments within the new manual check file(s) for all manual STIG checks
8. [Submit a Pull Request](https://devops.usafricom.mil/USAFRICOM/SCAR/_wiki/wikis/SCAR-Wiki/14/How-To-Submit-A-Pull-Request) to merge your changes into the master branch
