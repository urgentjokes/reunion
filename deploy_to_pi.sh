#!/bin/bash
# Deploy go/hi Server to Raspberry Pi (192.168.0.40)
set -e

PI_USER="${1:-bokkun}"
PI_HOST="${2:-192.168.0.40}"
TARGET="$PI_USER@$PI_HOST"
REMOTE_DIR="/home/$PI_USER/go-hi"

echo "========================================="
echo " Deploying go/hi Server to Raspberry Pi"
echo " Target: $TARGET"
echo " Remote Directory: $REMOTE_DIR"
echo "========================================="

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "1. Creating remote directory structure on Pi..."
ssh "$TARGET" "mkdir -p '$REMOTE_DIR/server'"

echo "2. Copying server files to Pi..."
scp -r "$DIR/server/"* "$TARGET:$REMOTE_DIR/server/"

echo "3. Configuring and starting systemd service on Pi..."
ssh "$TARGET" "bash -s" <<'EOF'
set -e
echo "Configuring gohi-server service..."
sudo cp /home/bokkun/go-hi/server/gohi-server.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable gohi-server
sudo systemctl restart gohi-server
sleep 1
sudo systemctl status gohi-server --no-pager
EOF

echo ""
echo "4. Testing connection to Raspberry Pi server..."
if curl -s -f "http://$PI_HOST:8003/health" >/dev/null; then
    echo "✔ SUCCESS! Raspberry Pi server is running and healthy at:"
    echo "   http://$PI_HOST:8003"
else
    echo "Server deployed. Check status with: ssh $TARGET 'systemctl status gohi-server'"
fi

echo "========================================="
echo " Deployment completed!"
echo "========================================="
