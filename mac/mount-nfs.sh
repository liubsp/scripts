#!/bin/bash

echo "Mounting NFSv3 Share Script"

# Parse named arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --mount-point)
            MOUNT_POINT="$2"
            shift; shift
            ;;
        --server)
            SERVER="$2"
            shift; shift
            ;;
        --remote-path)
            REMOTE_PATH="$2"
            shift; shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$MOUNT_POINT" || -z "$SERVER" || -z "$REMOTE_PATH" ]]; then
    echo "Usage: $0 --mount-point <mount_point> --server <server> --remote-path <remote_path>"
    echo
    echo "Mount an NFSv3 share to a local mount point."
    echo
    echo "Arguments:"
    echo "  --mount-point   Local directory to mount to (e.g. /Volumes/NASMedia)"
    echo "  --server        NFSv3 server address (e.g. 192.168.1.100)"
    echo "  --remote-path   Remote NFSv3 path (e.g. /mnt/tank/media)"
    exit 1
fi

ping -c 1 -W 1 "$SERVER" &>/dev/null
if [ $? -ne 0 ]; then
    echo "Server $SERVER is not reachable. Please check the server address."
    exit 1
fi

# List available NFS v3 shares
nfs_shares=$(/usr/bin/showmount -e -3 "$SERVER" | awk '{print $1}' | grep -v '^$')
if [ -z "$nfs_shares" ]; then
    echo "No NFSv3 shares available on $SERVER."
    exit 1
fi
echo "Available NFSv3 shares on $SERVER:"
echo "$nfs_shares"

# Create mount point if not exist
[ ! -d "$MOUNT_POINT" ] && sudo mkdir -p "$MOUNT_POINT"

# Mount only if not already mounted
/sbin/mount | grep "$MOUNT_POINT" | grep "$SERVER" > /dev/null
if [ $? -ne 0 ]; then
    sudo /sbin/mount_nfs -o resvport "${SERVER}:${REMOTE_PATH}" "$MOUNT_POINT"
    if [ $? -ne 0 ]; then
        echo "Failed to mount $REMOTE_PATH from $SERVER to $MOUNT_POINT."
        exit 1
    fi
    echo "Mounted $REMOTE_PATH from $SERVER to $MOUNT_POINT."
else
    echo "Mount point $MOUNT_POINT is already mounted."
    exit 0
fi

echo "Done."
