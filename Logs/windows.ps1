# Define Output File
$hostname = $env:COMPUTERNAME
$date = Get-Date -Format "yyyy-MM-dd"
$outputFile = "C:\Logs\os_log_review_$date.csv"

# Ensure Log Directory Exists
if (!(Test-Path "C:\Logs")) {
    New-Item -ItemType Directory -Path "C:\Logs"
}

# Function to Get Failed Logins
function Get-FailedLogins {
    Get-WinEvent -FilterHashtable @{
        LogName = "Security"
        ID = 4625   # Event ID for failed logins
    } -ErrorAction SilentlyContinue | ForEach-Object {
        [PSCustomObject]@{
            Hostname  = $hostname
            Date      = $_.TimeCreated.ToString("yyyy-MM-dd")
            Time      = $_.TimeCreated.ToString("HH:mm:ss")
            Username  = ($_ | Select-String -Pattern 'Account Name:\s+(\S+)' | ForEach-Object { $_.Matches.Groups[1].Value })
            EventType = "FAILED_LOGIN"
            Details   = $_.Message -replace "`r`n", " "
        }
    }
}

# Function to Get Sudo Equivalent (RunAs) Usage
function Get-RunAsUsage {
    Get-WinEvent -FilterHashtable @{
        LogName = "Security"
        ID = 4648  # Event ID for RunAs usage (Logon with explicit credentials)
    } -ErrorAction SilentlyContinue | ForEach-Object {
        [PSCustomObject]@{
            Hostname  = $hostname
            Date      = $_.TimeCreated.ToString("yyyy-MM-dd")
            Time      = $_.TimeCreated.ToString("HH:mm:ss")
            Username  = ($_ | Select-String -Pattern 'Account Name:\s+(\S+)' | ForEach-Object { $_.Matches.Groups[1].Value })
            EventType = "RUNAS_USAGE"
            Details   = $_.Message -replace "`r`n", " "
        }
    }
}

# Function to Get Administrator Privilege Usage
function Get-AdminPrivilegeUsage {
    Get-WinEvent -FilterHashtable @{
        LogName = "Security"
        ID = 4672  # Event ID for special privilege logon (Admin logins)
    } -ErrorAction SilentlyContinue | ForEach-Object {
        [PSCustomObject]@{
            Hostname  = $hostname
            Date      = $_.TimeCreated.ToString("yyyy-MM-dd")
            Time      = $_.TimeCreated.ToString("HH:mm:ss")
            Username  = ($_ | Select-String -Pattern 'Account Name:\s+(\S+)' | ForEach-Object { $_.Matches.Groups[1].Value })
            EventType = "ADMIN_PRIVILEGE_LOGIN"
            Details   = $_.Message -replace "`r`n", " "
        }
    }
}

# Collect and Export Data
$logs = @()
$logs += Get-FailedLogins
$logs += Get-RunAsUsage
$logs += Get-AdminPrivilegeUsage

$logs | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8

Write-Host "Log review report generated: $outputFile"
