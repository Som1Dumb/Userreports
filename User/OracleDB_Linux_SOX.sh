#!/bin/bash

# Print current user
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
            return 0
        fi
    done

    echo "❌ Oracle Database not found!"
    return 1
}

# Function to find the Oracle user (ora+SID), but NOT "oracle"
find_oracle_user() {
    echo "🔹 Searching for Oracle user (oraSID), excluding 'oracle' user..."

    ORACLE_USER=$(awk -F: '/^ora/ {if ($1 != "oracle") print $1}' /etc/passwd | head -n 1)

    if [[ -n "$ORACLE_USER" ]]; then
        echo "✅ Oracle user found: $ORACLE_USER"
    else
        echo "❌ No valid Oracle user found! Exiting..."
        exit 1
    fi
}

# Function to check sqlplus path for oraSID user
find_sqlplus() {
    echo "🔹 Checking for sqlplus command..."
    SQLPLUS_PATH=$(sudo -i -u "$ORACLE_USER" bash -c 'which sqlplus')

    if [ -n "$SQLPLUS_PATH" ]; then
        echo "✅ sqlplus found at: $SQLPLUS_PATH"
    else
        echo "❌ sqlplus command not found for $ORACLE_USER"
    fi
}

# Get the path of OracleDB.sql in the script's directory
setup_sql_script() {
    SCRIPT_DIR=$(dirname "$(realpath "$0")")
    SQL_SCRIPT_PATH="$SCRIPT_DIR/OracleDB.sql"

    if [[ -f "$SQL_SCRIPT_PATH" ]]; then
        echo "✅ SQL script found: $SQL_SCRIPT_PATH"
        echo "🔹 Changing ownership to $ORACLE_USER"
        chown "$ORACLE_USER" "$SQL_SCRIPT_PATH"
    else
        echo "❌ OracleDB.sql not found in $SCRIPT_DIR. Please place the script in the same directory."
        exit 1
    fi
}

# Run only if Oracle Database is installed
if is_oracle_installed; then
    echo "🔹 Oracle Database detected. Proceeding with script execution..."

    # Find Oracle user (excluding 'oracle' user)
    find_oracle_user

    # Setup SQL script (ownership and path)
    setup_sql_script

    # Print current user
    echo "🔹 Executing commands as user: $(whoami)"

    # Create directory if not exists
    echo "🔹 Creating directory: /report_tst"
    mkdir -p /report_tst
    echo "🔹 Changing ownership to $ORACLE_USER"
    chown "$ORACLE_USER" /report_tst

    # Check sqlplus for oraSID user
    find_sqlplus

    # Run sqlplus as oraSID with a full login shell
    echo "🔹 Switching to $ORACLE_USER and running sqlplus..."
    sudo -i -u "$ORACLE_USER" bash <<EOF
        echo "🔹 Inside Oracle user shell, user: \$(whoami)"
        source ~/.bash_profile  # Load Oracle environment variables
        echo "🔹 Checking sqlplus path: \$(which sqlplus)"
        sqlplus / as sysdba <<SQL
        @$SQL_SCRIPT_PATH
        exit;
SQL
EOF

    echo "✅ Script execution completed."
else
    echo "❌ Oracle Database is NOT installed. Exiting..."
    exit 1
fi
