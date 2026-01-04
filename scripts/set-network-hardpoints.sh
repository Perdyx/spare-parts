#!/usr/bin/env bash

# Author: Per
# Description: Script to set up directories in /media and sets ownership and permissions for homelab network shares.
# Usage: Run this script as an administrative user (not root).

# Mount the specified network share and generate the coorresponding fstab entry
mount_share() {
    local ip="${1%%/*}"
    local name="${1#*/}"
    local mountpoint="/mnt/${name,,}"
    local fstab="//$ip/${name^} $mountpoint cifs vers=3.0,credentials=/home/$(whoami)/.smbcredentials,uid=$(id -u),gid=$(id -g),iocharset=utf8,x-systemd.requires=network-online.target 0 0"

    if [ -d "$mountpoint" ]; then
        echo "Directory $mountpoint already exists. Skipping creation."
    else
        sudo mkdir -p "$mountpoint"
        sudo chown "$UID:$UID" "$mountpoint"
        sudo chmod 755 "$mountpoint"

        if ! grep -q "$ip/${name^}" /etc/fstab; then
            echo $fstab | sudo tee -a /etc/fstab >/dev/null
            echo "Added entry to /etc/fstab: $fstab"
        else
            echo "Replacing existing entry for $1 in /etc/fstab..."
            sudo sed -i "/\/\/$ip\/${name^}/d" /etc/fstab
            echo $fstab | sudo tee -a /etc/fstab >/dev/null
            echo "Updated /etc/fstab entry: $fstab"
        fi
    fi
}

# Ensure the script is not run as root but has sudo privileges
if [ "$(id -u)" -eq 0 ]; then
    echo "Error: This script must not be run as root."
    exit 1
fi

# Uncomment and duplicate the following line for each network share you want to set up
# Example: mount_share "192.168.1.2/Share"
mount_share "172.16.1.4/Private"
mount_share "172.16.1.4/Restricted"
mount_share "172.16.1.4/Share"
mount_share "172.16.1.4/Plex"
mount_share "172.16.1.4/Test"

# Guide the user through creation of ~/.smbcredentials if it doesn't exist
if [ ! -f ~/.smbcredentials ]; then
    echo "Creating ~/.smbcredentials file..."
    touch ~/.smbcredentials
    sudo chmod 600 ~/.smbcredentials

    read -p "Enter your SMB username: " smb_username
    echo "username=$smb_username" >> ~/.smbcredentials

    read -s -p "Enter your SMB password: " smb_password
    echo "password=$smb_password" >> ~/.smbcredentials
    
    echo "~/.smbcredentials file created."
fi

# Workaround for Fedora
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" == "fedora" ]]; then
        echo "Applying Fedora workaround: setting setuid on mount, umount, and mount.cifs"

        sudo chmod u+s /bin/mount
        sudo chmod u+s /bin/umount
        sudo chmod u+s /usr/sbin/mount.cifs
    fi
fi

sudo systemctl daemon-reload
sudo mount -a
echo "Setup complete."