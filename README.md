# Daily AI + Wildberries News Digest

Каждое утро в **09:00 МСК** Claude Code сам:
1. Читает свежие RSS-ленты про AI и Wildberries,
2. Пишет короткий дайджест на русском,
3. Шлёт его тебе в Telegram.

Никаких серверов, GitHub Actions и включённых ноутбуков — всё крутится как
[Claude Code Routine](https://code.claude.com/docs/en/routines) на серверах Anthropic.

---

## Как это устроено

```
┌───────────────────────────────────────────────┐
│ Claude Code Routine (cron 0 9 * * *, МСК)     │
│  • клонирует этот репо                        │
│  • читает CLAUDE.md + feeds.yaml              │
│  • WebFetch по каждому RSS → последние 24ч    │
│  • пишет дайджест на русском                  │
│  • curl → Telegram Bot API                    │
│  • коммитит logs/YYYY-MM-DD.md                │
└───────────────────────────────────────────────┘
             │
             ▼
   📱 Telegram-бот → ты
```

| Файл | Что делает |
|---|---|
| `CLAUDE.md` | Инструкция для routine-сессии (главный «мозг») |
| `feeds.yaml` | Список RSS-лент — правь, когда хочешь добавить/убрать источник |
| `scripts/send_telegram.sh` | Обёртка над Telegram Bot API с авто-чанкингом |
| `.claude/settings.json` | Preapproved-разрешения для headless-запуска |
| `logs/YYYY-MM-DD.md` | Архив того, что было отправлено каждый день |

---

## Настройка (делаешь один раз, ~10 минут)

### Шаг 1. Создай Telegram-бота у @BotFather

1. Открой [@BotFather](https://t.me/BotFather) в Telegram.
2. Напиши `/newbot`.
3. Придумай имя (например, «My Daily News») и username (должен заканчиваться на `bot`, например `my_daily_news_digest_bot`).
4. BotFather пришлёт **токен** вида `1234567890:AAFabc...`. **Скопируй его** — это `TELEGRAM_BOT_TOKEN`.

![Создание бота у BotFather](docs/img/01-botfather-newbot.png)
![Токен бота от BotFather](docs/img/02-botfather-token.png)

> ⚠️ Токен — секрет. Никуда его не коммить и не пересылай.

### Шаг 2. Узнай свой chat_id

1. Найди своего бота по username и напиши ему **`/start`** (иначе он не сможет писать тебе первым).
2. Открой в браузере (замени `<TOKEN>`):
   ```
   https://api.telegram.org/bot<TOKEN>/getUpdates
   ```
3. В JSON-ответе найди `"chat": { "id": 123456789, ... }`. **Скопируй число `id`** — это `TELEGRAM_CHAT_ID`.
   - Для личных сообщений — **положительное** число.
   - Если хочешь слать в группу/канал, добавь туда бота админом и возьми отрицательный id оттуда.

![Ответ getUpdates с chat.id](docs/img/03-getupdates-json.png)

### Шаг 3. Создай Cloud Environment на claude.ai

1. Зайди на [claude.ai](https://claude.ai) → **Settings** → **Environments** → **New environment**.
2. Заполни:
   - **Name**: `wb-news-digest`
   - **Network access**: **Full** (нужен outbound HTTP к RSS-сайтам и `api.telegram.org`)
   - **Environment variables**:
     - `TELEGRAM_BOT_TOKEN` = токен из шага 1
     - `TELEGRAM_CHAT_ID` = id из шага 2
3. Сохрани.

![Создание Environment](docs/img/04-environments-new.png)
![Настройка переменных](docs/img/05-environment-vars.png)

### Шаг 4. Создай Routine

1. Открой [claude.ai/code/routines](https://claude.ai/code/routines) → **New routine**.
2. Заполни:
   - **Name**: `Daily AI + WB News Digest`
   - **Repository**: `bailopan/wb-`
   - **Branch**: `main` (Routine будет читать этот код; свои логи коммитит в отдельную ветку `claude/daily-digest-*`)
   - **Environment**: `wb-news-digest` (созданное в шаге 3)
   - **Trigger type**: **Schedule** → **Daily**
   - **Prompt** (ровно одна строка):
     ```
     Выполни daily digest по инструкции в CLAUDE.md.
     ```
3. Сохрани.

![Создание Routine](docs/img/06-routines-new.png)
![Заполненная форма Routine](docs/img/07-routine-filled.png)

### Шаг 5. Поставь точное время (09:00 МСК)

Preset «Daily» запускает в какой-то стандартный час. Чтобы поставить **строго 09:00 Europe/Moscow**, в Claude Code CLI выполни:

```
/schedule list
/schedule update <id> --cron "0 9 * * *" --tz Europe/Moscow
```

`<id>` возьми из `/schedule list`. Проверь, что новое расписание отобразилось корректно.

![Проверка cron-расписания](docs/img/08-schedule-cron.png)

### Шаг 6. Прогони «вручную» (dry-run)

1. На [claude.ai/code/routines](https://claude.ai/code/routines) открой свой routine → **Run now**.
2. Дождись завершения (обычно 1–3 минуты).
3. Проверь три места:
   - **В Telegram** пришло сообщение с дайджестом;
   - В репо появилась **ветка** `claude/daily-digest-YYYY-MM-DD` с файлом `logs/YYYY-MM-DD.md`;
   - **В логе routine** нет красных ошибок.

![Лог первого запуска](docs/img/09-first-run-log.png)
![Сообщение в Telegram](docs/img/10-telegram-message.png)

Если всё ок — дальше оно поедет само каждый день в 09:00 МСК.

---

## Как менять источники новостей

Открой `feeds.yaml`, добавь/убери ленту, закоммить в `main` — следующий запуск уже возьмёт новый список.

```yaml
ai:
  - name: Мой новый источник
    url: https://example.com/rss
```

---

## Траблшутинг

| Симптом | Что сделать |
|---|---|
| Бот молчит утром | Зайди в лог последнего запуска routine на claude.ai/code/routines. Чаще всего — невалидный токен или chat_id. |
| В Telegram ошибка `chat not found` | Ты не нажал `/start` у бота, либо chat_id скопирован с ошибкой. |
| `Network error` в логе routine | В Cloud Environment не стоит **Network access: Full**. |
| Дайджест пустой | В секции реально ничего нового за 24ч (ок на выходных), либо упали все ленты — см. строку «Не удалось прочитать» в сообщении. |
| Хочу сменить время | `/schedule update <id> --cron "0 7 * * *" --tz Europe/Moscow` в CLI. |
| Хочу добавить Telegram-канал как источник | RSS-мостов для TG нет из коробки; проще подключить `rsshub`-инстанс с url `https://<rsshub>/telegram/channel/<name>` и добавить в `feeds.yaml`. |

---

## Полезные ссылки

- [Claude Code Routines](https://code.claude.com/docs/en/routines)
- [Cloud Environments](https://code.claude.com/docs/en/claude-code-on-the-web#the-cloud-environment)
- [Telegram Bot API — sendMessage](https://core.telegram.org/bots/api#sendmessage)
- [@BotFather](https://t.me/BotFather)

---

## Скриншоты

Файлы-плейсхолдеры лежат в `docs/img/`. Положи туда свои скрины с такими именами, и они автоматически подтянутся в README:

```
docs/img/
├── 01-botfather-newbot.png
├── 02-botfather-token.png
├── 03-getupdates-json.png
├── 04-environments-new.png
├── 05-environment-vars.png
├── 06-routines-new.png
├── 07-routine-filled.png
├── 08-schedule-cron.png
├── 09-first-run-log.png
└── 10-telegram-message.png
```
