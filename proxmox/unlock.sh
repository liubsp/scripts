#!/bin/bash

# Check if two arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <host_label> <host_ip>"
    exit 1
fi

# Assign command-line arguments
HOST_LABEL="$1"
HOST_IP="$2"

# Paths derived from host label
KNOWN_HOSTS_FILE="$HOME/.ssh/known_host_${HOST_LABEL}_initramfs"
SSH_KEY="$HOME/.ssh/id_rsa_initramfs_ssh_client_${HOST_LABEL}"

# Validate required files
if [ ! -f "$KNOWN_HOSTS_FILE" ]; then
    echo "Error: known_host file not found: $KNOWN_HOSTS_FILE"
    exit 2
fi

if [ ! -f "$SSH_KEY" ]; then
    echo "Error: SSH private key file not found: $SSH_KEY"
    exit 3
fi

# Disable command history for this session
HISTFILE=
set +o history

# Probe SSH connectivity before asking for password
echo "Probing SSH connection to $HOST_LABEL ($HOST_IP)..."
ssh -o BatchMode=yes \
    -o UserKnownHostsFile="$KNOWN_HOSTS_FILE" \
    -o StrictHostKeyChecking=yes \
    -o UpdateHostKeys=no \
    -i "$SSH_KEY" \
    root@"$HOST_IP" "exit"

# Check SSH result
if [ $? -ne 0 ]; then
    echo "Error: SSH connection to $HOST_LABEL ($HOST_IP) failed."
    exit 2
fi

# Prompt for ZFS key without echoing it
read -s -p "Enter key for ZFS rpool/ROOT: " ZFS_PASSWORD
echo

# Run the unlock command on the remote system
ssh -o UserKnownHostsFile="$KNOWN_HOSTS_FILE" \
    -o StrictHostKeyChecking=yes \
    -o UpdateHostKeys=no \
    -i "$SSH_KEY" \
    root@"$HOST_IP" "zfsunlock_pass $ZFS_PASSWORD"

# Clear password from memory
unset ZFS_PASSWORD

# Re-enable command history
set -o history
