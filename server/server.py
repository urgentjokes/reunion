#!/usr/bin/env python3
"""
go/hi Raspberry Pi Server
Serves the "Hello–I'm Home" web page and appends incoming terminal interaction logs directly into the HTML file.
"""

import sys
import os
import json
import time
import html
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
import argparse

DEFAULT_PORT = 8080
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
INDEX_FILE = os.path.join(BASE_DIR, "index.html")
LOG_FILE = os.path.join(BASE_DIR, "history.jsonl")

file_lock = threading.Lock()
recent_cache = []

def escape(s):
    return html.escape(str(s) if s is not None else "")

def append_to_html(entry):
    """Safely inserts a new table row into index.html immediately after <!-- GOHI_ENTRIES_START -->."""
    with file_lock:
        if not os.path.exists(INDEX_FILE):
            return False

        with open(INDEX_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        marker = "<!-- GOHI_ENTRIES_START -->"
        if marker not in content:
            # Fallback if marker is missing
            marker = '<tbody id="logBody">'

        is_success = str(entry.get("exit_code", "0")) == "0"
        badge_class = "badge-success" if is_success else "badge-error"
        cmd = entry.get("command", "")
        time_str = entry.get("time", "")
        duration = entry.get("duration", "")
        exit_code = entry.get("exit_code", 0)
        entry_id = entry.get("id", str(int(time.time() * 1000)))

        new_row = f'''
            <tr class="log-row" data-id="{escape(entry_id)}">
              <td class="command-cell">
                <a href="#" class="command-link" onclick="copyCommand(this, event)" data-command="{escape(cmd)}">
                  <span>{escape(cmd)}</span>
                  <span class="copy-icon">📋</span>
                </a>
              </td>
              <td class="time-cell">{escape(time_str)}</td>
              <td class="duration-cell">{escape(duration)}</td>
              <td class="error-cell">
                <span class="badge {badge_class}">{escape(exit_code)}</span>
              </td>
            </tr>'''

        parts = content.split(marker, 1)
        if len(parts) == 2:
            new_content = parts[0] + marker + new_row + parts[1]
            with open(INDEX_FILE, "w", encoding="utf-8") as f:
                f.write(new_content)

        # Also append to history.jsonl
        try:
            with open(LOG_FILE, "a", encoding="utf-8") as f:
                f.write(json.dumps(entry) + "\n")
        except Exception as e:
            print(f"[Error writing jsonl]: {e}", file=sys.stderr)

        recent_cache.insert(0, entry)
        if len(recent_cache) > 200:
            recent_cache.pop()

        return True

def load_initial_cache():
    if os.path.exists(LOG_FILE):
        try:
            with open(LOG_FILE, "r", encoding="utf-8") as f:
                lines = f.readlines()
                for line in lines[-200:]:
                    line = line.strip()
                    if line:
                        recent_cache.insert(0, json.loads(line))
        except Exception:
            pass

class GoHiHandler(BaseHTTPRequestHandler):
    def send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_cors_headers()
        self.end_headers()

    def do_GET(self):
        path = self.path.split("?")[0]

        if path in ("/", "/index.html"):
            try:
                with open(INDEX_FILE, "rb") as f:
                    content = f.read()
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(content)))
                self.send_cors_headers()
                self.end_headers()
                self.wfile.write(content)
            except Exception as e:
                self.send_error(500, f"Error reading index.html: {e}")
            return

        if path == "/api/recent":
            data = json.dumps(recent_cache[:50]).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(data)
            return

        if path == "/health":
            data = b'{"status":"ok"}'
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(data)
            return

        self.send_error(404, "Not Found")

    def do_POST(self):
        path = self.path.split("?")[0]
        if path in ("/log", "/api/log"):
            try:
                content_length = int(self.headers.get("Content-Length", 0))
                body = self.rfile.read(content_length).decode("utf-8")
                entry = json.loads(body)
                if not entry.get("id"):
                    entry["id"] = str(int(time.time() * 1000))

                append_to_html(entry)

                resp = json.dumps({"status": "success", "id": entry["id"]}).encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(resp)))
                self.send_cors_headers()
                self.end_headers()
                self.wfile.write(resp)
            except Exception as e:
                self.send_error(400, f"Failed to log entry: {e}")
            return

        self.send_error(404, "Endpoint not found")

    def log_message(self, format, *args):
        # Concise logging
        sys.stderr.write(f"[go/hi server] {self.address_string()} - {format % args}\n")

def run_server(port=DEFAULT_PORT):
    load_initial_cache()
    server_address = ("", port)
    httpd = HTTPServer(server_address, GoHiHandler)
    print(f"🚀 go/hi Raspberry Pi Server running at http://0.0.0.0:{port}")
    print(f"📄 Serving and appending directly to: {INDEX_FILE}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping server...")
        httpd.server_close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="go/hi Raspberry Pi Server")
    parser.add_argument("--port", type=int, default=int(os.environ.get("GOHI_PORT", DEFAULT_PORT)), help="Port to listen on")
    args = parser.parse_args()
    run_server(args.port)
