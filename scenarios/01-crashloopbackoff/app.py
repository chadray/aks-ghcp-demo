#!/usr/bin/env python3
"""
Scenario 1: CrashLoopBackOff Demo Application

This application intentionally crashes on startup to demonstrate
the CrashLoopBackOff failure pattern in Kubernetes.

The app attempts to load a configuration file that doesn't exist,
causing an immediate crash. Kubernetes will attempt to restart it,
leading to a CrashLoopBackOff status.
"""

import sys
import os
import time

def main():
    print("Application starting...", flush=True)
    print(f"Process ID: {os.getpid()}", flush=True)
    print("Attempting to load configuration...", flush=True)
    
    # Try to load a configuration file that doesn't exist
    config_path = "/app/config/application.conf"
    
    try:
        with open(config_path, 'r') as f:
            config = f.read()
        print(f"Configuration loaded from {config_path}", flush=True)
    except FileNotFoundError as e:
        print(f"ERROR: Configuration file not found at {config_path}", flush=True)
        print(f"Details: {str(e)}", flush=True)
        print("FATAL: Cannot start application without configuration", flush=True)
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: Unexpected error loading configuration: {str(e)}", flush=True)
        sys.exit(1)

if __name__ == "__main__":
    main()
