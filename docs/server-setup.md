# Конфигурация виртуальной машины devops-vm

## 1. Параметры машины

- ОС: Ubuntu Server 24.04.5 LTS.
- CPU: 2 ядра.
- RAM: 2 ГиБ.
- Виртуальный диск: 25 ГБ.
- Swap: 2 ГиБ.
- Корневой LVM-том: 11,5 ГБ.
- Имя хоста: devops-vm.
- Полное доменное имя: devops-vm.devops.local.

## 2. Сетевые интерфейсы

| Интерфейс | Тип адаптера | Адрес | Назначение |
|---|---|---|---|
| enp0s3 | NAT | 10.0.2.15/24 | Доступ во внешнюю сеть через хост |
| enp0s8 | Host-only | 192.168.56.101/24 | Связь между хостом Windows и VM |
| lo | Loopback | 127.0.0.1 | Локальные подключения |

На хосте Windows в файле hosts настроено:
192.168.56.101 devops.local

В Ubuntu полное имя хоста настроено через hostnamectl и /etc/hosts.

## 3. Правило проброса портов

VirtualBox NAT Port Forwarding:

- Протокол: TCP.
- Адрес хоста: 127.0.0.1.
- Порт хоста: 2222.
- Адрес гостя: 10.0.2.15 (или пустой адрес назначения в настройках правила).
- Порт гостя: 2222.

Подключение с Windows: ssh devops

Для имени devops используется SSH-конфигурация Windows:
%USERPROFILE%\.ssh\config

```sshconfig
Host devops
    HostName 127.0.0.1
    Port 2222
    User devops
    IdentityFile ~/.ssh/devops_vm
    IdentitiesOnly yes
```

## 8. Веб-сервер

### Установленный пакет

- Веб-сервер: Nginx 1.24.0.
- Установка: `sudo apt install nginx`.

### Конфигурация ресурса

- Файл конфигурации: `/etc/nginx/sites-available/devops-site`.
- Активная конфигурация: `/etc/nginx/sites-enabled/devops-site`.
- Каталог ресурса: `/var/www/devops-site`.
- Владелец каталога: `devops:devops`.
- Права каталога: `755`.
- Права HTML-файлов: `644`.

### TLS-сертификат

- Сертификат: `/etc/ssl/certs/devops.crt`.
- Владелец сертификата: `root:root`.
- Права сертификата: `644`.
- Приватный ключ: `/etc/ssl/private/devops.key`.
- Владелец ключа: `root:root`.
- Права приватного ключа: `600`.
- Тип сертификата: самоподписанный, RSA 2048 бит.
- Имя сертификата: `devops.local`.
- Срок действия: 365 дней (с 27.10.2026 по 27.10.2027).

### Команда формирования сертификата

```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/devops.key \
    -out /etc/ssl/certs/devops.crt \
    -subj "/CN=devops.local" \
    -addext "subjectAltName=DNS:devops.local"
```

## 9. Контейнеризация

### Docker Engine и Docker Compose

- Способ установки: официальный APT-репозиторий Docker.
- Docker Engine: 29.9.2.
- Docker Compose: 5.6.1.
- Пользователь для работы с Docker: `devops`.
- Пользователь `devops` включён в группу `docker`.

### Расположение проекта

- Каталог проекта на сервере: `/home/devops/app`.
- Dockerfile: `/home/devops/app/Dockerfile`.
- Файл Docker Compose: `/home/devops/app/docker-compose.yml`.
- Файл зависимостей: `/home/devops/app/requirements.txt`.
- Образ приложения: `devops-app:1.0`.
- Образ базы данных: `postgres:16-alpine`.

### Переменные окружения

- Файл с переменными окружения: `/home/devops/app/.env`.
- Шаблон переменных окружения: `/home/devops/app/.env.example`.
- Владелец файла `.env`: `devops:devops`.
- Права файла `.env`: `600`.
- Файл `.env` исключён из Git с помощью `.gitignore`.
- Файл `.env` содержит параметры подключения приложения к PostgreSQL и пароль базы данных.

### Публикуемые порты

- Flask-приложение: `127.0.0.1:5000:5000`.
- PostgreSQL: порт `5432` доступен только внутри Docker-сети и не опубликован на хосте.
- Прямой доступ к Flask через внешние сетевые интерфейсы VM ограничен привязкой к `127.0.0.1`.

### Хранение данных и сеть

- Именованный Docker volume: `app_db_data`.
- Назначение volume: постоянное хранение данных PostgreSQL.
- Docker-сеть: `app_backend`.
- Тип сети: `bridge`.
- Взаимодействие приложения с базой данных осуществляется по имени сервиса `db` через внутренний DNS Docker.

### Обратный прокси-сервер

- Веб-сервер: Nginx 1.24.0.
- Файл конфигурации: `/etc/nginx/sites-available/devops-site`.
- HTTPS-домен: `devops.local`.
- Порт HTTPS: `443`.
- Расположение приложения: `/app/`.
- Адрес upstream: `http://127.0.0.1:5000/`.
- Nginx выполняет обратное проксирование запросов к Flask-приложению.
- Существующий статический ресурс на `/` сохранён.
