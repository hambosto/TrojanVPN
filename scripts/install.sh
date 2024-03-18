#!/bin/bash

cd 

secs_to_human() {
    echo -e "Installation time : $(( ${1} / 3600 )) hours $(( (${1} / 60) % 60 )) minute's $(( ${1} % 60 )) seconds"
}

# Function to display banner
display_banner() {
    clear
    curl -sS https://raw.githubusercontent.com/hambosto/TrojanVPN/main/config/logo.txt
}

# Function to check if the script is already installed
check_installed() {
    if [ -f "/usr/local/etc/xray/domain" ]; then
        clear
        echo "Xray Script is already installed."
        echo "To make changes or reinstall, please rebuild your VPS."
        echo "For detailed instructions, visit: https://github.com/hambosto/TrojanVPN"
    fi
}


# Function to set up username and domain
setup_domains() {
    read -r -p "Enter your domain: " domain
    echo -e ""

    if [ -z "$domain" ]; then
        echo "Error: Domain cannot be empty or null."
    else
        echo "$domain" > /root/domain
    fi
}

# Function to install a component
install_component() {
    local component_name=$1
    local download_url=$2
    local install_script="/root/install-${component_name}.sh"

    display_banner
    echo "Installing $component_name..."
    sleep 1
    wget -qO "$install_script" "$download_url"
    chmod +x "$install_script"
    "$install_script"
    echo "$component_name installed successfully."
    rm "$install_script"
    sleep 3
    clear
}

# Main script starts here
echo -e "Updating Packages..."
apt update && apt upgrade -y && apt install curl wget -y

if [ "${EUID}" -ne 0 ]; then
    echo "Error: You need to run this script as root."
    exit 1
fi

if [ "$(systemd-detect-virt)" == "openvz" ]; then
    echo "Error: OpenVZ is not supported."
    exit 1
fi

start=$(date +%s)

check_installed
display_banner
setup_domains

# Install components
install_component "VPN Dependencies" "https://raw.githubusercontent.com/hambosto/TrojanVPN/main/scripts/setup/install-vpn.sh"
install_component "XRAY Core" "https://raw.githubusercontent.com/hambosto/TrojanVPN/main/scripts/setup/install-xray.sh"
install_component "Menu" "https://raw.githubusercontent.com/hambosto/TrojanVPN/main/scripts/setup/install-menu.sh"

# Display final information
display_banner
echo "--------------------------------------------"
echo "           Installation complete."
echo "--------------------------------------------"
echo "Your IP Address : $(curl -sS ipv4.icanhazip.com)"
echo "Your Domain     : $(cat /usr/local/etc/xray/domain)"
echo "--------------------------------------------"

echo ""
secs_to_human "$(($(date +%s) - ${start}))"
echo ""

read -rp "Do you want to reboot your system now? (yes/no): " user_input

rm -rf ~/install.sh

case $user_input in
    [Yy]|[Yy][Ee][Ss])
        clear
        echo "Rebooting your system..."
        sleep 2
        reboot
        ;;
    [Nn]|[Nn][Oo])
        clear
        echo "Exiting without reboot."
        sleep 2
        exit
        ;;
    *)
        clear
        echo "Invalid input. Rebooting your system..."
        sleep 2
        reboot
        ;;
esac
