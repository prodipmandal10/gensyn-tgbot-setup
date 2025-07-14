import asyncio
import subprocess
from telegram import Bot

BOT_TOKEN = '$BOT_TOKEN'
CHAT_ID = '$CHAT_ID'
BOT_PROMO_NAME = '$BOT_PROMO_NAME'

bot = Bot(token=BOT_TOKEN)
last_lines = []

def get_tmux_logs(session_name="GEN"):
    try:
        output = subprocess.check_output(['tmux', 'capture-pane', '-pt', session_name])
        return output.decode('utf-8').strip().splitlines()
    except Exception as e:
        print(f"[ERROR] TMUX capture failed: {e}")
        return []

async def monitor_logs():
    global last_lines
    while True:
        lines = get_tmux_logs()
        if not lines:
            await asyncio.sleep(3)
            continue

        new_lines = [line for line in lines if line not in last_lines]

        for line in new_lines:
            line = line.strip()
            if not line:
                continue

            header = BOT_PROMO_NAME

            if "Map: 100%" in line:
                msg = f"{header}\\n🩷 ({line})"
                await send_message(msg)

            elif line.startswith("Starting round:"):
                msg = f"{header}\\n🩷 ({line})"
                await send_message(msg)

            elif line.startswith("Joining round:"):
                msg = f"{header}\\n🩷 ({line})"
                await send_message(msg)

            elif "logging_utils.global_defs][ERROR] - Exception occurred during game run." in line:
                msg = f"{header}\\n🩷 (🚨 NODE CRASH DETECTED! {line})"
                await send_message(msg)

        last_lines = lines[-100:]
        await asyncio.sleep(3)

async def send_message(message):
    try:
        await bot.send_message(chat_id=CHAT_ID, text=message)
        print("Sent:", message)
    except Exception as e:
        print("[ERROR] Telegram send failed:", e)

if __name__ == '__main__':
    asyncio.run(monitor_logs())
