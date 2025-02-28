import os
import subprocess
import pyodbc
import datetime
import socket

# Paths to files
sox_script = r"windows_SOX.py"  # Update this path
sql_script = r"MSSQL.sql"       # Update this path

# Step 1: Run the windows_SOX.py script
try:
    subprocess.run(["python", sox_script], check=True)
    print("Successfully executed windows_SOX.py")
except subprocess.CalledProcessError as e:
    print(f"Error running windows_SOX.py: {e}")

# Step 2: Check if MSSQL is installed
def check_mssql():
    try:
        # Attempt to connect to the default SQL Server instance
        conn = pyodbc.connect('DRIVER={SQL Server};SERVER=localhost;Trusted_Connection=yes;')
        conn.close()
        return True
    except Exception as e:
        print(f"MSSQL not found: {e}")
        return False

# Step 3: If MSSQL is installed, execute SQL and save to CSV
if check_mssql():
    try:
        # Connect to MSSQL
        conn = pyodbc.connect('DRIVER={SQL Server};SERVER=localhost;Trusted_Connection=yes;')
        cursor = conn.cursor()

        # Read SQL script
        with open(sql_script, 'r') as file:
            sql_query = file.read()

        # Execute query
        cursor.execute(sql_query)

        # Fetch data
        columns = [column[0] for column in cursor.description]
        rows = cursor.fetchall()

        # Get hostname and date
        hostname = socket.gethostname()
        date_str = datetime.datetime.now().strftime("%Y-%m-%d")
        output_file = f"{hostname}-MSSQL-{date_str}.csv"

        # Write to CSV
        import csv
        with open(output_file, mode='w', newline='') as file:
            writer = csv.writer(file)
            writer.writerow(columns)  # Header
            writer.writerows(rows)   # Data

        print(f"Results saved to {output_file}")

        # Close connection
        cursor.close()
        conn.close()

    except Exception as e:
        print(f"Error executing SQL script: {e}")

else:
    print("MSSQL is not installed. Script execution completed.")
