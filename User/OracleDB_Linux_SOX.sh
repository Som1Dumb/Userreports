#!/bin/bash

# Run linux_SOX.py first (always executes)
echo "Running linux_SOX.py..."
./linux_SOX.py

# Function to check if Oracle Database is installed
is_oracle_installed() {
    oracle_paths=("/etc/oratab" "/u01/app/oracle" "/usr/lib/oracle" "/opt/oracle")

    for path in "${oracle_paths[@]}"; do
        if [ -e "$path" ]; then
            return 0  # Oracle is installed
        fi
    done

    return 1  # Oracle is not installed
}

# Run only if Oracle Database is installed
if is_oracle_installed; then
    echo "Oracle Database detected. Running script..."

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
