# reunion — Terminal Interaction Monitor & Viewer

A lightweight terminal interaction logger for macOS and Raspberry Pi. It automatically captures commands, timestamps, execution durations, and exit codes from all Terminal windows and tabs, prepends `(Hello)` to your prompt, and streams the logs to a live HTML page hosted on your Raspberry Pi living at `192.168.0.40:8003`.

---

## 🔄 How to Restart the Server and/or Daemon

### 1. Restarting the Mac Daemon (`gohi-daemon`)

The Mac daemon runs quietly in the background, collects terminal interactions from all tabs, and forwards them to the Raspberry Pi.

- **To restart the daemon in one command:**
  ```bash
  gohi-ctl restart
  ```
- **To start the daemon if it was stopped:**
  ```bash
  hello
  ```
  *(or `gohi-ctl start`)*
- **To stop the daemon:**
  ```bash
  gohi-ctl stop
  ```
- **To check if the daemon is running and view queue status:**
  ```bash
  gohi-ctl status
  ```

---

### 2. Restarting the Raspberry Pi Server (`gohi-server`)

The server runs on your Raspberry Pi at `192.168.0.40:8003` as a `systemd` service.

- **Option A (From your Mac — Recommended):**
  Run the automated deployment script from this directory:
  ```bash
  cd ~/developer-stuff/go-hi
  ./deploy_to_pi.sh
  ```
  *This copies the latest files, reloads systemd, restarts the server, and checks health.*

- **Option B (Directly via SSH from your Mac):**
  Restart the systemd service remotely:
  ```bash
  ssh bokkun@192.168.0.40 "sudo systemctl restart gohi-server"
  ```
  *(or use your shell alias: `pi` to SSH into the Pi first, then run `sudo systemctl restart gohi-server`)*

- **To check the Raspberry Pi server status:**
  ```bash
  ssh bokkun@192.168.0.40 "sudo systemctl status gohi-server"
  ```

- **To view live server logs on the Pi:**
  ```bash
  ssh bokkun@192.168.0.40 "sudo journalctl -u gohi-server -f"
  ```

---

## 🌐 Viewing the Log

- **Live on Raspberry Pi**: [http://192.168.0.40:8003](http://192.168.0.40:8003)
- **Local Mac Backup**: [~/developer-stuff/go-hi/index.html](file:///Users/davefriedman2023/developer-stuff/go-hi/index.html) *(double-click to open in any browser)*

---

## Architecture Overview

```
 ┌────────────────────────────────────────────────────────┐
 │                      macOS Client                      │
 │                                                        │
 │   Terminal Tab 1  Terminal Tab 2   Terminal Tab N      │
 │        │               │                │              │
 │        └───────────────┼────────────────┘              │
 │                        ▼                               │
 │             ~/.gohi/spool.log (zero-lag queue)         │
 │                        │                               │
 │                        ▼                               │
 │          gohi-daemon.py (background worker)            │
 │             ├─► Local HTML backup (~/go-hi/index.html) │
 │             └─► Retries offline buffering              │
 └────────────────────────┬───────────────────────────────┘
                          │ HTTP POST /log
                          ▼
 ┌────────────────────────────────────────────────────────┐
 │             Raspberry Pi (192.168.0.40)                │
 │                                                        │
 │   server.py (port 8003)                                │
 │     ├─► Appends <tr> row directly to index.html        │
 │     ├─► Serves "Hello–I’m Home" web page               │
 │     └─► Live-updates connected browser tabs            │
 └────────────────────────────────────────────────────────┘
```

---

## Features

1. **Lightweight & Zero Prompt Lag**: Commands are captured via native shell hooks (`zsh` and `bash`) with microsecond timestamp resolution and appended to a local queue in under 0.1ms. Your prompt will never hang, even if the Pi or Wi-Fi is temporarily down.
2. **Offline-Resilient**: The background daemon buffers interactions locally if the Raspberry Pi is unreachable, automatically flushing them when connectivity is restored.
3. **Local Backup Copy**: Every interaction is written simultaneously to `~/developer-stuff/go-hi/index.html` as an offline backup.
4. **Prompt Indicator**: When running, `(Hello)` is prepended to your command-line prompt:
   ```
   (Hello) /Users/davefriedman2023/developer-stuff/liberator (15:49) 
   > 
   ```
5. **"Hello–I’m Home" Web Dashboard**:
   - 4 required columns: **Command**, **Time**, **Duration**, **Error code**.
   - Clickable commands with instant copy-to-clipboard and toast confirmation.
   - Color-coded badges for error codes (`0` is green, non-zero is red).
   - Instant search/filter box and live auto-updating.
   - Pure HTML/CSS/JS with zero runtime dependencies.

---

## Initial Setup Reference

### Step 1: Deploy Server to Raspberry Pi
```bash
./deploy_to_pi.sh
```

### Step 2: Install Mac Client Hook
```bash
./install.sh
### Step 3: (Optional) Install Local Logger on Raspberry Pi Itself
To log your shell commands directly on the Raspberry Pi into a local HTML file (`~/pi-history.html`) with zero server/daemon needed:
```bash
./deploy_pi_local_logger.sh
```

---

## File Structure

- `client/`
  - `gohi.zsh`: Mac shell hooks, prompt modifier, and daemon checker for zsh.
  - `gohi.bash`: Mac shell hooks for bash.
  - `gohi-daemon.py`: Mac background daemon shipping records to the Pi with offline queueing.
  - `gohi-ctl`: Command-line management tool (`status`, `start`, `stop`, `restart`, `test`).
- `server/`
  - `index.html`: "Hello–I’m Home" dashboard template.
  - `server.py`: Lightweight Python 3 HTTP server that serves `index.html` and appends incoming logs.
  - `gohi-server.service`: Systemd service configuration for Raspberry Pi OS.
- `pi-client/`
  - `gohi-pi.sh`: Zero-server local shell logger for the Raspberry Pi (bash & zsh).
  - `index.html`: Standalone HTML dashboard template for Pi local history.
  - `install-pi.sh`: Installer script that runs on the Pi.
- `index.html`: Local backup HTML copy automatically maintained on your Mac.
- `install.sh`: Mac client configuration script.
- `deploy_to_pi.sh`: Deploy Raspberry Pi HTTP server.
- `deploy_pi_local_logger.sh`: Deploy zero-server local logger directly to Raspberry Pi.
