#!/usr/bin/env python3
"""
go/hi Raspberry Pi Server
Serves the "Hello–I'm Home" web page, appends incoming terminal interaction logs
chronologically directly into the HTML file, and supports deleting unwanted commands.
"""

import sys
import os
import re
import json
import time
import html
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
import argparse

DEFAULT_PORT = 8003
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
INDEX_FILE = os.path.join(BASE_DIR, "index.html")
LOG_FILE = os.path.join(BASE_DIR, "history.jsonl")

file_lock = threading.Lock()
recent_cache = []

def escape(s):
    return html.escape(str(s) if s is not None else "")

def append_to_html(entry):
    """Safely appends a new table row chronologically right before <!-- GOHI_ENTRIES_END -->."""
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
              <td class="action-cell">
                <button class="delete-btn" onclick="deleteEntry(this, event)" title="Delete command" aria-label="Delete">
                  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <polyline points="3 6 5 6 21 6"></polyline>
                    <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
                    <line x1="10" y1="11" x2="10" y2="17"></line>
                    <line x1="14" y1="11" x2="14" y2="17"></line>
                  </svg>
                </button>
              </td>
            </tr>\n'''

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

        recent_cache.append(entry)
        if len(recent_cache) > 200:
            recent_cache.pop(0)

        return True

def delete_from_html(entry_id):
    """Safely removes a table row by data-id from index.html and cache."""
    with file_lock:
        if not os.path.exists(INDEX_FILE):
            return False

        with open(INDEX_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        pattern = rf'[ \t]*<tr class="log-row" data-id="{re.escape(str(entry_id))}">.*?</tr>\n?'
        new_content = re.sub(pattern, "", content, flags=re.DOTALL)
        if new_content != content:
            with open(INDEX_FILE, "w", encoding="utf-8") as f:
                f.write(new_content)

        # Update cache
        global recent_cache
        recent_cache = [e for e in recent_cache if str(e.get("id")) != str(entry_id)]

        # Update jsonl log
        if os.path.exists(LOG_FILE):
            try:
                with open(LOG_FILE, "r", encoding="utf-8") as f:
                    lines = f.readlines()
                with open(LOG_FILE, "w", encoding="utf-8") as f:
                    for line in lines:
                        try:
                            item = json.loads(line)
                            if str(item.get("id")) != str(entry_id):
                                f.write(line)
                        except Exception:
                            f.write(line)
            except Exception as e:
                print(f"[Error updating jsonl]: {e}", file=sys.stderr)

        return True

def load_initial_cache():
    if os.path.exists(LOG_FILE):
        try:
            with open(LOG_FILE, "r", encoding="utf-8") as f:
                lines = f.readlines()
                for line in lines[-200:]:
                    line = line.strip()
                    if line:
                        recent_cache.append(json.loads(line))
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
            data = json.dumps(recent_cache[-50:]).encode("utf-8")
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

        if path in ("/delete", "/api/delete"):
            try:
                content_length = int(self.headers.get("Content-Length", 0))
                body = self.rfile.read(content_length).decode("utf-8")
                req_data = json.loads(body)
                entry_id = req_data.get("id")
                if entry_id:
                    delete_from_html(entry_id)
                    resp = json.dumps({"status": "deleted", "id": entry_id}).encode("utf-8")
                    self.send_response(200)
                    self.send_header("Content-Type", "application/json")
                    self.send_header("Content-Length", str(len(resp)))
                    self.send_cors_headers()
                    self.end_headers()
                    self.wfile.write(resp)
                    return
                else:
                    self.send_error(400, "Missing id in delete request")
                    return
            except Exception as e:
                self.send_error(400, f"Failed to delete entry: {e}")
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
