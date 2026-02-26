# Koha Docker Image (`pinokew/koha`)

Public, clean Koha image for Docker-based deployments.

This repository is focused on building and publishing a reusable image to Docker Hub.
It does not apply custom template patching at runtime.

## Image Tags

- `pinokew/koha:25.05` — version tag
- `pinokew/koha:latest` — moving tag
- `pinokew/koha:sha-<git_sha>` — immutable tag (exact build)

## Security Model

- No `.env` file is copied into the image.
- Database and broker credentials are provided only at container runtime.
- External template overrides are disabled in runtime bootstrap (public-image hardening).
- The container validates required Koha system templates from installed `koha-core` package.

## Required Runtime Environment Variables

Database:
- `MYSQL_SERVER` (or `DB_HOST`)
- `DB_NAME`
- `MYSQL_USER` (or `DB_USER`)
- `MYSQL_PASSWORD` (or `DB_PASS`)
- `DB_ROOT_PASS` (used to generate `/etc/mysql/koha-common.cnf`)

Koha:
- `KOHA_INSTANCE` (default: `library`)
- `TZ` or `KOHA_TIMEZONE`
- `KOHA_LANGS` (optional)

RabbitMQ:
- `MB_HOST` / `MB_PORT`
- `MB_USER` (or `RABBITMQ_USER`)
- `MB_PASS` (or `RABBITMQ_PASS`)

Optional setup pipeline controls:
- `KOHA_SETUP_FAIL_FAST`
- `KOHA_SETUP_REQUIRED_STEPS`
- `KOHA_SETUP_SKIP_STEPS`
- `KOHA_SETUP_ONLY_STEPS`

## Minimal Docker Compose Example

```yaml
services:
  koha:
    image: pinokew/koha:25.05
    ports:
      - "8080:8080"
      - "8081:8081"
    environment:
      KOHA_INSTANCE: library
      TZ: Europe/Kyiv
      KOHA_LANGS: "uk-UA"

      MYSQL_SERVER: db
      DB_NAME: koha_library
      MYSQL_USER: koha_db
      MYSQL_PASSWORD: change_me
      DB_ROOT_PASS: change_me_root

      MB_HOST: rabbitmq
      MB_PORT: 61613
      MB_USER: koha_mq
      MB_PASS: change_me_mq

      USE_ELASTICSEARCH: "true"
      ELASTICSEARCH_HOST: es:9200
```

## Notes

- Use Docker/Swarm/Kubernetes secrets for production credentials.
- Prefer immutable `sha-...` tag for reproducible deployments.
- `latest` is convenient, but not reproducible.
