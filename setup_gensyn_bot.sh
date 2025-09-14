#!/bin/bash

echo "=============================="
echo "  Made by PRODIP - Gensyn Bot Setup"
echo "=============================="

# 1. User input
read -p "🔐 Enter your Telegram Bot Token: " BOT_TOKEN
read -p "💬 Enter your Telegram Chat ID: " CHAT_ID
read -p "✏️ Enter your Bot Promotion Name (header message): " BOT_PROMO_NAME

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
# Using <<'EOF' to prevent shell from interpreting Python code inside the block
cat > gensyn_log_tg_bot.py <<'EOF'
import asyncio
import subprocess
import time
from telegram import Bot
from telegram.constants import ParseMode

BOT_TOKEN = 'BOT_TOKEN_PLACEHOLDER'
CHAT_ID = 'CHAT_ID_PLACEHOLDER'
BOT_PROMO_NAME = 'BOT_PROMO_NAME_PLACEHOLDER'
LOG_INTERVAL_MINUTES = 10
LOG_LINES_TO_SEND = 10

bot = Bot(token=BOT_TOKEN)
last_lines = []
last_log_time = time.time()

def get_tmux_logs(session_name="GEN"):
    try:
        output = subprocess.check_output(['tmux', 'capture-pane', '-pt', session_name])
        return output.decode('utf-8').strip().splitlines()
    except Exception as e:
        print(f"[ERROR] TMUX capture failed: {e}")
        return []

def escape_markdown_v2(text):
    """Escapes special characters in Markdown V2 to avoid parsing errors."""
    escape_chars = r'_*[]()~`>#+-=|{}.!'
    return "".join(f"\\{char}" if char in escape_chars else char for char in text)

async def send_last_10_lines():
    global last_log_time
    lines = get_tmux_logs()
    
    if not lines:
        return

    # Get the last 10 lines
    last_10_lines = lines[-LOG_LINES_TO_SEND:]
    
    # Format the message in a monospaced block
    header = f"{BOT_PROMO_NAME}\n\n📋 Last {LOG_LINES_TO_SEND} lines of log:"
    formatted_log = "\n".join([escape_markdown_v2(line) for line in last_10_lines])
    
    # Use triple backticks for a code block in Markdown V2
    msg = f"{header}\n```\n{formatted_log}\n```"
    await send_message(msg)
    last_log_time = time.time()

async def monitor_logs():
    global last_lines, last_log_time
    while True:
        lines = get_tmux_logs()
        if not lines:
            await asyncio.sleep(3)
            continue
        
        # Check for new logs and send instant alerts
        new_lines = [line for line in lines if line not in last_lines]

        for line in new_lines:
            line = line.strip()
            if not line:
                continue
            
            header = BOT_PROMO_NAME
            
            if "Map: 100%" in line:
                msg = f"{header}\n🗺️ {escape_markdown_v2(line)}"
                await send_message(msg)
            
            elif line.startswith("Starting round:"):
                msg = f"{header}\n🚀 {escape_markdown_v2(line)}"
                await send_message(msg)
            
            elif line.startswith("Joining round:"):
                msg = f"{header}\n🔄 {escape_markdown_v2(line)}"
                await send_message(msg)
            
            elif "logging_utils.global_defs][ERROR] - Exception occurred during game run." in line:
                msg = f"{header}\n🚨 NODE CRASH DETECTED!\n{escape_markdown_v2(line)}"
                await send_message(msg)
        
        # Check if 10 minutes have passed to send the log dump
        if time.time() - last_log_time >= LOG_INTERVAL_MINUTES * 60:
            await send_last_10_lines()

        last_lines = lines[-100:]
        await asyncio.sleep(3)

async def send_message(message):
    try:
        await bot.send_message(chat_id=CHAT_ID, text=message, parse_mode=ParseMode.MARKDOWN_V2)
        print("Sent:", message)
    except Exception as e:
        print(f"[ERROR] Telegram send failed: {e}")

if __name__ == '__main__':
    asyncio.run(monitor_logs())
EOF

# Properly escape user input for sed to avoid issues with special characters
ESCAPED_BOT_TOKEN=$(printf '%s\n' "$BOT_TOKEN" | sed 's/[][\/.&*$]/\\&/g')
ESCAPED_CHAT_ID=$(printf '%s\n' "$CHAT_ID" | sed 's/[][\/.&*$]/\\&/g')
ESCAPED_BOT_PROMO_NAME=$(printf '%s\n' "$BOT_PROMO_NAME" | sed 's/[][\/.&*$]/\\&/g')

# Replace placeholders with escaped user input values
sed -i "s|BOT_TOKEN_PLACEHOLDER|${ESCAPED_BOT_TOKEN}|g" gensyn_log_tg_bot.py
sed -i "s|CHAT_ID_PLACEHOLDER|${ESCAPED_CHAT_ID}|g" gensyn_log_tg_bot.py
sed -i "s|BOT_PROMO_NAME_PLACEHOLDER|${ESCAPED_BOT_PROMO_NAME}|g" gensyn_log_tg_bot.py


# 7. Run bot inside tmux session
echo "🚀 Starting the bot inside tmux session 'TGBOT'..."
tmux new-session -d -s TGBOT "cd $PWD && source venv/bin/activate && python gensyn_log_tg_bot.py"

echo "✅ Setup complete!"
echo "📝 To view bot logs: tmux attach -t TGBOT"
echo "📝 To detach tmux: Press Ctrl+B then D"
