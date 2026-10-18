# go/hi — Terminal Interaction Monitor

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Python: 3.7+](https://img.shields.io/badge/Python-3.7+-brightgreen.svg)]()
[![Shell: Bash / Zsh](https://img.shields.io/badge/Shell-Bash%20%7C%20Zsh-orange.svg)]()

> **"Hello–I’m Home"** — A lightweight, real-time terminal interaction monitor that logs every command you run, along with timestamps, execution durations, and exit status, presented in a clean, dark-mode web dashboard.

---

## ✨ Features

- ⚡ **Zero-Latency Shell Hooks**: Lightweight preexec/precmd hooks for **Zsh** and **Bash** that never slow down your prompt.
- 🏠 **"Hello–I'm Home" Web Dashboard**: Beautiful, dark-mode responsive UI.
- 📋 **Click-to-Copy**: Click any command link to immediately copy it to your system clipboard.
- 🗑️ **One-Click Deletion**: Delete unwanted commands, typos, or sensitive entries directly from the dashboard.
- ↕️ **Sortable & Filterable**: Sort dynamically by Command, Time, Duration, or Error code. Defaults to most recent first. Instant client-side search filtering.
- 🛡️ **Zero Data Loss**: Offline spool buffering automatically syncs pending commands once network connectivity to your server is restored.
- 🔄 **Two Deployment Modes**:
  1. **Remote Server Mode**: Ship logs to a central Raspberry Pi / home server.
  2. **Standalone Local Mode**: Zero-server, zero-daemon direct logging to a local HTML file.

---

## 🚀 Quickstart

See [QUICKSTART.md](QUICKSTART.md) for full setup instructions.

### 1. Remote Server Mode (Raspberry Pi / Linux Server)
```bash
# 1. Configure target server
cp config.example.env config.env
nano config.env

# 2. Deploy server to Raspberry Pi / Linux host
./deploy_server.sh

# 3. Install client on your Mac / Linux laptop
./install.sh

# 4. Activate shell
source ~/.zshrc
hello
```

### 2. Standalone Local Mode (Single Machine / Zero-Server)
```bash
./local-logger/install-local.sh
source ~/.zshrc
hello
```

---

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
