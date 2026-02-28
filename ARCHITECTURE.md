# Build Repo Architecture (Koha Image)

Дата: 2026-02-27

## 1) Призначення build-репо

Цей репозиторій відповідає за складання, перевірку і публікацію Docker-образу Koha.
Він не відповідає за продакшн-деплой середовища.

## 2) Межі відповідальності

1. Build-репо:
- `Dockerfile`, runtime bootstrap, патчі старту Koha;
- smoke/health перевірки образу;
- публікація `pinokew/koha` в Docker Hub.
2. Не входить у build-репо:
- оркестрація prod-середовища;
- інфраструктурні політики конкретного оточення;
- секрети/токени середовища.

## 3) Структура репозиторію

```text
koha-docker-build/
  Dockerfile
  files/                          # runtime-файли, що копіюються в image
  scripts/koha-setup/             # setup pipeline всередині контейнера
  docker/pinokew/ports.conf       # сумісний apache ports fix
   .env.example                    # мінімальний env для build/smoke
  README.md
  CHANGELOG.md
```

## 4) Правильний життєвий цикл образу

1. Змінити код/конфіги в `Dockerfile`, `files/`, `scripts/koha-setup/`.
2. Локально перевірити запуск через `docker-compose.yaml`.
3. Переконатися, що `koha` піднімається і `healthcheck` зелений.
4. Зібрати й опублікувати образ у Docker Hub.
5. Зафіксувати changelog і релізні дані (tag + digest).

## 5) Мінімальні quality gates перед публікацією

1. `docker compose config` валідний.
2. `koha`, `db`, `rabbitmq`, `es` переходять у `healthy` (або очікуваний `running` для `memcached`).
3. HTTP перевірки Koha (`8080`, `8081`) дають успіх.
4. Всередині контейнера коректний `KOHA_CONF` і валідний `ports.conf`.

## 6) Контракт артефакту для deploy-репо

Після кожного релізу build-репо має віддати в deploy-репо:

1. Image tag (`pinokew/koha:<version>`).
2. Незмінний digest (`pinokew/koha@sha256:...`).
3. Короткий release note: що змінилось у runtime bootstrap/сумісності.

## 7) SSOT і ENV-політика в build-репо

1. Шаблон змінних для локального запуску: `.env.example`.
2. У скриптах/конфігах не хардкодити домени, порти, інстанс, паролі.
3. Runtime-поведінка має визначатись через ENV.
4. Секрети не комітити.

## 8) Що не треба додавати у build-репо

1. Продакшн-специфічні `docker-compose` для клієнтських середовищ.
2. Важкі операційні сценарії експлуатації (runbook/ops для конкретного продакшну).
3. Бекапи, ключі, токени, приватні env-файли.

## 9) Зв'язок з deploy-репо

1. Build-репо публікує образ.
2. Deploy-репо оновлює тільки reference на tag/digest.
3. Rollback у deploy-репо робиться поверненням попереднього digest.
