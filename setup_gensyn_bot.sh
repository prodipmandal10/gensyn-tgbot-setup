#!/usr/bin/env python3

import asyncio
import subprocess
from telegram import Bot
import time
import re
from datetime import datetime

# ====== CONFIGURATION ======
BOT_TOKEN = 'YOUR_TELEGRAM_BOT_TOKEN'
CHAT_ID = 'YOUR_TELEGRAM_CHAT_ID'
BOT_PROMO_NAME = 'GENSYN- CJE(1)'   # আপনি নিজেরভাবে পরিবর্তন করতে পারেন
TMUX_SESSION = 'GEN'               # tmux session নাম, যদি আলাদা হয় সেটাও পরিবর্তন করুন
ALERT_INTERVAL = 600               # ১০ মিনিট = 600 সেকেন্ড
MAX_TRACK_LINES = 100              # কত লাইন মনে রাখবে (prevent duplicate alerts কোনও পুরোনো লগ নিয়ে)
# ============================

bot = Bot(token=BOT_TOKEN)
last_lines = []
last_alert_time = 0

def get_tmux_logs(session_name=TMUX_SESSION):
    """tmux থেকে session এর সমস্ত pane লগ ধরবে"""
    try:
        output = subprocess.check_output(['tmux', 'capture-pane', '-pt', session_name])
        return output.decode('utf-8', errors='ignore').strip().splitlines()
    except Exception as e:
        print(f"[ERROR] TMUX capture failed: {e}")
        return []

def clean_line(line: str) -> str:
    """লগের অপ্রয়োজনীয় অংশ ও বড় progress bar কমিয়ে সুন্দর একটি লাইন তৈরি করবে"""
    # Long progress bar কমিয়ে দেখাবে শুধু শুরু ও কিছু অংশ
    line = re.sub(r"█+", "█…", line)
    # লাইন আগে ও পরে spaces কেটে ফেল
    return line.strip()

async def send_message(text: str, parse_html: bool = False):
    try:
        if parse_html:
            await bot.send_message(chat_id=CHAT_ID, text=text, parse_mode="HTML")
        else:
            await bot.send_message(chat_id=CHAT_ID, text=text)
        print(f"Sent message at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    except Exception as e:
        print(f"[ERROR] Telegram send failed: {e}")

async def send_alert(lines):
    """শেষ ১০ লাইন একটি সুন্দর HTML pre block এ পাঠাবে"""
    clean_logs = "\n".join([clean_line(l) for l in lines[-10:]])
    timestamp = datetime.now().strftime("%d-%m-%Y %H:%M")
    message = (
        f"<b>🚨 GENSYN LOGS CHECK, [{timestamp}]</b>\n"
        f"<b>{BOT_PROMO_NAME}</b>\n\n"
        f"<pre>{clean_logs}</pre>"
    )
    await send_message(message, parse_html=True)

async def monitor_logs():
    global last_lines, last_alert_time
    while True:
        lines = get_tmux_logs()
        if not lines:
            await asyncio.sleep(3)
            continue

        # detect new lines to send events immediately
        new_lines = [line for line in lines if line not in last_lines]

        for line in new_lines:
            stripped = line.strip()
            if not stripped:
                continue

            # কিছু ইভেন্ট থাকলে সংবাদ / 알림 পাঠাবে
            if "Map: 100%" in stripped:
                msg = f"{BOT_PROMO_NAME}\n🗺️ {clean_line(stripped)}"
                await send_message(msg)
            elif stripped.startswith("Starting round:"):
                msg = f"{BOT_PROMO_NAME}\n🚀 {clean_line(stripped)}"
                await send_message(msg)
            elif stripped.startswith("Joining round:"):
                msg = f"{BOT_PROMO_NAME}\n🔄 {clean_line(stripped)}"
                await send_message(msg)
            elif "logging_utils.global_defs][ERROR]" in stripped:
                msg = f"{BOT_PROMO_NAME}\n🚨 NODE CRASH DETECTED!\n{clean_line(stripped)}"
                await send_message(msg)

        # duplicate prevention
        last_lines = lines[-MAX_TRACK_LINES:]

        # প্রতি ALERT_INTERVAL পর alert পাঠাবে
        now = time.time()
        if now - last_alert_time >= ALERT_INTERVAL:
            await send_alert(lines)
            last_alert_time = now

        await asyncio.sleep(3)

if __name__ == "__main__":
    asyncio.run(monitor_logs())
