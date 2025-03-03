-- Set SQL*Plus Output Formatting
SET PAGESIZE 50000
SET LINESIZE 300
SET TRIMSPOOL ON
SET TERMOUT OFF
SET FEEDBACK OFF
SET COLSEP ','

-- Define the directory where the file should be saved (Modify as needed)
DEFINE FILEPATH = '/reports_tst/'  -- Change this to your desired location
DEFINE FILENAME = 'Linux_OracleDB_SOX.csv'  -- Static filename

-- Show the file path before spooling
PROMPT Exporting data to &FILEPATH&FILENAME

-- Redirect output to the specified filename
SPOOL &FILEPATH&FILENAME

-- Query for User Details including Hostname
SELECT 
    SYS_CONTEXT('USERENV', 'HOST') AS Hostname,
    u.username AS Username,
    u.user_id AS User_SID,
    u.account_status AS Account_Status,
    NVL(TO_CHAR(u.lock_date, 'YYYY-MM-DD HH24:MI:SS'), 'N/A') AS Account_Lock_Date,
    NVL(TO_CHAR(u.expiry_date, 'YYYY-MM-DD HH24:MI:SS'), 'N/A') AS Password_Expiry_Date,
    u.profile AS User_Profile,
    u.default_tablespace AS Default_Tablespace,
    TO_CHAR(u.created, 'YYYY-MM-DD HH24:MI:SS') AS Created_Date,
    u.initial_rsrc_consumer_group AS Resource_Group,
    NVL(TO_CHAR(s.logon_time, 'YYYY-MM-DD HH24:MI:SS'), 'N/A') AS Last_Login_Time,
    LISTAGG(r.granted_role, '; ') WITHIN GROUP (ORDER BY r.granted_role) AS User_Roles
FROM dba_users u
LEFT JOIN dba_role_privs r ON u.username = r.grantee
LEFT JOIN v$session s ON u.username = s.username
GROUP BY SYS_CONTEXT('USERENV', 'HOST'), u.username, u.user_id, u.account_status, u.lock_date, 
         u.expiry_date, u.profile, u.default_tablespace, u.created, u.initial_rsrc_consumer_group, s.logon_time
ORDER BY u.username;

-- Stop Writing to CSV
SPOOL OFF

-- Print the file location
PROMPT Data exported successfully to &FILEPATH&FILENAME

-- Reset SQL*Plus Settings
SET TERMOUT ON
SET FEEDBACK ON
SET COLSEP ' '
