#!/usr/bin/env python3

import subprocess
import csv
import sys
import os

def run_linux_SOX():
    """Runs linux_SOX.py script"""
    try:
        print("Running linux_SOX.py...")
        subprocess.run(["./linux_SOX.py"], check=True)
    except Exception as e:
        print(f"Error running linux_SOX.py: {e}")

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
    platform = subprocess.check_output("awk -F= 'NR==4{print $2}' /etc/os-release", shell=True, universal_newlines=True).strip()
    return platform
 
def get_UID(user):
    return subprocess.run(["id", "-u", user], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True).stdout.strip()

def check_oracle_db():
    """Detects if OracleDB is installed by checking common locations"""
    oracle_paths = ["/etc/oratab", "/u01/app/oracle", "/usr/lib/oracle", "/opt/oracle"]
    for path in oracle_paths:
        if os.path.exists(path):
            return True
    return False

def get_description(user):
    cmd = f"getent passwd {user} | awk -F: '{{print $5}}'"
    try:
        description = subprocess.check_output(cmd, shell=True, universal_newlines=True).strip()
        return description.replace("\n", ". ")
    except subprocess.CalledProcessError:
        return "No description"

def get_lastLogin(user):
    try:
        output = subprocess.run(["lastlog", "-u", user], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True).stdout.strip()
        last = ' '.join(''.join(output).split('\n')[1].split(' ')[-6:]).strip().replace("\n", ". ")
        return last
    except Exception:
        return "No login data"

def get_privileges(user):
    try:
        result = subprocess.run(["sudo", "-l", "-U", user], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
        output = result.stdout.strip()

        if "may run the following commands" not in output:
            return "No sudo privileges"

        privileges = []
        lines = output.split("\n")
        for line in lines:
            line = line.strip()
            if line.startswith("User") or line.startswith("Matching") or "may run the following" in line:
                continue  # Skip irrelevant lines

            if line:
                privileges.append(line)

        return ' '.join(privileges) if privileges else "No specific privileges"

    except Exception as e:
        return f"Error retrieving privileges: {e}"

def get_groups(user):
    try:
        groups = subprocess.run(["groups", user], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True).stdout.strip()
        return groups.split(':')[1].strip()
    except Exception:
        return "No groups"
 
def get_locked_status(user):
    cmd = f"passwd -S {user} | awk '{{print $2}}'"
    try:
        return subprocess.check_output(cmd, shell=True, universal_newlines=True).strip()
    except subprocess.CalledProcessError:
        return "Unknown"
 
def get_last_password_change(user):
    cmd = f"chage -l {user} | grep 'Last password change' | awk -F': ' '{{print $2}}'"
    try:
        return subprocess.check_output(cmd, shell=True, universal_newlines=True).strip()
    except subprocess.CalledProcessError:
        return "Unknown"
 
def save_to_csv(writeMode, filename, data):
    file_path = filename
    
    with open(file_path, mode=writeMode, newline='') as file:
        writer = csv.writer(file)
        if writeMode == 'w':
            writer.writerow(data)
        else:
            writer.writerows(data)

def delete_existing(filename):
    file_path = filename
    if os.path.exists(file_path):
        print(f"File {file_path} exists. Removing it...")
        os.remove(file_path)

def setup_oracle_environment():
    """Creates directory, sets permissions, and runs SQL script if Oracle is installed."""
    print("Setting up Oracle environment...")
    
    # Create /report_tst directory
    try:
        os.makedirs("/report_tst", exist_ok=True)
        subprocess.run(["chown", "oradyn", "/report_tst"], check=True)
    except Exception as e:
        print(f"Error setting up directory: {e}")

    # Run SQL script as oradyn
    try:
        sql_command = """
        sudo -u oradyn bash -c 'sqlplus / as sysdba <<SQL
        @export_users.sql
        exit;
SQL'
        """
        subprocess.run(sql_command, shell=True, check=True)
        print("SQL script executed.")
    except subprocess.CalledProcessError as e:
        print(f"Error running SQL script: {e}")

def main():
    # Always run linux_SOX.py
    run_linux_SOX()

    hostname = subprocess.run("hostname", stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True).stdout.strip()
    users = get_users()
    platform = get_Platform()
 
    fileName = "Linux_OS_SOX.csv"
    
    header = ["hostname", "platform", "user", "uid", "description", "password locked", "last password change", "last login", "groups", "privileges"]
 
    try:
        flag = sys.argv[1]
    except IndexError:
        delete_existing(fileName)
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
                get_last_password_change(user),
                get_lastLogin(user),
                get_groups(user),
                get_privileges(user)
            ]
            rows.append(row)
        save_to_csv('a', fileName, rows)
        print("Data saved in CSV file.")
    else:
        if flag == "-dry":
            print("Dry run mode. No data saved.")

    if check_oracle_db():
        print("OracleDB detected. Setting up environment...")
        setup_oracle_environment()
    else:
        print("OracleDB not detected.")

if __name__ == "__main__":
    main()
