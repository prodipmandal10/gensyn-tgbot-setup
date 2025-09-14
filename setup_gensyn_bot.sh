#!/bin/bash

# ---------- User Config ----------
BOT_TOKEN="YOUR_BOT_TOKEN"
CHAT_ID="YOUR_CHAT_ID"
BOT_PROMO_NAME="GENSYN-CJE(1)"
TMUX_SESSION="gensyn_bot"
ALERT_INTERVAL=600   # 10 min
MAX_TRACK_LINES=200

# ---------- Install Dependencies ----------
sudo apt update -y
sudo apt install -y python3 python3-pip tmux

pip3 install python-telegram-bot==13.15

# ---------- Create Python Bot Script ----------
cat > gensyn_log_tg_bot.py << 'EOF'
import os
import time
import html
from telegram import Bot

# ---------- Config ----------
BOT_TOKEN = os.getenv("BOT_TOKEN", "YOUR_BOT_TOKEN")
CHAT_ID = os.getenv("CHAT_ID", "YOUR_CHAT_ID")
BOT_PROMO_NAME = os.getenv("BOT_PROMO_NAME", "GENSYN-CJE(1)")
ALERT_INTERVAL = int(os.getenv("ALERT_INTERVAL", "600"))
MAX_TRACK_LINES = int(os.getenv("MAX_TRACK_LINES", "200"))

bot = Bot(token=BOT_TOKEN)
log_file = os.path.expanduser("~/gensyn.log")

def send_message(text):
    bot.send_message(chat_id=CHAT_ID, text=text, parse_mode="HTML")

def tail_logs():
    """Keep only last N lines in log file"""
    if not os.path.exists(log_file):
        return []
    with open(log_file, "r") as f:
        lines = f.readlines()
    if len(lines) > MAX_TRACK_LINES:
        with open(log_file, "w") as f:
            f.writelines(lines[-MAX_TRACK_LINES:])
        lines = lines[-MAX_TRACK_LINES:]
    return lines

def main():
    while True:
        lines = tail_logs()
        if lines:
            last_10 = "\n".join(lines[-10:])
            # escape logs to avoid telegram HTML error
            escaped_logs = html.escape(last_10)
            msg = f"<b>🚨 {BOT_PROMO_NAME} - GENSYN LOGS CHECK 🚨</b>\n\n<pre>{escaped_logs}</pre>"
            send_message(msg)
        time.sleep(ALERT_INTERVAL)

if __name__ == "__main__":
    main()
EOF

# ---------- Export Vars ----------
export BOT_TOKEN=$BOT_TOKEN
export CHAT_ID=$CHAT_ID
export BOT_PROMO_NAME=$BOT_PROMO_NAME
export ALERT_INTERVAL=$ALERT_INTERVAL
export MAX_TRACK_LINES=$MAX_TRACK_LINES

# ---------- Run Inside tmux ----------
tmux kill-session -t $TMUX_SESSION 2>/dev/null
tmux new-session -d -s $TMUX_SESSION "python3 gensyn_log_tg_bot.py"
echo "✅ Gensyn Telegram Bot started inside tmux session: $TMUX_SESSION"
