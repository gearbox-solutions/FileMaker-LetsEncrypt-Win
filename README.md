# FileMaker-LetsEncrypt-Win
A PowerShell script for fetching and renewing Let's Encrypt SSL certificates for FileMaker Server running on Windows Server.

## Requirements
FileMaker Server deployed on Windows Server – 2012 R2, 2016, or 2019 but may work with other versions.
The “FileMaker Database Server Website” page must be reachable through the public internet using a web browser at the address you wish to get an SSL certificate for, such as http://myserver.mycompany.com. This means opening or forwarding port 80 in your router, firewall, or security groups. We use the Let’s Encrypt HTTP verification challenge, so we must make sure that Let’s Encrypt is able to reach our FileMaker server through HTTP.

## Downloads
Download the GetSSL.ps1 PowerShell script
First, you’ll need a copy of the GetSSL PowerShell script. Download or copy the file from `GetSSL.ps1` in this repository and put it where you’ll want to install the SSL certificate. We recommend making a new folder for the SSL renewal files at `C:\Program Files\FileMaker\SSL Renewal\` and saving this script in there. This folder will also hold logs and other renewal-related files once the script is run.

### Download Crypt-LE (le64.exe)
This script uses the Crypt-LE program from https://github.com/do-know/Crypt-LE/releases. Download the le64.exe executable and store it in a permanent, accessible location on your server. Preferably this would the same SSL Renewal folder used in the last step.

This application is a recommended ACME implementation for Windows from Let’s Encrypt. The source code is available for you to download and build it yourself. There is also a Perl version if you’d like to run that instead of a pre-compiled executable.


### Change Windows security to allow PowerShell Scripts to run
Windows Server will not allow you to run PowerShell scripts by default, so you’ll need to modify your security settings to allow this. Open PowerShell or PowerShell ISE as Administrator using the “Run as Administrator” option and enter the command:


```powershell
Set-ExecutionPolicy -Scope LocalMachine Unrestricted
```

Enter “y” and press enter to accept the security warnings that appear.

If you’ve copied this file to your server though RDP or over a network you should be fine here, but if the file was downloaded directly to the server from this site there may be another “downloaded from the internet” warning that you’ll have to clear. Place the file in a semi-final location and unblock it using the Unblock-File command, passing in the path to the file as a parameter.

```powershell
Unblock-File -Path "C:\Program Files\FileMaker\SSL Renewal\GetSSL.ps1"
```
Note: PowerShell must be Run as Administrator for this step and all subsequent steps, or you will receive errors. Be sure you are running PowerShell or the PowerShell ISE as Administrator using the “Run as Administrator” option, not just a user named Administrator.

## Configuration
### Edit the GetSSL.ps1 file
The script file needs to be edited so that it know the address you wish to get an SSL certificate for as well as some paths on your system. Right-click on the ps1 file and select edit to open a text editor. Change the certificate domain, email address, le64.exe path, and (if necessary) the FileMaker Server install path variables to reflect your server’s information and your contact information. Let’s Encrypt will use this contact information to reach out to you if there is a problem with the SSL certificate that they have issued to you.


### Test the PowerShell Script
> WARNING: Running this PowerShell script will safely restart your FileMaker Server service, abruptly disconnecting any active users. Make sure that nobody is connected to your server before you run this script.

We’re now ready to test the PowerShell script and retrieve a test certificate. Make sure nobody is connected or using your FileMaker server and then run the GetSSL.ps1 PowerShell script by navigating to the directory you have it copied to in your PowerShell window and entering:

```powershell
.\GetSSL.ps1
```

A bunch of text will scroll by in the PowerShell window as the script requests, fetches, and installs your SSL certificate. Your FileMaker Server service will then be stopped and started again automatically.

Watch the messages which appear on the screen and look for any errors. If you do see errors the error message may tell you where the problem is with the retrieval of your test certificate. A log file is also written to “SSL-Renewal.log” in the same directory as the PowerShell script.

Assuming things went smoothly, your test SSL certificate should now be installed! Go to your FileMaker Server admin console or try connecting to your FileMaker Server using FileMaker Pro. You may need to close and re-open your browser if you had the page open already. If you’re trying to use FileMaker Pro to test the connection you will need to completely quit and re-open FileMaker Pro to see the new certificate.

The new certificate should show as invalid due to the an invalid certificate authority, but should show your correct domain name. This is good, and means that the test was successful.


### Enable Admin Console External Authentication (FMS 17 or later)
FileMaker Server 17 now requires entering a username and password for the process of installing a certificate through the “fmsadmin certificate install” command. This is a new feature of FileMaker 17, and is not a part of earlier versions of FileMaker Server. We need to handle this request for authentication information in our process of installing a certificate. This request can be managed in one of two ways:

A. Use the external authentication for the FMS Admin console to allow the user running the GetSSL script access to the admin console.

B. Include the username and password in the GetSSL script.

Option B would require the admin console username and password to be stored in plain text, and would be insecure. Because of this, we recommend option A and enabling external authentication for the admin console. Configuring this feature will prevent the command from asking for authentication information if the user running the command is allowed access to the admin console.

In step 9 we will need to specify a Windows user with administrator access who will run the GetSSL script to renew and install the certificate. We want to make sure that this user will also have access to the FileMaker Server Admin console using its Windows username and password. We need to configure FMS to allow this user to log in to the admin console by specifying a group that the user is part of.

If you’re using Active Directory you’ll be able to select a group from AD which you want to grant access to the FMS Admin console. If your server is not part of an Active Directory domain you can use a local group on the computer for this access.  A good option for this is the “Administrators” group, since our user must be an administrator anyway for other features of the script to work.

In the FileMaker Server Admin console select the Administration menu at the top, then External Authentication from the list on the left side. There are two places we need to adjust.

1. External Accounts for Admin Console Sign In – Click the “Change” option and specify the group which should be allowed to access the FMS Admin console. “Administrators” is a good value to use here if you’re not using Active Directory. Click “Save Authentication Settings” to save your entered group name.
2. Admin Console Sign In, External Accounts – switch this to “Enabled” to allow the group specified above to log in.

### Disable Test Mode and Retrieve The Real Certificate
The PowerShell script comes set to run in test mode by default. If you’ve been able to successfully retrieve the test certificate it means that it is now safe to disable test mode. Change the $testMode variable in GetSSL.ps1 from 1 to 0. Save the file and run the PowerShell script again like you did in the last step. Once it’s finished installing, completely quit FileMaker Pro and your browser and then re-open to test the certificate installation. If you see the green lock icon it means you have successfully retrieved a valid certificate!

## Scheduling
Set up a schedule to renew the SSL certificate
SSL Certificates from Let’s Encrypt are only valid for 90 days and must be renewed before that time. [Let’s Encrypt does this purposefully](https://letsencrypt.org/2015/11/09/why-90-days.html) to encourage automation and increase security. In that spirit, we should set up an automatic renewal for our SSL certificates so that we don’t need to manually re-run this every couple of months. This process is similar to setting up a scheduled script in FileMaker Server.

Move the GetSSL.ps1 file to a relatively permanent location on your server and then open the Task Scheduler, which we will use to set up a new scheduled task.

Once you have the Task Scheduler open, right-click on the Task Scheduler Library icon on the left side of the window and select the “Create Basic Task” option.

Give your task a name and description so that you can recognize what is is and then press Next. Select a frequency for this task to run. Daily is a good setting here, and then on the next screen you can set it to recur every 65 days. The SSL certificates from Let’s Encrypt are good for 90 days at a time, so this will give us some leeway if there are problems

Enter `PowerShell` in the “Program/script:” field. Enter the path to the GetSSL.ps1 script in the “Add arguments (optional)” field with the `-File` option. If you used the recommended path for storing the script this should be `-File "C:\Program Files\FileMaker\SSL Renewal\GetSSL.ps1"`

Click the next button to review, and select the “Open Properties” checkbox. Complete the setup and the properties window will open for you to make final adjustments to this schedule. You can edit the triggers and scheduling here, but the important thing we need to do is change the security options.

Select the “Run whether user is logged o nor not” radio button and enter your password to allow the script to run even if you’re not logged into the machine. Also be sure to check the “Run with highest privileges” option to make the script Run as Administrator, which is required for the script to work properly. For FileMaker Server 17 it is important that the user you enter here is allowed to log in to the FMS admin console through external authentication, as described in the previous step.

## Done!
That’s all that you need to do! Your script should run automatically at your scheduled time to renew your SSL certificate with Let’s Encrypt. Do a test to make sure that it’s all working properly, that it gets a new certificate for you, and that your FileMaker Server service restarts after it has retrieved the certificate. If there is an issue, you may want to run the script manually in PowerShell or debug with the PowerShell ISE to locate any issues.

Keep in mind that your FileMaker Server service will be restarted after getting the new SSL certificate, so be sure to schedule it for a time when people will not be active in your system.