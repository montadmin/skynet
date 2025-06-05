Включва:
🔹 1. Генериране и обобщаване на новини
Scraper за сайтове (вкл. Google News, RSS)

Обобщаване на български език с Mistral 7B

Класификация и тагване (ключови думи)

🔹 2. Проверка на факти
SearXNG локална търсачка

Cross-check с други източници (новини по същата тема)

API за проверка в реално време

🔹 3. Генериране на изображения от текст
Stable Diffusion (InvokeAI) с RTX A4000

Web UI за T2I

Поддържа български промпти

🔹 4. Обработка на видео и аудио
Whisper (Faster Whisper GPU)

Транскрипция на аудио новини (вкл. YouTube/Vimeo mp4)

Поддръжка на български език

🔹 5. Telegram / Email интеграция
Автоматично изпращане на новини към Telegram канал/бот

Email чрез SMTP

Viber – подготвена интеграция (опционално)

🔹 6. WordPress авто-публикуване
REST API връзка към https://montana-live.tv

Категоризация, тагове, изображения

🔹 7. Web Admin Панел (на български и английски)
OpenWebUI (ChatGPT-подобен)

InvokeAI Web UI

Custom Admin Dashboard (FastAPI + SQLite + Stats)

Cron и логове

Самообучение на AI върху твое съдържание
Включва:

LoRA/QLoRA обучение върху локални новини (напр. от montana-live.tv)

Fine-tune скрипт (на база Mistral 7B)

HuggingFace съвместимост (за експортиране на моделите)

Dataset builder (auto-scraper + tokenizer за български)

Сигурност & Reverse Proxy
Traefik + HTTPS (Let's Encrypt)

Fail2Ban, UFW firewall

WireGuard VPN сървър

Базова защита на UI с пароли и 2FA (при желание)

Хардуерни изисквания:
Работи отлично с Cisco UCS C460 M4 + RTX A4000

Мин. 64GB RAM (за inference + training LoRA)

Мин. 12 CPU ядра за оптимална производителност

