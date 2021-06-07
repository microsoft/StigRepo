# How to commit changes to a branch

This topic will go over how to commit changes to your local repository and how to push those committed changes to a git branch.

1. The Source Control icon on the left will always indicate an **overview of how many changes** you currently have in your repository. Clicking it will show you the details of your current repository changes: **CHANGES, STAGED CHANGES and MERGE CHANGES.**
2. Clicking each item will show you in detail the **textual changes within each file**. Note that for unstaged changes, the editor on the right still lets you edit the file
3. You can also find indicators of the **status of your repository** in the bottom left corner of VS Code: the **current branch, dirty indicators** and the number of **incoming and outgoing commits** of the current branch. You can checkout any branch in your repository by clicking that status indicator and selecting the Git reference from the list.

## Staged Commits

---

1. **Open Visiual Studio Code**.
2. Press **Ctrl+Shift+P** to show the **Command Palette**.
3. Type in **git: add**. This allows your Visual Studio Code stage the change. Note: to unstage a change **git: reset**
4. You can type a commit message above the changes and press **Ctrl+Enter** to commit the changes. If there are any **staged changes**, ***only*** those will be committed, otherwise ***all*** changes will be committed.

## Commit All Changes

---

1. **Open Visiual Studio Code**.
2. Press **Ctrl+Shift+P** to show the **Command Palette**.
3. Type in **git: commit**.
4. You can type a commit message above the changes and press **Ctrl+Enter** to commit the changes. ***All*** changes will be committed.

## Push committed changes to a Git Repository

---

Once you have committed your changes locally, you will need to push your locally-committed changes to the centralized git repository in order for your team to see them. Follow the steps below to accomplish this:

1. Follow the steps above to commit your changes locally.
2. Notice that in the bottom-right of VS Code, next to the sync button (two arrows making up a circle) you see an up arrow with a "1" next to it. This means that you have a local commit that is ready to be pushed to your git branch.
3. Click the sync button to push your locally-committed changes to the centralized git repository.

**NOTE** - You can also press **Ctrl+Shift+P** to open the command pallet and run the **Git: Push** command to push your changes to the centralized Git Repository.

**NOTE** - You can also run **Git Push** from your powershell terminal to push your changes to the centralized Git Repository.
