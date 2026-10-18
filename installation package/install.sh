#!/bin/bash
# Install reunion Client on macOS / Linux
# Configures shell hooks, links gohi-ctl CLI, and starts the background daemon.
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSHRC="$HOME/.zshrc"
BASHRC="$HOME/.bashrc"
LOCAL_BIN="$HOME/.local/bin"
GOHI_DIR="$HOME/.gohi"

echo "========================================="
echo " Installing reunion Client"
echo "========================================="

# 1. Create client spool and config directory
mkdir -p "$GOHI_DIR"

# Copy config.env if present in installer and not yet in ~/.gohi
if [ -f "$DIR/config.env" ] && [ ! -f "$GOHI_DIR/config.env" ]; then
    cp "$DIR/config.env" "$GOHI_DIR/config.env"
    echo "✔ Copied config.env to $GOHI_DIR/config.env"
elif [ -f "$DIR/config.example.env" ] && [ ! -f "$GOHI_DIR/config.env" ]; then
    cp "$DIR/config.example.env" "$GOHI_DIR/config.env"
    echo "✔ Initialized default $GOHI_DIR/config.env (edit to customize host/port)"
fi

# 2. Make client scripts executable
chmod +x "$DIR/client/gohi-ctl" "$DIR/client/gohi-daemon.py" "$DIR/client/gohi.zsh" "$DIR/client/gohi.bash" 2>/dev/null || true

# 3. Install CLI helper into ~/.local/bin
mkdir -p "$LOCAL_BIN"
ln -sf "$DIR/client/gohi-ctl" "$LOCAL_BIN/gohi-ctl"
echo "✔ Linked gohi-ctl into $LOCAL_BIN/gohi-ctl"

# Ensure ~/.local/bin is in PATH notice
if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
    echo "ℹ Note: Make sure $LOCAL_BIN is in your PATH to run 'gohi-ctl' from anywhere."
fi

# 4. Add to shell rc files
ADDED=0
if [ -f "$ZSHRC" ] || [ "$SHELL" = "*/zsh" ]; then
    touch "$ZSHRC"
    GOHI_ZSH="[ -f \"$DIR/client/gohi.zsh\" ] && source \"$DIR/client/gohi.zsh\""
    if ! grep -q "gohi.zsh" "$ZSHRC"; then
        echo "" >> "$ZSHRC"
        echo "# reunion Terminal Logging Client" >> "$ZSHRC"
        echo "$GOHI_ZSH" >> "$ZSHRC"
        echo "✔ Added hook to $ZSHRC"
    else
        echo "✔ Hook already present in $ZSHRC"
    fi
    ADDED=1
fi

if [ -f "$BASHRC" ] || [ "$SHELL" = "*/bash" ]; then
    touch "$BASHRC"
    GOHI_BASH="[ -f \"$DIR/client/gohi.bash\" ] && source \"$DIR/client/gohi.bash\""
    if ! grep -q "gohi.bash" "$BASHRC"; then
        echo "" >> "$BASHRC"
        echo "# reunion Terminal Logging Client" >> "$BASHRC"
        echo "$GOHI_BASH" >> "$BASHRC"
        echo "✔ Added hook to $BASHRC"
    else
        echo "✔ Hook already present in $BASHRC"
    fi
    ADDED=1
fi

# 5. Start background daemon
echo "Starting reunion background daemon..."
"$DIR/client/gohi-ctl" restart >/dev/null 2>&1 || {
    nohup /usr/bin/python3 "$DIR/client/gohi-daemon.py" >/dev/null 2>&1 &
}
sleep 0.5

# 6. Verify status
"$DIR/client/gohi-ctl" status

echo "========================================="
echo " Installation complete!"
echo " In Terminal, run 'source ~/.zshrc' (or ~/.bashrc) to activate."
echo " Type 'hello' in your terminal to open the web dashboard!"
echo "========================================="
