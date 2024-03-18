#!/bin/bash

# Check if the user is root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Download and install menu scripts
echo "Downloading and installing menu scripts..."
wget -qO /usr/local/sbin/menu https://raw.githubusercontent.com/hambosto/TrojanVPN/main/scripts/menu/menu.sh && chmod +x /usr/local/sbin/menu
wget -qO /usr/local/sbin/menu-vmess https://raw.githubusercontent.com/hambosto/TrojanVPN/main/scripts/menu/vmess.py && chmod +x /usr/local/sbin/menu-vmess
wget -qO /usr/local/sbin/menu-vless https://raw.githubusercontent.com/hambosto/TrojanVPN/main/scripts/menu/vless.sh && chmod +x /usr/local/sbin/menu-vless
echo "Menu scripts installed."

# Download and install utility scripts
echo "Downloading and installing utility scripts..."
wget -qO /usr/local/sbin/cleaner https://raw.githubusercontent.com/hambosto/TrojanVPN/main/tools/cleaner.py && chmod +x /usr/local/sbin/cleaner
wget -qO /usr/local/sbin/bbr https://raw.githubusercontent.com/hambosto/TrojanVPN/main/tools/bbr.sh && chmod +x /usr/local/sbin/bbr
wget -qO /usr/local/sbin/expiry https://raw.githubusercontent.com/hambosto/TrojanVPN/main/tools/expiry.py && chmod +x /usr/local/sbin/expiry
wget -qO /usr/local/sbin/speedtest-cli https://raw.githubusercontent.com/hambosto/TrojanVPN/main/tools/speedtest-cli.py && chmod +x /usr/local/sbin/speedtest-cli
echo "Utility scripts installed."

echo "Setup completed successfully."
