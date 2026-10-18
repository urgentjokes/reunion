# nostalgia — Terminal Interaction Monitor

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Python: 3.7+](https://img.shields.io/badge/Python-3.7+-brightgreen.svg)]()
[![Shell: Bash / Zsh](https://img.shields.io/badge/Shell-Bash%20%7C%20Zsh-orange.svg)]()

> **"Hello–I’m Home"** — A lightweight, real-time terminal interaction monitor that logs every command you run, along with timestamps, execution durations, and exit status, presented in a clean, dark-mode web dashboard.

---

## 🎯 3 Supported Use Cases

1. **Use Case 1: Standalone Local HTML File (Zero-Server, Zero-Daemon)**
   - No server or daemon required.
   - Shell hooks write directly to `~/terminal-history.html`.
   - Perfect for single machines or standalone Raspberry Pi use.

2. **Use Case 2: Remote Server Only (Centralized Network Logger)**
   - Central web server on your Raspberry Pi or home server (`http://<host>:8003`).
   - Laptops forward commands across your local network. No local HTML stored.
   - Perfect for clean workstations and multi-device centralization.

3. **Use Case 3: Remote Server with Local HTML Backup (Hybrid / Offline-Safe)**
   - Live centralized server dashboard **plus** an offline-synced local HTML backup (`~/.gohi/backup.html`).
   - Buffers commands offline and automatically synchronizes when reconnected.
   - Perfect for laptops that move between home and travel.

---

## ✨ Features

- ⚡ **Zero-Latency Shell Hooks**: Lightweight preexec/precmd hooks for **Zsh** and **Bash** that never slow down your prompt.
- 🏠 **"Hello–I'm Home" Web Dashboard**: Clean, responsive dark-mode UI.
- 📋 **Click-to-Copy**: Click any command to copy it immediately to your clipboard.
- 🗑️ **One-Click Deletion**: Delete unwanted commands or typos directly from the dashboard.
- ↕️ **Sortable & Filterable**: Sort dynamically by Command, Time, Duration, or Error code. Defaults to **most recent first**. Real-time instant search filter.
- 🛡️ **Offline Queue**: Safe spool buffering ensures zero data loss during network hiccups.

---

## 🚀 Quickstart

See [QUICKSTART.md](QUICKSTART.md) for full walkthroughs of all three use cases.

### Quick Commands

#### Use Case 1: Local HTML Only
```bash
./local-logger/install-local.sh
source ~/.zshrc
hello
```

#### Use Case 2: Remote Server Only
```bash
cp config.example.env config.env
# Edit config.env: set ENABLE_LOCAL_BACKUP=false and your GOHI_HOST
./deploy_server.sh
./install.sh
source ~/.zshrc
hello
```

#### Use Case 3: Remote Server + Local Backup
```bash
cp config.example.env config.env
# Edit config.env: GOHI_HOST="<server-ip>", ENABLE_LOCAL_BACKUP=true (default)
./deploy_server.sh
./install.sh
source ~/.zshrc
hello
```

---

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
