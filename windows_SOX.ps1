# Get Current Date & Time
function Get-DateTime {
    return Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
}

# Get OS Name & Version
function Get-Platform {
    $osInfo = Get-CimInstance Win32_OperatingSystem
    return "$($osInfo.Caption) $($osInfo.Version)"
}

# Get List of Local Users
function Get-Users {
    return Get-WmiObject Win32_UserAccount | Where-Object { $_.LocalAccount -eq $true } | Select-Object -ExpandProperty Name
}

# Get User ID (SID)
function Get-UID($user) {
    return (Get-WmiObject Win32_UserAccount | Where-Object { $_.Name -eq $user }).SID
}

# Get Last Login Time
function Get-LastLogin($user) {
    $loginInfo = quser | ForEach-Object { ($_ -split '\s{2,}')[0] }
    if ($loginInfo -contains $user) {
        return "Currently Logged In"
    } else {
        return "No login info available"
    }
}

# Get User Description
function Get-UserDescription($user) {
    $desc = (Get-WmiObject Win32_UserAccount | Where-Object { $_.Name -eq $user }).Description
    if ($null -ne $desc -and $desc -ne "") {
        return $desc
    } else {
        return "No Description"
    }
}

# Check if User is Active or Disabled
function Get-AccountStatus($user) {
    $status = (Get-WmiObject Win32_UserAccount | Where-Object { $_.Name -eq $user }).Disabled
    if ($status -eq $true) {
        return "Disabled"
    } else {
        return "Active"
    }
}

# Get Hostname
function Get-Hostname {
    return $env:COMPUTERNAME
}

# Get User Privileges
function Get-UserPrivileges($user) {
    $privileges = whoami /priv | Select-String "Enabled"
    if ($null -ne $privileges -and $privileges.Count -gt 0) {
        return ($privileges -split '\s{2,}')[0] -join ", "
    } else {
        return "None"
    }
}

# Get Last Password Change
function Get-LastPasswordChange($user) {
    $passwordInfo = Get-WmiObject Win32_UserAccount | Where-Object { $_.Name -eq $user } | Select-Object -ExpandProperty PasswordLastChanged
    if ($null -ne $passwordInfo -and $passwordInfo -ne "") {
        return $passwordInfo
    } else {
        return "Unknown"
    }
}

# Get User Group Memberships
function Get-UserGroups($user) {
    $groups = net user $user | Select-String "\*" | ForEach-Object { ($_ -split '\s{2,}')[1] }
    if ($null -ne $groups -and $groups.Count -gt 0) {
        return $groups -join ", "
    } else {
        return "None"
    }
}

# Save collected data to CSV
function Save-ToCSV($data, $hostname) {
    $filename = "Windows_OS_SOX.csv"
    if (Test-Path $filename) {
        Remove-Item $filename -Force
    }
    $data | Export-Csv -Path $filename -NoTypeInformation
    Write-Host "Data successfully saved to $filename"
}

# Main Execution
function Main {
    Write-Host "Collecting user information from Windows..."
    $hostname = Get-Hostname
    $users = Get-Users
    $os_platform = Get-Platform
    $timestamp = Get-DateTime

    $user_data = @()
    foreach ($user in $users) {
        $uid = Get-UID $user
        $last_login = Get-LastLogin $user
        $status = Get-AccountStatus $user
        $groups = Get-UserGroups $user
        $privileges = Get-UserPrivileges $user
        $password = Get-LastPasswordChange $user
        $description = Get-UserDescription $user
        
        $user_data += [PSCustomObject]@{
            Hostname = $hostname
            Platform = $os_platform
            Username = $user
            "User ID (SID)" = $uid
            "Last Login" = $last_login
            "Account Status" = $status
            "User Groups" = $groups
            Privileges = $privileges
            "Last Password Change" = $password
            Description = $description
        }
    }
    
    Write-Host "OS: $os_platform"
    Write-Host "Date: $timestamp"
    Write-Host "Users found: $($users.Count)"

    Save-ToCSV $user_data $hostname
}

Main
