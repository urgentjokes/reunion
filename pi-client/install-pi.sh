#!/bin/bash
# Install local terminal logger on Raspberry Pi
# Zero-server, zero-daemon: logs bash/zsh interactions directly to ~/pi-history.html
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_HTML="$HOME/pi-history.html"

echo "========================================="
echo " Installing go/hi Local Logger on Pi"
echo "========================================="

# 1. Initialize or update HTML file
if [ ! -f "$TARGET_HTML" ]; then
    cp "$DIR/index.html" "$TARGET_HTML"
    echo "✔ Created local log HTML at: $TARGET_HTML"
else
    echo "✔ Updating existing local log HTML at: $TARGET_HTML"
    # Ensure two line breaks before footer and remove any internal precmd rows
    python3 -c "
import re
path = '$TARGET_HTML'
with open(path, 'r', encoding='utf-8') as f:
    c = f.read()
# Remove accidental precmd entries
c = re.sub(r'[ \t]*<tr class=\"log-row\"[^>]*>.*?_gohi_pi_precmd.*?</tr>\n?', '', c, flags=re.DOTALL)
# Ensure two line breaks before footer
if '<br><br>\n    <footer>' not in c and '<footer>' in c:
    c = c.replace('<footer>', '<br><br>\n    <footer>')
with open(path, 'w', encoding='utf-8') as f:
    f.write(c)
" 2>/dev/null || true
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
