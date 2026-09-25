#!/usr/bin/env bash
# Builds and starts the deploy webhook listener.
set -euo pipefail

DEVOPS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVOPS_DIR

exec docker compose -f "$DEVOPS_DIR/deploy/docker-compose.yml" up --build -d "$@"
