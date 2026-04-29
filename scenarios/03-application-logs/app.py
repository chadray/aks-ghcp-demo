#!/usr/bin/env python3
"""
Scenario 3: Application Logs Demo

This application runs successfully but has errors in its logs.
It simulates a real application that:
- Starts up successfully
- Exposes a health check endpoint (responds to readiness/liveness probes)
- But has business logic errors that appear only in logs

This demonstrates a common issue where the pod appears "Running" but
is not functioning correctly. Support teams must read logs to diagnose.
"""

import http.server
import socketserver
import threading
import time
import json
import random
import os
from datetime import datetime

PORT = 8080
REQUEST_COUNT = 0
ERROR_COUNT = 0

class LogEntry:
    def __init__(self, level, message, request_id=None):
        self.timestamp = datetime.now().isoformat()
        self.level = level
        self.message = message
        self.pid = os.getpid()
        self.request_id = request_id or str(random.randint(10000, 99999))
    
    def __str__(self):
        return f"[{self.timestamp}] [{self.level}] [PID:{self.pid}] [REQ:{self.request_id}] {self.message}"

def log(level, message, request_id=None):
    entry = LogEntry(level, message, request_id)
    print(str(entry), flush=True)

class AppRequestHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        global REQUEST_COUNT, ERROR_COUNT
        
        request_id = f"{REQUEST_COUNT:05d}"
        REQUEST_COUNT += 1
        
        # Health check endpoint
        if self.path == "/health":
            log("INFO", "Health check requested", request_id)
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = json.dumps({
                "status": "healthy",
                "pid": os.getpid(),
                "requests_processed": REQUEST_COUNT
            })
            self.wfile.write(response.encode())
            return
        
        # Readiness check endpoint
        if self.path == "/ready":
            log("INFO", "Readiness check requested", request_id)
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = json.dumps({"ready": True})
            self.wfile.write(response.encode())
            return
        
        # Main application endpoint - has bugs
        if self.path == "/api/data":
            log("INFO", "Processing /api/data request", request_id)
            
            try:
                # Simulate database query
                log("DEBUG", "Attempting database connection", request_id)
                time.sleep(0.1)  # Simulate DB latency
                
                # Simulate 40% of requests having business logic errors
                if random.random() < 0.4:
                    ERROR_COUNT += 1
                    log("ERROR", "Database connection timeout after 30000ms", request_id)
                    log("ERROR", "Failed to retrieve customer data from database", request_id)
                    log("WARN", "Retrying operation (attempt 1/3)", request_id)
                    
                    # Retry logic that also fails
                    time.sleep(0.2)
                    log("ERROR", "Retry failed: Connection pool exhausted", request_id)
                    
                    self.send_response(500)
                    self.send_header('Content-type', 'application/json')
                    self.end_headers()
                    response = json.dumps({
                        "error": "Internal Server Error",
                        "request_id": request_id
                    })
                    self.wfile.write(response.encode())
                else:
                    log("INFO", "Query executed successfully", request_id)
                    log("DEBUG", f"Retrieved {random.randint(10, 100)} records", request_id)
                    
                    self.send_response(200)
                    self.send_header('Content-type', 'application/json')
                    self.end_headers()
                    response = json.dumps({
                        "status": "success",
                        "records": random.randint(10, 100)
                    })
                    self.wfile.write(response.encode())
            except Exception as e:
                ERROR_COUNT += 1
                log("ERROR", f"Unexpected error: {str(e)}", request_id)
                log("ERROR", "Stack trace: Exception in data processing", request_id)
                
                self.send_response(500)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                response = json.dumps({"error": "Internal error"})
                self.wfile.write(response.encode())
            return
        
        # Unknown endpoint
        self.send_response(404)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        response = json.dumps({"error": "Not found"})
        self.wfile.write(response.encode())

    def log_message(self, format, *args):
        # Suppress default logging
        pass

def print_startup_info():
    print(f"\n{'='*60}", flush=True)
    print(f"Application Starting", flush=True)
    print(f"{'='*60}", flush=True)
    log("INFO", "Application initializing")
    log("INFO", f"Process ID: {os.getpid()}")
    log("INFO", "Reading configuration from environment")
    log("DEBUG", f"LOG_LEVEL: {os.environ.get('LOG_LEVEL', 'INFO')}")
    log("DEBUG", f"PORT: {PORT}")
    log("INFO", "Database connection pool: max_connections=20")
    log("INFO", "Cache initialized (TTL: 3600s)")
    log("INFO", f"Starting HTTP server on port {PORT}")
    log("INFO", "Application ready to accept requests")
    print(f"{'='*60}\n", flush=True)

def periodic_stats():
    """Print stats periodically"""
    time.sleep(10)
    while True:
        log("INFO", f"Stats - Total requests: {REQUEST_COUNT}, Errors: {ERROR_COUNT}, Error rate: {ERROR_COUNT/max(REQUEST_COUNT,1)*100:.1f}%")
        time.sleep(15)

if __name__ == "__main__":
    print_startup_info()
    
    # Start stats thread
    stats_thread = threading.Thread(target=periodic_stats, daemon=True)
    stats_thread.start()
    
    # Start HTTP server
    with socketserver.TCPServer(("", PORT), AppRequestHandler) as httpd:
        try:
            log("INFO", "HTTP server listening")
            httpd.serve_forever()
        except KeyboardInterrupt:
            log("INFO", "Shutdown requested")
            print(f"\nApplication terminating", flush=True)
