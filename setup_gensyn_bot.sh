#!/bin/bash

echo "=============================="
echo "  Made by PRODIP - Gensyn Bot Setup (Last 10 Lines Only)"
echo "=============================="

# 1. User input
read -p "🔐 Enter your Telegram Bot Token: " BOT_TOKEN
read -p "💬 Enter your Telegram Chat ID: " CHAT_ID
read -p "✏️ Enter your Bot Promotion Name (header message): " BOT_PROMO_NAME
read -p "💻 Enter the tmux session name to monitor (default: GEN): " TMUX_SESSION
TMUX_SESSION=${TMUX_SESSION:-GEN}
read -p "👤 Enter your Name (for pink header, e.g., CJE): " USER_NAME

# 2. Setup directory
BOT_DIR=gensyn-tg-bot
mkdir -p "$BOT_DIR"
cd "$BOT_DIR"

# 3. Update & install dependencies
echo "⚙️ Updating package list and installing dependencies..."
sudo apt update -y
sudo apt install -y python3 python3-venv python3-pip tmux

# 4. Create & activate virtualenv
echo "🐍 Creating Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# 5. Upgrade pip and install python-telegram-bot
echo "📦 Installing required Python libraries..."
pip install --upgrade pip
pip install python-telegram-bot --quiet

# 6. Create Python bot script
cat > gensyn_log_tg_bot.py <<'EOF'
import asyncio
import subprocess
import time
import html
from telegram import Bot
from telegram.constants import ParseMode

BOT_TOKEN = 'BOT_TOKEN_PLACEHOLDER'
CHAT_ID = 'CHAT_ID_PLACEHOLDER'
BOT_PROMO_NAME = 'BOT_PROMO_NAME_PLACEHOLDER'
TMUX_SESSION = 'TMUX_SESSION_PLACEHOLDER'
USER_NAME = 'USER_NAME_PLACEHOLDER'

LOG_INTERVAL_MINUTES = 10
LOG_LINES_TO_SEND = 10

bot = Bot(token=BOT_TOKEN)
last_lines = []
last_log_time = time.time()

def get_tmux_logs(session_name=TMUX_SESSION):
    try:
        output = subprocess.check_output(['tmux', 'capture-pane', '-pt', session_name])
        lines = output.decode('utf-8').strip().splitlines()
        lines = [line.replace("<br>", "\n") for line in lines]
        return lines
    except Exception as e:
        print(f"[ERROR] TMUX capture failed: {e}")
        return []

async def send_message(message):
    try:
        await bot.send_message(chat_id=CHAT_ID, text=message, parse_mode=ParseMode.HTML)
        print("Sent:", message)
    except Exception as e:
        print(f"[ERROR] Telegram send failed: {e}")

async def send_last_10_lines():
    global last_log_time
    lines = get_tmux_logs()
    if not lines:
        return
    last_10_lines = lines[-LOG_LINES_TO_SEND:]
    header = f"☁️💗 {html.escape(BOT_PROMO_NAME)} 💗☁️\n💖 {html.escape(USER_NAME)} 💖\n"
    formatted_log = "\n".join([html.escape(line) for line in last_10_lines])
    msg = f"{header}\n<pre><code>{formatted_log}</code></pre>"
    await send_message(msg)
    last_log_time = time.time()

async def monitor_logs():
    global last_lines, last_log_time
    while True:
        lines = get_tmux_logs()
        if not lines:
            await asyncio.sleep(3)
            continue

        new_lines = [line for line in lines if line not in last_lines]

        # Instant alerts for important events
        instant_msgs = []
        for line in new_lines:
            line = line.strip()
            if not line:
                continue
            escaped_line = html.escape(line)
            if line.startswith("Starting round:"):
                instant_msgs.append(f"🚀 {escaped_line}")
            elif line.startswith("Joining round:"):
                instant_msgs.append(f"🔄 {escaped_line}")
            elif "logging_utils.global_defs][ERROR] - Exception occurred during game run." in line:
                instant_msgs.append(f"🚨 NODE CRASH DETECTED!\n{escaped_line}")

        # Send instant alerts
        for msg in instant_msgs:
            await send_message(f"☁️💗 {html.escape(BOT_PROMO_NAME)} 💗☁️\n💖 {html.escape(USER_NAME)} 💖\n{msg}")

        # Check 10 min log dump
        if time.time() - last_log_time >= LOG_INTERVAL_MINUTES * 60:
            await send_last_10_lines()

        last_lines = lines[-100:]
        await asyncio.sleep(3)

async def main():
    while True:
        try:
            await monitor_logs()
        except Exception as e:
            print(f"[CRASH] Bot crashed: {e}\nRestarting in 5 seconds...")
            await asyncio.sleep(5)

if __name__ == '__main__':
    asyncio.run(main())
EOF

# Escape user input
ESCAPED_BOT_TOKEN=$(printf '%s\n' "$BOT_TOKEN" | sed 's/[][\/.&*$]/\\&/g')
ESCAPED_CHAT_ID=$(printf '%s\n' "$CHAT_ID" | sed 's/[][\/.&*$]/\\&/g')
ESCAPED_BOT_PROMO_NAME=$(printf '%s\n' "$BOT_PROMO_NAME" | sed 's/[][\/.&*$]/\\&/g')
ESCAPED_TMUX_SESSION=$(printf '%s\n' "$TMUX_SESSION" | sed 's/[][\/.&*$]/\\&/g')
ESCAPED_USER_NAME=$(printf '%s\n' "$USER_NAME" | sed 's/[][\/.&*$]/\\&/g')

# Replace placeholders
sed -i "s|BOT_TOKEN_PLACEHOLDER|${ESCAPED_BOT_TOKEN}|g" gensyn_log_tg_bot.py
sed -i "s|CHAT_ID_PLACEHOLDER|${ESCAPED_CHAT_ID}|g" gensyn_log_tg_bot.py
sed -i "s|BOT_PROMO_NAME_PLACEHOLDER|${ESCAPED_BOT_PROMO_NAME}|g" gensyn_log_tg_bot.py
sed -i "s|TMUX_SESSION_PLACEHOLDER|${ESCAPED_TMUX_SESSION}|g" gensyn_log_tg_bot.py
sed -i "s|USER_NAME_PLACEHOLDER|${ESCAPED_USER_NAME}|g" gensyn_log_tg_bot.py

# 7. Run bot inside tmux session
echo "🚀 Starting the bot inside tmux session 'TGBOT'..."
tmux new-session -d -s TGBOT "cd $PWD && source venv/bin/activate && python gensyn_log_tg_bot.py"

echo "✅ Setup complete!"
echo "📝 To view bot logs: tmux attach -t TGBOT"
echo "📝 To detach tmux: Press Ctrl+B then D"
