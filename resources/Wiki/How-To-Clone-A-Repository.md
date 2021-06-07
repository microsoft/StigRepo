# Version Controlling with Git in Visual Studio Code and Azure DevOps

##### AKA: How to clone a Repo in TFS and Azure DevOps

Azure DevOps supports several types of version controls. However, Git is the primary tool used. Here is a quick overview of the Git version control system:

- **Git**: Git is a distributed version control system. Git repositories can live locally (such as on a developer’s machine). Each developer has a copy of the source repository on their dev machine. Developers can commit each set of changes on their dev machine and perform version control operations such as history and compare without a network connection.

## Prerequisites

* [Visual Studio Code](https://code.visualstudio.com/) with the C# extension installed.
* [Git for Windows](https://gitforwindows.org/) 2.21.0 or later.

### Task 1: Configuring Visiual Studio Code

You can also:

- Open Visual Studio Code. In this task, you will configure a Git credential helper to securely store the Git credentials used to communicate with Azure DevOps. If you have already configured a credential helper and Git identity, you can skip to the next task.
- From the main menu, select Terminal | New Terminal to open a terminal window.
- Execute the command below to configure a credential helper.

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

If you do not already have the DoD Root certs installed Navigate to <https://www.cpms.osd.mil/Subpage/DODRootCertificates/> and follow the directions listed.

### Task 2: Cloning an Existing Repo

1. In a browser tab, navigate to **<https://devops.peoc3t.com/MN_PPSS/>**
2. Getting a local copy of a Git repo is called “cloning”. Every mainstream development tool supports this and will be able to connect to Azure Repos to pull down the latest source to work with. Navigate to the **Repos** hub.
3. Click **Clone**.
4. Click the **Copy to clipboard** button next to the repo clone URL. You can plug this URL into any Git-compatible tool to get a copy of the codebase.
5. Open an instance of **Visual Studio Code**.
6. Press **Ctrl+Shift+P** to show the ***Command Palette***. The Command Palette provides an easy and convenient way to access a wide variety of tasks, including those provided by 3rd party extensions.
7. Execute the ***Git: Clone*** command. It may help to type **“Git”** to bring it to the shortlist.
8. Paste in the URL to your repo and press **Enter**.
9. Select a local path to clone the repo to.
10. When prompted, log in to your Azure DevOps account.
11. Once the cloning has completed, click **Open Repository**. You can ignore any warnings raised about opening the projects. The solution may not be in a buildable state, but that’s okay since we’re going to focus on working with Git and building the project itself is not necessary.