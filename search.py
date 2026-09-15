import logging
from duckduckgo_search import DDGS
from guardrails import remove_emojis

logger = logging.getLogger(__name__)

def perform_web_search(query: str, max_results: int = 4) -> str:
    """
    جستجوی سریع وب بدون نیاز به کلید API با DuckDuckGo
    و استخراج بهترین نتایج به همراه منبع
    """
    if not query:
        return ""
    try:
        results = []
        with DDGS() as ddgs:
            for r in ddgs.text(query, max_results=max_results):
                title = remove_emojis(r.get("title", ""))
                body = remove_emojis(r.get("body", ""))
                href = r.get("href", "")
                results.append(f"- عنوان: {title}\n  خلاصه: {body}\n  منبع: {href}")

        if results:
            return "\n\n".join(results)
        return "هیچ نتیجه‌ای در وب یافت نشد."
    except Exception as e:
        logger.error(f"Search error: {e}")
        return "خطا در برقراری ارتباط با وب."
