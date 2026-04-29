#!/usr/bin/env python3
"""
Scenario 4: Key Vault Secret Volume Demo Application

This application reads a secret mounted from Azure Key Vault via the
Secrets Store CSI Driver. It uses workload identity to authenticate
to Key Vault over a private endpoint.

The app continuously reads the mounted secret file and prints its status,
demonstrating that the secret was successfully retrieved from Key Vault.
"""

import time
import os
import sys

SECRET_PATH = "/mnt/secrets/demo-secret"


def main():
    print("=== Key Vault Secret Volume Demo ===", flush=True)
    print(f"Process ID: {os.getpid()}", flush=True)
    print(f"Looking for secret at: {SECRET_PATH}", flush=True)
    print("", flush=True)

    while True:
        try:
            with open(SECRET_PATH, "r") as f:
                secret_value = f.read().strip()
            print(f"[OK] Secret mounted successfully. Value length: {len(secret_value)} chars", flush=True)
            print(f"[OK] Secret preview: {secret_value[:4]}****", flush=True)
        except FileNotFoundError:
            print(f"[ERROR] Secret file not found at {SECRET_PATH}", flush=True)
            print("[ERROR] The CSI secret volume may not be mounted correctly", flush=True)
        except PermissionError:
            print(f"[ERROR] Permission denied reading {SECRET_PATH}", flush=True)
        except Exception as e:
            print(f"[ERROR] Unexpected error: {e}", flush=True)

        print("[INFO] Next check in 30 seconds...", flush=True)
        time.sleep(30)


if __name__ == "__main__":
    main()
