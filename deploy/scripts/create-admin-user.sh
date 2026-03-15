#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_DIR="${REPO_DIR}/deploy/compose"
ENV_FILE="${COMPOSE_DIR}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
    echo "Missing ${ENV_FILE}" >&2
    exit 1
fi

if [[ ! -d "${COMPOSE_DIR}" ]]; then
    echo "Missing compose directory: ${COMPOSE_DIR}" >&2
    exit 1
fi

if ! grep -q '^REGISTRATION_SHARED_SECRET=' "${ENV_FILE}"; then
    echo "REGISTRATION_SHARED_SECRET is missing from ${ENV_FILE}" >&2
    exit 1
fi

admin_user="${1:-${MATRIX_ADMIN_USER:-}}"
admin_password="${MATRIX_ADMIN_PASSWORD:-}"

if [[ -z "${admin_user}" ]]; then
    read -r -p "Matrix admin username: " admin_user
fi

if [[ -z "${admin_password}" ]]; then
    read -r -s -p "Matrix admin password: " admin_password
    echo
fi

if [[ -z "${admin_user}" || -z "${admin_password}" ]]; then
    echo "Username and password are required." >&2
    exit 1
fi

cd "${COMPOSE_DIR}"
docker compose --env-file .env exec -T synapse \
    register_new_matrix_user \
    -u "${admin_user}" \
    -p "${admin_password}" \
    -a \
    -c /data/homeserver.yaml \
    http://localhost:8008