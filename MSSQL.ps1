param (
    [string]$ServerName,  # SQL Server instance
    [string]$Database,    # Database name
    [string]$QueryFile = "MSSQL.sql"  # Default SQL query file
)

# Validate Parameters
if (-not $ServerName -or -not $Database) {
    Write-Host "Usage: .\Export-SQLDataToCSV.ps1 -ServerName YourServer -Database YourDatabase [-QueryFile YourSQLFile.sql]"
    exit
}

# Ensure the SQL query file exists
if (!(Test-Path $QueryFile)) {
    Write-Host "Error: Query file '$QueryFile' not found."
    exit
}

# Read the SQL query from file
$Query = Get-Content -Path $QueryFile -Raw

# Define output file (CSV)
$OutputFile = "C:\ExportedData\$env:COMPUTERNAME-MSSQL.csv"

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
    $SqlResults = Invoke-Sqlcmd -ServerInstance $ServerName -Database $Database -Query $Query -TrustServerCertificate

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
