Ключови функционалности:
Събиране на новини:

Поддръжка за RSS/Atom фийдове (Dnevnik, Mediapool и др.)

Скрейпинг от Google News

Локално запазване на статиите

Обработка на съдържание:

Разпознаване на български език (langdetect)

Обобщаване с Mistral 7B (оптимизирано за български)

Автоматично тагване и класификация

Проверка на факти:

Локална SearXNG инсталация (търсене в Google/Bing/Wikipedia)

Cross-checking с различни източници

API за интеграция с други системи

Автоматизация:

Cron задача за ежедневно обновяване

Systemd услуги за постоянно работещи компоненти

Логване на процесите

Инструкции за употреба:
Инсталирайте необходимите зависимости:

bash
apt-get update && apt-get install -y python3-venv python3-dev libxml2-dev libxslt1-dev
Стартирайте инсталацията:

bash
chmod +x news_ai_installer.sh
./news_ai_installer.sh
След инсталация:

Тествайте процесора на новини:

bash
sudo -u ainews python3 /home/ainews/news_app/news_processor/process_news.py
Достъпване на API-то: http://<IP>:8000/docs

Проверка на SearXNG: http://localhost:8080

Персонализация:
Добавете допълнителни RSS източници в process_news.py

Конфигурирайте SearXNG в settings.yml

Добавете собствени модели за класификация

Системата е проектирана да работи изцяло локално без зависимост от външни API-та, с акцент върху българския език и проверка на информация.

New chat
