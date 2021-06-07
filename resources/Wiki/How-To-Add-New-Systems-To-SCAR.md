# How to guide for adding new systems to the SCAR repository

This topic will cover the process of adding new configuration data to the master branch of SCAR.

## Create a Git Branch

---

### Create a Branch from the Azure DevOps Website

This topic will go over how to create a branch from the Azure DevOps Website

1. Create a Development Branch - (How To Work With Git Branches](https://devops.usafricom.mil/USAFRICOM/SCAR/_wiki/wikis/SCAR-Wiki/15/How-To-Work-With-Git-Branches)
2. Once your new branch is created, click on the **Pipelines** tab in DevOps 
3. Click on the following pipeline **DevBranch - Generate New Configdata**
4. Click **Run Pipeline**
5. Select your development branch from the **Branch/Tag** dropdown menu
6. Click **Variables**
7. Specify the name of the Active Directory Organizational Unit that your systems are located in.
8. Click the back arrow and then click **Run** to execute the build
9. Once the build completes, verify that the new configuration data, DSC config scripts(s), and MOF(s) are created in the new development branch
