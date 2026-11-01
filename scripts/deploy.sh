
#!/usr/bin/env bash
# Доставка статического ресурса на devops-vm
# Использование: scripts/deploy.sh [--dry-run]

set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"

# Определяем корень репозитория независимо от текущего каталога
REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")/.." rev-parse --show-toplevel)"
LOCAL_DIR="${REPO_ROOT}/site/"

# 1. Разбор аргументов
DRY_RUN=false

if [[ $# -gt 1 ]]; then
    echo "Ошибка: неизвестные аргументы" >&2
    exit 1
fi

if [[ $# -eq 1 ]]; then
    if [[ "$1" == "--dry-run" ]]; then
        DRY_RUN=true
    else
        echo "Ошибка: допустимый аргумент только --dry-run" >&2
        exit 1
    fi
fi

# 2. Проверка наличия главной страницы
if [[ ! -f "${LOCAL_DIR}index.html" ]]; then
    echo "Ошибка: ${LOCAL_DIR}index.html не найден" >&2
    exit 1
fi

# 3. Проверка чистоты Git
if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
    echo "Ошибка: в репозитории есть незакоммиченные изменения" >&2
    exit 1
fi

# Получаем короткий хеш текущего коммита
COMMIT_HASH="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"

# 4. Подготовка параметров rsync
RSYNC_ARGS=(
    -avz
    --delete
    --chmod=D755,F644
    -e "ssh -o BatchMode=yes -o ConnectTimeout=5"
)

if [[ "$DRY_RUN" == true ]]; then
    RSYNC_ARGS+=(--dry-run)
fi

# 5. Синхронизация
rsync "${RSYNC_ARGS[@]}" \
    "$LOCAL_DIR" \
    "${REMOTE}:${REMOTE_DIR}/"

# 6. Для dry-run завершаем работу без проверки доступности сайта
if [[ "$DRY_RUN" == true ]]; then
    echo "Пробный запуск завершён успешно."
    exit 0
fi

# 7. Проверка доступности сайта с проверкой сертификата
if ! curl --cacert "$CA_CERT" -f -sS \
    --connect-timeout 5 \
    --max-time 15 \
    -o /dev/null "$SITE_URL"; then
    echo "Ошибка: сайт недоступен или проверка сертификата не пройдена" >&2
    exit 1
fi

# 8. Успешное завершение
echo "Деплой выполнен успешно. Коммит: ${COMMIT_HASH}"
exit 0
