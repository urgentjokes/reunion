# go/hi — Terminal Interaction Monitor & Viewer

A lightweight terminal interaction logger for macOS and Raspberry Pi. It automatically captures commands, timestamps, execution durations, and exit codes from all Terminal windows and tabs, prepends `(Hello)` to your prompt, and streams the logs to a live HTML page hosted on your Raspberry Pi living at `192.168.0.40`.

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
3. **Prompt Indicator**: When running, `(Hello)` is prepended to your command-line prompt:
   ```
   (Hello) /Users/davefriedman2023/developer-stuff/liberator (15:49) 
   > 
   ```
4. **"Hello–I’m Home" Web Dashboard**:
   - 4 required columns: **Command**, **Time**, **Duration**, **Error code**.
   - Clickable commands with instant copy-to-clipboard and toast confirmation.
   - Color-coded badges for error codes (`0` is green, non-zero is red).
   - Instant search/filter box and live auto-updating.
   - Pure HTML/CSS/JS with zero runtime dependencies.

---

## Quick Setup

### Step 1: Deploy Server to Raspberry Pi

Run the automated deploy script:
```bash
./deploy_to_pi.sh
```
This copies the server files to `bokkun@192.168.0.40:/home/bokkun/go-hi/server`, installs and starts the `systemd` service (`gohi-server.service`), and verifies the endpoint.

You can view the page anytime by opening:
**`http://192.168.0.40:8003`** (or open the local backup at `~/developer-stuff/go-hi/index.html`)

### Step 2: Install Mac Client Hook

Run the local installer:
```bash
./install.sh
```
This:
- Adds the `gohi.zsh` source hook to `~/.zshrc` (and `~/.bashrc` if present).
- Adds the `hello` alias to manually start the daemon whenever needed.
- Symlinks `gohi-ctl` into `~/.local/bin/gohi-ctl` for easy status checks.
- Launches the background daemon.

To activate immediately in your current terminal:
```bash
source ~/.zshrc
```

To manually launch the daemon anytime:
```bash
hello
```

---

## Verifying & Managing

Use `gohi-ctl` from any terminal:

```bash
# Check status of daemon, local queue, and Raspberry Pi server
gohi-ctl status

# Send a test log entry directly to the Raspberry Pi
gohi-ctl test

# Start or stop the background daemon
gohi-ctl start
gohi-ctl stop
```

---

## File Structure

- `client/`
  - `gohi.zsh`: Shell hooks (`preexec`, `precmd`), prompt modifier, and daemon self-healing for zsh.
  - `gohi.bash`: Equivalent hooks for bash users.
  - `gohi-daemon.py`: Mac background daemon shipping records to the Pi with offline queueing.
  - `gohi-ctl`: Command-line management tool.
- `server/`
  - `index.html`: "Hello–I’m Home" dashboard.
  - `server.py`: Lightweight Python 3 HTTP server that serves `index.html` and appends incoming logs.
  - `gohi-server.service`: Systemd service configuration for Raspberry Pi OS.
- `install.sh`: Mac client configuration script.
- `deploy_to_pi.sh`: Remote Raspberry Pi deployment script.
