import json
import subprocess
import os
import base64
from datetime import datetime, timedelta
from tabulate import tabulate
from rich.prompt import IntPrompt, Prompt
import requests

# Constants
USERS_FILE = "/usr/local/etc/xray/users.db"
XRAY_CONFIG = "/usr/local/etc/xray/config.json"


# Functions
def display_banner():
    url = "https://raw.githubusercontent.com/hambosto/TrojanVPN/main/config/logo"
    response = requests.get(url)
    if response.status_code == 200:
        print(response.text)
    else:
        print("Failed to retrieve banner")


def load_json_file(file_path):
    with open(file_path, "r") as file:
        return json.load(file)


def save_json_file(data, file_path):
    with open(file_path, "w") as file:
        json.dump(data, file, indent=4)


def restart_xray_service():
    os.system("systemctl restart xray.service")
    os.system("service cron restart")


def display_vmess_clients(vmess_clients):
    table_data = [
        [idx + 1, user["user"], user["expiry"]]
        for idx, user in enumerate(vmess_clients)
    ]
    print("---------------------------------------------------")
    print(tabulate(table_data, headers=["No", "User", "Expiry"], tablefmt="plain"))
    print("---------------------------------------------------\n")


def renew_vmess():
    display_banner()
    users_data = load_json_file(USERS_FILE)
    vmess_clients = users_data.get("vmess", [])

    if not vmess_clients:
        print("No existing VMESS clients found.")
        input("Press [Enter] to go back to the menu")
        menu_vmess()
        return

    display_vmess_clients(vmess_clients)

    client_number = IntPrompt.ask(
        "Select User (Number)",
        choices=[str(index + 1) for index, user in enumerate(vmess_clients)],
        show_choices=False,
    )
    expiration_days = IntPrompt.ask("Expired (Days)")

    selected_user = vmess_clients[client_number - 1]
    client_exp = datetime.strptime(selected_user["expiry"], "%Y-%m-%d")
    new_exp_date = (client_exp + timedelta(days=expiration_days)).strftime("%Y-%m-%d")

    users_data["vmess"][client_number - 1]["expiry"] = new_exp_date
    save_json_file(users_data)

    print("---------------------------------------------------")
    print("Client Name :", selected_user["user"])
    print("Expired On  :", new_exp_date)
    print("Status      : Renewed Successfully")
    print("---------------------------------------------------")

    input("Press [Enter] to go back to the menu")
    menu_vmess()


def delete_vmess():
    users_data = load_json_file(USERS_FILE)
    vmess_clients = users_data.get("vmess", [])

    if not vmess_clients:
        print("No existing VMESS clients found.")
        input("Press any key to go back to the menu")
        return

    display_vmess_clients(vmess_clients)

    selected_client = IntPrompt.ask(
        "Select Client (Number)",
        choices=[str(index + 1) for index, user in enumerate(vmess_clients)],
        show_choices=False,
    )
    selected_index = int(selected_client) - 1
    username = vmess_clients[selected_index]["user"]
    expiry_date = vmess_clients[selected_index]["expiry"]

    del users_data["vmess"][selected_index]
    save_json_file(users_data, USERS_FILE)

    config_data = load_json_file(XRAY_CONFIG)

    for inbound in config_data["inbounds"]:
        if "clients" in inbound["settings"]:
            inbound["settings"]["clients"] = [
                client
                for client in inbound["settings"]["clients"]
                if client.get("email") != username
            ]

    save_json_file(config_data, XRAY_CONFIG)

    restart_xray_service()

    print("---------------------------------------------------")
    print("Client Name :", username)
    print("Expired On  :", expiry_date)
    print("Status      : Deleted Successfully")
    print("---------------------------------------------------")

    input("Press any key to go back to the menu")
    menu_vmess()


def create_vmess():
    display_banner()
    domain = open("/usr/local/etc/xray/domain").read().strip()

    while True:
        username = Prompt.ask("Username")
        username = (
            f"TrojanVPN-{username}-VMESS"  # just to make sure the username is unique
        )
        existing_users = load_json_file(USERS_FILE)
        existing_user = next(
            (user for user in existing_users["vmess"] if user["user"] == username), None
        )

        if existing_user:
            print("Error: User already exists.")
            input("Press Enter to continue...\n")
        else:
            break

    expiration_days = IntPrompt.ask("Set expiration (days)")
    expiration_days = int(expiration_days) if expiration_days else 1

    uuid = subprocess.run(["uuidgen"], stdout=subprocess.PIPE, text=True).stdout.strip()
    expiration_date = (datetime.now() + timedelta(days=expiration_days)).strftime(
        "%Y-%m-%d"
    )
    today = datetime.now().strftime("%Y-%m-%d")

    new_user = {"user": username, "uuid": uuid, "expiry": expiration_date}
    existing_users.append(new_user)
    save_json_file(existing_users, USERS_FILE)

    config_data = load_json_file(XRAY_CONFIG)

    config_data["inbounds"][3]["settings"]["clients"].append(
        {"id": uuid, "alterId": 0, "email": username}
    )
    config_data["inbounds"][6]["settings"]["clients"].append(
        {"id": uuid, "alterId": 0, "email": username}
    )
    config_data["inbounds"][8]["settings"]["clients"].append(
        {"id": uuid, "alterId": 0, "email": username}
    )

    save_json_file(config_data, XRAY_CONFIG)

    restart_xray_service()

    vmess_tls = {
        "v": "2",
        "ps": username,
        "add": domain,
        "port": "443",
        "id": uuid,
        "aid": "0",
        "net": "ws",
        "path": "/vmess",
        "type": "none",
        "host": domain,
        "tls": "tls",
    }

    vmess_none_tls = {
        "v": "2",
        "ps": username,
        "add": domain,
        "port": "80",
        "id": uuid,
        "aid": "0",
        "net": "ws",
        "path": "/vmess",
        "type": "none",
        "host": domain,
        "tls": "none",
    }

    vmess_grpc = {
        "v": "2",
        "ps": username,
        "add": domain,
        "port": "443",
        "id": uuid,
        "aid": "0",
        "net": "grpc",
        "path": "vmess-grpc",
        "type": "none",
        "host": domain,
        "tls": "tls",
    }

    encoded_tls = f"vmess://{base64.b64encode(json.dumps(vmess_tls).encode()).decode()}"
    encoded_non_tls = f"vmess://{base64.b64encode(json.dumps(vmess_none_tls).encode()).decode()"
    encoded_grpc = f"vmess://{base64.b64encode(json.dumps(vmess_grpc).encode()).decode()"

    print("---------------------------------------------------")
    print("Remarks           :", username)
    print("Created On        :", today)
    print("Expired On        :", expiration_date)
    print("Domain            :", domain)
    print("Port TLS          : 443")
    print("Port None TLS     : 80")
    print("UUID              :", uuid)
    print("Security          : Auto")
    print("Network           : WS")
    print("Path TLS          : /vmess")
    print("Path None TLS     : /vmess")
    print("---------------------------------------------------")
    print("VMESS TLS         :", encoded_tls)
    print("VMESS NONE TLS    :", encoded_non_tls)
    print("VMESS GRPC        :", encoded_grpc)
    print("---------------------------------------------------\n")

    input("Press [Enter] to go back to the menu")
    menu_vmess()


def menu_vmess():
    display_banner()

    print("---------------------------------------------------")
    print("1. Create VMESS")
    print("2. Delete VMESS")
    print("3. Renew VMESS")
    print("0. Go Back to Menu")
    print("---------------------------------------------------\n")

    menu_selection = IntPrompt.ask(
        "Select Menu", choices=[str(index) for index in range(5)], show_choices=False
    )

    if menu_selection == 1:
        create_vmess()
    elif menu_selection == 2:
        delete_vmess()
    elif menu_selection == 3:
        renew_vmess()
    elif menu_selection == 0:
        os.system("menu")
    else:
        menu_vmess()


# Main function
if __name__ == "__main__":
    menu_vmess()
