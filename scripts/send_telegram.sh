#!/usr/bin/env bash
# Отправляет текст со stdin в Telegram через Bot API.
# Автоматически режет сообщение по границе абзаца, если длиннее 4000 символов
# (лимит Telegram — 4096, берём запас).
#
# Требуемые переменные окружения:
#   TELEGRAM_BOT_TOKEN — токен бота от @BotFather
#   TELEGRAM_CHAT_ID   — id чата, куда слать (число, может быть отрицательным для групп)
#
# Необязательные:
#   TELEGRAM_PARSE_MODE — "HTML" (по умолчанию) или "MarkdownV2"
#
# Использование:
#   echo "<b>Привет</b>" | scripts/send_telegram.sh
#   scripts/send_telegram.sh < digest.txt

set -euo pipefail

: "${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN is not set — add it to Cloud Environment}"
: "${TELEGRAM_CHAT_ID:?TELEGRAM_CHAT_ID is not set — add it to Cloud Environment}"

PARSE_MODE="${TELEGRAM_PARSE_MODE:-HTML}"
MAX_LEN=4000
API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"

send_chunk() {
    local text="$1"
    local http_code
    http_code=$(curl --silent --show-error --output /tmp/tg_response.json --write-out '%{http_code}' \
        --max-time 30 \
        --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=${text}" \
        --data-urlencode "parse_mode=${PARSE_MODE}" \
        --data-urlencode "disable_web_page_preview=true" \
        "${API}")

    if [[ "${http_code}" != "200" ]]; then
        echo "Telegram API error (HTTP ${http_code}):" >&2
        cat /tmp/tg_response.json >&2
        echo >&2
        return 1
    fi
}

payload=$(cat)

if [[ -z "${payload//[[:space:]]/}" ]]; then
    echo "send_telegram.sh: stdin is empty, nothing to send" >&2
    exit 1
fi

# Если влезает одним сообщением — шлём как есть.
if (( ${#payload} <= MAX_LEN )); then
    send_chunk "${payload}"
    exit 0
fi

# Иначе — режем по двойному переводу строки (границе абзацев).
chunk=""
while IFS= read -r paragraph || [[ -n "${paragraph}" ]]; do
    candidate="${chunk}${chunk:+$'\n\n'}${paragraph}"
    if (( ${#candidate} > MAX_LEN )); then
        if [[ -n "${chunk}" ]]; then
            send_chunk "${chunk}"
            chunk="${paragraph}"
        else
            # Один параграф длиннее лимита — режем жёстко по символам.
            while (( ${#paragraph} > MAX_LEN )); do
                send_chunk "${paragraph:0:MAX_LEN}"
                paragraph="${paragraph:MAX_LEN}"
            done
            chunk="${paragraph}"
        fi
    else
        chunk="${candidate}"
    fi
done < <(printf '%s' "${payload}" | awk 'BEGIN{RS="\n\n"} {print; if (!match($0, /\n$/)) print ""}')

if [[ -n "${chunk}" ]]; then
    send_chunk "${chunk}"
fi
