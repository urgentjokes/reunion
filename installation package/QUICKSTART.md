# 🚀 nostalgia Quickstart Guide

**nostalgia** is an intelligent, low-overhead terminal interaction monitor that logs every command you run, along with timestamps, execution durations, and exit status, presented in a clean, dark-mode web dashboard. It also lets you search for previous commands, and provides one-click reusability.

It is designed to be completely flexible and supports **three distinct use cases** depending on your workflow:

1. **[Use Case 1: Standalone Local HTML File](#-use-case-1-standalone-local-html-file-zero-server-zero-daemon)** — Zero server, zero daemon. Everything logs directly to a local HTML file on your machine.
2. **[Use Case 2: Remote Server Only](#-use-case-2-remote-server-only-centralized-network-logger)** — Commands ship to a central server (e.g. Raspberry Pi) on your network. No local HTML files stored.
3. **[Use Case 3: Remote Server with Local HTML Backup](#-use-case-3-remote-server-with-local-html-backup-hybrid--offline-safe)** — The best of both worlds. The remote server hosts your live home dashboard, while your machine maintains a synced local HTML backup copy with offline spooling.

---

## 📊 Comparison of the 3 Use Cases

| Feature | Use Case 1: Local HTML File | Use Case 2: Remote Server Only | Use Case 3: Remote + Local Backup |
| :--- | :--- | :--- | :--- |
| **Architecture** | Zero-server, zero-daemon | Client daemon + HTTP server | Client daemon + HTTP server |
| **Web Server Needed** | ❌ No | ✅ Yes (Raspberry Pi / Linux host) | ✅ Yes (Raspberry Pi / Linux host) |
| **Background Daemon** | ❌ No | ✅ Yes (`gohi-daemon.py`) | ✅ Yes (`gohi-daemon.py`) |
| **Where Logs Live** | `~/terminal-history.html` | Server `history.jsonl` & `index.html` | Server **AND** `~/.gohi/backup.html` |
| **Offline Behavior** | Always writes to local disk | Buffers in `pending.log`, syncs on connect | Buffers in queue **and** writes to backup HTML |
| **Ideal For** | Single laptop or directly on a Pi | Clean laptop, centralized logging | Travelers, offline work, zero-loss safety |

---

## 📦 Package Layout

```text
installation package/
├── QUICKSTART.md              # This guide (speaks to all 3 use cases)
├── README.md                  # Project overview
├── LICENSE                    # MIT License
├── config.example.env         # Central configuration template
├── install.sh                 # Client installer (Use Cases 2 & 3)
├── deploy_server.sh           # Remote server deployer via SSH (Use Cases 2 & 3)
│
├── client/                    # Client-side files
│   ├── gohi-ctl               # CLI control tool (status, open, test, restart)
│   ├── gohi-daemon.py         # Daemon with configurable local backup & spooling
│   ├── gohi.zsh               # Non-blocking Zsh preexec/precmd hooks
│   └── gohi.bash              # Non-blocking Bash DEBUG trap hooks
│
├── server/                    # Web server & dashboard
│   ├── index.html             # "Hello–I'm Home" web UI (sortable, copyable, trash can)
│   ├── server.py              # Lightweight HTTP server & API (port 8003 default)
│   └── gohi-server.service    # Systemd service unit for 24/7 background operation
│
└── local-logger/              # Standalone local-only mode (Use Case 1)
    ├── index.html             # Standalone local dashboard template
    ├── append.py              # Safe subshell appender
    ├── gohi-local.sh          # Self-contained Bash & Zsh hooks
    └── install-local.sh       # One-step local installer
```

---

## 🍓 Use Case 1: Standalone Local HTML File (Zero-Server, Zero-Daemon)

**Goal:** You want all commands logged to an elegant HTML dashboard on your machine without running any background server or daemon.

### Step 1: Run the Local Installer
From the `installation package/` directory:
```bash
./local-logger/install-local.sh
```
*What this does:*
- Initializes `~/terminal-history.html` from the dashboard template.
- Sets execute permissions on helper scripts.
- Hooks non-blocking shell handlers into `~/.zshrc` and/or `~/.bashrc`.

### Step 2: Activate Shell
Reload your shell configuration or open a new terminal tab:
```bash
source ~/.zshrc   # Or: source ~/.bashrc
```
Your prompt will display the `(Hello)` prefix.

### Step 3: View Your Dashboard
Run commands as usual. At any time, open your local dashboard by typing:
```bash
hello
```
Or open the file directly in your browser:
```text
file:///Users/<your-username>/terminal-history.html
```

---

## 🌐 Use Case 2: Remote Server Only (Centralized Network Logger)

**Goal:** You want a centralized dashboard running on your home server (e.g. Raspberry Pi) at `http://<server-ip>:8003`. Your laptop sends commands across your local network directly to the server, and **does not** maintain any local HTML backup files.

### Step 1: Configure for Remote Only
Copy `config.example.env` to `config.env`:
```bash
cp config.example.env config.env
```
Edit `config.env` and disable the local backup:
```bash
# Server IP or hostname
GOHI_HOST="192.168.0.40"

# Server Port
GOHI_PORT="8003"

# SSH user for server deployment
REMOTE_USER="pi"

# Disable local HTML backup (Remote Only mode)
ENABLE_LOCAL_BACKUP=false
```

### Step 2: Deploy Server to Raspberry Pi / Linux Host
From your laptop, deploy the server files and systemd service over SSH:
```bash
./deploy_server.sh
```
The script will copy `server/`, create the systemd service, start it, and verify that `http://<server-ip>:8003/health` is online.

### Step 3: Install Client on Your Laptop / Workstation
Run the client installer:
```bash
./install.sh
```
*What this does:*
- Initializes `~/.gohi/` with your `config.env`.
- Links `gohi-ctl` into `~/.local/bin/gohi-ctl`.
- Adds hooks to `~/.zshrc` (or `~/.bashrc`).
- Starts `gohi-daemon.py` with `ENABLE_LOCAL_BACKUP=false`.

### Step 4: Activate & Open
Reload your shell:
```bash
source ~/.zshrc
```
Type `hello` in your terminal to open the remote server dashboard in your browser (`http://<server-ip>:8003`).

*(Note: If your laptop is temporarily offline, commands are buffered in `~/.gohi/pending.log` and automatically shipped the moment your laptop reconnects to the network).*

---

## 🛡️ Use Case 3: Remote Server with Local HTML Backup (Hybrid / Offline-Safe)

**Goal:** You want the centralized remote server dashboard on your local network, **plus** a synced local HTML backup copy (`~/.gohi/backup.html`) on your laptop so you can view your history even when offline or away from home.

### Step 1: Configure with Local Backup Enabled
Copy `config.example.env` to `config.env`:
```bash
cp config.example.env config.env
```
Ensure `ENABLE_LOCAL_BACKUP=true` (this is the default):
```bash
# Server IP or hostname
GOHI_HOST="192.168.0.40"

# Server Port
GOHI_PORT="8003"

# SSH user for server deployment
REMOTE_USER="pi"

# Keep a synced local HTML backup copy (~/.gohi/backup.html)
ENABLE_LOCAL_BACKUP=true
```

### Step 2: Deploy the Remote Server
```bash
./deploy_server.sh
```

### Step 3: Install the Client
```bash
./install.sh
```
*What this does:*
- Sets up the background daemon with concurrent dual-writing:
  1. Appends interaction entries immediately to `~/.gohi/backup.html`.
  2. Forwards interactions to the remote server at `http://<server-ip>:8003/log`.
  3. If the server is unreachable, buffers commands in `~/.gohi/pending.log` and automatically syncs them when reconnected.

### Step 4: Activate & Access
Reload your shell:
```bash
source ~/.zshrc
```

- **Open the Dashboard**: Simply type `hello`. If your server is reachable, it opens `http://<server-ip>:8003`. If you're offline or away from home, it automatically falls back to opening your local `~/.gohi/backup.html`!
- **Direct Local File Access**: You can also open the local backup at any time:
  ```bash
  open ~/.gohi/backup.html
  ```

---

## 🛠️ Management & Commands

### Client Controller (`gohi-ctl`)
Use `gohi-ctl` to inspect and control the client:

```bash
# Check status of daemon, local queue, local backup, and server connectivity
gohi-ctl status

# Open the dashboard in your default browser (server if online, local backup if offline)
gohi-ctl open

# Send a test entry to verify end-to-end logging
gohi-ctl test

# Restart the client background daemon
gohi-ctl restart

# Stop the client daemon
gohi-ctl stop

# Start the client daemon
gohi-ctl start
```

### Remote Server Management (on Raspberry Pi / Linux Host)
```bash
# Check server service status
sudo systemctl status gohi-server

# Restart server
sudo systemctl restart gohi-server

# View live server journal logs
journalctl -u gohi-server -f
```

---

## 🌟 Dashboard Features

Across all three use cases, you get the same clean, responsive dark-mode interface:

- **📋 Click-to-Copy**: Click any command link to copy the exact text to your clipboard with a confirmation toast.
- **🗑️ Delete Button**: Click the trash can icon on any row to instantly remove unwanted commands or sensitive entries. In server mode, deletions sync to the server.
- **↕️ Sortable Columns**: Click **Command**, **Time**, **Duration**, or **Error code** headers to sort. Defaults to **most recent commands at the top**.
- **🔍 Real-Time Filter**: Type in the search box to filter commands and timestamps in real time.
- **⚡ Live Auto-Poll**: In server mode, the dashboard polls every 2 seconds to display commands as they finish.

---

## ❓ Troubleshooting & FAQ

### How do I switch between Use Case 2 (Remote Only) and Use Case 3 (Remote + Local Backup)?
Edit `~/.gohi/config.env` and change `ENABLE_LOCAL_BACKUP`:
- `ENABLE_LOCAL_BACKUP=true` (Use Case 3)
- `ENABLE_LOCAL_BACKUP=false` (Use Case 2)

Then restart the daemon:
```bash
gohi-ctl restart
```

### How do I uninstall or remove the prompt prefix?
- To disable the hooks, remove the `nostalgia` source lines from `~/.zshrc` and `~/.bashrc`.
- To stop the daemon, run `gohi-ctl stop`.
