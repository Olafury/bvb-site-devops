#!/usr/bin/env bash
# Pulls the latest branch of a project, rebuilds its stack and reports the result to Telegram.
# Usage: deploy.sh backend|frontend
# Triggered by hooks.json inside the site.deploy container (docker exec site.deploy ./deploy/deploy.sh backend to run manually).
set -Eeuo pipefail

PROJECT="${1:-}"
LOG_FILE="$(mktemp)"
STEP="init"

send_telegram() {
  curl -fsS --max-time 15 \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=$1" \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" > /dev/null \
    || echo "Failed to send Telegram message" >&2
}

commit_info() {
  printf '📦 Проект: %s\n🌿 Ветка: %s\n🔗 Коммит: %s\n💬 Сообщение: %s' \
    "$(basename -s .git "$(git remote get-url origin)")" "$BRANCH" \
    "$(git rev-parse --short HEAD)" "$(git log -1 --pretty=%s)"
}

on_error() {
  local code=$?
  trap - ERR
  set +e
  send_telegram "$(printf '❌ Развертывание не удалось!\n%s\n⚠️ Шаг: %s\n\n%s' \
    "$(commit_info)" "$STEP" "$(tail -n 20 "$LOG_FILE" | tail -c 3000)")"
  exit "$code"
}

main() {
  case "$PROJECT" in
    backend)
      REPO_DIR="${BACKEND_DIR:?BACKEND_DIR is not set}"
      BRANCH="${BACKEND_BRANCH:-develop}"
      ;;
    frontend)
      REPO_DIR="${FRONTEND_DIR:?FRONTEND_DIR is not set}"
      BRANCH="${FRONTEND_BRANCH:-main}"
      ;;
    *)
      echo "Usage: $0 backend|frontend" >&2
      exit 2
      ;;
  esac
  : "${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN is not set}"
  : "${TELEGRAM_CHAT_ID:?TELEGRAM_CHAT_ID is not set}"
  cd "$REPO_DIR"

  # One deploy at a time across all projects: a request during a running deploy waits for it to finish.
  exec 9> /tmp/site-deploy.lock
  flock 9

  exec > >(tee -a "$LOG_FILE") 2>&1
  trap on_error ERR
  trap 'rm -f "$LOG_FILE"' EXIT

  STEP="git fetch"
  git fetch --prune origin "$BRANCH"
  STEP="git checkout"
  git checkout -f -B "$BRANCH" "origin/$BRANCH"

  STEP="docker compose up"
  docker compose -f docker-compose.yml up --build -d

  STEP="notify"
  send_telegram "$(printf '✅ Развертывание завершено!\n%s' "$(commit_info)")"
  echo "Deploy of $PROJECT $(git rev-parse --short HEAD) finished"
}

main "$@"
