#!/bin/bash
# Deploy local terminal logger to Raspberry Pi (zero-server mode)
set -e

PI_USER="${1:-bokkun}"
PI_HOST="${2:-192.168.0.40}"
TARGET="$PI_USER@$PI_HOST"
REMOTE_DIR="/home/$PI_USER/go-hi/pi-client"

echo "========================================="
echo " Deploying Local Logger to Raspberry Pi"
echo " Target: $TARGET"
echo " Remote Directory: $REMOTE_DIR"
echo "========================================="

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "1. Creating remote directory structure on Pi..."
ssh "$TARGET" "mkdir -p '$REMOTE_DIR'"

echo "2. Copying files to Pi..."
scp -r "$DIR/pi-client/"* "$TARGET:$REMOTE_DIR/"

echo "3. Running installer on Pi..."
ssh "$TARGET" "bash '$REMOTE_DIR/install-pi.sh'"

echo ""
echo "========================================="
echo " ✔ All set! Interactions on the Pi will now be logged locally to:"
echo "    /home/$PI_USER/pi-history.html"
echo "========================================="
