#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${REPO_DIR}/deploy/compose/.env"
COMPOSE_DIR="${REPO_DIR}/deploy/compose"
SYNAPSE_DIR="${REPO_DIR}/deploy/synapse"
GENERATED_CONFIG="${SYNAPSE_DIR}/homeserver.generated.yaml"
RENDERED_CONFIG="${SYNAPSE_DIR}/homeserver.yaml"
BOOTSTRAP_NGINX="${REPO_DIR}/build/nginx/matrix-http.conf"
FINAL_NGINX="${REPO_DIR}/build/nginx/matrix.conf"

load_env() {
    set -a
    source "${ENV_FILE}"
    set +a
}

require_command() {
    local command_name="$1"

    if ! command -v "${command_name}" >/dev/null 2>&1; then
        echo "Missing required command: ${command_name}" >&2
        exit 1
    fi
}

extract_top_level_block() {
    local source_file="$1"
    local key_name="$2"

    awk -v key_name="${key_name}" '
        $0 ~ "^" key_name ":" {
            capture = 1
        }
        capture {
            if (printed && $0 ~ "^[A-Za-z_][A-Za-z0-9_]*:" && $0 !~ "^" key_name ":") {
                exit
            }
            print
            printed = 1
        }
    ' "${source_file}"
}

append_preserved_block() {
    local key_name="$1"
    local block_content

    if grep -q "^${key_name}:" "${RENDERED_CONFIG}"; then
        return
    fi

    block_content="$(extract_top_level_block "${GENERATED_CONFIG}" "${key_name}")"
    if [[ -n "${block_content}" ]]; then
        printf '\n%s\n' "${block_content}" >> "${RENDERED_CONFIG}"
    fi
}

install_prerequisites() {
    sudo apt update
    sudo apt install -y ca-certificates curl gnupg lsb-release gettext-base nginx coturn element-web certbot python3-certbot-nginx
}

install_docker() {
    if command -v docker >/dev/null 2>&1; then
        return
    fi

    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
        $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

enable_services() {
    sudo systemctl enable --now docker
    sudo sed -i 's/^#TURNSERVER_ENABLED=.*/TURNSERVER_ENABLED=1/' /etc/default/coturn
    sudo sed -i 's/^TURNSERVER_ENABLED=.*/TURNSERVER_ENABLED=1/' /etc/default/coturn
}

generate_synapse_config() {
    load_env

    mkdir -p "${SYNAPSE_DIR}"

    if [[ ! -f "${GENERATED_CONFIG}" ]]; then
        cd "${COMPOSE_DIR}"
        docker compose --env-file .env run --rm \
            -e SYNAPSE_SERVER_NAME="${DOMAIN}" \
            -e SYNAPSE_REPORT_STATS=no \
            synapse generate

        cp "${RENDERED_CONFIG}" "${GENERATED_CONFIG}"
    fi
}

render_configs() {
    bash "${REPO_DIR}/deploy/scripts/render-templates.sh"

    if [[ -f "${GENERATED_CONFIG}" ]]; then
        append_preserved_block "macaroon_secret_key"
        append_preserved_block "form_secret"
        append_preserved_block "signing_key_path"
        append_preserved_block "trusted_key_servers"
        append_preserved_block "report_stats"
    fi
}

validate_synapse_config() {
    bash "${REPO_DIR}/deploy/scripts/validate-synapse-config.sh"
}

install_bootstrap_nginx() {
    sudo cp "${BOOTSTRAP_NGINX}" /etc/nginx/sites-available/matrix.conf
    sudo ln -sf /etc/nginx/sites-available/matrix.conf /etc/nginx/sites-enabled/matrix.conf
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo nginx -t
    sudo systemctl restart nginx
}

run_certbot_if_configured() {
    load_env

    if [[ -z "${CERTBOT_EMAIL:-}" ]]; then
        echo "Skipping certbot because CERTBOT_EMAIL is not set."
        echo "Run this manually after bootstrap: sudo certbot --nginx -d ${DOMAIN}"
        return
    fi

    sudo certbot --nginx --non-interactive --agree-tos -m "${CERTBOT_EMAIL}" -d "${DOMAIN}" ${CERTBOT_ARGS:-}
}

certificates_exist() {
    load_env
    [[ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" && -f "/etc/letsencrypt/live/${DOMAIN}/privkey.pem" ]]
}

install_final_configs() {
    load_env

    if ! certificates_exist; then
        echo "TLS certificates are not present yet. Keeping the HTTP-only nginx bootstrap config in place."
        echo "After running certbot, install the final nginx config with:"
        echo "  sudo cp ${FINAL_NGINX} /etc/nginx/sites-available/matrix.conf"
        echo "  sudo nginx -t && sudo systemctl reload nginx"
        sudo cp "${REPO_DIR}/build/coturn/turnserver.conf" /etc/turnserver.conf
        sudo cp "${REPO_DIR}/build/element-web/config.json" "${ELEMENT_CONFIG_PATH}"
        sudo systemctl enable --now coturn
        return
    fi

    sudo cp "${FINAL_NGINX}" /etc/nginx/sites-available/matrix.conf
    sudo cp "${REPO_DIR}/build/coturn/turnserver.conf" /etc/turnserver.conf
    sudo cp "${REPO_DIR}/build/element-web/config.json" "${ELEMENT_CONFIG_PATH}"
    sudo nginx -t
    sudo systemctl restart nginx
    sudo systemctl enable --now coturn
}

start_backend() {
    cd "${COMPOSE_DIR}"
    docker compose --env-file .env up -d postgres synapse
}

main() {
    require_command bash
    require_command curl

    if [[ ! -f "${ENV_FILE}" ]]; then
        echo "Missing ${ENV_FILE}" >&2
        exit 1
    fi

    load_env
    install_prerequisites
    install_docker
    require_command docker
    enable_services
    generate_synapse_config
    render_configs
    validate_synapse_config
    install_bootstrap_nginx
    run_certbot_if_configured
    install_final_configs
    start_backend

    echo
    echo "Bootstrap finished."
    if ! certificates_exist; then
        echo "TLS is still pending. Run certbot, then install the final nginx config shown above."
    fi
    echo "Next: create the first admin user:"
    echo "  cd ${COMPOSE_DIR}"
    echo "  docker compose --env-file .env exec synapse register_new_matrix_user -c /data/homeserver.yaml http://localhost:8008"
}

main "$@"