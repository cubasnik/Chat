#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${REPO_DIR}/deploy/compose/.env"

if ! command -v envsubst >/dev/null 2>&1; then
    echo "envsubst is required. Install gettext-base on Debian 12." >&2
    exit 1
fi

if [[ ! -f "${ENV_FILE}" ]]; then
    echo "Missing ${ENV_FILE}. Copy deploy/compose/.env.example first." >&2
    exit 1
fi

set -a
source "${ENV_FILE}"
set +a

render() {
    local template_path="$1"
    local output_path="$2"

    mkdir -p "$(dirname "${output_path}")"
    envsubst < "${template_path}" > "${output_path}"
    echo "Rendered ${output_path}"
}

render "${REPO_DIR}/deploy/synapse/homeserver.yaml.template" "${REPO_DIR}/deploy/synapse/homeserver.yaml"
render "${REPO_DIR}/deploy/nginx/matrix-http.conf.template" "${REPO_DIR}/build/nginx/matrix-http.conf"
render "${REPO_DIR}/deploy/nginx/matrix.conf.template" "${REPO_DIR}/build/nginx/matrix.conf"
render "${REPO_DIR}/deploy/coturn/turnserver.conf.template" "${REPO_DIR}/build/coturn/turnserver.conf"
render "${REPO_DIR}/deploy/element-web/config.json.template" "${REPO_DIR}/build/element-web/config.json"

echo "Keep the generated Synapse signing key, macaroon secret, and log config from the first Synapse bootstrap run."