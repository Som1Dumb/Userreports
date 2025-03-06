param (
    [string]$QueryFile = "MSSQL.sql"  # Default SQL query file
)

# Check if MSSQL is installed via registry
$SqlServer = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server" -ErrorAction SilentlyContinue

if ($SqlServer) {
    Write-Host "MSSQL is installed. Proceeding with SQL execution..."
    
    # Auto-detect the Server Name (assumes default instance)
    $ServerName = "$env:COMPUTERNAME"
    
    # Attempt to get the default database dynamically
    $Database="master"
    
    # Validate Database
    if (-not $Database) {
        Write-Host "Error: No default database found on server '$ServerName'."
        exit
    }

    Write-Host "Using Server: $ServerName, Database: $Database"

    # Ensure the SQL query file exists
    if (!(Test-Path $QueryFile)) {
        Write-Host "Error: Query file '$QueryFile' not found."
        exit
    }

    # Read the SQL query from file
    $Query = Get-Content -Path $QueryFile -Raw

    # Define output file (CSV) in the current working directory
    $OutputFile = "Windows_MSSQL_SOX.csv"

    # If the CSV file exists, delete it
    if (Test-Path $OutputFile) {
        Remove-Item $OutputFile -Force
        Write-Host "Old CSV file deleted: $OutputFile"
    }

    # Run the SQL Query and fetch results
    try {
        $SqlResults = Invoke-Sqlcmd -ServerInstance $ServerName -Database $Database -Query $Query 

        # Check if data was retrieved
        if ($SqlResults) {
            # Export to CSV
            $SqlResults | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
            Write-Host "Export successful! New file saved at: $OutputFile"
        } else {
            Write-Host "No data returned from SQL query."
        }
    } catch {
        Write-Host "Error running SQL query: $_"
    }
} else {
    Write-Host "MSSQL is not installed. Exiting script."
}

# Save collected data to CSV in the current working directory
function Save-ToCSV($data) {
    $filename = "Windows_OS_SOX.csv"
    if (Test-Path $filename) {
        Remove-Item $filename -Force
    }
    $data | Export-Csv -Path $filename -NoTypeInformation
    Write-Host "Data successfully saved to $filename"
}

# Get user group memberships
function Get-UserGroups($user) {
    $groups = net user $user | Select-String "\*" | ForEach-Object { ($_ -split '\s{2,}')[1] }
    if ($groups) { return $groups -join ", " } else { return "None" }
}

# Get user privileges
function Get-UserPrivileges($user) {
    $privileges = whoami /priv | Select-String "Enabled"
    if ($privileges) { return ($privileges -split '\s{2,}')[0] -join ", " } else { return "None" }
}

# Get last login timestamp in human-readable format
function Get-LastLogin($user) {
    try {
        $domain = (Get-WmiObject Win32_ComputerSystem).Domain
        $userVariants = @($user, "$domain\$user")  # Check both formats

        # Search Security Log for Logon Event (ID 4624) excluding SYSTEM and NETWORK logins
        $event = Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4624} -MaxEvents 500 |
                 Where-Object {
                     ($userVariants -contains $_.Properties[5].Value -or $userVariants -contains $_.Properties[6].Value) -and
                     ($_.Properties[8].Value -ne "127.0.0.1") # Exclude local logins like SYSTEM
                 } |
                 Select-Object -First 1

        # Return formatted date-time if found
        if ($event) {
            return $event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
        } else {
            return "No login info available"
        }
    } catch {
        return "No login info available"
    }
}


# Main Execution
function Main {
    Write-Host "Collecting user information from Windows..."
    $hostname = $env:COMPUTERNAME
    $users = Get-WmiObject Win32_UserAccount | Where-Object { $_.LocalAccount -eq $true } | Select-Object -ExpandProperty Name
    $os_platform = (Get-CimInstance Win32_OperatingSystem).Caption
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"

    $user_data = @()
    foreach ($user in $users) {
        $uid = (Get-WmiObject Win32_UserAccount | Where-Object { $_.Name -eq $user }).SID
        $status = (Get-WmiObject Win32_UserAccount | Where-Object { $_.Name -eq $user }).Disabled
        $status = if ($status -eq $true) { "Disabled" } else { "Active" }
        $groups = Get-UserGroups $user
        $privileges = Get-UserPrivileges $user
        $last_login = Get-LastLogin $user

        $user_data += [PSCustomObject]@{
            Hostname = $hostname
            Platform = $os_platform
            Username = $user
            "User ID (SID)" = $uid
            "Account Status" = $status
            "User Groups" = $groups
            "Privileges" = $privileges
            "Last Login" = $last_login
        }
    }
    
    Write-Host "OS: $os_platform"
    Write-Host "Date: $timestamp"
    Write-Host "Users found: $($users.Count)"

    Save-ToCSV $user_data
}

Main
