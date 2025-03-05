#!/bin/bash

# Variables
HOSTNAME=$(hostname)
LOG_FILE="/var/log/auth.log"  # Change to /var/log/secure for RHEL-based systems
OUTPUT_CSV="/var/log/os_log_review_$(date +%Y-%m-%d).csv"

# Function to detect OS and set the correct log file
detect_os() {
    if [[ -f /etc/redhat-release ]]; then
        LOG_FILE="/var/log/secure"
    elif [[ -f /etc/debian_version ]]; then
        LOG_FILE="/var/log/auth.log"
    else
        echo "Unsupported OS. Exiting."
        exit 1
    fi
}

# Function to extract failed login attempts
get_failed_logins() {
    echo "Hostname,Date,Time,Username,IP,Event_Type" > "$OUTPUT_CSV"
    grep -i "failed password" "$LOG_FILE" | while read -r line; do
        DATE=$(echo "$line" | awk '{print $1, $2, $3}')
        USERNAME=$(echo "$line" | grep -oP '(?<=user )\S+')
        IP=$(echo "$line" | grep -oP '(?<=from )\S+')
        echo "$HOSTNAME,$DATE,$USERNAME,$IP,FAILED_LOGIN" >> "$OUTPUT_CSV"
    done
}

# Function to extract sudo command usage
get_sudo_usage() {
    grep -i "sudo:" "$LOG_FILE" | while read -r line; do
        DATE=$(echo "$line" | awk '{print $1, $2, $3}')
        USERNAME=$(echo "$line" | grep -oP '(?<=user=)\S+')
        COMMAND=$(echo "$line" | grep -oP '(?<=COMMAND=).*')
        echo "$HOSTNAME,$DATE,$USERNAME,N/A,SUDO_USAGE,$COMMAND" >> "$OUTPUT_CSV"
    done
}

# Function to extract runas commands (runuser)
get_runas_usage() {
    grep -i "runuser" "$LOG_FILE" | while read -r line; do
        DATE=$(echo "$line" | awk '{print $1, $2, $3}')
        USERNAME=$(echo "$line" | grep -oP '(?<=user )\S+')
        echo "$HOSTNAME,$DATE,$USERNAME,N/A,RUNAS_COMMAND" >> "$OUTPUT_CSV"
    done
}

# Main execution
detect_os
get_failed_logins
get_sudo_usage
get_runas_usage

# Output confirmation
echo "Log review report generated: $OUTPUT_CSV"
