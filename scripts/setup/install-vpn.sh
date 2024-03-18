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
update_and_upgrade() {
    apt update -y
    apt upgrade -y
    apt dist-upgrade -y

    # Install necessary packages
    apt install netfilter-persistent apt-transport-https cmake build-essential cron bzip2 gzip coreutils uuid-runtime -y

    # Set timezone
    ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
}

# Function to install Nginx
install_nginx() {
    echo "Installing Nginx..."
    apt install nginx -y

    echo "Removing default Nginx configuration files..."
    rm /etc/nginx/sites-enabled/default
    rm /etc/nginx/sites-available/default

    echo "Downloading Nginx configuration files from GitHub..."
    download_file "https://raw.githubusercontent.com/hambosto/TrojanVPN/main/config/nginx.conf" "/etc/nginx/nginx.conf"
    download_file "https://raw.githubusercontent.com/hambosto/TrojanVPN/main/config/grpc.conf" "/etc/nginx/conf.d/grpc.conf"

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

# Function to install fail2ban and DOS-Deflate
install_fail2ban_and_dos_deflate() {
    apt install fail2ban -y

    enable_and_start_service "fail2ban"

    if [ -d '/usr/local/ddos' ]; then
        echo "Please uninstall the previous version first"
        exit 0
    else
        mkdir /usr/local/ddos
    fi

    echo "Installing DOS-Deflate..."

    for file in ddos.conf LICENSE ignore.ip.list ddos.sh; do
        download_file "http://www.inetbase.com/scripts/ddos/$file" "/usr/local/ddos/$file"
    done

    ln -s /usr/local/ddos/ddos.sh /usr/local/sbin/ddos

    echo "Download complete."

    echo "Creating a cron job to run the script every minute (Default setting)..."
    /usr/local/ddos/ddos.sh --cron > /dev/null 2>&1
    echo "Cron job created."
}

# Function to block Torrent and P2P Traffic
block_torrent_and_p2p_traffic() {
    echo "Blocking torrent and P2P traffic strings..."

    iptables -A FORWARD -m string --string "get_peers" --algo bm -j DROP
    iptables -A FORWARD -m string --string "announce_peer" --algo bm -j DROP
    iptables -A FORWARD -m string --string "find_node" --algo bm -j DROP
    iptables -A FORWARD -m string --algo bm --string "BitTorrent" -j DROP
    iptables -A FORWARD -m string --algo bm --string "BitTorrent protocol" -j DROP
    iptables -A FORWARD -m string --algo bm --string "peer_id=" -j DROP
    iptables -A FORWARD -m string --algo bm --string ".torrent" -j DROP
    iptables -A FORWARD -m string --algo bm --string "announce.php?passkey=" -j DROP
    iptables -A FORWARD -m string --algo bm --string "torrent" -j DROP
    iptables -A FORWARD -m string --algo bm --string "announce" -j DROP

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

# Main execution starts here
update_and_upgrade
install_nginx
install_vnstat
install_fail2ban_and_dos_deflate
block_torrent_and_p2p_traffic
configure_dns_resolution
configure_cron_jobs
restart_services

rm -f /root/install-vpn.sh

echo "Cleanup and restart completed."
