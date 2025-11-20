#!/usr/bin/env bash
set -euo pipefail

# === Підтягнути змінні з .env (твій DB_NAME, DB_USER, DB_PASS і т.д.) ===
if [ -f .env ]; then
  set -a
  . ./.env
  set +a
else
  echo "❌ Файл .env не знайдено в поточній директорії!"
  exit 1
fi

BACKUP_ROOT="./backups"
TS="$(date +'%Y-%m-%d_%H-%M-%S')"
BACKUP_DIR="$BACKUP_ROOT/$TS"

mkdir -p "$BACKUP_DIR"
echo "📁 Створено директорію для бекапів: $BACKUP_DIR"

# === 1. Дамп бази даних Koha (MariaDB) ===
# Сервіс БД у твоєму docker-compose називається 'db'

echo "💾 Роблю SQL-дамп бази даних ${DB_NAME}..."
docker compose exec db sh -c "mysqldump -u\"${DB_USER}\" -p\"${DB_PASS}\" \"${DB_NAME}\"" > "$BACKUP_DIR/${DB_NAME}.sql"
echo "✅ Дамп БД збережено в $BACKUP_DIR/${DB_NAME}.sql"

# === 2. Бекап тома mariadb-koha (файлова копія даних БД) ===
# Це додатковий рівень безпеки, поруч із SQL-дампом.

echo "📦 Архівую Docker-том mariadb-koha..."
docker run --rm \
  -v mariadb-koha:/volume \
  -v "$BACKUP_DIR":/backup \
  alpine sh -c "cd /volume && tar -czf /backup/mariadb-koha_volume.tar.gz ."
echo "✅ mariadb-koha_volume.tar.gz збережено в $BACKUP_DIR"

# === 3. Бекап томів Koha: koha_config і koha_data ===

echo "📦 Архівую Docker-том koha_config (/etc/koha/sites)..."
docker run --rm \
  -v koha_config:/volume \
  -v "$BACKUP_DIR":/backup \
  alpine sh -c "cd /volume && tar -czf /backup/koha_config_volume.tar.gz ."
echo "✅ koha_config_volume.tar.gz збережено в $BACKUP_DIR"

echo "📦 Архівую Docker-том koha_data (/var/lib/koha)..."
docker run --rm \
  -v koha_data:/volume \
  -v "$BACKUP_DIR":/backup \
  alpine sh -c "cd /volume && tar -czf /backup/koha_data_volume.tar.gz ."
echo "✅ koha_data_volume.tar.gz збережено в $BACKUP_DIR"

# === 4. Бекап тома Elasticsearch es-data ===
# Його можна буде не відновлювати, а переіндексувати, але бекап не завадить.

echo "📦 Архівую Docker-том es-data (Elasticsearch)..."
docker run --rm \
  -v es-data:/volume \
  -v "$BACKUP_DIR":/backup \
  alpine sh -c "cd /volume && tar -czf /backup/es-data_volume.tar.gz ."
echo "✅ es-data_volume.tar.gz збережено в $BACKUP_DIR"

echo "🎉 Усі бекапи успішно створено в: $BACKUP_DIR"
