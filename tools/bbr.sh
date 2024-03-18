#!/bin/bash

SYSCTL_CONF="/etc/sysctl.conf"
LOG_FILE="install_bbr.log"

# Function to check operating system
_os_full() {
    if [ -f /etc/redhat-release ]; then
        awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release
    elif [ -f /etc/os-release ]; then
        awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release
    elif [ -f /etc/lsb-release ]; then
        awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release
    fi
}

# Function to check if BBR is already enabled
check_bbr_status() {
    sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null | grep -q "bbr"
}

# Function to configure sysctl settings
sysctl_config() {
    sed -i '/net.core.default_qdisc/d' "$SYSCTL_CONF"
    sed -i '/net.ipv4.tcp_congestion_control/d' "$SYSCTL_CONF"
    echo "net.core.default_qdisc = fq" >> "$SYSCTL_CONF"
    echo "net.ipv4.tcp_congestion_control = bbr" >> "$SYSCTL_CONF"
    sysctl -p >/dev/null 2>&1
}

# Function to reboot the system
reboot_os() {
    read -rp "Do you want to restart the system? [y/n]: " is_reboot
    if [[ "$is_reboot" == "y" || "$is_reboot" == "Y" ]]; then
        echo "The system will now reboot..."
        reboot
    else
        echo "Reboot has been canceled."
        exit 0
    fi
}

# Main function to install BBR
install_bbr() {
    clear
    echo "---------- System Information ----------"
    echo " OS      : $(_os_full)"
    echo " Arch    : $(uname -m) ($(getconf LONG_BIT) Bit)"
    echo " Kernel  : $(uname -r)"
    echo "----------------------------------------"
    echo " Automatically enable TCP BBR script"
    echo "----------------------------------------"
    echo
    read -rp "Press any key to start...or Press Ctrl+C to cancel" _
    
    if check_bbr_status; then
        echo
        echo "TCP BBR has already been enabled. Nothing to do."
        exit 0
    fi
    
    sysctl_config
    reboot_os
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

# Run the main installation function
install_bbr 2>&1 | tee "${LOG_FILE}"
