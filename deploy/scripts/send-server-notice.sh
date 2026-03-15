#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${REPO_DIR}/deploy/compose/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
    echo "Missing ${ENV_FILE}" >&2
    exit 1
fi

target_user="${1:-}"
notice_body="${2:-}"
admin_user="${MATRIX_ADMIN_USER:-}"
admin_password="${MATRIX_ADMIN_PASSWORD:-}"

if [[ -z "${target_user}" ]]; then
    read -r -p "Target Matrix user ID: " target_user
fi

if [[ -z "${notice_body}" ]]; then
    read -r -p "Server notice body: " notice_body
fi

if [[ -z "${admin_user}" ]]; then
    read -r -p "Admin username: " admin_user
fi

if [[ -z "${admin_password}" ]]; then
    read -r -s -p "Admin password: " admin_password
    echo
fi

if [[ -z "${target_user}" || -z "${notice_body}" || -z "${admin_user}" || -z "${admin_password}" ]]; then
    echo "Target user, notice body, admin username, and admin password are required." >&2
    exit 1
fi

load_env() {
    set -a
    source "${ENV_FILE}"
    set +a
}

json_escape() {
    python -c "import json,sys; print(json.dumps(sys.argv[1]))" "$1"
}

extract_json_field() {
    local field_name="$1"
    python -c "import json,sys; print(json.load(sys.stdin).get(sys.argv[1], ''))" "${field_name}"
}

load_env

login_payload=$(cat <<EOF
{
  "type": "m.login.password",
  "identifier": {
    "type": "m.id.user",
    "user": $(json_escape "${admin_user}")
  },
  "password": $(json_escape "${admin_password}")
}
EOF
)

login_response="$(curl -fsSL -X POST \
    -H "Content-Type: application/json" \
    -d "${login_payload}" \
    "http://127.0.0.1:8008/_matrix/client/v3/login")"

access_token="$(printf '%s' "${login_response}" | extract_json_field access_token)"

if [[ -z "${access_token}" ]]; then
    echo "Failed to obtain admin access token." >&2
    exit 1
fi

notice_payload=$(cat <<EOF
{
  "user_id": $(json_escape "${target_user}"),
  "content": {
    "msgtype": "m.text",
    "body": $(json_escape "${notice_body}")
  }
}
EOF
)

curl -fsSL -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${access_token}" \
    -d "${notice_payload}" \
    "http://127.0.0.1:8008/_synapse/admin/v1/send_server_notice"

echo
echo "Server notice sent to ${target_user}."