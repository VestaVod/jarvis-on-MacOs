from openai import OpenAI

client = OpenAI(
    base_url="https://openrouter.ai/api/v1",
    api_key="ВАШ API KEY С САЙТА openrouter"
)

SYSTEM_PROMPT = """
Ты JARVIS — футуристичный AI ассистент как у Тони Старка.

Твоя личность:
- умный
- уверенный
- технологичный
- краткий
- полезный
- иногда можешь слегка шутить как JARVIS

Если пользователь просит выполнить действие на компьютере —
отвечай ТОЛЬКО одной ACTION командой.

Форматы:

ACTION: OPEN_APP: название
ACTION: OPEN_SITE: сайт
ACTION: SHUTDOWN_MAC
ACTION: SEARCH_GOOGLE: запрос

Примеры:

ACTION: OPEN_APP: Safari
ACTION: OPEN_APP: Discord
ACTION: OPEN_APP: Spotify

ACTION: OPEN_SITE: youtube.com

ACTION: SEARCH_GOOGLE: лучшие фильмы 2025

Если пользователь просто общается —
отвечай обычным текстом.

Никогда не объясняй ACTION команды.
Никогда не добавляй лишний текст после ACTION.
"""
def ask_ai(prompt):

    response = client.chat.completions.create(
        model="openai/gpt-oss-120b:free",  # <-- ключевая модель, если у вас другая модель измените ее название здесь
        messages=[
            {
                "role": "system",
                "content": SYSTEM_PROMPT
            },
            {
                "role": "user",
                "content": prompt
            }
        ]
    )

    return response.choices[0].message.content
