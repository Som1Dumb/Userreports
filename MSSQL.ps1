param (
    [string]$QueryFile = "MSSQL.sql"  # Default SQL query file
)

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

# Define output file (CSV)
$OutputFile = "C:\ExportedData\$ServerName-MSSQL.csv"

# Ensure the ExportedData directory exists
if (!(Test-Path "C:\ExportedData")) {
    New-Item -ItemType Directory -Path "C:\ExportedData"
}

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
