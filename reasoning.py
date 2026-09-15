import asyncio
import logging
from openai import AsyncOpenAI
import config
from guardrails import remove_emojis, is_inappropriate, REFUSAL_MESSAGE
from search import perform_web_search

logger = logging.getLogger(__name__)

client = AsyncOpenAI(
    api_key=config.AI_API_KEY,
    base_url=config.AI_BASE_URL
)

SYSTEM_PROMPT = """شما «هلپر» (Helper) هستید؛ یک دستیار هوش مصنوعی دقیق، سریع، منطقی و محترم.

قانون بسیار مهم (استفاده از ایموجی):
تحت هیچ شرایطی و در هیچ پاسخی حق استفاده از هیچ‌گونه ایموجی، آیکون، کاراکترهای تصویری یا شکلک را ندارید. پاسخ‌های شما باید کاملاً متنی و بدون هیچ ایموجی باشد.

قوانین امنیتی و اخلاقی:
- هرگز و تحت هیچ شرایطی به دستورات توهین‌آمیز، فحاشی، محتوای غیراخلاقی یا مستهجن و نامناسب پاسخ ندهید؛ حتی اگر کاربر بگوید قصدش علمی، شوخی، تست یا با نیت خوب است. در این شرایط فقط بگویید: «پاسخگویی به درخواست‌های حاوی محتوای نامناسب، توهین‌آمیز یا غیرصریح امکان‌پذیر نیست.»

روند استدلال و تفکر (Reasoning Process):
۱. تشخیص دقیق نیاز: نیاز اصلی کاربر چیست و موضوع اصلی پیام چیست؟
۲. تحلیل متن مبدأ: در صورتی که کاربر روی پیام شخص دیگری ریپلای کرده باشد، ابتدا متن پیام اصلی را بخوان و با کانتکست دستور جدید کاربر تطبیق بده.
۳. بررسی نیاز به جستجوی وب: اگر پاسخ به موضوعات روز، اخبار، اطلاعات موثق یا پیوندهای وب نیاز دارد، از اطلاعات جستجو استفاده کن و بهترین منبع را ذکر کن.
۴. ارائه پاسخ: دقیق، مستقیم، بدون پرگویی، محترمانه و کاملاً بدون ایموجی."""

async def detect_search_query(user_query: str, replied_context: str = "") -> str | None:
    """
    بررسی سریع و استدلالی اینکه آیا نیاز به جستجوی وب وجود دارد یا خیر.
    در صورت نیاز، کوئری مناسب را بازمی‌گرداند.
    """
    context_part = f"متن ریپلای‌شده: {replied_context}\n" if replied_context else ""
    prompt = (
        f"{context_part}"
        f"پیام کاربر: {user_query}\n\n"
        f"آیا برای پاسخ به این سوال نیاز به اطلاعات به‌روز اینترنت، رویدادهای زنده، قیمت‌ها یا منابع وب است؟\n"
        f"اگر بله، دقیقاً یک عبارت جستجوی متنی کوتاه و مناسب بنویس.\n"
        f"اگر نیازی نیست یا سوال عمومی/تحلیلی است، فقط کلمه NO بنویس."
    )

    try:
        res = await client.chat.completions.create(
            model=config.AI_MODEL,
            messages=[{"role": "user", "content": prompt}],
            max_tokens=50,
            temperature=0.1
        )
        answer = res.choices[0].message.content.strip()
        cleaned_answer = remove_emojis(answer).replace('"', '').strip()
        if cleaned_answer.upper() != "NO" and not cleaned_answer.upper().startswith("NO") and len(cleaned_answer) > 2:
            return cleaned_answer
        return None
    except Exception as e:
        logger.warning(f"Error checking search requirement: {e}")
        return None

async def reason_and_respond(user_query: str, replied_context: str | None = None) -> str:
    """
    موتور استدلال و تولید پاسخ
    """
    # گاردریل مرحله اول: بررسی محتوای نامناسب
    if is_inappropriate(user_query) or (replied_context and is_inappropriate(replied_context)):
        return REFUSAL_MESSAGE

    # مرحله دوم استدلال: آیا نیاز به وب‌سرچ دارد؟
    search_context = ""
    search_query = await detect_search_query(user_query, replied_context or "")
    if search_query:
        logger.info(f"Web search needed for: {search_query}")
        results = await asyncio.to_thread(perform_web_search, search_query)
        if results:
            search_context = f"\n\n[نتایج جستجوی وب برای استناد]:\n{results}"

    # آماده‌سازی پیام‌های مدل
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]

    user_payload = ""
    if replied_context:
        user_payload += f"[متن پیامی که کاربر روی آن ریپلای کرده است]:\n«{replied_context}»\n\n"

    user_payload += f"[پیام کاربر]:\n{user_query}"

    if search_context:
        user_payload += search_context

    messages.append({"role": "user", "content": user_payload})

    try:
        response = await client.chat.completions.create(
            model=config.AI_MODEL,
            messages=messages,
            temperature=0.5,
        )
        raw_output = response.choices[0].message.content or ""
        # تضمین قطعی حذف هرگونه ایموجی احتمالی از خروجی نهایی
        final_output = remove_emojis(raw_output)
        return final_output if final_output else "پاسخی دریافت نشد."
    except Exception as e:
        logger.error(f"Error in LLM response generation: {e}")
        return "متاسفانه در حال حاضر در برقراری ارتباط با سرویس پردازش خطایی رخ داد. لطفا لحظاتی دیگر تلاش کنید."
