# Reverse proxy (Caddy)

Заменяет вручную настроенный nginx + certbot на хосте. Единая точка входа для [bvb-site-backend](https://github.com/Olafury/bvb-site-backend) (контейнеры `site.api`, `site.worker`, `site.minio`), [bvb-site-frontend](https://github.com/Yuliya555/bvb-site-frontend) (`site.front`) и вебхука деплоя (`site.deploy`). Маршруты — в [caddy/Caddyfile](caddy/Caddyfile), сертификаты Let's Encrypt Caddy получает и продлевает сам.

Прокси, фронт, бэкенд и вебхук деплоя запускаются независимо друг от друга: Caddy находит контейнеры по имени в момент запроса, а пока контейнер не запущен, на его маршруте отдаётся 502.

## Запуск

```bash
docker compose -f proxy/docker-compose.yml up -d
```

Перед первым запуском:

- DNS всех доменов из Caddyfile указывает на этот сервер;
- порты 80 и 443 открыты и не заняты (nginx на хосте остановлен: `systemctl disable --now nginx`).

## Изменение маршрутов

Отредактировать `caddy/Caddyfile`, затем:

```bash
docker exec site.caddy caddy reload --config /etc/caddy/Caddyfile
```

Сервисы из compose-проектов в сети `site` адресуются по имени контейнера (`site.api:8080`), процессы на самом хосте — через `host.docker.internal:<порт>`.

## Эксплуатация

- Логи (в том числе выпуск сертификатов): `docker logs -f site.caddy`
- Сертификаты хранятся в томе `caddy_data`, его нельзя удалять.
