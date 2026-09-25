# Деплой по HTTP-запросу

`POST /hooks/deploy-<проект>` с токеном → контейнер `site.deploy` → [deploy.sh](deploy.sh) `<проект>`:

| Проект | Хук | Репозиторий | Ветка по умолчанию |
|---|---|---|---|
| `backend` | `/hooks/deploy-backend` | `BACKEND_DIR` | `develop` (`BACKEND_BRANCH`) |
| `frontend` | `/hooks/deploy-frontend` | `FRONTEND_DIR` | `main` (`FRONTEND_BRANCH`) |

1. `git fetch` + `git checkout -f -B <ветка> origin/<ветка>` в репозитории проекта; локальные изменения в отслеживаемых файлах на сервере сбрасываются;
2. `docker compose -f docker-compose.yml up --build -d` в корне репозитория проекта;
3. сообщение в Telegram (при ошибке — сообщение с упавшим шагом и хвостом лога).

Деплои выполняются по одному: запрос во время идущего деплоя ждёт его завершения.

На сервере нужен только Docker с compose-плагином: listener ([adnanh/webhook](https://github.com/adnanh/webhook)), git, ssh и docker CLI находятся внутри образа, а контейнер управляет хостовым Docker через `/var/run/docker.sock`.

## Установка на сервер

Репозитории проектов должны быть уже склонированы. Для клонированных по SSH (`git@github.com:...`) используется ключ из `DEPLOY_SSH_KEY`: он монтируется в контейнер только для чтения и должен быть без пароля. Deploy key в GitHub привязывается только к одному репозиторию, поэтому для двух приватных репозиториев нужен ключ пользователя с доступом к обоим. Публичный репозиторий можно клонировать по HTTPS, тогда ключ для него не нужен.

```bash
cd /srv/github/bvb-site-devops
cp deploy/.env.example deploy/.env   # заполнить токен, данные Telegram, пути к репозиториям и путь к ключу
./deploy/up.sh
```

`.env` самих проектов (для их `docker-compose.yml`) лежат в корнях их репозиториев.

## Запуск деплоя

```bash
curl -X POST -H "X-Deploy-Token: <DEPLOY_TOKEN>" https://deploy.bvb-news.ru/hooks/deploy-backend
curl -X POST -H "X-Deploy-Token: <DEPLOY_TOKEN>" https://deploy.bvb-news.ru/hooks/deploy-frontend
```

Ответ `Deploy started` приходит сразу, а сам деплой идёт в фоне; о результате сообщит Telegram. При неверном токене сервер отвечает `401`.

Снаружи хуки доступны только через reverse proxy ([../proxy](../proxy)) по HTTPS. На самом сервере listener слушает `127.0.0.1:${DEPLOY_WEBHOOK_PORT}`.

## Telegram

1. Создать бота через @BotFather → `TELEGRAM_BOT_TOKEN`.
2. Написать боту (или добавить его в группу), затем взять `chat.id` из `https://api.telegram.org/bot<token>/getUpdates` → `TELEGRAM_CHAT_ID`.

## Эксплуатация

- Логи вебхука и деплоев: `docker logs -f site.deploy`
- Деплой без HTTP-запроса: `docker exec site.deploy ./deploy/deploy.sh backend` (или `frontend`)
- После `git pull` в этом репозитории: `deploy.sh` подхватывается сразу (он читается при каждом запуске), `hooks.json` — после `docker restart site.deploy`, остальные файлы `deploy/` и `deploy/.env` — после `./deploy/up.sh`.
