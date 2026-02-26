FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive
ARG S6_OVERLAY_VERSION=3.2.0.2
ARG KOHA_VERSION=25.05
ARG TARGETARCH
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

LABEL org.opencontainers.image.source=https://github.com/teorgamm/koha-docker

RUN apt-get  update \
    && apt-get install -y --no-install-recommends \
            wget \
            apache2 \
            gnupg2 \
            apt-transport-https \
            xz-utils \
    && rm -rf /var/cache/apt/archives/* \
    && rm -rf /var/lib/apt/lists/*

ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz

RUN echo "${TARGETARCH}" && case "${TARGETARCH}" in \
            "amd64")  S6_ARCH=x86_64  ;; \
            "arm64")  S6_ARCH=aarch64  ;; \
            "arm")  S6_ARCH=armhf ;; \
        esac \
    && wget -P /tmp/ -q "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz" \
    && tar -C / -Jxpf "/tmp/s6-overlay-${S6_ARCH}.tar.xz"

RUN mkdir -p /etc/apt/keyrings/ && \
    wget -qO - https://debian.koha-community.org/koha/gpg.asc | gpg --dearmor -o /etc/apt/keyrings/koha.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/koha.gpg] https://debian.koha-community.org/koha ${KOHA_VERSION}  main" | tee /etc/apt/sources.list.d/koha.list
# Встановлюємо локалі, необхідні для Koha (en + uk)
RUN apt-get update && apt-get install -y --no-install-recommends locales && \
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
    echo "uk_UA.UTF-8 UTF-8" >> /etc/locale.gen && \
    locale-gen && \
    apt-get purge -y --auto-remove -y locales && \
    rm -rf /var/lib/apt/lists/*
# Install Koha
RUN apt-get update \
    && apt-get install -y koha-core \
       idzebra-2.0 \
       apache2 \
       logrotate \
    && rm -rf /var/cache/apt/archives/* \
    && rm -rf /var/lib/apt/lists/*

# KDV: виправляємо створення каталогу логів у koha-create (не падати, якщо вже існує)
RUN sed -i 's#mkdir "/var/log/koha/\$name"#mkdir -p "/var/log/koha/\$name" || true#' /usr/sbin/koha-create \
 && sed -i 's#chown "$username:$username" "/var/log/koha/\$name"#chown "$username:$username" "/var/log/koha/\$name" || true#' /usr/sbin/koha-create \
 && sed -i 's#chown $username:$username /var/log/koha/\$name/\*\.log#chown $username:$username /var/log/koha/\$name/*.log || true#' /usr/sbin/koha-create || true

 
RUN a2enmod rewrite \
    && a2enmod headers \
    && a2enmod proxy_http \
    && a2enmod cgi \
    && a2dissite 000-default \
    && echo "Listen 8081\nListen 8080" > /etc/apache2/ports.conf \
    && mkdir -p /var/log/koha/apache \
    && mkdir -p /var/log/koha/apache

RUN mkdir -p /usr/share/koha/etc

# Підкидаємо всі наші файли в образ
COPY --chown=0:0 files/ /
# Runtime-пайплайн налаштування з кореня репозиторію
COPY --chown=0:0 scripts/koha-setup/ /etc/s6-overlay/scripts/


# Гарантуємо, що скрипти s6 виконувані (включно з підпапками)
RUN find /etc/s6-overlay/scripts -type f -name "*.sh" -exec chmod +x {} \;


# модулі та конфіги Apache
RUN a2enmod proxy proxy_http headers && \
    a2dismod mpm_itk || true && \
    a2enconf fqdn

# (опційно) переконатися, що sites-enabled посилається на наш vhost
RUN ln -sf ../sites-available/library.conf /etc/apache2/sites-enabled/library.conf

# Виправляємо CRLF у конфігах s6-overlay
RUN apt-get update && apt-get install -y --no-install-recommends dos2unix && \
    { find /etc/s6-overlay -type f -print0 | xargs -0 dos2unix; } && \
    apt-get purge -y dos2unix && rm -rf /var/lib/apt/lists/*

# -----------------------
    
WORKDIR /docker


EXPOSE 2100 6001 8080 8081

CMD [ "/init" ]
