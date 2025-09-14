#!/bin/bash

echo "=============================="
echo "  Made by PRODIP - Gensyn Bot Setup"
echo "=============================="

# 1. User input
read -p "🔐 Enter your Telegram Bot Token: " BOT_TOKEN
read -p "💬 Enter your Telegram Chat ID: " CHAT_ID
read -p "✏️ Enter your Bot Promotion Name (header message): " BOT_PROMO_NAME

# 2. Setup directory
BOT_DIR=$HOME/gensyn-tg-bot
mkdir -p "$BOT_DIR"
cd "$BOT_DIR"

# 3. Write Python bot script
cat > gensyn_log_tg_bot.py <<EOF
import asyncio
import subprocess
from telegram import Bot

BOT_TOKEN = "$BOT_TOKEN"
CHAT_ID = "$CHAT_ID"
BOT_PROMO_NAME = "$BOT_PROMO_NAME"

bot = Bot(token=BOT_TOKEN)

def get_tmux_logs(session_name="GEN"):
    try:
        output = subprocess.check_output(['tmux', 'capture-pane', '-pt', session_name])
        return output.decode('utf-8').strip().splitlines()
    except Exception:
        return []

async def periodic_alert():
    while True:
        lines = get_tmux_logs()
        if lines:
            last_10 = "\n".join(lines[-10:])
            msg = f"<b>🚨 {BOT_PROMO_NAME} - GENSYN LOGS CHECK 🚨</b>\\n\\n<pre>{last_10}</pre>"
            try:
                await bot.send_message(chat_id=CHAT_ID, text=msg, parse_mode="HTML")
                print("Sent logs update ✅")
            except Exception as e:
                print("[ERROR]", e)
        await asyncio.sleep(600)  # প্রতি 10 মিনিটে alert

if __name__ == "__main__":
    asyncio.run(periodic_alert())
EOF

# 4. Install dependencies
echo "⚙️ Installing Python & packages..."
sudo apt update -y
sudo apt install -y python3 python3-venv python3-pip tmux

python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install python-telegram-bot --quiet

# 5. Run bot in tmux
echo "🚀 Starting the bot inside tmux session 'TGBOT'..."
tmux kill-session -t TGBOT 2>/dev/null
tmux new-session -d -s TGBOT "cd $BOT_DIR && source venv/bin/activate && python gensyn_log_tg_bot.py"

echo "✅ Setup complete!"
echo "👉 To view bot logs: tmux attach -t TGBOT"
echo "👉 To detach: Press Ctrl+B then D"
