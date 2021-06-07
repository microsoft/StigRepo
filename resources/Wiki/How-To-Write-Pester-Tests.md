# How to write Pester Tests for automated testing

This topic will cover what pester testing is and how to write tests for code changes that you submit.

## What is Pester

Pester is a community-based project designed from the ground up as a testing framework for PowerShell, written in PowerShell. It’s open source, so you can look through the source code and even make contributions back to it. You can find the [Full Project](https://github.com/pester/Pester) on GitHub.

## Types of Automated Testing

There are several different types of automated code testing including Unit Testing, Integration Testing, and Acceptance Testing. For the DSCSM Project, we are mainly concerned with unit and integration testing, but should have test plans in-place for acceptance testing once our customer(s) have a release from DSCSM to ensure that the product is working for them as expected.

### Unit Testing

Unit tests are performed by the developer and are typically focused on the code they’ve just created or modified. They provide feedback that the code works as they wanted it to. Unit tests are done in isolation. By isolating the test to run on just the code they’ve written, and not that of external modules, they can be assured any problems they find are with their code and not with external modules or functions.

To achieve isolation, testing uses the concept of mocks. Within a test a mock is used instead calling the actual external function desired. For example, let’s say your script calls **Test-Path** to validate the existence of a file. Actually, calling the real **Test-Path** function could cause several issues in testing.

First, the **Test-Path** cmdlet itself could have a bug in it, previously undiscovered or maybe just not known to the developer. Second, the developer could be assuming the path containing the file they are seeking will always exist as part of the test. Issues would certainly arise if the directory was to unexpectedly vanish. Finally, the drive containing the file may not be present or issues such as network connectivity or hardware failure could be causing problems.

Should any of these issues occur, the developer is left not only trying to debug his own code, but also struggling with the many ways the **Test-Path** cmdlet could have failed.

Mocks provide a way to remove external code, such as **Test-Path**, from the equation. As you will see later in this wiki, you can create a ‘fake’ or ‘mock’ version of **Test-Path** that would always return a true (or false). This removes the external call (in this case to **Test-Path**) as a possible vector for errors a developer might have to track down.

### Integration Testing

Integration testing is the next step in your testing workflow. Once a developer successfully completes their unit tests, they are ready for integration testing. Integration tests go beyond just testing the code the developer has finished working on, to testing it along with all the related code for a project.

For example, let’s say you updated two functions in module A. This module is part of a bigger project that encompasses two other modules, B and C, in addition to A. When executing integration tests, it would call all of the tests for all three modules. This is to ensure changes to module A don’t adversely affect modules B and C.

Typically, integration tests do not employ mocks. To fully test integration, in addition to your own code, you should execute that code against other modules. These modules might include some you’ve purchased, or those provided by Microsoft such as **AzureRM** or **SqlServer**. Integration testing is often considered ‘white box’ testing. In white box testing, also referred to as clear box or glass box, the tester has access to the underlying source code.

Many source code control systems have the ability to automatically perform integration testing. Once code is checked in, the system will automatically execute the integration tests you’ve configured.

### Acceptance Testing

Acceptance tests should be done by someone other than the developer. Some companies have internal organizations set up just to perform testing. In other organizations business users are often employed as testers, although this isn’t as common when testing non-application projects such as PowerShell scripts.

Acceptance testing is typically done in a ‘black box’ style. In black box testing, the testers do not look at or have access to the source code. Instead they simply execute the scripts and look at the results. If the results are as expected, for example a new server is created or database is deployed, the test passes.

## Install the Pester Module

---

Before you begin writing Pester Tests, you'll need to ensure that you have the Pester Module installed on your system. Follow the steps below to accomplish this.

### Task 1: Install the Pester Module

1. Open Powershell, Powershell ISE, or Visual Studio Code as an administrator
2. Run **Install-Module Pester** or **Install-Module Pester -Force** from your Active Powershell Terminal.
3. Verify that the Pester Module was installed by running **Get-Module Pester**

## Writing and Executing Unit Tests with Pester

---

### Task 1: Write a Powershell function

In this example, we will write a simple Powershell function that adds one to a number that's provided as a parameter:

```sh
function Add-One {
    param(
        $Number
    )

    $Number + 1
}
```

### Task 2: Write the unit test

Now that we have a function to test, we can write a unit test to ensure that the function is accomplishing the intended action.

1. First, we need to load the function into our session. Here we will use dot sourcing to pull the function into our active session:

```sh
## Ensure the function is available
. .\Add-One.ps1
```

2. Now that our function is loaded into our session, we can start writing our Pester Unit Test. To do that, we start by creating a **Describe** scriptblock and giving it a name. In this example, our test will be called **Add-One**:

```sh
## Ensure the function is available
. .\Add-One.ps1

Describe 'Add-One' {

}
```

3. Within our **Describe** Block, we'll create a couple of variables for our data.

```sh
## Ensure the function is available
. .\Add-One.ps1

Describe 'Add-One' {

    $TestNumber = 1
    $result = Add-One -Number $TestNumber

}
```

4. Now that we have our variables in place, we need to create  **It** scriptblock. The **It** scriptblock consists of the **It** Command followed by a string describing the criteria you are testing for. Here, we are naming our **It** block "should return 2.

```sh
## Ensure the function is available
. .\Add-One.ps1

Describe 'Add-One' {

    $TestNumber = 1
    $result = Add-One -Number $TestNumber

    It 'should return 2' {
    }
}
```

5. Now we need to add some logic to our **It** scriptblock. In this example, we will say that the value of **\$Result** should be equal to **2**. To do this, we will use the **\$Result** variable we created. We will pipe the value of **\$Result** into the **should be** command and provide the value of **2** that we are looking for by writing **\$Result | Should be 2**

```sh
## Ensure the function is available
. .\Add-One.ps1

Describe 'Add-One' {

    $TestNumber = 1
    $result = Add-One -Number $TestNumber

    It 'should return 2' {
        $Result | Should be 2
    }
}
```

6. Save your new Pester Test with the **.Tests** extension before the **.ps1** extension. This tells the Pester Module the it is a **.ps1** script that contains pester tests. Using the **.Tests** extension allows us to execute **Invoke-Pester -Path \$FolderName** and Pester will automatically run every **.ps1** script file within that folder that contains the **.Tests** extension. In this example,we'll name our test script **Add-One.Tests.ps1**. In the next task, we'll learn how to execute our new unit test.

## Executing Pester Tests

---

To execute your pester tests, you'll run the **Invoke-Pester** command. If all of your test files are named using the **.Tests** extension, you can provide the path to the folder containing all of your tests and it will execute every test script within that folder. You can also specify a single test file to execute. Follow the steps below.

### Task 1: Execute a single test locally

You can execute a single test within a test script containing multiple tests by following the steps below:

1. Ensure you have the Pester Module installed on your system.
2. Write a Pester Test and note the name of the test.
3. Save your test within a Pester Test Script as **[ScriptName]**.Tests.ps1
4. In an active Powershell session, run the following command:

```sh
Invoke-Pester -Script $ScriptPath -TestName $TestName
```

### Task 2: Execute all tests contained within a test script

You can run multiple tests contained within a single test script by following the steps below:

You can execute a single test within a test script containing multiple tests by only providing a script name to the Invoke-Pester cmdlet. Follow the steps below to accomplish this:

1. Ensure you have the Pester Module installed on your system.
2. Write multiple Pester Tests and save them within a single Pester Test Script as **[ScriptName]**.Tests.ps1
3. In an active Powershell session, run the following command:

```sh
Invoke-Pester -Script $ScriptPath
```

### Task 3: Execute all test scripts within a folder

Finally, by naming our Pester Test Scripts using the **.tests** extension, we can provide a folder name to the Invoke-Pester cmdlet and it will execute every test contained within every script named using the **.tests** extension. Follow the steps below to accomplish this:

1. Ensure you have the Pester Module installed on your system.
2. Write multiple Pester Test Files and save them within a Folder as **[ScriptName]**.Tests.ps1
3. In an active Powershell session, run the following command:

```sh
Invoke-Pester -Script $ScriptFolder
```

**NOTE** - You can provide multiple directories to the **-Script** parameter of the Invoke-Command cmdlet and it will recursively execute all **.tests.ps1** files within all the directories that are provided.

### Task 4: Automate Unit Testing within a CI/CD Pipeline

Now that we understand how to write Pester Tests and how to execute them locally, we need to know how to make testing an automated part of our CI/CD build/release process. We can follow the steps below to accomplish this within TFS and/or ADO.

#### Team Foundation Server CI/CD Build Testing

1. Write and save Pester Test files with the **.tests.ps1** extension within the **Test\Unit** folder under the **DSCSM** repository.
2. Open the DSCSM Project in Team Foundation Server
3. In TFS, click the **Build and Release** Tab
4. Within the **Builds** tab, select or create the Build process you'd like to add your automated testing to and click **Edit**
5. Within your build, select the process you'd like to add your automated testing step to and click the **+** sign to create a new build task.
6. Click the **Test** tab, hover over the **Visual Studio Test** task, and click **Add**
7. Click and drag your new task to where you want it to be executed within the build process.
8. Select the new **VsTest - testAssemblies** task and provide file/folder names for your test files.
9. Save the Build process.
10. Return to the **Builds** tab and click **Queue new build...** to execute your build process.

#### Azure Devops CI/CD Build Testing

1. Write and save Pester Test files with the **.tests.ps1** extension within the **Test\Unit** folder under the **DSCSM** repository.
2. Open the DSCSM Project in Azure Devops
3. In ADO, click the **Pipelines** Tab
4. Under the **Builds** tab, select or create the Build process you'd like to add your automated testing to and click **Edit**
5. Within your build, select the process you'd like to add your automated testing step to and click the **+** sign to create a new build task.
6. Click the **Test** tab, hover over the **Visual Studio Test** task, and click **Add**
7. Click and drag your new task to where you want it to be executed within the build process.
8. Select the new **VsTest - testAssemblies** task and provide file/folder names for your test files.
9. Save the build process
10. Return to the **Builds** tab and click **Queue** to execute your build process.

## Develop Test Plans in TFS and ADO

---

Azure Devops and Team Foundation Server also allow development teams to create test plans.
