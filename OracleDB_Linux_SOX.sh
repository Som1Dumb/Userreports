#!/bin/bash

# Run linux_SOX.py first (always executes)
echo "Running linux_SOX.py..."
./linux_SOX.py

# Function to check if Oracle Database is installed
is_oracle_installed() {
    # Check for Oracle binary directories or sqlplus
    if [ -d "/u01/app/oracle" ] || [ -d "/opt/oracle" ] || [ -n "$(which sqlplus 2>/dev/null)" ]; then
        return 0  # Oracle is installed
    else
        return 1  # Oracle is not installed
    fi
}

# Run only if Oracle Database is installed
if is_oracle_installed; then
    echo "Oracle Database detected. Running script..."

    # Extract usernames that match "ora" but not "oracle"
    USERNAMES=$(awk -F: '/ora/ && !/oracle/ {print $1}' /etc/passwd)

    # Create directory if not exists
    mkdir -p /report_tst
    chown oradyn /report_tst

    # Switch to oradyn and execute SQL script
    sudo -u oradyn bash <<EOF
        sqlplus / as sysdba <<SQL
        @export_users.sql
        exit;
SQL
EOF

    echo "Script execution completed."
else
    echo "Oracle Database is NOT installed. Exiting..."
    exit 1
fi
