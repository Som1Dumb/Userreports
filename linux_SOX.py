#!/usr/bin/env python3

import subprocess
import csv
import sys
import os

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
        print(f"Błąd odczytu pliku: {e}")
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
    cmd = ''.join(["cat /etc/passwd | grep -w \"", user, "\" | awk -F: '{print $5}'"])
    description = subprocess.check_output(cmd, shell=True, universal_newlines=True).strip().replace("\n", ". ")
    return description

def get_lastLogin(user):
    output = subprocess.run(["lastlog", "-u", user], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True).stdout.strip()
    last = ' '.join(''.join(output).split('\n')[1].split(' ')[-6:]).strip().replace("\n", ". ")
    return last

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
    groups = subprocess.run(["groups", user], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True).stdout.strip()
    return groups.split(':')[1].strip()
 
def get_locked_status(user):
    cmd = "passwd -S " + user + " | awk '{print $2}'"
    return subprocess.check_output(cmd, shell=True, universal_newlines=True).strip()
 
# def get_privileges(user):
#     privs = subprocess.run(["sudo", "-l", "-U", user], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True).stdout.strip().split('\n')[4:]
#     legitPrivs = []
#     for priv in privs:
#         if "NOPASSWD" not in priv:
#             clean_priv = priv.strip().replace("ALL", "").strip()
#             if clean_priv:
#                 legitPrivs.append(clean_priv)
#     return ' '.join(legitPrivs)

def get_last_password_change(user):
    cmd = f"chage -l {user} | grep 'Last password change' | awk -F': ' '{{print $2}}'"
    last_change = subprocess.check_output(cmd, shell=True, universal_newlines=True).strip()
    return last_change
 
def save_to_csv(writeMode, filename, data):
    file_path = f"{filename}"
    
    with open(file_path, mode=writeMode, newline='') as file:
        writer = csv.writer(file)
        if writeMode == 'w':
            writer.writerow(data)
        else:
            writer.writerows(data)

def delete_existing(filename):
        file_path = f"{filename}"
        if os.path.exists(file_path):
            print(f"File {file_path} exists. Removing it...")
            os.remove(file_path)
            
# def get_description(user):
#     cmd = ''.join(["cat /etc/passwd | grep -w \"", user, "\" | awk -F: '{print $5}'"])
#     description = subprocess.check_output(cmd, shell=True, universal_newlines=True).strip()
#     return description
 
def main():
    hostname = subprocess.run("hostname", stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True).stdout.strip()
    users = get_users()
    platform = get_Platform()
 
    fileName = f"Linux_OS_SOX.csv"
    
    header = ["hostname", "platform", "user", "uid", "description", "password locked", "last password change", "last login", "groups", "privileges"]
 
    try:
        flag = sys.argv[1]
    except:
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
            print("It's only dry run. No data is saved.")
    
    if check_oracle_db():
        print("OracleDB detected.")
    else:
        print("OracleDB not detected.")

if __name__ == "__main__":
    main()
