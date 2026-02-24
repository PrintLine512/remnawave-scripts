#!/bin/bash
set -e

INSTALL_DIR="/opt/remnanode-agent"
REPO_URL="https://github.com/Case211/remnawave-admin.git"
AGENT_AUTH_TOKEN=${AGENT_AUTH_TOKEN:?Need AGENT_AUTH_TOKEN}
AGENT_NODE_UUID=${AGENT_NODE_UUID:?Need AGENT_NODE_UUID}
ENV_FILE="$INSTALL_DIR/node-agent/.env"

echo "==> Installing Remnawave Node Agent"

# зависимости
apt update
apt install -y git python3 python3-venv python3-pip

# создаём директорию
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# если уже есть репа — обновляем
if [ -d "$INSTALL_DIR/.git" ]; then
    echo "==> Updating existing repository"
    git fetch origin main
    git reset --hard origin/main
else
    echo "==> Cloning repository (sparse checkout)"
    git clone --filter=blob:none --no-checkout $REPO_URL .
    git sparse-checkout init --cone
    git sparse-checkout set node-agent
    git checkout main
fi

cd node-agent



if [ ! -f "$ENV_FILE" ]; then
    echo "==> Creating .env file"

    cat > "$ENV_FILE" <<EOF
AGENT_NODE_UUID=$AGENT_NODE_UUID
AGENT_AUTH_TOKEN=$AGENT_AUTH_TOKEN

AGENT_COLLECTOR_URL=https://vadms.xer.su
AGENT_COMMAND_ENABLED=true
AGENT_WS_SECRET_KEY=30fc9aee7a0926f455bbdf726655b5a1c9b8b80b1b72d819198a728cf01d6c13

AGENT_INTERVAL_SECONDS=30
AGENT_LOG_PARSING_MODE=realtime
AGENT_REALTIME_CHECK_INTERVAL_SECONDS=5
AGENT_XRAY_LOG_PATH=/var/log/remnanode/access.log

AGENT_MAX_BUFFER_SIZE=50000
AGENT_SEND_MAX_RETRIES=3
AGENT_SEND_RETRY_DELAY_SECONDS=5.0

AGENT_LOG_LEVEL=DEBUG
AGENT_MAX_UPTIME_HOURS=6
EOF

    chmod 600 "$ENV_FILE"
else
    echo "==> .env already exists — skipping"
fi

# python venv
if [ ! -d "venv" ]; then
    echo "==> Creating virtual environment"
    python3 -m venv venv
fi

source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# systemd unit
echo "==> Creating systemd service"

cat > /etc/systemd/system/remnanode-agent.service <<EOF
[Unit]
Description=Remnawave Node Agent
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR/node-agent
EnvironmentFile=$INSTALL_DIR/node-agent/.env
ExecStart=$INSTALL_DIR/node-agent/venv/bin/python -m src.main
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now remnanode-agent

echo "==> Done"
systemctl status remnanode-agent --no-pager
