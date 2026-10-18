#!/bin/bash
# Install nostalgia Standalone Local Logger
# Zero-server, zero-daemon: logs bash/zsh interactions directly to ~/terminal-history.html
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_HTML="${GOHI_HTML:-$HOME/terminal-history.html}"

echo "========================================="
echo " Installing nostalgia Standalone Local Logger"
echo "========================================="

# 1. Initialize HTML file
if [ ! -f "$TARGET_HTML" ]; then
    cp "$DIR/index.html" "$TARGET_HTML"
    echo "✔ Created local log HTML at: $TARGET_HTML"
else
    echo "✔ Found existing local log HTML at: $TARGET_HTML"
fi

chmod +x "$DIR/append.py" "$DIR/gohi-local.sh" 2>/dev/null || true

# 2. Add to ~/.zshrc if zsh exists / is default shell
HOOK_LINE="[ -f \"$DIR/gohi-local.sh\" ] && source \"$DIR/gohi-local.sh\""
ADDED=0

if [ -f "$HOME/.zshrc" ] || [ "$SHELL" = "*/zsh" ]; then
    ZSHRC="$HOME/.zshrc"
    touch "$ZSHRC"
    if ! grep -q "gohi-local.sh" "$ZSHRC"; then
        echo "" >> "$ZSHRC"
        echo "# nostalgia Standalone Local Terminal Logger" >> "$ZSHRC"
        echo "$HOOK_LINE" >> "$ZSHRC"
        echo "✔ Added hook to $ZSHRC"
    else
        echo "✔ Hook already present in $ZSHRC"
    fi
    ADDED=1
fi

# 3. Add to ~/.bashrc if bash exists / is default shell
if [ -f "$HOME/.bashrc" ] || [ "$SHELL" = "*/bash" ]; then
    BASHRC="$HOME/.bashrc"
    touch "$BASHRC"
    if ! grep -q "gohi-local.sh" "$BASHRC"; then
        echo "" >> "$BASHRC"
        echo "# nostalgia Standalone Local Terminal Logger" >> "$BASHRC"
        echo "$HOOK_LINE" >> "$BASHRC"
        echo "✔ Added hook to $BASHRC"
    else
        echo "✔ Hook already present in $BASHRC"
    fi
    ADDED=1
fi

if [ "$ADDED" -eq 0 ]; then
    echo "Notice: Neither ~/.zshrc nor ~/.bashrc found. Add this line to your shell rc file:"
    echo "  $HOOK_LINE"
fi

echo "========================================="
echo " Installation complete!"
echo " Log file: $TARGET_HTML"
echo " Run 'source ~/.zshrc' (or ~/.bashrc) to activate, or open a new terminal."
echo " Type 'hello' in your terminal at any time to open your log dashboard!"
echo "========================================="
