import subprocess
import csv
import datetime
import os
import socket

# Get Current Date & Time
def getDate():
    return datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")

# Get OS Name & Version
def get_Platform():
    try:
        platform = subprocess.run(["wmic", "os", "get", "Caption,Version"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        lines = platform.stdout.split("\n")
        os_info = [line.strip() for line in lines if line.strip()]
        return f"{os_info[1]}" if len(os_info) > 1 else "Unknown"
    except Exception as e:
        return f"Error: {str(e)}"

# Get List of Local Users
def get_users():
    try:
        users_output = subprocess.run(["wmic", "useraccount", "get", "name"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        users = users_output.stdout.strip().split("\n")[1:]  # Skip Header
        return [user.strip() for user in users if user.strip()]
    except Exception as e:
        return [f"Error: {str(e)}"]

# Get User ID (SID) in Windows
def get_UID(user):
    try:
        uid_output = subprocess.run(["wmic", "useraccount", "where", f"name='{user}'", "get", "SID"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        lines = uid_output.stdout.strip().split("\n")
        return lines[1].strip() if len(lines) > 1 else "N/A"
    except Exception as e:
        return f"Error: {str(e)}"

# Get Last Login Time
def get_lastLogin(user):
    try:
        login_output = subprocess.run(["net", "user", user], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        lines = login_output.stdout.split("\n")
        for line in lines:
            if "Last logon" in line:
                return line.split("Last logon")[1].strip()
        return "No login info available"
    except Exception as e:
        return f"Error: {str(e)}"

# Check if User is Active or Disabled
def get_account_status(user):
    try:
        status_output = subprocess.run(["wmic", "useraccount", "where", f"name='{user}'", "get", "Disabled"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        lines = status_output.stdout.strip().split("\n")
        if len(lines) > 1:
            return "Disabled" if "TRUE" in lines[1] else "Active"
        return "Unknown"
    except Exception as e:
        return f"Error: {str(e)}"
    
def get_hostname():
    try:
        return socket.gethostname()
    except Exception as e: 
        return f"Error: {str(e)}"

def get_user_privileges(user):
    try:
        privileges_output = subprocess.run(["whoami", "/priv"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        print(privileges_output)
        print(type(privileges_output))
        lines = privileges_output.stdout.split("\n")
        print(lines)
        privs=[]
        for line in lines:
            print(line)
            if "Enabled" in line:
                priv = line.split()[0]
                privs.append(priv)
        return ", ".join(privs) if privs else "None"
    except Exception as e:
        return f"Error: {str(e)}"
def get_last_password_change(user):
    try:
        password=subprocess.run(["wmic", "useraccount", "where", f"name='{user}'", "get", "PasswordLastSet"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        lines=password.stdout.strip().split("\n")
        return lines[1].strip() if len(lines)>1 else "Unknown"
    except Exception as e:
        return f"Error: {str(e)}"
# Get User Group Memberships
def get_user_groups(user):
    try:
        groups_output = subprocess.run(["net", "user", user], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        lines = groups_output.stdout.split("\n")
        group_line = False
        groups = []
        # print(lines)
        for line in lines:
            # print(line)
            if "Local Group Memberships" in line or "Global Group memberships" in line:
                group_line = True
                # print(line)
                line=line.replace("Local Group Memberships","")
                line=line.replace("Global Group memberships","")
                # print(line)
                groups.append(line)
                continue
            # print(line)
            # print(group_line)
            # if group_line:
            #     groups.append(line)
            # print(groups)
            group_line=False
        return ", ".join(groups) if groups else "None"
    except Exception as e:
        return f"Error: {str(e)}"

# Save collected data to CSV
def save_to_csv(data, filename="windows_user_info.csv"):
    headers = ["Hostname","Platform","Username", "User ID (SID)", "Last Login", "Account Status", "User Groups", "Priveleges", "Last Password Change"]
    with open(filename, mode="w", newline="") as file:
        writer = csv.writer(file)
        writer.writerow(headers)
        writer.writerows(data)
    print(f"Data successfully saved to {filename}")

# Collecting Data
def main():
    print("Collecting user information from Windows...")
    hostname=get_hostname()
    users = get_users()
    os_platform = get_Platform()
    timestamp = getDate()
    
    user_data = []
    for user in users:
        uid = get_UID(user)
        last_login = get_lastLogin(user)
        status = get_account_status(user)
        groups = get_user_groups(user)
        privileges = get_user_privileges(user)
        password=get_last_password_change(user)
        user_data.append([hostname, os_platform, user, uid, last_login, status, groups, privileges, password])

    # Print summary
    print(f"OS: {os_platform}")
    print(f"Date: {timestamp}")
    print(f"Users found: {len(users)}")

    # Save to CSV
    save_to_csv(user_data)

if __name__ == "__main__":
    main()
