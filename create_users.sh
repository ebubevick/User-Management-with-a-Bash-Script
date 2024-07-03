#!/bin/bash

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Check if the input file is provided
if [ -z "$1" ]; then
    echo "Usage: bash create_users.sh <name-of-text-file>"
    exit 1
fi

INPUT_FILE="$1"
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.csv"

# Create log and password files with appropriate permissions
mkdir -p /var/secure  # Ensure the secure directory exists
touch "$LOG_FILE" "$PASSWORD_FILE"  # Create the log and password files
chmod 600 "$LOG_FILE" "$PASSWORD_FILE"  # Restrict file permissions to the owner

# Function to log actions with a timestamp
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to generate a random password
generate_password() {
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c 12
}

# Read the input file line by line
while IFS= read -r line || [[ -n "$line" ]]; do
    line=$(echo "$line" | xargs)  # Remove leading/trailing whitespace
    [ -z "$line" ] && continue  # Skip empty lines

    # Split the line into username and groups
    IFS=';' read -r username groups <<< "$line"
    username=$(echo "$username" | xargs)  # Remove whitespace around username
    groups=$(echo "$groups" | xargs | tr ',' ' ')  # Remove whitespace and convert commas to spaces

    # Create the user if it doesn't exist
    if ! id "$username" &>/dev/null; then
        useradd -m -s /bin/bash "$username"  # Create user with a home directory and bash shell
        log_action "User $username created."
    else
        log_action "User $username already exists."
        continue  # Skip to the next line if the user already exists
    fi

    # Add the user to their personal group
    usermod -aG "$username" "$username"

    # Process each additional group
    for group in $groups; do
        group=$(echo "$group" | xargs)  # Remove whitespace around group name
        getent group "$group" >/dev/null || groupadd "$group"  # Create group if it doesn't exist
        usermod -aG "$group" "$username"  # Add user to group
        log_action "User $username added to group $group."
    done

    # Generate a random password and set it for the user
    password=$(generate_password)
    echo "$username:$password" | chpasswd
    log_action "Password for user $username set."

    # Store the username and password in the password file
    echo "$username,$password" >> "$PASSWORD_FILE"
done < "$INPUT_FILE"

log_action "User creation script completed."

exit 0
