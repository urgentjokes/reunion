#!/usr/bin/env python3
"""
go/hi Mac Background Daemon
Monitors the local command spool and reliably ships interaction records
to the Raspberry Pi living at 192.168.0.40.
Ensures zero data loss with local pending queue and automatic retry.
"""

import os
import sys
import time
import json
import signal
import urllib.request
import urllib.error

PI_HOST = os.environ.get("GOHI_HOST", "192.168.0.40")
PI_PORT = int(os.environ.get("GOHI_PORT", "8080"))
PI_URL = f"http://{PI_HOST}:{PI_PORT}/log"

GOHI_DIR = os.path.expanduser("~/.gohi")
PID_FILE = os.path.join(GOHI_DIR, "daemon.pid")
SPOOL_FILE = os.path.join(GOHI_DIR, "spool.log")
PENDING_FILE = os.path.join(GOHI_DIR, "pending.log")
DAEMON_LOG = os.path.join(GOHI_DIR, "daemon.log")

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

def send_to_pi(entry):
    """Sends a single log entry to the Raspberry Pi over HTTP."""
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
