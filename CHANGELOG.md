# Changelog: Fix запуску з `pinokew/koha:25.05`

Дата: 2026-02-27  
Репозиторій: `koha-docker-build`

## 1) Контекст

Мета: стабільно запустити стек Koha на публічному образі `pinokew/koha:25.05` з робочими `OPAC/Staff` та станом контейнерів `healthy`.

Початково стек не стартував коректно: `koha-app` переходив у `unhealthy`, а залежний `tunnel` не підіймався.

## 2) Що ламалося

1. У `pinokew/koha:25.05` файл `/etc/apache2/ports.conf` був некоректний:
`Listen 8081\nListen 8080` в одному рядку (літеральний `\n`).
Це давало Apache-помилку:
`AH00526: Syntax error on line 1 of /etc/apache2/ports.conf: Port must be specified`

2. Частина процесів Koha очікувала конфіг за шляхом `/etc/koha/sites/default/koha-conf.xml`,
але інстанс використовував `library` (`/etc/koha/sites/library/koha-conf.xml`).
У логах:
`unable to locate Koha configuration file koha-conf.xml`

3. Через пункти вище healthcheck `koha-app` падав/таймаутився, і `tunnel` не запускався через `depends_on`.

## 3) Що змінено

### 3.1. Додано фікс `ports.conf` для образу `pinokew`

Створено файл:
- `docker/pinokew/ports.conf`

Вміст:
- `Listen 8081`
- `Listen 8080`

І змонтовано в контейнер `koha` read-only:
- `./docker/pinokew/ports.conf:/etc/apache2/ports.conf:ro`

Файл: `docker-compose.yaml`

### 3.2. Узгоджено шлях до `koha-conf.xml`

Додано явний `KOHA_CONF`:
- `KOHA_CONF: /etc/koha/sites/${KOHA_INSTANCE}/koha-conf.xml`

Додано сумісний mount для очікуваного `default`:
- `${VOL_KOHA_CONF}/${KOHA_INSTANCE}:/etc/koha/sites/default`

Файл: `docker-compose.yaml`

### 3.3. Додано явні порти Koha в ENV контейнера

Додано:
- `KOHA_OPAC_PORT: ${KOHA_OPAC_PORT}`
- `KOHA_INTRANET_PORT: ${KOHA_INTRANET_PORT}`

Файл: `docker-compose.yaml`

### 3.4. Уточнено залежності старту

Для `koha` змінено очікування `rabbitmq` на `service_healthy`.

Файл: `docker-compose.yaml`

## 4) Ключові зміни в конфігурації (де дивитись)

- `docker-compose.yaml`:
  - ENV для Koha (`KOHA_CONF`, `KOHA_*_PORT`)
  - Volumes для `default` і `ports.conf`
  - `depends_on` з `rabbitmq: service_healthy`
- `docker/pinokew/ports.conf`: новий файл із валідними `Listen`

## 5) Валідація після фіксу

Виконані перевірки:

1. Статуси контейнерів:
- `koha-app` -> `healthy`
- `db` -> `healthy`
- `es` -> `healthy`
- `rabbitmq` -> `healthy`
- `memcached` -> `running`
- `tunnel` -> `running`

2. HTTP:
- `curl http://127.0.0.1:8080` -> `200`
- `curl http://127.0.0.1:8081` -> `200`

3. Перевірка всередині `koha-app`:
- `/etc/apache2/ports.conf` має дві окремі строки `Listen 8081` і `Listen 8080`
- `KOHA_CONF=/etc/koha/sites/library/koha-conf.xml`
- `/etc/koha/sites/default/koha-conf.xml` існує (через mount сумісності)

## 6) Поточний робочий режим

Робочий режим запуску з цим фіксом:

1. Образ Koha:
- `KOHA_IMAGE_NAME=pinokew/koha`
- `KOHA_IMAGE_TAG=25.05`

2. Запуск:
- `docker compose -p koha-doker up -d`

3. Зупинка:
- `docker compose -p koha-doker down`

## 7) Примітка

У логах може з'являтися:
- `ERROR: Module mpm_itk does not exist!`

У зафіксованому стані це не блокує запуск: контейнери та HTTP-ендпоінти залишаються працездатними.

## 8) Правильна модель двох репозиторіїв (Image repo + Deploy repo)

Нижче зафіксовано цільову схему роботи, щоб уникати змішування відповідальностей:

1. `koha-docker-build` (цей репо) = **репозиторій образу**
- Відповідає тільки за складання, патчі рантайму, smoke-тести образу, публікацію в Docker Hub.
- Результат: версійований образ `pinokew/koha:<tag>` + незмінний `sha256:digest`.

2. Окремий репо інсталяції = **репозиторій системи/деплою**
- Відповідає за `docker-compose`/інфраструктурну збірку готового середовища.
- Споживає вже зібраний образ із Docker Hub.
- Містить тільки runtime-конфіги, `.env`, volume strategy, backup/restore, домени/тунелі.

### 8.1. Що має бути в image-repo (цей репо)

1. `Dockerfile` + скрипти ініціалізації/патчів без environment-specific хардкоду.
2. Автотести образу (мінімум):
- контейнер стартує;
- Apache слухає потрібні порти;
- `KOHA_CONF` підхоплюється коректно;
- базові health/smoke HTTP перевірки проходять.
3. CI pipeline:
- build multi-arch (за потреби);
- security scan;
- publish у Docker Hub;
- підпис/атестація (за можливості).
4. Versioning:
- релізні теги (`25.05.x`, `latest` опційно);
- обов'язкова фіксація digest у реліз-нотах.

### 8.2. Що має бути в deploy-repo (інший репо)

1. `docker-compose.yaml` (або Helm/K8s) без `build:` для Koha, тільки `image: pinokew/koha:<tag або digest>`.
2. SSOT через ENV:
- усі домени, порти, шляхи томів, instance name, URL-и задаються через `.env`;
- скрипти не містять захардкоджених `library.fby.com.ua`, фіксованих портів чи абсолютних шляхів.
3. Окремі профілі для `dev/stage/prod` через різні env-файли.
4. Операційні скрипти:
- bootstrap;
- backup/restore;
- migrate/update;
- health checks та post-deploy перевірки.

### 8.3. Рекомендований релізний потік між репозиторіями

1. У `koha-docker-build`:
- випускається новий tag образу;
- публікується digest;
- оновлюється changelog.
2. У deploy-repo:
- окремим PR оновлюється тільки image reference (`tag`/`digest`);
- запускаються інтеграційні smoke-тести;
- після успішних перевірок виконується деплой.
3. Rollback:
- повернення попереднього digest без перебудови образу.

### 8.4. Політика SSOT ENV (критично)

1. Джерело правди для runtime-параметрів: `.env` + `docker-compose.yaml`.
2. Скрипти читають тільки ENV-змінні, дефолти допускаються лише як безпечний fallback.
3. Жодного environment-specific хардкоду в скриптах і Dockerfile.
4. У changelog фіксуються нові/змінені ENV-ключі та їх вплив.

## 9) Оновлення 2026-02-28: підтверджено запуск у deploy-репо

Підтверджено, що образ `pinokew/koha:25.05` стартує коректно в окремому deploy-репо без ручних hotfix усередині контейнера.

### 9.1. Що змінено для стабільного clean-start

1. `scripts/koha-setup/00-runner.sh`
- `06-koha-create.sh` зроблено required-кроком за замовчуванням.
- Додано fail, якщо required-кроки відфільтровані через `SKIP/ONLY`.
- Додано фінальну перевірку артефакту: `KOHA_CONF` (`/etc/koha/sites/<instance>/koha-conf.xml`) має існувати.

2. `scripts/koha-setup/steps/06-koha-create.sh`
- Додано preflight `apachectl -t` перед `koha-create`.
- Після успішного `koha-create` оновлюється `/etc/koha-envvars/INSTANCE_NAME`.
- Після успішного `koha-create` оновлюється `/etc/koha-envvars/KOHA_CONF`.
- Якщо `koha-conf.xml` не створено, startup завершується з помилкою.

3. `scripts/koha-setup/steps/08-apache-config.sh`
- `ports.conf` тепер нормалізується через `printf` з реальними переносами рядків.
- Порти беруться з env: `KOHA_OPAC_PORT`, `KOHA_INTRANET_PORT`.
- `AssignUserID` видаляється з instance vhost-конфігів.
- Обидва `<VirtualHost *>` примусово оновлюються під env-порти.

4. `scripts/koha-setup/steps/09-start-services.sh`
- Увімкнення модулів Apache: `cgi` + `cgid`.
- Запуски `koha-plack`/`koha-worker`/`koha-es-indexer` логують warning з кодом помилки (без silent-ignore).

5. `docker-compose.yaml` і `docker-compose.deploy.yaml`
- Переключено порт-мапінг на env->env (host/container): `${KOHA_OPAC_PORT}:${KOHA_OPAC_PORT}`, `${KOHA_INTRANET_PORT}:${KOHA_INTRANET_PORT}`.
- Healthcheck Koha використовує `KOHA_INTRANET_PORT` з env.
- Прибрано read-only mount `ports.conf` у build-compose, щоб runtime-скрипт міг коректно генерувати `ports.conf`.

### 9.2. Факт валідації

1. Образ успішно запущений у deploy-репо.
2. Підтверджено роботу при портах:
- `KOHA_INTRANET_PORT=8081`
- `KOHA_OPAC_PORT=8082`
3. Симптоми з попередніх релізів не відтворюються:
- `Port must be specified`
- `unable to locate Koha configuration file`
