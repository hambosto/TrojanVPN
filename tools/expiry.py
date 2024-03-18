#!/usr/bin/env python3

import json
from datetime import datetime
import subprocess

# File paths
USERS_FILE = "/usr/local/etc/xray/users.db"
XRAY_CONFIG = "/usr/local/etc/xray/config.json"

def load_json(file_path):
    """Load JSON data from a file."""
    with open(file_path, "r") as file:
        return json.load(file)

def save_json(data, file_path):
    """Save JSON data to a file."""
    with open(file_path, "w") as file:
        json.dump(data, file, indent=4)

def remove_expired_users(users_data, current_date):
    """Remove expired users from users data."""
    expired_users = []
    for protocol, users in users_data.items():
        expired_users.extend([user for user in users if user.get("expiry") == current_date])

    if expired_users:
        for protocol, users in users_data.items():
            users_data[protocol] = [user for user in users if user.get("expiry") != current_date]
        save_json(users_data, USERS_FILE)

def remove_expired_clients(config_data, expired_usernames):
    """Remove expired clients from XRay configuration."""
    for inbound in config_data.get("inbounds", []):
        if "settings" in inbound:
            clients = inbound["settings"].get("clients", [])
            updated_clients = [client for client in clients if client.get("email") not in expired_usernames]
            inbound["settings"]["clients"] = updated_clients

    save_json(config_data, XRAY_CONFIG)

def restart_xray_service():
    """Restart the XRay service."""
    subprocess.run(["sudo", "systemctl", "restart", "xray"])

def main():
    # Current date
    current_date = datetime.now().strftime("%Y-%m-%d")

    # Load users data from users.json
    users_data = load_json(USERS_FILE)

    # Extract expired usernames
    expired_usernames = set()
    for protocol, users in users_data.items():
        expired_usernames.update([user["user"] for user in users if user.get("expiry") == current_date])

    # Remove expired users from users.json
    remove_expired_users(users_data, current_date)

    # Load XRay configuration from config.json
    xray_config_data = load_json(XRAY_CONFIG)

    # Remove expired clients from XRay configuration
    remove_expired_clients(xray_config_data, expired_usernames)

    # Restart XRay service
    restart_xray_service()

if __name__ == "__main__":
    main()
