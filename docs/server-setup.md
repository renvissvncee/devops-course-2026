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
