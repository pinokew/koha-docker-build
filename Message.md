# 2026-02-27 - Runtime hotfix inside `koha` container -> changes required in image-build repo

## Context
- Після `docker compose up -d` сервіс `koha` був `unhealthy`.
- Симптоми: `Port must be specified` (Apache), відсутній `/etc/koha/sites/<instance>/koha-conf.xml`, масові помилки Koha про `unable to locate Koha configuration file`.
- Корінь проблеми: `koha-create` падав раніше за створення інстансу через некоректний Apache-конфіг, а пайплайн продовжувався як optional-кроки.

## What was manually fixed inside running container
- Перезаписано `/etc/apache2/ports.conf` у валідний формат з двома рядками `Listen` (окремі рядки, не literal `\n`).
- Увімкнено Apache-модулі, критичні для Koha: `rewrite`, `headers`, `proxy_http`, `cgi`, `cgid`.
- Повторно виконано `koha-create` для створення `koha-conf.xml` та instance-конфігів.
- В `/etc/apache2/sites-available/library.conf`:
- Видалено `AssignUserID` (модуль `mpm_itk` відсутній у контейнерному режимі).
- Виправлено порти у `<VirtualHost *:...>` під env-порти OPAC/Intranet.
- Перезапущено Apache, після чого healthcheck `koha` став `healthy`.

## Message for image-build repository: required code changes
- `scripts/koha-setup/steps/08-apache-config.sh`
- Гарантовано нормалізувати `ports.conf` через `printf` з реальними переносами рядків.
- Використовувати env-порти (`KOHA_OPAC_PORT`, `KOHA_INTRANET_PORT`) у `ports.conf`.
- Обов'язково видаляти `AssignUserID` з vhost-конфігів інстансу.
- Примусово оновлювати `<VirtualHost *:...>` для обох vhost-блоків під env-порти.

- `scripts/koha-setup/steps/05-patch-koha-create.sh`
- Зберегти/посилити контейнерний patch `koha-create`:
- bypass hard-stop перевірки `mpm_itk`;
- приймати `cgid_module` як валідний замінник `cgi_module`;
- зробити idempotent створення користувача/групи;
- не валити setup на `service apache2 restart` всередині `koha-create`.

- `scripts/koha-setup/steps/06-koha-create.sh`
- Додати preflight перед `koha-create`: перевірка `apachectl -t` і fail-fast з явною помилкою.
- Після успішного `koha-create` оновлювати `/etc/koha-envvars/INSTANCE_NAME` і `/etc/koha-envvars/KOHA_CONF`.

- `scripts/koha-setup/steps/09-start-services.sh`
- Явно вмикати `cgid` разом з `cgi` (`a2enmod ... cgi cgid`).
- Логувати помилки `koha-plack/koha-worker` як warning, але не приховувати причину.

- `scripts/koha-setup/00-runner.sh` (або default env у образі)
- Зробити `06-koha-create.sh` required-кроком за замовчуванням.
- Зафейлити startup, якщо required-кроки setup неуспішні (`koha-conf.xml` не створено).

## Acceptance criteria for next image release
- Після чистого `docker compose up -d` без ручного втручання створюється `/etc/koha/sites/<instance>/koha-conf.xml`.
- `apachectl -t` проходить без помилок.
- Контейнер `koha` переходить у `healthy`.
- У логах відсутні `Port must be specified` та `unable to locate Koha configuration file`.
