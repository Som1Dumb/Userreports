-- Set SQL*Plus Output Formatting
SET PAGESIZE 50000
SET LINESIZE 300
SET TRIMSPOOL ON
SET TERMOUT ON
SET FEEDBACK OFF
SET COLSEP ','
SET LONG 100000  -- Allows large outputs for XMLAGG (CLOB format)

-- Define filename (Ensure no extra spaces in file name)
DEFINE FILENAME = 'Linux_OracleDB_SOX.csv'

-- Show the file path before spooling
PROMPT Exporting data to &FILENAME

-- Redirect output to the specified filename
SPOOL &FILENAME

-- Query for User Details including Hostname and Privileges
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

    -- Handling long role lists with XMLAGG
    (SELECT RTRIM(XMLAGG(XMLELEMENT(e, r.granted_role || '; ') ORDER BY r.granted_role).EXTRACT('//text()'), '; ')
     FROM dba_role_privs r WHERE r.grantee = u.username) AS User_Roles,

    -- Handling long privilege lists with XMLAGG
    (SELECT RTRIM(XMLAGG(XMLELEMENT(e, p.privilege || '; ') ORDER BY p.privilege).EXTRACT('//text()'), '; ')
     FROM dba_sys_privs p WHERE p.grantee = u.username) AS User_Privileges

FROM dba_users u
LEFT JOIN v$session s ON u.username = s.username

ORDER BY u.username;

-- Stop Writing to CSV
SPOOL OFF

-- Print the file location
PROMPT Data exported successfully to &FILENAME

-- Reset SQL*Plus Settings
SET TERMOUT ON
SET FEEDBACK ON
SET COLSEP ' '
