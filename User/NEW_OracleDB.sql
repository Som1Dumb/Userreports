-- Set environment for SQL*Plus
SET HEADING OFF
SET FEEDBACK OFF
SET LINESIZE 300
SET PAGESIZE 0
SET TERMOUT OFF
SET TRIMSPOOL ON

-- Define file name
COLUMN today_date NEW_VALUE date_str
COLUMN host_name NEW_VALUE host_str

-- Get system date and host name
SELECT TO_CHAR(SYSDATE, 'YYYY-MM-DD') AS today_date FROM DUAL;
SELECT SYS_CONTEXT('USERENV', 'HOST') AS host_name FROM DUAL;

-- Define the CSV file name
SPOOL users_list.csv

-- Print CSV headers
PROMPT "hostname, date, username, sid, last_login_date, last_login_time"

-- Fetch users, SID, and last login info
SELECT '"' || '&host_str' || '", "' || '&date_str' || '", "' 
       || s.USERNAME || '", "' 
       || s.SID || '", "' 
       || TO_CHAR(u.LAST_LOGIN, 'YYYY-MM-DD') || '", "' 
       || TO_CHAR(u.LAST_LOGIN, 'HH24:MI:SS') || '"'
FROM V$SESSION s
JOIN DBA_USERS u ON s.USERNAME = u.USERNAME
WHERE s.USERNAME IS NOT NULL
ORDER BY s.USERNAME, s.SID;

-- Stop spooling
SPOOL OFF

-- Reset SQL*Plus environment
SET HEADING ON
SET FEEDBACK ON
SET TERMOUT ON
