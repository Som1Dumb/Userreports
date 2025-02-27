#!/usr/bin/env python3


import subprocess
import csv
import sys
import os
import argparse

# Define the path to the Oracle query file
ORACLE_QUERY_FILE = "OracleDB.sql"

def getDate():
    return subprocess.run(["date", "-u", "+%FT%TZ"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True).stdout.strip()

def get_users():
    users = []
    try:
        with open('/etc/passwd', 'r') as passwdFile:
            for line in passwdFile:
                userName = line.strip().split(':')[0]
                users.append(userName)
    except Exception as e:
        print(f"Error reading file: {e}")
    return users

def get_Platform():
    return subprocess.check_output("awk -F= 'NR==4{print $2}' /etc/os-release", shell=True, universal_newlines=True).strip()

def get_UID(user):
    return subprocess.run(["id", "-u", user], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True).stdout.strip()

def get_lastLogin(user):
    output = subprocess.run(["lastlog", "-u", user], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True).stdout.strip()
    lastlog_lines = output.split("\n")
    return ' '.join(lastlog_lines[1].split()[-6:]).strip() if len(lastlog_lines) > 1 else "Never logged in"

def get_groups(user):
    groups = subprocess.run(["groups", user], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True).stdout.strip()
    return groups.split(':')[1].strip() if ':' in groups else "No groups"

def get_locked_status(user):
    cmd = f"passwd -S {user} | awk '{{print $2}}'"
    return subprocess.check_output(cmd, shell=True, universal_newlines=True).strip()

def get_privileges(user):
    privs = subprocess.run(["sudo", "-l", "-U", user], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True).stdout.strip().split('\n')[4:]
    legitPrivs = []
    
    for priv in privs:
        if "NOPASSWD" not in priv:
            clean_priv = priv.replace("ALL", "").strip()
            clean_priv = ' '.join(clean_priv.split())  # Normalize spaces
            if clean_priv:
                legitPrivs.append(clean_priv)
    
    return ' '.join(legitPrivs)

def save_to_csv(writeMode, filename, data):
    with open(filename, mode=writeMode, newline='') as file:
        writer = csv.writer(file)
        if writeMode == 'w':
            writer.writerow(data)
        else:
            writer.writerows(data)

def get_description(user):
    cmd = f"cat /etc/passwd | grep -w \"{user}\" | awk -F: '{{print $5}}'"
    return subprocess.check_output(cmd, shell=True, universal_newlines=True).strip()

def check_oracle_db():
    """Detects if OracleDB is installed by checking common locations"""
    oracle_paths = ["/etc/oratab", "/u01/app/oracle", "/usr/lib/oracle", "/opt/oracle"]
    for path in oracle_paths:
        if os.path.exists(path):
            return True
    return False

def read_oracle_query():
    """Reads the SQL query from a file."""
    if os.path.exists(ORACLE_QUERY_FILE):
        with open(ORACLE_QUERY_FILE, 'r') as file:
            return file.read().strip()
    else:
        print(f"Oracle query file '{ORACLE_QUERY_FILE}' not found.")
        return None

def execute_oracle_query(db_user, db_password, db_host, db_service):
    """Executes an Oracle SQL query from a file and saves results to CSV."""
    query = read_oracle_query()
    if not query:
        print("No valid Oracle query found. Skipping execution.")
        return

    sqlplus_cmd = f'echo "{query}" | sqlplus -s {db_user}/{db_password}@{db_host}/{db_service}'

    try:
        output = subprocess.check_output(sqlplus_cmd, shell=True, universal_newlines=True).strip()
        
        # Process SQL output into CSV format
        lines = output.split("\n")
        data = [line.split() for line in lines if line.strip()]
        
        hostname = subprocess.run("hostname", stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True).stdout.strip()
        date = getDate()
        filename = f"{hostname}-OracleDB-Report-{date}.csv"
        
        # Save results to CSV
        save_to_csv('w', filename, ["Column1", "Column2"])  # Replace with actual headers
        save_to_csv('a', filename, data)  # Save query results

        print(f"OracleDB report saved as {filename}")

    except subprocess.CalledProcessError as e:
        print(f"Error executing Oracle query: {e}")

def main():
    # Argument parser for OracleDB credentials
    parser = argparse.ArgumentParser(description="SOX Report Generator with OracleDB Query Execution")
    parser.add_argument("--db-user", required=True, help="OracleDB username")
    parser.add_argument("--db-password", required=True, help="OracleDB password")
    parser.add_argument("--db-host", required=True, help="OracleDB host")
    parser.add_argument("--db-service", required=True, help="OracleDB service")

    args = parser.parse_args()

    hostname = subprocess.run("hostname", stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True).stdout.strip()
    users = get_users()
    platform = get_Platform()
    date = getDate()
    fileName = f"{hostname}_SOX_report_{date}.csv"

    for us in users:
        print(us + " " + get_privileges(us))

    header = ["hostname", "platform", "user", "uid", "description", "password locked", "last login", "groups", "privileges"]

    try:
        flag = sys.argv[1]  
    except IndexError:      
        print("Gathering data...")
        save_to_csv('w', fileName, header)
        rows = []
        for user in users:
            row = [
                hostname,
                platform[1:-1],
                user,
                get_UID(user),
                get_description(user),
                get_locked_status(user),
                get_lastLogin(user),
                get_groups(user),
                get_privileges(user)
            ]
            rows.append(row)
        save_to_csv('a', fileName, rows)
        print("Data saved in CSV file.")
    else:
        if flag == "-dry":
            print("It's only a dry run. No data is saved.")

    # Check for OracleDB and execute the query if found
    if check_oracle_db():
        print("OracleDB detected. Running query from file...")
        execute_oracle_query(args.db_user, args.db_password, args.db_host, args.db_service)
    else:
        print("OracleDB not detected.")

if __name__ == "__main__":
    main()
