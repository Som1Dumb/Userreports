# Define SQL Server Parameters
$ServerName = "YourServerName"  # Change to your SQL Server name
$Database = "master"  # Using the master database
$ExportPath = "C:\ExportedData\UserAudit.csv"  # Path where the CSV will be saved

# Define SQL Query
$SqlQuery = @"
DECLARE @CurrentDateTime DATETIME = GETUTCDATE();

WITH UserAudit AS (
    SELECT 
        SERVERPROPERTY('MachineName') AS Hostname,
        SERVERPROPERTY('Edition') AS SQLServerEdition,
        SERVERPROPERTY('ProductVersion') AS SQLServerVersion,
        SERVERPROPERTY('ProductLevel') AS SQLServerBuild,
        @CurrentDateTime AS CurrentDateUTC,
        sp.name AS Username,
        sp.sid AS User_SID,
        sp.create_date AS CreatedDate,
        sp.modify_date AS LastModifiedDate,
        sl.login_time AS LastLoginTime,
        CASE 
            WHEN sp.is_disabled = 1 THEN 'Disabled' 
            ELSE 'Active' 
        END AS AccountStatus,
        CASE 
            WHEN sp.is_policy_checked = 1 THEN 'Enforced' 
            ELSE 'Not Enforced' 
        END AS PasswordPolicyEnforced,
        CASE 
            WHEN sp.is_expiration_checked = 1 THEN 'Enforced' 
            ELSE 'Not Enforced' 
        END AS PasswordExpirationEnforced,
        sp.default_database_name AS DefaultDatabase,
        lsd.password_last_set_time AS LastPasswordChangeDate,
        CASE 
            WHEN lsd.is_locked = 1 THEN 'Locked' 
            ELSE 'Not Locked' 
        END AS AccountLockedStatus,
        STRING_AGG(sp2.name, ', ') AS ServerRoles
    FROM sys.server_principals sp
    LEFT JOIN sys.dm_exec_sessions sl ON sp.sid = sl.security_id
    LEFT JOIN sys.server_role_members srm ON sp.principal_id = srm.member_principal_id
    LEFT JOIN sys.server_principals sp2 ON srm.role_principal_id = sp2.principal_id
    LEFT JOIN sys.sql_logins lsd ON sp.principal_id = lsd.principal_id
    WHERE sp.type IN ('S', 'U')  -- 'S' = SQL User, 'U' = Windows User
    GROUP BY sp.name, sp.sid, sp.create_date, sp.modify_date, sp.is_disabled, sl.login_time,
             sp.is_policy_checked, sp.is_expiration_checked, sp.default_database_name,
             lsd.password_last_set_time, lsd.is_locked
)
SELECT * FROM UserAudit
ORDER BY Username;
"@

# Execute SQL Query and Export to CSV
try {
    Write-Host "Executing SQL query on $ServerName..."
    
    $Results = Invoke-Sqlcmd -ServerInstance $ServerName -Database $Database -Query $SqlQuery -TrustServerCertificate
    
    if ($Results) {
        # Ensure Export Directory Exists
        $ExportFolder = Split-Path $ExportPath -Parent
        if (!(Test-Path $ExportFolder)) {
            New-Item -ItemType Directory -Path $ExportFolder -Force | Out-Null
        }

        # Export Data to CSV
        Write-Host "Exporting data to $ExportPath..."
        $Results | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8

        Write-Host "Export Completed Successfully!"
    } else {
        Write-Host "No data returned from the SQL query."
    }
}
catch {
    Write-Host "An error occurred: $_"
}
