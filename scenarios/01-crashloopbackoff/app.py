#!/usr/bin/env python3
"""
Scenario 1: CrashLoopBackOff Demo Application

This application intentionally crashes on startup to demonstrate
the CrashLoopBackOff failure pattern in Kubernetes.

The app expects its configuration file to be supplied at runtime via a
volume mounted at /app/config. When that mount is missing, the config file
does not exist, the app exits with code 1, and Kubernetes restarts it
repeatedly, leading to a CrashLoopBackOff status.
"""

import sys
import os
import time

def main():
    print("Application starting...", flush=True)
    print(f"Process ID: {os.getpid()}", flush=True)
    print("Attempting to load configuration...", flush=True)

    # The configuration file is expected to be supplied at runtime via a
    # volume mounted at /app/config. When that mount is missing, the file
    # does not exist and the application cannot start.
    config_path = os.environ.get("CONFIG_PATH", "/app/config/application.conf")

    try:
        with open(config_path, 'r') as f:
            config = f.read()
        print(f"Configuration loaded from {config_path}", flush=True)
    except FileNotFoundError as e:
        print(f"ERROR: Configuration file not found at {config_path}", flush=True)
        print(f"Details: {str(e)}", flush=True)
        print("FATAL: Cannot start application without configuration", flush=True)
        print("HINT: Expected a volume mounted at /app/config containing application.conf", flush=True)
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: Unexpected error loading configuration: {str(e)}", flush=True)
        sys.exit(1)

    # Configuration was loaded successfully - run forever so the pod stays Ready.
    print("Configuration valid. Application is running.", flush=True)
    while True:
        print("heartbeat: application healthy", flush=True)
        time.sleep(30)

if __name__ == "__main__":
    main()
