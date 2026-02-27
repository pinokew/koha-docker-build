# Roadmap: Koha Enterprise Production (v2)

**Дата оновлення:** 2026-02-27  
**Ціль:** перевести Koha-платформу в керований enterprise-prod режим з прогнозованим релізом, формалізованою безпекою, спостережуваністю та гарантованим відновленням.

## Принцип перегрупування

Спочатку закриваємо ризики, які можуть призвести до витоку/компрометації або неможливості відновлення, і лише потім оптимізуємо продуктову частину.

1. Фаза 0: Секрети та базовий security baseline.
2. Фаза 1: SDLC governance і контроль змін.
3. Фаза 2: CI/CD + supply-chain hardening.
4. Фаза 3: Runtime hardening, мережа, ресурси, healthchecks.
5. Фаза 4: Observability/SRE.
6. Фаза 5: DR/Backup + PITR.
7. Фаза 6: Performance та інтеграції (SMTP/GA4).
8. Фаза 7: SSO/OIDC Lockdown.

---

## Фаза 0 (обов'язкова): Секрет-менеджмент і базовий Security Baseline

### 0.1 Інвентаризація та класифікація секретів
- Скласти реєстр секретів: DB (`DB_PASS`, `DB_ROOT_PASS`), RabbitMQ, Cloudflare token, SMTP creds, API keys.
- Для кожного секрету визначити: owner, де зберігається, де використовується, період ротації, blast radius.
- Винести реєстр у `docs/security/SECRETS_INVENTORY.md`.

### 0.2 Перенесення секретів із plaintext-потоків
- Заборонити зберігання секретів у git-tracked файлах.
- Перевірити що `.env`:
- не відстежується git;
- додано в `.dockerignore` (щоб не потрапляв у build context);
- має права `0600` на хості.
- Для CI використовувати тільки GitHub Secrets/Variables, не `ARG`/`ENV` для секретів у Dockerfile.

### 0.3 Ротація та анулювання потенційно скомпрометованих ключів
- Згенерувати нові значення для DB, RabbitMQ, Cloudflare, SMTP.
- Негайно відкликати старі токени/паролі.
- Додати `runbook` ротації в `docs/security/SECRETS_ROTATION_RUNBOOK.md`.

### 0.4 Secret scanning та запобігання витокам
- Додати в CI секрет-сканер (`gitleaks` або `trufflehog`) як required check.
- Додати pre-commit hook для локального сканування.
- Додати policy: PR блокується, якщо знайдено hardcoded secret.

### 0.5 Базовий security baseline контейнерів/хоста
- База: регулярне оновлення base image, список дозволених base images.
- Контейнери: мінімізувати root-доступ, зафіксувати привілеї, не використовувати зайві capabilities.
- Хост: SSH key-only, fail2ban, firewall policy за замовчуванням `deny inbound`.

### Артефакти фази
- `docs/security/SECRETS_INVENTORY.md`
- `docs/security/SECRETS_ROTATION_RUNBOOK.md`
- `docs/security/SECURITY_BASELINE.md`

### DoD
- Відсутні секрети у git history нових комітів.
- CI має обов'язковий secret scan gate.
- Всі production секрети ротовані після впровадження.
- `.env` не потрапляє в build context і не комітиться.

---

## Фаза 1: SDLC Governance

### 1.1 Branch protection
- Увімкнути branch protection для `main`:
- заборона direct push;
- мінімум 1-2 review approvals;
- required status checks;
- require up-to-date branch before merge.

### 1.2 CODEOWNERS
- Створити `.github/CODEOWNERS`.
- Призначити власників на критичні зони:
- `.github/workflows/*`
- `Dockerfile`
- `scripts/koha-setup/*`
- `docker-compose.yaml` (в deploy-репо).

### 1.3 Required checks
- Обов'язкові перевірки:
- `hadolint`
- `shellcheck`
- `trivy config`
- `trivy image (pre-push)`
- `secret scan`
- `yaml lint/compose validation` (deploy-репо).

### 1.4 Підпис комітів/релізів
- Увімкнути обов'язкові signed commits (GPG/SSH signing).
- Теги релізів підписувати.
- Перевірку підписів зробити required check.

### 1.5 Шаблони процесу
- Додати PR template з секціями: ризики, rollback-план, тест-план.
- Додати issue templates: bug/security/ops.
- Додати lightweight RFC-шаблон для змін у runtime/безпеці.

### Артефакти фази
- `.github/CODEOWNERS`
- `.github/pull_request_template.md`
- `docs/process/CHANGE_CONTROL.md`

### DoD
- Жодна зміна не потрапляє в `main` без review + required checks.
- Критичні директорії мають owner approval.
- Підпис комітів/релізів увімкнено і перевіряється.

---

## Фаза 2: CI/CD та Supply-Chain Hardening

### 2.1 Архітектура 2-репо
- `koha-docker-build`: збірка, сканування, публікація образів.
- `koha-deploy`: compose, env schema, деплой-оркестрація, backup/restore.

### 2.2 Hardening GitHub Actions
- Pin `uses:` actions по commit SHA для критичних workflow.
- Мінімальні `permissions` на рівні workflow/job.
- `concurrency` для уникнення race conditions.
- Guard publish job по owner/repo context.

### 2.3 Артефакти довіри
- Генерація SBOM (SPDX).
- Build provenance attestation.
- Підпис контейнера (`cosign sign`) і верифікація перед деплоєм.

### 2.4 Релізна дисципліна
- Теги: semver-like для релізу Koha + immutable `sha-*`.
- Заборонити деплой `latest` у prod.
- Release notes автоматизувати з changelog.

### DoD
- Кожен прод-образ має SBOM, provenance і підпис.
- Всі критичні action-и зафіксовані (SHA).
- Прод деплой використовує immutable digest/tag.

---

## Фаза 3: Runtime Hardening + Network Policy + Resource Limits/Healthchecks

### 3.1 Контейнерний hardening (compose)
- Для сервісів, де можливо:
- `read_only: true`
- `tmpfs` для тимчасових директорій
- `security_opt: ["no-new-privileges:true"]`
- `cap_drop: ["ALL"]` + точково `cap_add` за потреби
- `user: UID:GID` (не root), де сумісно.

### 3.2 Мережеві політики
- Розділити мережі: `frontnet` (вхід через proxy), `backnet` (внутрішні сервіси).
- Не публікувати назовні: 3306, 9200, 11211, 5672.
- Доступ до цих сервісів лише між контейнерами в `backnet`.
- Єдина точка входу: Traefik/Cloudflare Tunnel.

### 3.3 Шифрування та транспорт
- TLS termination на edge (Cloudflare/Traefik).
- Внутрішні з'єднання шифрувати там, де підтримується без деградації.
- Заборонити plaintext admin endpoints назовні.

### 3.4 Resource governance
- Встановити `mem_limit`, `cpus`, `pids_limit`, `ulimits` для кожного сервісу.
- Налаштувати restart policy (`unless-stopped`/`always` за роллю сервісу).
- Додати обмеження логів через `logging.driver` + rotation.

### 3.5 Healthchecks
- Koha OPAC/Staff: HTTP health endpoint.
- MariaDB: `mysqladmin ping`.
- RabbitMQ: `rabbitmq-diagnostics ping`.
- Elasticsearch: `/_cluster/health` з timeout.
- Memcached: `stats`/TCP check.

### 3.6 Валідація hardening
- Провести smoke + soak тести після вмикання обмежень.
- Додати checklist сумісності для non-root/read-only режимів.

### DoD
- Внутрішні сервіси не мають зовнішніх published ports.
- На критичних сервісах активні hardening-параметри.
- Кожен сервіс має валідний healthcheck.
- Compose має resource limits і log rotation.

---

## Фаза 4: Observability / SRE

### 4.1 Логи
- Стандартизувати формат логів (json/plain policy).
- Централізувати збір (Loki/ELK/Vector).
- Додати кореляційні поля: service, instance, request_id.

### 4.2 Метрики
- Prometheus + exporters:
- node_exporter (host)
- cadvisor (containers)
- mysqld_exporter (MariaDB)
- rabbitmq exporter
- blackbox exporter для HTTP probes.

### 4.3 Алертинг
- Alertmanager + канали (Telegram/Email).
- Критичні алерти:
- 5xx spike
- висока latency
- падіння healthcheck
- вільний диск < поріг
- невдалий backup/restore test.

### 4.4 SLO/SLI/Error Budget
- Визначити SLI:
- доступність OPAC/Staff
- latency p95/p99
- error rate.
- Визначити SLO (наприклад 99.9% для OPAC).
- Вести error budget policy: коли freeze релізів, коли дозволяється feature work.

### 4.5 Runbooks та Incident response
- Runbook на типові інциденти: DB down, ES degraded, RabbitMQ queue backlog, disk full.
- Incident template: impact, timeline, workaround, RCA.
- Postmortem без blame з action items і owner/deadline.

### DoD
- Є централізовані логи, метрики, алерти.
- Затверджені SLO/SLI + error budget policy.
- На кожен P1/P2 сценарій існує runbook.

---

## Фаза 5: DR/Backup + регулярний Restore-test + PITR (MariaDB binlog)

### 5.1 DR-цілі
- Формалізувати `RPO` і `RTO` (напр. RPO 15 хв, RTO 2 год).
- Зафіксувати залежності та пріоритети відновлення сервісів.

### 5.2 Backup strategy 3-2-1
- 3 копії, 2 різні носії, 1 offsite.
- Щоденний logical backup + регулярний physical backup (за потреби).
- Шифрування backup-архівів у спокої та під час передачі.

### 5.3 PITR для MariaDB
- Увімкнути binlog:
- `log_bin=ON`
- `server_id` унікальний
- `binlog_expire_logs_seconds` за політикою retention
- Регулярно зберігати binlog офсайт разом з full backup.

### 5.4 Restore automation
- `restore.sh` має підтримувати:
- full restore
- restore + apply binlogs до timestamp (PITR)
- dry-run/verify режим.

### 5.5 Регулярні тестові відновлення
- Schedule: мінімум 1 раз/місяць + після критичних змін схеми.
- Автоматичний звіт: час відновлення, успішність, відхилення від RPO/RTO.
- Перевірка цілісності: checksums + smoke tests після restore.

### 5.6 Документація та аудит
- DR Runbook з поетапним планом дій (хто/коли/що робить).
- Таблиця контактів і ескалацій.
- Журнал проведених DR-тестів.

### DoD
- PITR технічно працює та протестований.
- Є підтверджений регулярний restore-test.
- RPO/RTO досягаються на практиці, не лише на папері.

---

## Фаза 6: Performance та інтеграції (після baseline)

### 6.1 Performance tuning
- Memcached memory sizing.
- MariaDB tuning (`innodb_buffer_pool_size`, `max_connections`).
- Plack workers/requests tuning через `.env`.
- Навантажувальний профіль (peak-season сценарії).

### 6.2 SMTP
- Безпечна інтеграція SMTP через секрети.
- Тестові нотифікації + retry policy.

### 6.3 Аналітика GA4
- Впроваджувати лише після policy щодо приватності/consent.
- Фільтрація PII, мінімізація даних, юридична перевірка.

### DoD
- Підтверджене покращення p95/p99.
- SMTP стабільний у production сценаріях.
- Аналітика не порушує політику приватності.

---

## Фаза 7: OIDC/SSO Lockdown

### 7.1 Політика автентифікації
- Єдиний IdP (Microsoft Entra ID) як primary auth.
- Локальні паролі Koha вимкнені для користувачів, де це допустимо.

### 7.2 Break-glass доступ
- Окремий аварійний адмін-акаунт.
- Зберігання доступу через сейф-секретів + audit trail.
- Регламент використання та післяінцидентна ротація.

### 7.3 UX та контроль
- Прибрати/сховати стандартні форми логіну для кінцевих користувачів.
- Перевірити, що адмін-панель має коректні fallback-сценарії.

### DoD
- SSO є основним шляхом входу.
- Break-glass процес перевірений і задокументований.
- Немає неконтрольованих локальних auth-шляхів.

---

## Критерії готовності Enterprise Production (фінальний gate)

- Security: секрети керуються централізовано, ротація та сканування активні.
- Delivery: захищений SDLC, required checks, підписані артефакти.
- Runtime: мережа ізольована, hardening + healthchecks + limits активні.
- Reliability: є SLO/SLI, алерти, runbooks, вимірюваний error budget.
- Recovery: DR/PITR перевірені регулярними тестами відновлення.
