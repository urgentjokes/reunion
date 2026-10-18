#!/bin/bash
# Deploy go/hi Server to Raspberry Pi or Remote Linux Machine
# Usage: ./deploy_server.sh [user@host or user] [host] [port]
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read defaults from config.env if available
CFG_FILE="$DIR/config.env"
if [ ! -f "$CFG_FILE" ] && [ -f "$HOME/.gohi/config.env" ]; then
    CFG_FILE="$HOME/.gohi/config.env"
fi

DEFAULT_HOST="192.168.0.40"
DEFAULT_USER="pi"
DEFAULT_PORT="8003"

if [ -f "$CFG_FILE" ]; then
    # Parse simple key-values
    CFG_HOST=$(grep -E '^GOHI_HOST=' "$CFG_FILE" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    CFG_PORT=$(grep -E '^GOHI_PORT=' "$CFG_FILE" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    CFG_USER=$(grep -E '^REMOTE_USER=' "$CFG_FILE" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    [ -n "$CFG_HOST" ] && DEFAULT_HOST="$CFG_HOST"
    [ -n "$CFG_PORT" ] && DEFAULT_PORT="$CFG_PORT"
    [ -n "$CFG_USER" ] && DEFAULT_USER="$CFG_USER"
fi

ARG1="$1"
ARG2="$2"
ARG3="$3"

if [[ "$ARG1" == *"@"* ]]; then
    REMOTE_USER="${ARG1%@*}"
    REMOTE_HOST="${ARG1#*@}"
else
    REMOTE_USER="${ARG1:-$DEFAULT_USER}"
    REMOTE_HOST="${ARG2:-$DEFAULT_HOST}"
fi
REMOTE_PORT="${ARG3:-$DEFAULT_PORT}"

TARGET="$REMOTE_USER@$REMOTE_HOST"
REMOTE_DIR="/home/$REMOTE_USER/go-hi"

echo "========================================="
echo " Deploying go/hi Server"
echo " Target: $TARGET"
echo " Port:   $REMOTE_PORT"
echo " Directory: $REMOTE_DIR"
echo "========================================="

echo "1. Creating remote directory structure on server..."
ssh "$TARGET" "mkdir -p '$REMOTE_DIR/server'"

echo "2. Copying server files to remote target..."
scp -r "$DIR/server/"* "$TARGET:$REMOTE_DIR/server/"

echo "3. Configuring and launching systemd service on remote server..."
ssh "$TARGET" "bash -s" <<EOF
set -e
SERVICE_FILE="/etc/systemd/system/gohi-server.service"

echo "Generating systemd service file..."
sudo tee "\$SERVICE_FILE" > /dev/null <<SERVICE_EOF
[Unit]
Description=go/hi Terminal Logging Server
After=network.target

[Service]
Type=simple
User=$REMOTE_USER
WorkingDirectory=$REMOTE_DIR/server
ExecStart=/usr/bin/python3 $REMOTE_DIR/server/server.py --port $REMOTE_PORT
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE_EOF

sudo systemctl daemon-reload
sudo systemctl enable gohi-server
sudo systemctl restart gohi-server
sleep 1
sudo systemctl status gohi-server --no-pager
EOF

echo ""
echo "4. Testing connection to server..."
if curl -s -f "http://$REMOTE_HOST:$REMOTE_PORT/health" >/dev/null; then
    echo "✔ SUCCESS! Server is online and responsive at:"
    echo "   http://$REMOTE_HOST:$REMOTE_PORT"
else
    echo "Server deployed. Check status with: ssh $TARGET 'systemctl status gohi-server'"
fi

echo "========================================="
echo " Server deployment completed!"
echo "========================================="
