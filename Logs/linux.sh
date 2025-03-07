#!/bin/bash

# Variables
HOSTNAME=$(hostname)
LOG_FILE="/var/log/auth.log"  # Default for Debian/Ubuntu; changes dynamically for RHEL
OUTPUT_CSV="$(pwd)/os_log_review_$(date +%Y-%m-%d).csv"

# Function to detect OS and set the correct log file
detect_os() {
    echo "[INFO] Detecting OS..."
    if [[ -f /etc/redhat-release ]]; then
        LOG_FILE="/var/log/secure"
        echo "[INFO] Detected RHEL-based OS. Using log file: $LOG_FILE"
    elif [[ -f /etc/debian_version ]]; then
        LOG_FILE="/var/log/auth.log"
        echo "[INFO] Detected Debian-based OS. Using log file: $LOG_FILE"
    else
        echo "[ERROR] Unsupported OS. Exiting."
        exit 1
    fi
}

# Function to extract failed login attempts
get_failed_logins() {
    echo "[INFO] Extracting failed login attempts..."
    echo "Hostname,Date,Time,Username,IP,Event_Type,Command" > "$OUTPUT_CSV"
    grep -i "failed password" "$LOG_FILE" | while read -r line; do
        DATE=$(echo "$line" | awk '{print $1, $2, $3}')
        USERNAME=$(echo "$line" | grep -oP '(?<=user )\S+')
        IP=$(echo "$line" | grep -oP '(?<=from )\S+')
        echo "$HOSTNAME,$DATE,$USERNAME,$IP,FAILED_LOGIN,N/A" >> "$OUTPUT_CSV"
    done
    echo "[INFO] Failed login extraction complete."
}

# Function to extract sudo command usage (fixing empty command issue)
get_sudo_usage() {
    echo "[INFO] Extracting sudo command usage..."
    grep -i "sudo:" "$LOG_FILE" | while read -r line; do
        DATE=$(echo "$line" | awk '{print $1, $2, $3}')
        USERNAME=$(echo "$line" | grep -oP '(?<=user=)\S+')
        COMMAND=$(echo "$line" | sed -n 's/.*sudo: //p')  # Extracts everything after "sudo:"

        # If no command found, set "UNKNOWN"
        if [[ -z "$COMMAND" ]]; then
            COMMAND="UNKNOWN"
        fi

        echo "$HOSTNAME,$DATE,$USERNAME,N/A,SUDO_USAGE,\"$COMMAND\"" >> "$OUTPUT_CSV"
    done
    echo "[INFO] Sudo command extraction complete."
}

# Function to extract runas commands (runuser)
get_runas_usage() {
    echo "[INFO] Extracting runuser (runas) command usage..."
    grep -i "runuser" "$LOG_FILE" | while read -r line; do
        DATE=$(echo "$line" | awk '{print $1, $2, $3}')
        USERNAME=$(echo "$line" | grep -oP '(?<=user )\S+')
        COMMAND=$(echo "$line" | sed -n 's/.*command: //p')  # Extracts everything after "command:"

        # If no command found, set "UNKNOWN"
        if [[ -z "$COMMAND" ]]; then
            COMMAND="UNKNOWN"
        fi

        echo "$HOSTNAME,$DATE,$USERNAME,N/A,RUNAS_COMMAND,\"$COMMAND\"" >> "$OUTPUT_CSV"
    done
    echo "[INFO] Runuser command extraction complete."
}

# Main execution
detect_os
get_failed_logins
get_sudo_usage
get_runas_usage

# Output confirmation
echo "[SUCCESS] Log review report generated: $OUTPUT_CSV"
