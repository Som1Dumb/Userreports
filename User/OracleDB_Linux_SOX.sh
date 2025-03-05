#!/bin/bash

# Print the current user running the script
echo "🔹 Current user: $(whoami)"

# Run linux_SOX.py first (always executes)
echo "🔹 Running linux_SOX.py..."
./linux_SOX.py

# Function to check if Oracle Database is installed
is_oracle_installed() {
    oracle_paths=("/etc/oratab" "/u01/app/oracle" "/usr/lib/oracle" "/opt/oracle")
    
    echo "🔹 Checking for Oracle installation..."
    for path in "${oracle_paths[@]}"; do
        if [ -e "$path" ]; then
            echo "✅ Oracle detected at: $path"
            return 0  # Oracle is installed
        fi
    done

    echo "❌ Oracle Database not found!"
    return 1  # Oracle is not installed
}

# Function to check if sqlplus is available
find_sqlplus() {
    echo "🔹 Checking for sqlplus command..."
    SQLPLUS_PATH=$(command -v sqlplus)
    
    if [ -n "$SQLPLUS_PATH" ]; then
        echo "✅ sqlplus found at: $SQLPLUS_PATH"
    else
        echo "❌ sqlplus command not found in PATH"
    fi
}

# Run only if Oracle Database is installed
if is_oracle_installed; then
    echo "🔹 Oracle Database detected. Proceeding with script execution..."

    # Print the user executing this part of the script
    echo "🔹 Executing commands as user: $(whoami)"

    # Create directory if not exists
    echo "🔹 Creating directory: /report_tst"
    mkdir -p /report_tst
    echo "🔹 Changing ownership to oradyn"
    chown oradyn /report_tst

    # Check if sqlplus exists before running
    find_sqlplus

    # Print the user executing the SQL command
    echo "🔹 Running sqlplus as oradyn..."
    sudo -u oradyn bash <<EOF
        whoami  # Print the user running this block
        which sqlplus  # Find sqlplus location in PATH
        echo "🔹 Attempting to run sqlplus..."
        sqlplus / as sysdba <<SQL
        @export_users.sql
        exit;
SQL
EOF

    echo "✅ Script execution completed."
else
    echo "❌ Oracle Database is NOT installed. Exiting..."
    exit 1
fi
