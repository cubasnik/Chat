#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${REPO_DIR}/deploy/compose/.env"
COMPOSE_DIR="${REPO_DIR}/deploy/compose"
BACKUP_DIR="${1:-${REPO_DIR}/backups}"

timestamp="$(date +%Y%m%d-%H%M%S)"
archive_prefix="chat-backup-${timestamp}"

load_env() {
    set -a
    source "${ENV_FILE}"
    set +a
}

main() {
    if [[ ! -f "${ENV_FILE}" ]]; then
        echo "Missing ${ENV_FILE}" >&2
        exit 1
    fi

    load_env

    mkdir -p "${BACKUP_DIR}"

    echo "Creating config and key backup"
    tar -czf "${BACKUP_DIR}/${archive_prefix}-config.tgz" \
        -C "${REPO_DIR}" \
        deploy/compose/.env \
        deploy/synapse

    echo "Creating PostgreSQL dump"
    cd "${COMPOSE_DIR}"
    docker compose --env-file .env exec -T postgres \
        pg_dump -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" | gzip > "${BACKUP_DIR}/${archive_prefix}-postgres.sql.gz"

    echo "Backups created:"
    echo "  ${BACKUP_DIR}/${archive_prefix}-config.tgz"
    echo "  ${BACKUP_DIR}/${archive_prefix}-postgres.sql.gz"
}

main "$@"