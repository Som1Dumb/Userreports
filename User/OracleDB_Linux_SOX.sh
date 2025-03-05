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

# Function to check sqlplus path for oradyn user
find_sqlplus() {
    echo "🔹 Checking for sqlplus command..."
    SQLPLUS_PATH=$(sudo -i -u oradyn bash -c 'which sqlplus')

    if [ -n "$SQLPLUS_PATH" ]; then
        echo "✅ sqlplus found at: $SQLPLUS_PATH"
    else
        echo "❌ sqlplus command not found for oradyn"
    fi
}

# Function to parse arguments
parse_arguments() {
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -file)
                SQL_SCRIPT_PATH="$2"
                shift 2
                ;;
            *)
                echo "❌ Unknown parameter: $1"
                exit 1
                ;;
        esac
    done
}

# Ask user for the SQL script file if not provided
ask_for_sql_script() {
    while [[ -z "$SQL_SCRIPT_PATH" || ! -f "$SQL_SCRIPT_PATH" ]]; do
        read -rp "🔹 Enter the full path to export_users.sql: " SQL_SCRIPT_PATH
        if [[ -f "$SQL_SCRIPT_PATH" ]]; then
            echo "✅ SQL script found: $SQL_SCRIPT_PATH"
        else
            echo "❌ File not found. Please enter a valid path."
            SQL_SCRIPT_PATH=""
        fi
    done
}

# Parse input arguments
parse_arguments "$@"

# Run only if Oracle Database is installed
if is_oracle_installed; then
    echo "🔹 Oracle Database detected. Proceeding with script execution..."

    # Ask user for the SQL script path if not provided via -file flag
    ask_for_sql_script

    # Print current user
    echo "🔹 Executing commands as user: $(whoami)"

    # Create directory if not exists
    echo "🔹 Creating directory: /report_tst"
    mkdir -p /report_tst
    echo "🔹 Changing ownership to oradyn"
    chown oradyn /report_tst

    # Check sqlplus for oradyn user
    find_sqlplus

    # Run sqlplus as oradyn with a full login shell
    echo "🔹 Switching to oradyn and running sqlplus..."
    sudo -i -u oradyn bash <<EOF
        echo "🔹 Inside oradyn shell, user: \$(whoami)"
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
