#!/bin/bash
# Install go/hi on Mac
# Configures Terminal to run the mechanism in the background across all tabs and windows
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSHRC="$HOME/.zshrc"
BASHRC="$HOME/.bashrc"
LOCAL_BIN="$HOME/.local/bin"

echo "========================================="
echo " Installing go/hi on Mac"
echo "========================================="

# 1. Create spool directory
mkdir -p "$HOME/.gohi"

# 2. Install CLI helper into ~/.local/bin
mkdir -p "$LOCAL_BIN"
ln -sf "$DIR/client/gohi-ctl" "$LOCAL_BIN/gohi-ctl"
echo "✔ Linked gohi-ctl into $LOCAL_BIN/gohi-ctl"

# 3. Add to ~/.zshrc
GOHI_SOURCE_LINE="[ -f \"$DIR/client/gohi.zsh\" ] && source \"$DIR/client/gohi.zsh\""
GOHI_ALIAS_LINE="alias hello=\"$LOCAL_BIN/gohi-ctl start\""
if [ -f "$ZSHRC" ]; then
    if ! grep -q "gohi.zsh" "$ZSHRC"; then
        echo "" >> "$ZSHRC"
        echo "# go/hi Terminal Logging Mechanism" >> "$ZSHRC"
        echo "$GOHI_SOURCE_LINE" >> "$ZSHRC"
        echo "✔ Added go/hi hook to $ZSHRC"
    fi
    if ! grep -q "alias hello=" "$ZSHRC"; then
        echo "$GOHI_ALIAS_LINE" >> "$ZSHRC"
        echo "✔ Added alias hello to $ZSHRC"
    fi
else
    echo "# go/hi Terminal Logging Mechanism" > "$ZSHRC"
    echo "$GOHI_SOURCE_LINE" >> "$ZSHRC"
    echo "$GOHI_ALIAS_LINE" >> "$ZSHRC"
    echo "✔ Created $ZSHRC with go/hi hook and alias hello"
fi

# 4. Optional bash support
if [ -f "$BASHRC" ]; then
    if ! grep -q "gohi.bash" "$BASHRC"; then
        echo "" >> "$BASHRC"
        echo "# go/hi Terminal Logging Mechanism" >> "$BASHRC"
        echo "[ -f \"$DIR/client/gohi.bash\" ] && source \"$DIR/client/gohi.bash\"" >> "$BASHRC"
        echo "alias hello=\"$LOCAL_BIN/gohi-ctl start\"" >> "$BASHRC"
        echo "✔ Added go/hi hook and alias hello to $BASHRC"
    fi
fi

# 5. Start background daemon
echo "Starting go/hi background daemon..."
nohup /usr/bin/python3 "$DIR/client/gohi-daemon.py" >/dev/null 2>&1 &
sleep 0.5

# 6. Verify daemon status
"$DIR/client/gohi-ctl" status

echo "========================================="
echo " Installation complete!"
echo " In Terminal, run 'source ~/.zshrc' or open a new window/tab to activate."
echo "========================================="
