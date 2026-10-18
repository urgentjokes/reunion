# 🚀 go/hi Quickstart Guide

**go/hi** is an intelligent, low-overhead terminal interaction monitor that logs every command you run, along with its execution timestamp, duration, and exit status. It provides an elegant, dark-mode web dashboard featuring click-to-copy, instant search filtering, sortable columns, and one-click deletion of unwanted commands.

---

## 📦 Package Layout

```text
installation package/
├── QUICKSTART.md              # This guide
├── README.md                  # Overview & architecture
├── LICENSE                    # MIT License
├── config.example.env         # Sample environment configuration
├── install.sh                 # Client installer (Mac / Linux)
├── deploy_server.sh           # Automated remote server deployer (Raspberry Pi / Linux)
│
├── client/                    # Client-side files
│   ├── gohi-ctl               # CLI control tool (status, start, stop, restart, test)
│   ├── gohi-daemon.py         # Background daemon with offline buffer & local backup
│   ├── gohi.zsh               # Non-blocking Zsh preexec/precmd hooks
│   └── gohi.bash              # Non-blocking Bash DEBUG trap hooks
│
├── server/                    # Web server & dashboard
│   ├── index.html             # "Hello–I'm Home" web interface
│   ├── server.py              # Lightweight HTTP server & API
│   └── gohi-server.service    # Systemd service unit for 24/7 background operation
│
└── local-logger/              # Zero-server, zero-daemon standalone mode
    ├── index.html             # Standalone dashboard template
    ├── append.py              # Subshell safe appender
    ├── gohi-local.sh          # Self-contained shell hooks for bash & zsh
    └── install-local.sh       # One-step local installer
```

---

## 🎯 Choose Your Deployment Mode

| Feature | Option A: Remote Server Mode | Option B: Standalone Local Mode |
| :--- | :--- | :--- |
| **Ideal For** | Laptops/workstations logging to a home server / Pi | Single machine or direct use on a Pi |
| **Server Needed** | Yes (runs lightweight HTTP server on Pi/server) | **No server required** |
| **Daemon Needed** | Yes (local daemon ships logs & buffers offline) | **No daemon required** |
| **Web Dashboard** | Hosted at `http://<host>:8003` with auto-polling | Local file (`file://$HOME/terminal-history.html`) |
| **Interactive Deletes** | Syncs live deletions across browser and server | Instant visual deletion in browser |
| **Offline Buffering** | Spools locally if offline, flushes when reconnected | Always direct to disk |

---

## Option A: Client & Remote Server Setup (Recommended)

### Step 1: Configure Your Network Settings
Copy `config.example.env` to `config.env`:
```bash
cp config.example.env config.env
```
Edit `config.env` with your server details:
```bash
# IP or hostname of your Raspberry Pi / remote server
GOHI_HOST="192.168.0.40"

# Port to serve the dashboard on (default: 8003)
GOHI_PORT="8003"

# SSH user for deploying to the remote server
REMOTE_USER="pi"
```

### Step 2: Deploy the Server to Raspberry Pi (or Linux Server)
Run the automated deployment script from your machine:
```bash
./deploy_server.sh
```
*What this does:*
1. Securely copies `server/` to `~/go-hi/server` on your remote server via SSH/SCP.
2. Generates and activates a systemd service (`gohi-server.service`).
3. Starts the server automatically and verifies health on port 8003.

### Step 3: Install the Client on Your Machine (Mac / Linux)
On your laptop or workstation, run:
```bash
./install.sh
```
*What this does:*
1. Initializes `~/.gohi` for configuration and offline spool storage.
2. Symlinks `gohi-ctl` into `~/.local/bin/gohi-ctl`.
3. Adds hooks to `~/.zshrc` (or `~/.bashrc`).
4. Starts the background daemon `gohi-daemon.py`.

### Step 4: Activate & Open
Reload your shell:
```bash
source ~/.zshrc   # Or open a new terminal window / tab
```
You will notice the `(Hello)` indicator in your prompt. 

Type `hello` in your terminal to open the web dashboard in your browser!
```bash
hello
```

---

## Option B: Standalone Local Mode (Zero-Server, Zero-Daemon)

If you just want your commands logged to an HTML dashboard on the local machine without running any background server or daemon:

### Step 1: Run the Local Installer
```bash
./local-logger/install-local.sh
```
*What this does:*
1. Creates `~/terminal-history.html` from the dashboard template.
2. Hooks into `~/.zshrc` and `~/.bashrc`.
3. Configures prompt prefix and the `hello` helper command.

### Step 2: Activate & Enjoy
```bash
source ~/.zshrc   # or source ~/.bashrc
```
Every command you run is now logged directly to `~/terminal-history.html`.

Type `hello` to open your local dashboard in your browser at any time!

---

## 🛠️ Management & Commands

### Client Daemon Management (`gohi-ctl`)
If running in Remote Mode (Option A), use `gohi-ctl` to control the client:

```bash
# Check status of daemon, server connectivity, and spool queue
gohi-ctl status

# Restart the client daemon
gohi-ctl restart

# Stop the client daemon
gohi-ctl stop

# Start the client daemon
gohi-ctl start

# Send a test entry to verify end-to-end logging
gohi-ctl test
```

### Remote Server Management
On your Raspberry Pi / remote server:
```bash
# Check server status
sudo systemctl status gohi-server

# Restart server
sudo systemctl restart gohi-server

# View live server logs
journalctl -u gohi-server -f
```

---

## 🌟 Dashboard Features

- **Click-to-Copy (📋)**: Click any command in the table to instantly copy it to your clipboard with a confirmation toast.
- **Delete Button (🗑️)**: Click the trash can icon on any row to delete unwanted commands or typos.
- **Sortable Columns**: Click **Command**, **Time**, **Duration**, or **Error code** headers to sort. By default, rows sort with the **most recent commands at the top**.
- **Instant Search**: Type in the search bar to filter commands and timestamps in real time.
- **Live Auto-Refresh**: In server mode, the dashboard polls for new commands every 2 seconds without reloading the page.

---

## ❓ Troubleshooting

### My prompt doesn't show `(Hello)`:
Run `source ~/.zshrc` (or `source ~/.bashrc`), or open a completely new terminal window.

### `gohi-ctl` says command not found:
Ensure `~/.local/bin` is in your `PATH`. You can add this to your `~/.zshrc`:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

### My laptop is offline / away from home:
`go/hi` features **zero data loss**:
1. When disconnected from your server, commands are safely buffered in `~/.gohi/pending.log`.
2. A full local HTML backup is maintained at `~/.gohi/backup.html`.
3. As soon as your laptop reconnects to the network, the daemon automatically flushes all pending commands to the server.
