import re

# الگوی حذف هرگونه ایموجی و نشانه‌های گرافیکی
EMOJI_PATTERN = re.compile(
    "["
    "\U0001F600-\U0001F64F"  # emoticons
    "\U0001F300-\U0001F5FF"  # symbols & pictographs
    "\U0001F680-\U0001F6FF"  # transport & map symbols
    "\U0001F1E0-\U0001F1FF"  # flags (iOS)
    "\U00002702-\U000027B0"
    "\U000024C2-\U0001F251"
    "\U0001F900-\U0001F9FF"  # supplemental symbols
    "\U0001FA70-\U0001FAFF"  # symbols and pictographs extended-a
    "\U00002600-\U000026FF"  # miscellaneous symbols
    "\U00002B50"             # star
    "\U0000FE0F"             # variation selector
    "]+",
    flags=re.UNICODE
)

def remove_emojis(text: str) -> str:
    """حذف کامل تمام ایموجی‌ها از متن خروجی"""
    if not text:
        return ""
    cleaned = EMOJI_PATTERN.sub("", text)
    # اصلاح فاصله‌های اضافه احتمالی بعد از حذف ایموجی
    return re.sub(r' +', ' ', cleaned).strip()

# کلمات و الگوهای توهین‌آمیز و نامناسب
OFFENSIVE_KEYWORDS = [
    r'کسکش', r'کصکش', r'جنده', r'کونی', r'حرومزاده', r'خارکصه',
    r'مادرسگ', r'بی‌شرف', r'بیشرف', r'حرومی', r'دیوث', r'سکس',
    r'پورن', r'کیر', r'کون', r'جق', r'لاشی', r'پفیوز', r'مادرقهوه'
]

OFFENSIVE_REGEX = re.compile("|".join(OFFENSIVE_KEYWORDS), re.IGNORECASE)

REFUSAL_MESSAGE = "پاسخگویی به درخواست‌های حاوی محتوای نامناسب، توهین‌آمیز یا غیرصریح امکان‌پذیر نیست."

def is_inappropriate(text: str) -> bool:
    """بررسی اینکه آیا متن ورودی حاوی کلمات توهین‌آمیز یا غیراخلاقی است یا خیر"""
    if not text:
        return False
    return bool(OFFENSIVE_REGEX.search(text))
