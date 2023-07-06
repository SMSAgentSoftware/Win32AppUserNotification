## Example script wrapper for Intune Win32 app using Win32AppUserNotification.exe in SYSTEM context.

#region Functions
# function to display a notification to the logged-in user
function Display-UserNotification{
    param($Title,$Text,$Timeout)

    # Create the VBScript silent wrapper    
    $VBScriptContent = @"
p = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
location = p &"\"& WScript.Arguments(0)
command = "powershell.exe -nologo -ExecutionPolicy Bypass -File """ &location &""""
set shell = CreateObject("WScript.Shell")
shell.Run command,0
"@
    try 
    {
        $VBScriptContent | Out-File -FilePath "$WorkingDirectory\Invoke-PSScript.vbs" -Force -ErrorAction Stop 
    }
    catch 
    {
        return "Failed: $($_.Exception.Message)"
    }

    # Set the notification exe location
    $exe = "$WorkingDirectory\Win32AppUserNotification.exe"

    # Create the script definition
    $ScriptContent = @"
# Build the argument list as a string array
[string[]]`$stringArray = "`"`"$Title`"`"","`"`"$Text`"`""

# Start a stopwatch for the notification timeout
`$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()

# Start the notification process
`$Process = Start-Process -FilePath "$Exe" -ArgumentList `$stringArray -NoNewWindow -PassThru

# Wait for exit or timeout
do {}
until (`$Process.HasExited -eq `$true -or `$stopWatch.Elapsed.TotalSeconds -ge $Timeout)

# If timed-out, kill the process
If (`$Process.HasExited -ne `$true)
{
    `$Process.Kill()
}
"@
    try 
    {
        $ScriptContent | Out-File -FilePath "$WorkingDirectory\Pop-Win32AppUserNotification.ps1" -Force -ErrorAction Stop 
    }
    catch 
    {
        return "Failed: $($_.Exception.Message)"
    }

    # Create the scheduled task definition
    $XMLContent = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
<RegistrationInfo>
    <Date>$((Get-Date -Format s).ToString())</Date>
    <Author>HenrySmith</Author>
    <URI>\Pop-Win32AppUserNotification</URI>
</RegistrationInfo>
<Triggers />
<Principals>
    <Principal id="Author">
    <GroupId>S-1-5-32-545</GroupId>
    <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
</Principals>
<Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
    <StopOnIdleEnd>false</StopOnIdleEnd>
    <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <DisallowStartOnRemoteAppSession>false</DisallowStartOnRemoteAppSession>
    <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
    <Priority>7</Priority>
</Settings>
<Actions Context="Author">
    <Exec>
    <Command>$WorkingDirectory\Invoke-PSScript.vbs</Command>
    <Arguments>Pop-Win32AppUserNotification.ps1</Arguments>
    </Exec>
</Actions>
</Task>
"@
    try 
    {
        $XMLContent | Out-File -FilePath "$WorkingDirectory\Pop-Win32AppUserNotification.xml" -Force -ErrorAction Stop 
    }
    catch 
    {
        return "Failed: $($_.Exception.Message)"
    }

    # Create the scheduled task
    try 
    {
        $null = Register-ScheduledTask -Xml (Get-Content "$WorkingDirectory\Pop-Win32AppUserNotification.xml" -ErrorAction Stop | out-string) -TaskName "Pop-Win32AppUserNotification" -TaskPath "\"  -Force -ErrorAction Stop
    }
    catch 
    {
        return "Failed: $($_.Exception.Message)"
    }

    # Start the scheduled task
    try 
    {
        $null = Start-ScheduledTask -TaskName "Pop-Win32AppUserNotification" -TaskPath "\" -ErrorAction Stop
    }
    catch 
    {
        return "Failed: $($_.Exception.Message)"
    }  

    # Wait for task to start
    Start-Sleep -Seconds 5

    # Cleanup task
    try 
    {
        Unregister-ScheduledTask -TaskName "Pop-Win32AppUserNotification" -TaskPath "\" -Confirm:$false -ErrorAction Stop
    }
    catch 
    {
        return "Failed: $($_.Exception.Message)"
    }

}
#endregion

#region UserNotification
# Set the app name (notification title)
$Title = "Adobe Acrobat DC CC 2023"
    
# Build the main notification text using a string builder.
$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("This application will enforce a restart at the end of the installation.")
[void]$sb.AppendLine("Save and close your work now!")
[void]$sb.Remove(($sb.Length -2),2) ## Removes the trailing carriage return added by the AppendLine method of StringBuilder.

# Create a user-accessible temp location
$TempDirectoryName = [guid]::NewGuid().Guid.SubString(0,8)
$script:WorkingDirectory = "$env:ProgramData\$TempDirectoryName"
if (-not ([System.IO.Directory]::Exists($WorkingDirectory)))
{
    [void][System.IO.Directory]::CreateDirectory($WorkingDirectory)
}

# Copy Win32AppUserNotification.exe to temp location
[System.IO.File]::Copy("$PSScriptRoot\Win32AppUserNotification.exe","$WorkingDirectory\Win32AppUserNotification.exe",$true)

# Pop the notification
Display-UserNotification -Title $AppName -Text $sb.ToString() -Timeout 300 # 300 seconds - 5 minutes

# Timeout to wait for the notification process to display
$ProcessWaitTimeout = [timespan]::FromSeconds(30)

# Start a stopwatch for the process timeout
$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()

# Wait for notification process to start or timeout
do {
    $Process = Get-Process -Name Win32AppUserNotification -ErrorAction SilentlyContinue
}
until ($null -ne $Process -or $stopWatch.Elapsed -ge $ProcessWaitTimeout)
$stopWatch.Stop()

# Wait for the process to exit
if ($null -ne $Process)
{
    # Wait for notification process or timeout
    do { }
    until ($Process.HasExited -eq $true)
    $Process.Dispose()
}

# Clean up temp files
$PowerShell = [powershell]::Create()
try {    
    [void]$PowerShell.AddScript({Param($WorkingDirectory);[System.IO.Directory]::Delete($WorkingDirectory,$true)})
    [void]$PowerShell.AddArgument($WorkingDirectory)
    [void]$PowerShell.Invoke()
}
catch {
    $_
}
#endregion

#region Install
#### Main install logic here...
#endregion