-- Set SQL*Plus Output Formatting
SET PAGESIZE 50000
SET LINESIZE 300
SET TRIMSPOOL ON
SET TERMOUT ON
SET FEEDBACK OFF
SET COLSEP ','
SET LONG 100000  -- Allow long CLOB outputs for XMLAGG

-- Define the directory where the file should be saved (Modify as needed)
DEFINE FILENAME = 'Linux_OracleDB_SOX.csv'  -- Static filename

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

    -- Using XMLAGG to handle long lists without ORA-01489
    (SELECT RTRIM(XMLAGG(XMLELEMENT(e, r.granted_role || '; ') ORDER BY r.granted_role).EXTRACT('//text()'), '; ') 
     FROM dba_role_privs r WHERE r.grantee = u.username) AS User_Roles,

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
