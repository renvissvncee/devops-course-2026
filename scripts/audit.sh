#!/usr/bin/env bash
set -uo pipefail

PASS=0
FAIL=0

check() {
    local desc="$1"
    local expected="$2"
    local actual="$3"

    if [[ "$actual" == "$expected" ]]; then
        echo " [OK] $desc"
        ((PASS++))
    else
        echo " [FAIL] $desc (ожидалось: '$expected', получено: '$actual')"
        ((FAIL++))
    fi
}

echo "Аудит конфигурации: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"

echo "[1] Служба SSH"

check "Вход от имени root запрещён" \
    "no" "$(sudo sshd -T | awk '/^permitrootlogin/{print $2}')"

check "Парольная аутентификация отключена" \
    "no" "$(sudo sshd -T | awk '/^passwordauthentication/{print $2}')"

check "SSH использует порт, отличный от 22" \
    "nonstandard" "$(sudo sshd -T | awk '/^port /{if ($2 != 22) found=1} END {print (found ? "nonstandard" : "22")}')"

check "MaxAuthTries равен 3" \
    "3" "$(sudo sshd -T | awk '/^maxauthtries/{print $2}')"

echo "[2] Межсетевой экран"

check "Межсетевой экран активен" \
    "active" "$(sudo ufw status | awk '/^Status:/{print $2}')"

check "Политика входящего трафика — deny" \
    "deny" "$(sudo ufw status verbose | awk -F'Default: ' '/Default:/{split($2,a,","); split(a[1],b," "); print b[1]}')"

echo "[3] Учётные записи"

awk -F: '$3>=1000 && $3<65534 {printf " %s (uid=%s)\n",$1,$3}' /etc/passwd

echo "[4] Веб-сервер"

check "Служба Nginx активна" \
    "active" "$(systemctl is-active nginx)"

check "Конфигурация Nginx корректна" \
    "valid" "$(sudo nginx -t >/dev/null 2>&1 && echo valid || echo invalid)"

check "Сертификат действителен ещё минимум 30 дней" \
    "valid" "$(sudo openssl x509 -in /etc/ssl/certs/devops.crt -checkend 2592000 >/dev/null 2>&1 && echo valid || echo invalid)"

check "Права файлов сайта и приватного ключа безопасны" \
    "secure" "$(if [[ -z "$(find /var/www/devops-site -perm -o+w -print -quit)" ]] && [[ "$(sudo stat -c '%a' /etc/ssl/private/devops.key)" == "600" ]]; then echo secure; else echo insecure; fi)"
echo "[5] Контейнеризация"

check "Служба Docker активна" \
    "active" "$(systemctl is-active docker)"

check "Контейнер PostgreSQL находится в состоянии healthy" \
    "healthy" "$(docker inspect -f '{{.State.Health.Status}}' app-db-1)"

check "Порты 5000 и 5432 опубликованы только на localhost" \
    "secure" "$(ss -tln | awk '
        $4 ~ /:(5000|5432)$/ && $4 !~ /^127\.0\.0\.1:/ {bad=1}
        END {print (bad ? "insecure" : "secure")}
    ')"

check "Права файла .env равны 600" \
    "600" "$(stat -c '%a' "$HOME/app/.env")"
echo "Пройдено: $PASS, не пройдено: $FAIL"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
