# bvb-site-devops

Серверная обвязка bvb-news.ru, общая для двух приложений:

- [bvb-site-backend](https://github.com/Olafury/bvb-site-backend) — API, worker, Postgres, MinIO, NATS;
- [bvb-site-frontend](https://github.com/Yuliya555/bvb-site-frontend) — Next.js.

| Каталог | Что внутри |
|---|---|
| [proxy/](proxy) | Caddy: HTTPS, сертификаты и маршруты всех доменов |
| [deploy/](deploy) | Вебхук деплоя обоих приложений с уведомлениями в Telegram |

Compose-файлы самих приложений остаются в их репозиториях. Все стеки связаны внешней Docker-сетью `site` и находят друг друга по имени контейнера.

## Схема сервера

```
/srv/github/
  bvb-site-backend/    .env в корне
  bvb-site-frontend/   .env в корне
  bvb-site-devops/     deploy/.env
```

## Установка на новый сервер

1. Установить Docker с compose-плагином и создать общую сеть:
   ```bash
   docker network create site
   ```
2. Склонировать три репозитория в `/srv/github` и положить `.env` приложений и `deploy/.env` (см. [deploy/.env.example](deploy/.env.example)).
3. Перенести данные со старого сервера (см. ниже).
4. Запустить приложения:
   ```bash
   cd /srv/github/bvb-site-backend && docker compose -f docker-compose.yml up -d --build
   cd /srv/github/bvb-site-frontend && docker compose -f docker-compose.yml up -d --build
   ```
5. Запустить вебхук деплоя: `/srv/github/bvb-site-devops/deploy/up.sh`.
6. Проверить конфиг прокси:
   ```bash
   docker run --rm -v "$PWD/proxy/caddy:/etc/caddy" caddy:2-alpine caddy validate --config /etc/caddy/Caddyfile
   ```
7. Переключить DNS всех доменов из [proxy/caddy/Caddyfile](proxy/caddy/Caddyfile) на новый сервер (TTL лучше заранее снизить до 300) и запустить прокси:
   ```bash
   docker compose -f proxy/docker-compose.yml up -d
   docker logs -f site.caddy   # выпуск сертификатов
   ```
8. В CI заменить URL деплоя на `https://deploy.bvb-news.ru/hooks/deploy-backend` и `.../hooks/deploy-frontend`.

## Перенос данных

Перед выгрузкой остановить на старом сервере `site.api` и `site.worker`, чтобы данные не менялись.

Postgres (все базы, включая `tickerq`):

```bash
# старый сервер
docker exec site.postgres pg_dumpall -U <DB_DEFAULT_USER> > all.sql
# новый сервер: сначала поднять только базу
docker compose -f docker-compose.yml up -d postgres
docker exec -i site.postgres psql -U <DB_DEFAULT_USER> -d postgres < all.sql
```

Ошибки `already exists` для роли и базы, которые Postgres создаёт сам из `.env`, ожидаемы.

MinIO: том называется `<имя каталога бэкенда>_minio_data`, точное имя — в `docker volume ls`.

```bash
# старый сервер (после docker stop site.minio)
docker run --rm -v bvb-site-backend_minio_data:/data -v "$PWD":/backup alpine tar czf /backup/minio.tgz -C /data .
# новый сервер (до первого запуска minio)
docker volume create bvb-site-backend_minio_data
docker run --rm -v bvb-site-backend_minio_data:/data -v "$PWD":/backup alpine tar xzf /backup/minio.tgz -C /data
```
