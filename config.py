import os
from dotenv import load_dotenv

load_dotenv()

TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "").strip()
AI_API_KEY = os.getenv("AI_API_KEY", "").strip()
AI_BASE_URL = os.getenv("AI_BASE_URL", "https://api.openai.com/v1").strip()
AI_MODEL = os.getenv("AI_MODEL", "gpt-4o-mini").strip()

# کلمات کلیدی برای صدا زدن هلپر
TRIGGER_NAMES = ["هلپر", "helper"]
