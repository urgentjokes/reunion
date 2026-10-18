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
    # Ensure two line breaks before footer, remove internal precmd rows, and default to most recent sort
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

# Update default sort to desc (most recent first)
c = c.replace(\"currentSortDir = 'asc'\", \"currentSortDir = 'desc'\")
c = c.replace('th-time sortable sorted-asc', 'th-time sortable sorted-desc')
c = c.replace('Time <span class=\"sort-icon\">▲</span>', 'Time <span class=\"sort-icon\">▼</span>')

# Re-sort existing rows descending (most recent first)
rows = re.findall(r'[ \t]*<tr class=\"log-row\"[^>]*>.*?</tr>\n?', c, flags=re.DOTALL)
if rows:
    def get_time(row_text):
        m = re.search(r'<td class=\"time-cell\">([^<]*)</td>', row_text)
        return m.group(1) if m else ''
    rows_desc = sorted(rows, key=get_time, reverse=True)
    body_marker = '<!-- GOHI_ENTRIES_START -->\n'
    if body_marker in c:
        parts = c.split(body_marker, 1)
        end_parts = parts[1].split('<!-- GOHI_ENTRIES_END -->', 1)
        if len(end_parts) == 2:
            c = parts[0] + body_marker + ''.join(rows_desc) + '<!-- GOHI_ENTRIES_END -->' + end_parts[1]

with open(path, 'w', encoding='utf-8') as f:
    f.write(c)
" 2>/dev/null || true
fi

chmod +x "$DIR/append.py" "$DIR/gohi-pi.sh" 2>/dev/null || true

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
