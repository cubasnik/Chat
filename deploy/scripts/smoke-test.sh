#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${REPO_DIR}/deploy/compose/.env"
COMPOSE_DIR="${REPO_DIR}/deploy/compose"

load_env() {
    set -a
    source "${ENV_FILE}"
    set +a
}

check_url() {
    local url="$1"
    local expect="$2"

    echo "Checking ${url}"
    if ! response="$(curl -fsSL "${url}")"; then
        echo "Request failed: ${url}" >&2
        exit 1
    fi

    if [[ -n "${expect}" ]] && [[ "${response}" != *"${expect}"* ]]; then
        echo "Response from ${url} did not contain expected text: ${expect}" >&2
        exit 1
    fi
}

main() {
    if [[ ! -f "${ENV_FILE}" ]]; then
        echo "Missing ${ENV_FILE}" >&2
        exit 1
    fi

    load_env

    check_url "https://${DOMAIN}/" ""
    check_url "https://${DOMAIN}/config.json" "${PUBLIC_BASEURL%/}"
    check_url "https://${DOMAIN}/_matrix/client/versions" "versions"

    echo "Checking Docker services"
    cd "${COMPOSE_DIR}"
    docker compose --env-file .env ps

    echo "Checking host services"
    sudo systemctl --no-pager --full status nginx coturn fail2ban | sed -n '1,80p'

    echo "Checking firewall status"
    sudo ufw status verbose

    echo "Smoke test finished. Manual client-side tests are still required for login, E2EE, upload, and calls."
}

main "$@"