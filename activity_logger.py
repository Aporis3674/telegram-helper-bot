import os
import json
import time
import logging
from logging.handlers import RotatingFileHandler
from datetime import datetime

LOGS_DIR = os.path.join(os.path.dirname(__file__), "logs")
os.makedirs(LOGS_DIR, exist_ok=True)

APP_LOG_FILE = os.path.join(LOGS_DIR, "helper_bot.log")
ACTIVITY_LOG_FILE = os.path.join(LOGS_DIR, "activity.jsonl")

# راه‌اندازی لاگر متنی چرخشی (Rotating Log)
logger = logging.getLogger("HelperBot")
logger.setLevel(logging.INFO)

# Console Handler
if not logger.handlers:
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)
    console_format = logging.Formatter(
        "%(asctime)s - [%(levelname)s] - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )
    console_handler.setFormatter(console_format)
    logger.addHandler(console_handler)

    # File Handler (Max 10MB per file, keeps 5 backups)
    file_handler = RotatingFileHandler(
        APP_LOG_FILE,
        maxBytes=10 * 1024 * 1024,
        backupCount=5,
        encoding="utf-8"
    )
    file_handler.setLevel(logging.INFO)
    file_format = logging.Formatter(
        "%(asctime)s - [%(levelname)s] - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )
    file_handler.setFormatter(file_format)
    logger.addHandler(file_handler)

def record_activity(
    user_id: int | None,
    username: str | None,
    full_name: str | None,
    chat_id: int | None,
    chat_type: str,
    chat_title: str | None,
    trigger_type: str,
    raw_message: str,
    query: str,
    replied_context: str | None,
    web_search_query: str | None,
    response_text: str,
    duration_sec: float,
    status: str = "success",
    error_message: str | None = None
):
    """
    ثبت کامل و دقیق رفتار کاربر در فایل لاگ ساختاریافته JSONL و لاگ متنی
    """
    record = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "user": {
            "id": user_id,
            "username": username,
            "name": full_name
        },
        "chat": {
            "id": chat_id,
            "type": chat_type,
            "title": chat_title
        },
        "trigger": trigger_type,
        "input": {
            "raw": raw_message,
            "cleaned_query": query,
            "replied_context": replied_context
        },
        "reasoning": {
            "web_search": bool(web_search_query),
            "search_query": web_search_query
        },
        "output": {
            "response": response_text,
            "length": len(response_text) if response_text else 0
        },
        "metrics": {
            "duration_sec": round(duration_sec, 2),
            "status": status,
            "error": error_message
        }
    }

    # ذخیره در فایل JSONL برای تحلیل سریع
    try:
        with open(ACTIVITY_LOG_FILE, "a", encoding="utf-8") as f:
            f.write(json.dumps(record, ensure_ascii=False) + "\n")
    except Exception as e:
        logger.error(f"Failed to write activity json: {e}")

    # چاپ لاگ خلاصه در کنسول و فایل متنی
    user_str = f"@{username}" if username else f"{full_name} ({user_id})"
    chat_str = f"[{chat_type.upper()}] {chat_title or chat_id}"
    logger.info(
        f"USER: {user_str} | CHAT: {chat_str} | TRIGGER: {trigger_type} | "
        f"QUERY: {query[:60]}... | SEARCH: {web_search_query or 'None'} | "
        f"TIME: {round(duration_sec, 2)}s | STATUS: {status}"
    )
