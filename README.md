KDV Koha - Enterprise Library System Image

This is an Enterprise-ready, Stateless Docker image for Koha ILS, built specifically for modern containerized environments (Kubernetes / Docker Compose).

Unlike standard Koha installations, this image is optimized for CI/CD, Zero-Trust security, and horizontal scalability.

🚀 Key Features & Architectural Changes

100% Stateless: No configuration files or secrets are baked into the image. Everything is generated at runtime via Environment Variables.

Modern Plack Stack: Completely ditches the legacy mpm_itk and CGI setups. Runs exclusively on Apache2 + Plack (Starman) for high performance.

s6-overlay Orchestration: Uses a step-by-step modular runtime bootstrap. Background workers, the Elasticsearch indexer daemon, and the web server are gracefully managed by s6.

Native Elasticsearch Auto-indexing: The koha-es-indexer daemon is correctly configured and starts automatically, ensuring real-time search indexing.

Secure Permissions: Enforces strict UID/GID (1000:1000) for the library-koha user, solving common permission conflicts in mounted volumes.

🛠 Quick Start (Docker Compose)

Since this image is stateless, you must provide the necessary database and message broker configurations via environment variables.

Here is a minimal docker-compose.yml example to run this image alongside MariaDB, RabbitMQ, Memcached, and Elasticsearch:

services:
  koha:
    image: yourusername/kdv-koha:25.05
    container_name: koha-app
    ports:
      - "8080:8080" # OPAC
      - "8081:8081" # Staff Interface
    environment:
      - KOHA_INSTANCE=library
      - KOHA_LANGS=uk-UA en
      # Database
      - MYSQL_SERVER=db
      - DB_NAME=koha_library
      - MYSQL_USER=koha_admin
      - MYSQL_PASSWORD=supersecret
      # RabbitMQ
      - MB_HOST=rabbitmq
      - MB_USER=koha_mq
      - MB_PASS=mq_secret
      # Features
      - USE_ELASTICSEARCH=true
      - ELASTICSEARCH_HOST=es:9200


⚙️ Environment Variables Reference

This image requires several environment variables to run correctly.

Database Configuration

MYSQL_SERVER (or DB_HOST): The hostname of the MariaDB container.

DB_NAME: The name of the database.

MYSQL_USER (or DB_USER): Database user.

MYSQL_PASSWORD (or DB_PASS): Database password.

Message Broker (RabbitMQ)

MB_HOST: RabbitMQ server hostname.

MB_USER (or RABBITMQ_USER): RabbitMQ username.

MB_PASS (or RABBITMQ_PASS): RabbitMQ password.

System Settings

KOHA_INSTANCE: The name of the Koha instance (default: library).

KOHA_LANGS: Space-separated list of languages to install and activate (e.g., uk-UA en).

USE_ELASTICSEARCH: Set to true to enable the ES indexer daemon.

KOHA_SETUP_FAIL_FAST: Set to true to immediately stop the container if any setup step fails.

🛡 Security Note

This image expects all sensitive credentials to be passed during runtime. Do not mount static templates containing passwords directly into the container.

Built with ❤️ by the KDV Project.