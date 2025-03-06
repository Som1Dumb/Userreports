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
    
    $user_data += [PSCustomObject]@{
        Hostname = $hostname
        Platform = $os_platform
        Username = $user
        "User ID (SID)" = $uid
        "Account Status" = $status
    }
}

    
    Write-Host "OS: $os_platform"
    Write-Host "Date: $timestamp"
    Write-Host "Users found: $($users.Count)"

    Save-ToCSV $user_data
}

Main
