#!/bin/bash
# Install local terminal logger on Raspberry Pi
# Zero-server, zero-daemon: logs bash/zsh interactions directly to ~/pi-history.html
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_HTML="$HOME/pi-history.html"

echo "========================================="
echo " Installing go/hi Local Logger on Pi"
echo "========================================="

# 1. Initialize HTML file if not present
if [ ! -f "$TARGET_HTML" ]; then
    cp "$DIR/index.html" "$TARGET_HTML"
    echo "✔ Created local log HTML at: $TARGET_HTML"
else
    echo "✔ Found existing local log HTML at: $TARGET_HTML"
fi

# 2. Add to ~/.bashrc
BASHRC="$HOME/.bashrc"
HOOK_LINE="[ -f \"$DIR/gohi-pi.sh\" ] && source \"$DIR/gohi-pi.sh\""

if [ -f "$BASHRC" ]; then
    if ! grep -q "gohi-pi.sh" "$BASHRC"; then
        echo "" >> "$BASHRC"
        echo "# go/hi Pi Local Terminal Logger" >> "$BASHRC"
        echo "$HOOK_LINE" >> "$BASHRC"
        echo "✔ Added hook to $BASHRC"
    else
        echo "✔ Hook already present in $BASHRC"
    fi
fi

# 3. Add to ~/.zshrc if present
ZSHRC="$HOME/.zshrc"
if [ -f "$ZSHRC" ]; then
    if ! grep -q "gohi-pi.sh" "$ZSHRC"; then
        echo "" >> "$ZSHRC"
        echo "# go/hi Pi Local Terminal Logger" >> "$ZSHRC"
        echo "$HOOK_LINE" >> "$ZSHRC"
        echo "✔ Added hook to $ZSHRC"
    fi
fi

echo "========================================="
echo " Installation complete!"
echo " Log file: $TARGET_HTML"
echo " Run 'source ~/.bashrc' or open a new terminal session on the Pi to activate."
echo "========================================="
