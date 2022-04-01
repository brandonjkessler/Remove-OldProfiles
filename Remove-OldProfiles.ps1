<#

Version: 1.3.0
Author: Brandon Kessler
Description:
Removes profiles that are a certain age or older. Based on "last Modified" date of user's folder.

#>

## Paramaters ##
Param(
    [int]$Days = 30,
    [array]$Exclude = @()
    #[string]$Computer
)

Start-Transcript -Path "C:\Windows\Logs\Remove-OldProfiles.log" -Append

## Create Arrays and Varaiables
$UserProfilesArr = @()
$Exclude += @("default", "Public", $env:USERNAME, "SQL") ## Standard accounts to ignore

# Get user names from CIM Object but remove system users
$users = get-ciminstance -ClassName Win32_UserProfile | Where-Object{$_.LocalPath -match 'C:\\Users'}

# Check the Event Logs for successful Logins AFTER the days specified.
$userLogonEvent = get-eventlog -LogName 'Security' -InstanceId '4624' -After $((Get-Date).AddDays(-$Days))

##Get the List of User folders
$users | ForEach-Object {
    $userName = $_.LocalPath.Replace('C:\Users\','')
    if($userName -match ($Exclude -join '|')){ ## Check if User  is in Exclusion list
        Write-Host "$userName was ignored because it is excluded."
    } elseif(($UserLogonEvent.Message -match "$userName") -ne $null) { ## Check to see if the user has logged in more recently than the time specified
            Write-Host "$userName was not old enough."
    } else{ ## If the user has not logged in successfully recently then remove their account
            Write-Warning "$userName will be added to removal array."
            $UserProfilesArr += $userName # Add to array for removal
            $UserProfilesArr += $UserProfilesArr | Sort-Object -Verbose
    } ## End of If/Else Statement
        
    
} ## End of Get-ChildItem

## Remove the User Profiles
Get-CimInstance -Class Win32_Userprofile | Where-Object { 
        $UserProfilesArr -match ($_.LocalPath -replace ".*\\" -replace ".*\\") ## -replace ".*\\" is a regex that will remove all characters up to and including the first "\". Doing it twice results in removing "C:\" and then "Users\" from the comparison.
} | ForEach-Object {
        Write-Host("Deleting $_")
        Remove-CimInstance -InputObject $_ -Verbose
}

Stop-Transcript

Exit 0
