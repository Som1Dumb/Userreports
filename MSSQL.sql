-- Set UTC Date Time
DECLARE @CurrentDateTime DATETIME = GETUTCDATE();

-- Create a Temporary Table to Store Results
IF OBJECT_ID('tempdb..#UserAudit') IS NOT NULL
    DROP TABLE #UserAudit;

CREATE TABLE #UserAudit (
    Hostname NVARCHAR(255),
    SQLServerEdition NVARCHAR(255),
    SQLServerVersion NVARCHAR(255),
    SQLServerBuild NVARCHAR(255),
    CurrentDateUTC DATETIME,
    Username NVARCHAR(255),
    User_SID VARBINARY(85),
    CreatedDate DATETIME,
    LastModifiedDate DATETIME,
    LastLoginTime DATETIME NULL,
    AccountStatus NVARCHAR(50),
    PasswordPolicyEnforced NVARCHAR(50),
    PasswordExpirationEnforced NVARCHAR(50),
    DefaultDatabase NVARCHAR(255),
    LastPasswordChangeDate DATETIME NULL,
    AccountLockedStatus NVARCHAR(50),
    ServerRoles NVARCHAR(MAX)
);

-- Insert System and User Information into Temporary Table
INSERT INTO #UserAudit
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
ORDER BY sp.name;

-- Export Data to CSV using BCP
DECLARE @SQLCmd NVARCHAR(MAX);
SET @SQLCmd = 'bcp "SELECT * FROM tempdb..#UserAudit" queryout "C:\ExportedData\UserAudit.csv" -c -t, -T -S ' + @@SERVERNAME;

EXEC xp_cmdshell @SQLCmd;

-- Clean Up: Drop Temporary Table
DROP TABLE #UserAudit;
