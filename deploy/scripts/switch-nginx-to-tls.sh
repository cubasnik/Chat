#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${REPO_DIR}/deploy/compose/.env"
FINAL_NGINX="${REPO_DIR}/build/nginx/matrix.conf"

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

    if [[ ! -f "${FINAL_NGINX}" ]]; then
        echo "Missing rendered nginx TLS config: ${FINAL_NGINX}" >&2
        echo "Run: bash deploy/scripts/render-templates.sh" >&2
        exit 1
    fi

    if [[ ! -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" || ! -f "/etc/letsencrypt/live/${DOMAIN}/privkey.pem" ]]; then
        echo "TLS certificates for ${DOMAIN} are not present yet." >&2
        echo "Run certbot first: sudo certbot --nginx -d ${DOMAIN}" >&2
        exit 1
    fi

    sudo cp "${FINAL_NGINX}" /etc/nginx/sites-available/matrix.conf
    sudo nginx -t
    sudo systemctl reload nginx

    echo "nginx switched to the final TLS config for ${DOMAIN}."
}

main "$@"