#!/bin/bash
# Чекаємо секунд, щоб мережа та DNS точно піднялися
sleep 60

cd $HOME/Koha/koha-doker

# Примусовий перезапуск для чистого старту
docker compose down
docker compose up -d