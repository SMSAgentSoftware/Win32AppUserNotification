## Example script wrapper for Intune Win32 app using Win32AppUserNotification.exe in USER context.

#region UserNotification
# Set current location
Set-Location -Path $PSScriptRoot

# Set the app name (notification title)
$Title = "Adobe Acrobat DC CC 2023"
    
# Build the main notification text using a string builder.
$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("This application will enforce a restart at the end of the installation.")
[void]$sb.AppendLine("Save and close your work now!")
[void]$sb.Remove(($sb.Length -2),2) ## Removes the trailing carriage return added by the AppendLine method of StringBuilder.

# Build the argument list as a string array. Make sure to include the escaped quotes!
[string[]]$stringArray = "`"$Title`"","`"$($sb.ToString())`""

# Set a timeout for the notification
$Timeout = [timespan]::FromSeconds(300)

# Start a stopwatch for the notification timeout
$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()

# Start the notification process
$Process = Start-Process -FilePath ".\Win32AppUserNotification.exe" -ArgumentList $stringArray -NoNewWindow -PassThru

# Wait for exit or timeout
do {}
until ($Process.HasExited -eq $true -or $stopWatch.Elapsed -ge $Timeout)

# If timed-out, kill the process
If ($Process.HasExited -ne $true)
{
    $Process.Kill()
}
#endregion

#region Install
#### Main install logic here...
#endregion