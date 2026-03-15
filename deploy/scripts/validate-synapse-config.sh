#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_DIR="${REPO_DIR}/deploy/compose"
ENV_FILE="${COMPOSE_DIR}/.env"
CONFIG_FILE="${REPO_DIR}/deploy/synapse/homeserver.yaml"

if [[ ! -f "${ENV_FILE}" ]]; then
    echo "Missing ${ENV_FILE}" >&2
    exit 1
fi

if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "Missing ${CONFIG_FILE}" >&2
    echo "Run: bash deploy/scripts/render-templates.sh" >&2
    exit 1
fi

cd "${COMPOSE_DIR}"
docker compose --env-file .env run --rm synapse python -m synapse.config -c /data/homeserver.yaml