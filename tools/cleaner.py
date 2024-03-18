#!/usr/bin/env python3

import os
from datetime import datetime

def clear_logs(log_files):
    for log in log_files:
        print(f"{log} clear")
        with open(log, 'w'):
            pass

def main():
    # Find log files and clear them
    log_files = []
    for root, dirs, files in os.walk('/var/log/'):
        for file in files:
            if file.endswith('.log') or file.endswith('.err') or file.startswith('mail.'):
                log_files.append(os.path.join(root, file))
    clear_logs(log_files)

    # Clear specific log files
    specific_logs = [
        "/var/log/syslog",
        "/var/log/btmp",
        "/var/log/messages",
        "/var/log/debug"
    ]
    clear_logs(specific_logs)

    # Log the action
    with open('/root/clear_log', 'a') as log_file:
        log_file.write(f"{datetime.now()}: All Log Files Cleared Successfully\n")

if __name__ == "__main__":
    main()
