import subprocess
import csv
import sys
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
    platform = ""
    platform = subprocess.check_output("awk -F= 'NR==4{print $2}' /etc/os-release", shell=True, universal_newlines=True).strip()
    return platform
 
def get_UID(user):
    return subprocess.run(["id", "-u", user], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True).stdout.strip()
 
def get_lastLogin(user):
    output = subprocess.run(["lastlog", "-u", user], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True).stdout.strip()
    last = ' '.join(''.join(output).split('\n')[1].split(' ')[-6:]).strip()
    return last
 
def get_groups(user):
    groups = subprocess.run(["groups", user], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True).stdout.strip()
    return groups.split(':')[1].strip()
 
def get_locked_status(user):
    cmd = "passwd -S " + user + " | awk '{print $2}'"
    return subprocess.check_output(cmd, shell=True, universal_newlines=True).strip()
 
def get_privileges(user): #przemyslec czy chcemy pokazywac klientowi NOPASSWD:ALL!!!
    privs = subprocess.run(["sudo", "-l", "-U", user], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True).stdout.strip().split('\n')[4:]
    legitPrivs = []
    for priv in privs:
        if "NOPASSWD" not in priv:
            legitPrivs.append(priv.strip())
    return ' '.join(legitPrivs)
 
def save_to_csv(writeMode, filename, data):
    #writeMode 'w' - write headers row to csv file
    #writeMode 'a' - append multiple data rows to csv file
    with open(filename, mode=writeMode, newline='') as file:
        writer = csv.writer(file)
        if writeMode == 'w':
            writer.writerow(data)
        else:
            writer.writerows(data)
 
def get_description(user):
    cmd = ''.join(["cat /etc/passwd | grep -w \"", user, "\" | awk -F: '{print $5}'"])
    description = subprocess.check_output(cmd, shell=True, universal_newlines=True).strip()
    return description
 
def main():
    hostname = subprocess.run("hostname", stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True).stdout.strip()
    users = get_users()
    platform = get_Platform()
 
    #name of generated csv file
    date = getDate() + ".csv"
    fileName = '_'.join([hostname, "SOX", "report", date])
 
    for us in users:
        print(us + " " + get_privileges(us))#jeszcze pracuje
   
   
    #in case of ading new column to report - add header below
    header = ["hostname", "platform", "user", "uid", "description", "password locked", "last login", "groups", "privileges"]
 
    try:
        flag = sys.argv[1] # -dry argument determines if data is really saved or it's just a test
    except:      
        print("Gathering data...")
        save_to_csv('w', fileName, header)
        rows = []
        for user in users:
            row = []
            row.append(hostname)
            row.append(platform[1:-1])
            row.append(user)
            row.append(get_UID(user))
            row.append(get_description(user))
            row.append(get_locked_status(user))
            row.append(get_lastLogin(user))
            row.append(get_groups(user))
            row.append(get_privileges(user))
 
            rows.append(row) #merging user properties to single row
        save_to_csv('a', fileName, rows)
        print("Data saved in CSV file.")
    else:
        if flag == "-dry":
            print("It's only dry run. No data is saved.")
 
if __name__ == "__main__":
    main()
 