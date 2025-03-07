# Define Output File
$hostname = $env:COMPUTERNAME
$date = Get-Date -Format "yyyy-MM-dd"
$outputFile = "C:\Logs\os_log_review_$date.csv"

# Ensure Log Directory Exists
if (!(Test-Path "C:\Logs")) {
    try {
        New-Item -ItemType Directory -Path "C:\Logs" -Force
    } catch {
        Write-Host "Error: Unable to create log directory. Check permissions."
        exit
    }
}

# Function to Check if Security Logs are Accessible
function Check-SecurityLog {
    try {
        Get-WinEvent -ListLog Security -ErrorAction Stop | Out-Null
        return $true
    } catch {
        Write-Host "Error: Cannot access Security logs. Ensure you have admin rights."
        return $false
    }
}

# Function to Get Failed Logins
function Get-FailedLogins {
    if (-not (Check-SecurityLog)) { return @() }
    Get-WinEvent -FilterHashtable @{
        LogName = "Security"
        ID = 4625  # Failed logins
    } -ErrorAction SilentlyContinue | ForEach-Object {
        [PSCustomObject]@{
            Hostname  = $hostname
            Date      = $_.TimeCreated.ToString("yyyy-MM-dd")
            Time      = $_.TimeCreated.ToString("HH:mm:ss")
            Username  = if ($_.Properties.Count -gt 5) { $_.Properties[5].Value } else { "UNKNOWN" }
            EventType = "FAILED_LOGIN"
            Details   = ($_.Message -replace "`r`n", " ")
        }
    }
}

# Function to Get RunAs (Explicit Credentials) Usage
function Get-RunAsUsage {
    if (-not (Check-SecurityLog)) { return @() }
    Get-WinEvent -FilterHashtable @{
        LogName = "Security"
        ID = 4648  # Logon with explicit credentials
    } -ErrorAction SilentlyContinue | ForEach-Object {
        [PSCustomObject]@{
            Hostname  = $hostname
            Date      = $_.TimeCreated.ToString("yyyy-MM-dd")
            Time      = $_.TimeCreated.ToString("HH:mm:ss")
            Username  = if ($_.Properties.Count -gt 5) { $_.Properties[5].Value } else { "UNKNOWN" }
            EventType = "RUNAS_USAGE"
            Details   = ($_.Message -replace "`r`n", " ")
        }
    }
}

# Function to Get Administrator Privilege Usage
function Get-AdminPrivilegeUsage {
    if (-not (Check-SecurityLog)) { return @() }
    Get-WinEvent -FilterHashtable @{
        LogName = "Security"
        ID = 4672  # Special privilege logon (Admin logins)
    } -ErrorAction SilentlyContinue | ForEach-Object {
        [PSCustomObject]@{
            Hostname  = $hostname
            Date      = $_.TimeCreated.ToString("yyyy-MM-dd")
            Time      = $_.TimeCreated.ToString("HH:mm:ss")
            Username  = if ($_.Properties.Count -gt 5) { $_.Properties[5].Value } else { "UNKNOWN" }
            EventType = "ADMIN_PRIVILEGE_LOGIN"
            Details   = ($_.Message -replace "`r`n", " ")
        }
    }
}

# Collect and Export Data
$logs = @()
$logs += Get-FailedLogins
$logs += Get-RunAsUsage
$logs += Get-AdminPrivilegeUsage

# Export CSV only if logs exist
if ($logs.Count -gt 0) {
    $logs | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
    Write-Host "Log review report generated: $outputFile"
} else {
    Write-Host "No relevant log events found."
}
