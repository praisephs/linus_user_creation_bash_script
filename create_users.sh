#!/bin/bash

# Define the file containing user and group information
USER_FILE="$1"
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Function to generate a random password
generate_password() {
    echo $(openssl rand -base64 12)
}

# Create log file if it does not exist
if [ ! -f "$LOG_FILE" ]; then
    sudo touch "$LOG_FILE"
    sudo chmod 640 "$LOG_FILE"
fi

# Create secure directory and password file if they do not exist
if [ ! -d "/var/secure" ]; then
    sudo mkdir -p /var/secure
    sudo chmod 700 /var/secure
fi

if [ ! -f "$PASSWORD_FILE" ]; then
    sudo touch "$PASSWORD_FILE"
    sudo chmod 600 "$PASSWORD_FILE"
fi

# Read each line of the file
while IFS=';' read -r username groups; do
    # Remove carriage return if present and trim whitespace
    username=$(echo "$username" | tr -d '\r' | xargs)
    groups=$(echo "$groups" | tr -d '\r' | xargs)

    # Skip empty lines
    if [ -z "$username" ]; then
        continue
    fi

    # Check if the user already exists
    if id "$username" &>/dev/null; then
        echo "$(date): User $username already exists." | sudo tee -a "$LOG_FILE"
    else
        # Generate a random password
        password=$(generate_password)

        # Create the user with a home directory and set the password
        sudo useradd -m -p "$(openssl passwd -1 $password)" "$username"
        echo "$(date): User $username created with home directory and password." | sudo tee -a "$LOG_FILE"
        echo "$(date): $username: $password" | sudo tee -a "$PASSWORD_FILE" > /dev/null

        # Add user to the specified groups
        IFS=',' read -ra group_array <<< "$groups"
        for group in "${group_array[@]}"; do
            if getent group "$group" &>/dev/null; then
                sudo usermod -aG "$group" "$username"
                echo "$(date): User $username added to group $group." | sudo tee -a "$LOG_FILE"
            else
                sudo groupadd "$group"
                sudo usermod -aG "$group" "$username"
                echo "$(date): Group $group created and user $username added to it." | sudo tee -a "$LOG_FILE"
            fi
        done

        # Set permissions and ownership for the user's home directory
        sudo chmod 700 /home/"$username"
        sudo chown "$username":"$username" /home/"$username"
        echo "$(date): Permissions and ownership set for /home/$username." | sudo tee -a "$LOG_FILE"
    fi
done < "$USER_FILE"
