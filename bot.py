import re
import html
import logging
from telegram import Update
from telegram.constants import ParseMode
from telegram.ext import (
    Application,
    CommandHandler,
    MessageHandler,
    filters,
    ContextTypes
)
import config
from guardrails import remove_emojis
from reasoning import reason_and_respond

logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    level=logging.INFO
)
logger = logging.getLogger("HelperBot")

async def send_as_blockquote(message, text: str, quote: bool = True):
    """
    ارسال پیام داخل قالب blockquote در تلگرام
    به همراه پشتیبانی از پیام‌های طولانی و تضمین عدم وجود ایموجی
    """
    cleaned = remove_emojis(text)
    if not cleaned:
        cleaned = "پاسخی دریافت نشد."

    # بررسی محدودیت طول پیام در تلگرام (حداکثر ۴۰۹۶ کاراکتر)
    chunk_size = 3500
    if len(cleaned) <= chunk_size:
        formatted = f"<blockquote>{html.escape(cleaned)}</blockquote>"
        try:
            await message.reply_text(formatted, parse_mode=ParseMode.HTML, quote=quote)
        except Exception as e:
            logger.warning(f"Error sending HTML blockquote: {e}. Falling back to plain text.")
            await message.reply_text(cleaned, quote=quote)
    else:
        # تقسیم به چند پیام برای پیام‌های طولانی
        for i in range(0, len(cleaned), chunk_size):
            chunk = cleaned[i:i + chunk_size]
            formatted_chunk = f"<blockquote>{html.escape(chunk)}</blockquote>"
            is_first = (i == 0)
            try:
                await message.reply_text(formatted_chunk, parse_mode=ParseMode.HTML, quote=(quote if is_first else False))
            except Exception:
                await message.reply_text(chunk, quote=(quote if is_first else False))

def is_bot_mentioned_or_called(text: str, bot_username: str) -> bool:
    """
    بررسی اینکه آیا در متن پیام، ربات تگ شده یا نام «هلپر» یا «helper» آمده است
    """
    if not text:
        return False

    # بررسی منشن آیدی ربات
    if bot_username and f"@{bot_username.lower()}" in text.lower():
        return True

    # بررسی نام هلپر یا helper با در نظر گرفتن مرز کلمات و علائم نگارشی
    pattern = re.compile(r'(^|\s|[،,\.\!\?])(هلپر|helper)($|\s|[،,\.\!\?])', re.IGNORECASE)
    return bool(pattern.search(text))

def clean_trigger_words(text: str, bot_username: str) -> str:
    """
    حذف نام ربات و منشن از متن برای ارسال پرسش خالص به موتور استدلال
    """
    if not text:
        return ""
    cleaned = text
    if bot_username:
        cleaned = re.sub(rf'@{bot_username}', '', cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r'(^|\s|[،,\.\!\?])(هلپر|helper)($|\s|[،,\.\!\?])', ' ', cleaned, flags=re.IGNORECASE)
    return cleaned.strip()

async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    پاسخ به دستور start کاملا رسمی، بدون ایموجی و در قالب blockquote
    """
    message = update.effective_message
    if not message:
        return
    text = (
        "سلام. من هلپر (Helper) هستم، دستیار هوشمند شما.\n\n"
        "می‌توانید سوالات خود را بپرسید. در گروه‌ها نیز با صدا زدن نام من (هلپر یا helper)، "
        "منشن کردن آیدی من یا ریپلای روی پیام دیگران و صدا زدنم، می‌توانم به شما پاسخ دهم."
    )
    await send_as_blockquote(message, text, quote=False)

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    message = update.effective_message
    if not message or not (message.text or message.caption):
        return

    chat_type = message.chat.type
    raw_text = message.text or message.caption or ""

    bot_info = await context.bot.get_me()
    bot_username = bot_info.username or ""

    is_private = chat_type == "private"
    is_reply_to_bot = (
        message.reply_to_message is not None and
        message.reply_to_message.from_user is not None and
        message.reply_to_message.from_user.id == bot_info.id
    )
    is_called = is_bot_mentioned_or_called(raw_text, bot_username)

    # اگر در گروه باشد و ربات صدا زده نشده باشد و ریپلای روی خود ربات نباشد، پیام نادیده گرفته می‌شود
    if not is_private and not is_reply_to_bot and not is_called:
        return

    # استخراج کانتکست پیام ریپلای‌شده در صورت وجود
    replied_context = None
    if message.reply_to_message:
        replied_msg = message.reply_to_message
        replied_context = replied_msg.text or replied_msg.caption
        # اگر نام فرستنده پیام ریپلای‌شده موجود بود، به کانتکست اضافه می‌کنیم
        sender_name = replied_msg.from_user.full_name if replied_msg.from_user else "کاربر"
        if replied_context:
            replied_context = f"پیام از طرف {sender_name}: {replied_context}"

    # پاکسازی متن سوال از کلمات صدازدن
    query = clean_trigger_words(raw_text, bot_username)
    if not query and replied_context:
        query = "این پیام را بررسی، تحلیل یا خلاصه کن و توضیح بده."
    elif not query:
        query = raw_text

    # ارسال وضعیت در حال تایپ
    await context.bot.send_chat_action(chat_id=message.chat_id, action="typing")

    # پردازش در موتور استدلال
    response_text = await reason_and_respond(query, replied_context)

    # ارسال پاسخ به صورت blockquote
    await send_as_blockquote(message, response_text, quote=True)

def main():
    if not config.TELEGRAM_BOT_TOKEN:
        logger.error("خطا: مقدار TELEGRAM_BOT_TOKEN در فایل .env تنظیم نشده است.")
        return

    if not config.AI_API_KEY:
        logger.warning("هشدار: مقدار AI_API_KEY در فایل .env تنظیم نشده است.")

    app = Application.builder().token(config.TELEGRAM_BOT_TOKEN).build()

    app.add_handler(CommandHandler("start", start_command))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))

    logger.info("Helper Bot is starting...")
    app.run_polling()

if __name__ == "__main__":
    main()
