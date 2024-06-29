#!/bin/bash

# Function to download a file from a URL
download_file() {
    local url="$1"
    local destination="$2"
    wget -qO "$destination" "$url"
}

# Function to enable and start a systemd service
enable_and_start_service() {
    local service="$1"
    systemctl enable "$service"
    systemctl start "$service"
}

# Function to restart a systemd service
restart_service() {
    local service="$1"
    systemctl restart "$service"
}

# Function to update and upgrade the system
install_dependency() {
    echo "Installing necessary packages..."
    apt update -y
    apt upgrade -y
    apt install -y \
        netfilter-persistent \
        cmake \
        cron \
        uuid-runtime \
        python3-psutil \
        python3-pandas \
        python3-tabulate \
        python3-rich \
        python3-distro \
        python3-requests
    echo "Dependency installation complete."
}

# Function to install Nginx
install_nginx() {
    echo "Starting Nginx installation and configuration..."

    echo "Installing Nginx..."
    apt install nginx -y

    echo "Cleaning up default Nginx configuration..."
    rm -rf /var/www/html/*
    rm /etc/nginx/sites-enabled/default
    rm /etc/nginx/sites-available/default

    echo "Downloading Nginx configuration files..."
    download_file "https://raw.githubusercontent.com/hambosto/TrojanVPN/main/config/nginx.conf" "/etc/nginx/nginx.conf"
    sed -i "s/\$domain/$domain/g" "/etc/nginx/nginx.conf"

    echo "Restarting Nginx..."
    restart_service "nginx"

    echo "Nginx installation and configuration completed successfully."
}


# Function to install vnstat
install_vnstat() {
    echo "Installing vnstat..."
    apt install vnstat -y
    systemctl enable vnstat.service
    systemctl restart vnstat.service
    echo "vnstat installation complete."
}

# Function to block Torrent and P2P Traffic
block_torrent_and_p2p_traffic() {
    echo "Blocking torrent and P2P traffic strings..."

    sudo iptables -A INPUT -p udp --dport 6881:6889 -j DROP
    sudo iptables -A INPUT -p tcp --dport 6881:6889 -j DROP
    sudo iptables -A INPUT -p tcp --dport 6881:6889 -m string --algo bm --string "BitTorrent" -j DROP
    sudo iptables -A INPUT -p udp --dport 6881:6889 -m string --algo bm --string "BitTorrent" -j DROP

    echo "Saving and applying iptables rules..."
    iptables-save > /etc/iptables.up.rules
    iptables-restore -t < /etc/iptables.up.rules

    echo "Saving and reloading netfilter-persistent rules..."
    netfilter-persistent save
    netfilter-persistent reload
}

# Function to install resolvconf service
configure_dns_resolution() {
    echo "Installing necessary packages (resolvconf)..."
    apt install resolvconf -y

    echo "Starting and enabling DNS resolution services..."
    enable_and_start_service "resolvconf"

    echo "Setting DNS to Cloudflare in /root/current-dns.txt..."
    echo "Cloudflare DNS" > /root/current-dns.txt
    echo "nameserver 1.1.1.1" >> /etc/resolvconf/resolv.conf.d/head
    echo "nameserver 1.0.0.1" >> /etc/resolvconf/resolv.conf.d/head

    resolvconf --enable-updates

    echo "Restarting DNS resolution services..."
    restart_service "resolvconf"

    echo "DNS resolution service installation and configuration completed successfully."
}

# Function to configure cron jobs
configure_cron_jobs() {
    echo "0 6 * * * root reboot" >> /etc/crontab
    echo "0 0 * * * root /usr/local/sbin/expiry" >> /etc/crontab
    echo "*/2 * * * * root /usr/local/sbin/cleaner" >> /etc/crontab

    echo "Restarting cron service..."
    restart_service "cron"
}

# Function to restart services
restart_services() {
    echo "Restarting services..."
    restart_service "nginx"
    restart_service "cron"
    restart_service "fail2ban"
    restart_service "resolvconf"
    restart_service "vnstat"
}

domain=$(cat /root/domain)

# Main execution starts here
install_dependency
install_nginx
install_vnstat
block_torrent_and_p2p_traffic
configure_dns_resolution
configure_cron_jobs
restart_services

rm -f /root/install-vpn.sh

echo "Cleanup and restart completed."
