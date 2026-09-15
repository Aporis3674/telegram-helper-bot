#!/usr/bin/env bash
set -e

echo "--------------------------------------------------"
echo "      Telegram Helper AI Bot Installer"
echo "--------------------------------------------------"

# Check root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script with root or sudo privileges."
  exit 1
fi

# Update system repositories and install dependencies
echo "[1/6] Updating system packages and installing prerequisites..."
apt-get update -y
apt-get install -y python3 python3-pip python3-venv curl git

# Installation directory
INSTALL_DIR="/opt/helper-bot"
echo "[2/6] Preparing project source in $INSTALL_DIR..."

if [ -d "$INSTALL_DIR/.git" ]; then
    echo "Existing repository found, pulling latest changes..."
    cd "$INSTALL_DIR"
    git pull origin main || true
elif [ -f "./bot.py" ]; then
    mkdir -p "$INSTALL_DIR"
    cp -r ./* "$INSTALL_DIR/" 2>/dev/null || true
else
    mkdir -p "$INSTALL_DIR"
    git clone https://github.com/Aporis3674/telegram-helper-bot.git "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"

# Setup Python virtual environment
echo "[3/6] Setting up Python virtual environment and installing packages..."
python3 -m venv venv
"$INSTALL_DIR/venv/bin/pip" install --upgrade pip
"$INSTALL_DIR/venv/bin/pip" install -r "$INSTALL_DIR/requirements.txt"

# Prompt configuration from user
echo "[4/6] Configuring environment variables..."
if [ -e /dev/tty ]; then
    read -p "Enter Telegram Bot Token: " TG_TOKEN </dev/tty
    read -p "Enter AI API Key: " AI_KEY </dev/tty
    read -p "Enter AI Base URL [Default: https://api.openai.com/v1]: " AI_BASE_URL </dev/tty
    read -p "Enter AI Model [Default: gpt-4o-mini]: " AI_MODEL </dev/tty
else
    read -p "Enter Telegram Bot Token: " TG_TOKEN
    read -p "Enter AI API Key: " AI_KEY
    read -p "Enter AI Base URL [Default: https://api.openai.com/v1]: " AI_BASE_URL
    read -p "Enter AI Model [Default: gpt-4o-mini]: " AI_MODEL
fi

AI_BASE_URL=${AI_BASE_URL:-"https://api.openai.com/v1"}
AI_MODEL=${AI_MODEL:-"gpt-4o-mini"}

# Create .env file
cat <<EOF > "$INSTALL_DIR/.env"
TELEGRAM_BOT_TOKEN=$TG_TOKEN
AI_API_KEY=$AI_KEY
AI_BASE_URL=$AI_BASE_URL
AI_MODEL=$AI_MODEL
EOF

chmod 600 "$INSTALL_DIR/.env"

# Create systemd service
echo "[5/6] Creating systemd background service..."
cat <<EOF > /etc/systemd/system/helper-bot.service
[Unit]
Description=Telegram Helper AI Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/venv/bin/python3 $INSTALL_DIR/bot.py
Restart=always
RestartSec=5
EnvironmentFile=$INSTALL_DIR/.env

[Install]
WantedBy=multi-user.target
EOF

# Reload and enable systemd service
echo "[6/6] Enabling and starting helper-bot service..."
systemctl daemon-reload
systemctl enable helper-bot
systemctl restart helper-bot

echo "--------------------------------------------------"
echo "Installation completed successfully."
echo "Check service status: systemctl status helper-bot"
echo "View live logs: journalctl -u helper-bot -f"
echo "Restart service: systemctl restart helper-bot"
echo "Stop service: systemctl stop helper-bot"
echo "--------------------------------------------------"
