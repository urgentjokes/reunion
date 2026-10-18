#!/usr/bin/env python3
"""
go/hi Mac Background Daemon
Monitors the local command spool and reliably ships interaction records
to the Raspberry Pi living at 192.168.0.40.
Ensures zero data loss with local pending queue and automatic retry.
Also maintains a local backup HTML file at ~/developer-stuff/go-hi/index.html.
"""

import os
import sys
import time
import json
import html
import signal
import urllib.request
import urllib.error

PI_HOST = os.environ.get("GOHI_HOST", "192.168.0.40")
PI_PORT = int(os.environ.get("GOHI_PORT", "8003"))
PI_URL = f"http://{PI_HOST}:{PI_PORT}/log"

GOHI_DIR = os.path.expanduser("~/.gohi")
PID_FILE = os.path.join(GOHI_DIR, "daemon.pid")
SPOOL_FILE = os.path.join(GOHI_DIR, "spool.log")
PENDING_FILE = os.path.join(GOHI_DIR, "pending.log")
DAEMON_LOG = os.path.join(GOHI_DIR, "daemon.log")

LOCAL_HTML_FILE = os.path.expanduser("~/developer-stuff/go-hi/index.html")
REPO_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATE_FILE = os.path.join(REPO_DIR, "server", "index.html")

running = True

def log(msg):
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] {msg}\n"
    try:
        with open(DAEMON_LOG, "a", encoding="utf-8") as f:
            f.write(line)
    except Exception:
        pass

def handle_signal(sig, frame):
    global running
    log(f"Received signal {sig}, exiting gracefully...")
    running = False

signal.signal(signal.SIGTERM, handle_signal)
signal.signal(signal.SIGINT, handle_signal)

def append_to_local_html(entry):
    """Appends interaction entry to local backup HTML file at ~/developer-stuff/go-hi/index.html."""
    try:
        if not os.path.exists(LOCAL_HTML_FILE):
            if os.path.exists(TEMPLATE_FILE):
                with open(TEMPLATE_FILE, "r", encoding="utf-8") as tf:
                    base_content = tf.read()
                with open(LOCAL_HTML_FILE, "w", encoding="utf-8") as lf:
                    lf.write(base_content)
            else:
                return

        with open(LOCAL_HTML_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        marker = "<!-- GOHI_ENTRIES_END -->"
        if marker not in content:
            marker = '</tbody>'

        is_success = str(entry.get("exit_code", "0")) == "0"
        badge_class = "badge-success" if is_success else "badge-error"
        cmd = html.escape(str(entry.get("command", "")))
        time_str = html.escape(str(entry.get("time", "")))
        duration = html.escape(str(entry.get("duration", "")))
        exit_code = html.escape(str(entry.get("exit_code", 0)))
        entry_id = html.escape(str(entry.get("id", int(time.time() * 1000))))

        new_row = f'''
            <tr class="log-row" data-id="{entry_id}">
              <td class="command-cell">
                <a href="#" class="command-link" onclick="copyCommand(this, event)" data-command="{cmd}">
                  <span>{cmd}</span>
                  <span class="copy-icon">📋</span>
                </a>
              </td>
              <td class="time-cell">{time_str}</td>
              <td class="duration-cell">{duration}</td>
              <td class="error-cell">
                <span class="badge {badge_class}">{exit_code}</span>
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
            new_content = parts[0] + new_row + marker + parts[1]
            with open(LOCAL_HTML_FILE, "w", encoding="utf-8") as f:
                f.write(new_content)
    except Exception as e:
        log(f"Error appending to local HTML backup: {e}")

def send_to_pi(entry):
    """Sends a single log entry to the Raspberry Pi over HTTP and writes to local backup HTML."""
    append_to_local_html(entry)
    data = json.dumps(entry).encode("utf-8")
    req = urllib.request.Request(
        PI_URL,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=2.0) as resp:
            return resp.status == 200
    except Exception as e:
        return False

def flush_pending():
    """Attempts to send any accumulated entries in pending.log to the Pi."""
    if not os.path.exists(PENDING_FILE):
        return True

    with open(PENDING_FILE, "r", encoding="utf-8") as f:
        lines = f.readlines()

    if not lines:
        return True

    remaining = []
    success_count = 0
    pi_alive = True

    for line in lines:
        line_str = line.strip()
        if not line_str:
            continue
        if not pi_alive:
            remaining.append(line_str)
            continue

        try:
            entry = json.loads(line_str)
            if send_to_pi(entry):
                success_count += 1
            else:
                pi_alive = False
                remaining.append(line_str)
        except Exception:
            # Bad JSON, don't keep retrying corrupt line
            pass

    if success_count > 0:
        log(f"Synced {success_count} pending entries to Raspberry Pi.")

    with open(PENDING_FILE, "w", encoding="utf-8") as f:
        for rem in remaining:
            f.write(rem + "\n")

    return pi_alive

def process_spool():
    """Reads newly spooled commands and tries to forward them."""
    if not os.path.exists(SPOOL_FILE):
        return

    # Atomic move or read & truncate
    entries = []
    try:
        with open(SPOOL_FILE, "r", encoding="utf-8") as f:
            lines = f.readlines()
        # Truncate spool immediately
        with open(SPOOL_FILE, "w", encoding="utf-8") as f:
            pass
    except Exception as e:
        log(f"Error accessing spool: {e}")
        return

    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
            entries.append(entry)
        except Exception:
            continue

    if not entries:
        return

    # Append to pending
    with open(PENDING_FILE, "a", encoding="utf-8") as f:
        for entry in entries:
            f.write(json.dumps(entry) + "\n")

    flush_pending()

def run_daemon():
    os.makedirs(GOHI_DIR, exist_ok=True)

    # Initialize local HTML backup if not yet present
    if not os.path.exists(LOCAL_HTML_FILE) and os.path.exists(TEMPLATE_FILE):
        try:
            with open(TEMPLATE_FILE, "r", encoding="utf-8") as tf:
                content = tf.read()
            with open(LOCAL_HTML_FILE, "w", encoding="utf-8") as lf:
                lf.write(content)
        except Exception as e:
            log(f"Error initializing local HTML: {e}")

    # Check pidfile
    if os.path.exists(PID_FILE):
        try:
            with open(PID_FILE, "r") as f:
                old_pid = int(f.read().strip())
            os.kill(old_pid, 0)
            print(f"go/hi daemon already running with PID {old_pid}")
            sys.exit(0)
        except (OSError, ValueError):
            pass  # Process not running, stale pid file

    # Write current pid
    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))

    log(f"go/hi daemon started (PID {os.getpid()}). Target: {PI_URL}")

    last_pending_retry = time.time()
    try:
        while running:
            process_spool()

            # Periodically retry any pending items if Pi was offline
            now = time.time()
            if now - last_pending_retry > 5:
                flush_pending()
                last_pending_retry = now

            time.sleep(0.2)
    finally:
        if os.path.exists(PID_FILE):
            try:
                os.remove(PID_FILE)
            except Exception:
                pass
        log("go/hi daemon stopped.")

if __name__ == "__main__":
    run_daemon()
