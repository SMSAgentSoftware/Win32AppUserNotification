# Win32AppUserNotification
### _Display a simple notification to end users during an Intune Win32 app install_

Win32AppUserNotification is a simple .Net Framework app that can be used to display a notification to the logged-on user during an Intune Win32 app install. It requires the use of a PowerShell script wrapper.

The notification can be displayed for Win32 apps in both SYSTEM and USER context and will display on top of other windows.

### Screenshot examples
![alt text](https://github.com/SMSAgentSoftware/Win32AppUserNotification/blob/main/Screenshots/ss1.png?raw=true)
![alt text](https://github.com/SMSAgentSoftware/Win32AppUserNotification/blob/main/Screenshots/ss2.png?raw=true)

### How to use
Download the **[Release](https://github.com/SMSAgentSoftware/Win32AppUserNotification/releases)** and package the **Win32AppUserNotification.exe** in the same directory as your PowerShell install wrapper script. Example wrapper scripts containing logic to call the notification can be found in the **Example wrapper scripts** folder. The notification wrapper code is different between USER and SYSTEM context installs. Populate the **Title** parameter (eg with the app name) and add the main notification text using the StringBuilder code.

### How it works
You can pass two arguments to the notification executable - a **title** and some **text**. It is recommended to prepare the text using a .Net StringBuilder object to preserve line breaks, as demonstrated in the example script wrappers.

When running in USER context, the process is straight forward - the notification text is prepared, the exe is called and a timeout is used to automatically close the notification after a defined period in case of no response from the user.

When running in SYSTEM context, a scheduled task is created to run the exe in the user context. The involves more complex code, but has the advantage of not requiring an additional dependency like ServiceUI.exe from MDT to run in user context.
The wrapper code does a few things:
- Creates a temp working directory in a user-accessible location
- Copies the Win32AppUserNotification.exe to this location
- Creates a VBScript to run a PS script with no window
- Creates a PS script to call the notification exe
- Creates and starts a scheduled task to run the PS script
- Removes the scheduled task and cleans up the temp directory
