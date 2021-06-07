# Configuring Visual Studio Code

This topic will discuss varios aspects of downloading, installing, and configuring Visual Studio Code so that you can be an effective contributor to the DSCSM Project.

## Install VS Code and Git

---

### Task 1: Install Visual Studio Code

If you don't have VS Code installed, you will need to install download and install it. Follow the steps below to do this:

1. Open your web browser and navagate here - [Visual Studio Code](https://code.visualstudio.com/)
2. Click the **Download for Windows** button on the Visual Studio Code page.
3. Click **Save File** and run the executable once the download completes.
4. Follow the configuration prompts to install Visual Studio Code.

### Task 2: Install Git

You will need to install Git on your system to allow VS Code to interact with the DSCSM code repository. Follow the steps below to accomplish this:

1. Open your web browser and navagate here - [Git](https://code.visualstudio.com/)
2. Click the **Download** button on the Git for Windows page.
3. Click **Save File** and run the executable once the download completes.
4. Follow the configuration prompts to install Git for Windows.

## Add extensions to Visual Studio Code

---

VS Code offers a wide range of extensions that enable additional functionality to VS Code.

### Task 4 Install VS Code Extensions

Follow the steps below to install extensions for VS Code:

1. Open VS Code and click the extensions tab on the left.
2. Seach for the name of the extension you want to install.
3. Click the desired extension to select it
4. Click **Install**

### Required Extensions for contributing to the DSCSM project

The following extensions are essential for contriuting to DSCSM:

|Extension Name                 |Description                    |Link                                                                                               |
|-------------------------------|-------------------------------|---------------------------------------------------------------------------------------------------|
|Powershell                     |Required for PS Development    |[Link](https://marketplace.visualstudio.com/items?itemName=ms-vscode.PowerShell)                   |
|C#                             |Required for C# Development    |[Link](https://marketplace.visualstudio.com/items?itemName=ms-vscode.csharp)                       |
|Azure Boards                   |Work with TFS/ADO via VS Code  |[Link](https://marketplace.visualstudio.com/items?itemName=ms-vsts.team)                           |

### **Recommended VS Code Extensions**

The following extensions are not essential for contriuting to DSCSM, but are recommended to make your efforts easier:

|Extension Name                 |Description                    |Link                                                                                               |
|-------------------------------|-------------------------------|---------------------------------------------------------------------------------------------------|
|Markdown Preview Enhanced      |Preview Markdown Documents     |[Link](https://marketplace.visualstudio.com/items?itemName=shd101wyy.markdown-preview-enhanced)    |
|Bracket Pair Colorizer         |Highlights bracket pairs       |[Link](https://marketplace.visualstudio.com/items?itemName=CoenraadS.bracket-pair-colorizer)       |
|Trailing Spaces                |Trim trailing white space      |[Link](https://marketplace.visualstudio.com/items?itemName=shardulm94.trailing-spaces)             |
|GitLens                        |Enhances Git functionality     |[Link](https://marketplace.visualstudio.com/items?itemName=eamodio.gitlens)                        |
|Excel Viewer                   |Easily view CSV/Excel Files    |[Link](https://marketplace.visualstudio.com/items?itemName=GrapeCity.gc-excelviewer)               |
|XML Tools                      |Enhance XML functionality      |[Link](https://marketplace.visualstudio.com/items?itemName=DotJoshJohnson.xml)                     |
|Powershell Preview             |Preview of new Powershell Ext  |[Link](https://marketplace.visualstudio.com/items?itemName=ms-vscode.PowerShell-Preview)           |
|Liveshare                      |Share VS Code Session with team|[Link](https://marketplace.visualstudio.com/items?itemName=MS-vsliveshare.vsliveshare)             |

## Manage Visual Studio Code Credentials

---

You will need to authenticate to the DSCSM Azure DevOps Server instance in order to use VS Code to interact with it. Follow the steps below to configure git credential manager:

### Task 1: Configure Git Credentials with Visual Studio Code

**Note:** If you already have already configured a Git Credential helper and Git identity, skip to Step 2.

1. Open Visual Studio Code. In this task, you will configure a Git credential helper to securely store the Git credentials used to communicate with Azure DevOps. If you have already configured a credential helper and Git identity, you can skip to the next task.
2. From the main menu, select Terminal | New Terminal to open a terminal window.
3. Execute the command below to configure a credential helper.

```sh
git config --global -l
git config --global http.sslbackend schannel
git config --global credential.scmpeoc3t.army.mil.authority negotiate (TFS)
and/or
git config --global credential.peoc3t.com.authority negotiate (ADO)
```

If you get a certificate error add this command:

```sh
Git config --global http.sslverify false
```

**Note:** If you do not already have the DoD Root certs installed Navigate to <https://www.cpms.osd.mil/Subpage/DODRootCertificates/> and follow the directions listed.
