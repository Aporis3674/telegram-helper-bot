#!/usr/bin/env bash
set -e

echo "--------------------------------------------------"
echo "        نصب خودکار ربات تلگرام Helper"
echo "--------------------------------------------------"

# بررسی دسترسی روت
if [ "$EUID" -ne 0 ]; then
  echo "خطا: لطفا این اسکریپت را با دسترسی root یا sudo اجرا کنید."
  exit 1
fi

# بروزرسانی مخازن لینوکس و نصب پیش‌نیازها
echo "[1/6] بروزرسانی سیستم و نصب پیش‌نیازها..."
apt-get update -y
apt-get install -y python3 python3-pip python3-venv curl git

# مسیر نصب
INSTALL_DIR="/opt/helper-bot"
echo "[2/6] آماده‌سازی و دریافت کدهای پروژه در $INSTALL_DIR..."

if [ -d "$INSTALL_DIR/.git" ]; then
    echo "پروژه از قبل موجود است، دریافت آخرین تغییرات..."
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

# ایجاد محیط مجازی پایتون
echo "[3/6] ایجاد محیط مجازی پایتون و نصب پکیج‌ها..."
python3 -m venv venv
"$INSTALL_DIR/venv/bin/pip" install --upgrade pip
"$INSTALL_DIR/venv/bin/pip" install -r "$INSTALL_DIR/requirements.txt"

# دریافت اطلاعات تنظیمی از کاربر
echo "[4/6] تنظیم مقادیر اولیه..."
# استفاده از dev/tty جهت پشتیبانی کامل از اجرای تعاملی در پایپ curl
if [ -e /dev/tty ]; then
    read -p "توکن ربات تلگرام (Telegram Bot Token): " TG_TOKEN </dev/tty
    read -p "کلید هوش مصنوعی (AI API Key): " AI_KEY </dev/tty
    read -p "آدرس Base URL هوش مصنوعی [پیش‌فرض: https://api.openai.com/v1]: " AI_BASE_URL </dev/tty
    read -p "نام مدل هوش مصنوعی [پیش‌فرض: gpt-4o-mini]: " AI_MODEL </dev/tty
else
    read -p "توکن ربات تلگرام (Telegram Bot Token): " TG_TOKEN
    read -p "کلید هوش مصنوعی (AI API Key): " AI_KEY
    read -p "آدرس Base URL هوش مصنوعی [پیش‌فرض: https://api.openai.com/v1]: " AI_BASE_URL
    read -p "نام مدل هوش مصنوعی [پیش‌فرض: gpt-4o-mini]: " AI_MODEL
fi
AI_MODEL=${AI_MODEL:-"gpt-4o-mini"}

# ایجاد فایل .env
cat <<EOF > "$INSTALL_DIR/.env"
TELEGRAM_BOT_TOKEN=$TG_TOKEN
AI_API_KEY=$AI_KEY
AI_BASE_URL=$AI_BASE_URL
AI_MODEL=$AI_MODEL
EOF

chmod 600 "$INSTALL_DIR/.env"

# ایجاد سرویس systemd
echo "[5/6] ساخت سرویس سیستم (Systemd Service)..."
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

# بارگذاری و فعال‌سازی سرویس
echo "[6/6] فعال‌سازی و راه‌اندازی سرویس..."
systemctl daemon-reload
systemctl enable helper-bot
systemctl restart helper-bot

echo "--------------------------------------------------"
echo "نصب ربات با موفقیت به پایان رسید."
echo "وضعیت سرویس: systemctl status helper-bot"
echo "مشاهده زنده لاگ‌ها: journalctl -u helper-bot -f"
echo "توقف ربات: systemctl stop helper-bot"
echo "راه‌اندازی مجدد: systemctl restart helper-bot"
echo "--------------------------------------------------"
