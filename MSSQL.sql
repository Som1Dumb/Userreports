-- Set UTC Date Time
DECLARE @CurrentDateTime DATETIME = GETUTCDATE();
DECLARE @Hostname NVARCHAR(255) = CONVERT(NVARCHAR(255), SERVERPROPERTY('MachineName'));
DECLARE @FilePath NVARCHAR(255) = 'C:\ExportedData\' + @Hostname + '-MSSQL.csv';

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
    DefaultDatabase NVARCHAR(255),
    ServerRoles NVARCHAR(MAX)
);

-- Insert System and User Information into Temporary Table
INSERT INTO #UserAudit (
    Hostname, 
    SQLServerEdition, 
    SQLServerVersion, 
    SQLServerBuild, 
    CurrentDateUTC, 
    Username, 
    User_SID, 
    CreatedDate, 
    LastModifiedDate, 
    LastLoginTime, 
    AccountStatus, 
    DefaultDatabase, 
    ServerRoles
)
SELECT 
    @Hostname AS Hostname,
    CONVERT(NVARCHAR(255), SERVERPROPERTY('Edition')) AS SQLServerEdition,
    CONVERT(NVARCHAR(255), SERVERPROPERTY('ProductVersion')) AS SQLServerVersion,
    CONVERT(NVARCHAR(255), SERVERPROPERTY('ProductLevel')) AS SQLServerBuild,
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
    sp.default_database_name AS DefaultDatabase,
    -- Alternative for STRING_AGG: Using STUFF with FOR XML PATH to concatenate roles
    STUFF(
        (SELECT ', ' + sp2.name
         FROM sys.server_role_members srm
         INNER JOIN sys.server_principals sp2 ON srm.role_principal_id = sp2.principal_id
         WHERE srm.member_principal_id = sp.principal_id
         FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 
        1, 2, '') AS ServerRoles
FROM sys.server_principals sp
LEFT JOIN sys.dm_exec_sessions sl ON sp.sid = sl.security_id
WHERE sp.type IN ('S', 'U')  -- 'S' = SQL User, 'U' = Windows User
ORDER BY sp.name;

-- Check Results: Display the Data Before Exporting
SELECT * FROM #UserAudit;

-- Export Data to CSV using BCP
DECLARE @SQLCmd NVARCHAR(MAX);
DECLARE @SQLCmd_VARCHAR VARCHAR(MAX);  -- Declare as VARCHAR for xp_cmdshell

-- Ensure conversion to VARCHAR(MAX)
SET @SQLCmd = 'bcp "SELECT * FROM tempdb..#UserAudit" queryout "' + @FilePath + '" -c -t, -T -S ' + CAST(@@SERVERNAME AS NVARCHAR(255));

-- Convert NVARCHAR to VARCHAR explicitly
SET @SQLCmd_VARCHAR = CAST(@SQLCmd AS VARCHAR(MAX));

-- Debugging: Print the SQL Command (Check if the command looks correct)
PRINT @SQLCmd_VARCHAR;

-- Execute the command using xp_cmdshell
EXEC xp_cmdshell @SQLCmd_VARCHAR;

-- Clean Up: Drop Temporary Table
DROP TABLE #UserAudit;
