#!/usr/bin/env python3
"""
Scenario 2: ImagePullBackOff - This application would run fine if the image could be pulled.

This is a simple web application that would respond to requests,
but it will never get to run because the image cannot be pulled.
"""

import http.server
import socketserver
import os

PORT = 8080

class MyHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/plain')
        self.end_headers()
        response = f"Hello from ImagePullBackOff Demo!\nPID: {os.getpid()}\n"
        self.wfile.write(response.encode())

    def log_message(self, format, *args):
        print(format % args, flush=True)

if __name__ == "__main__":
    print(f"Starting HTTP server on port {PORT}...", flush=True)
    with socketserver.TCPServer(("", PORT), MyHTTPRequestHandler) as httpd:
        print(f"Server running and ready to accept requests", flush=True)
        httpd.serve_forever()
