#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${REPO_DIR}/deploy/compose/.env"
FAIL2BAN_JAIL="/etc/fail2ban/jail.d/chat-local.conf"
SYSCTL_FILE="/etc/sysctl.d/99-chat-hardening.conf"

load_env() {
    set -a
    source "${ENV_FILE}"
    set +a
}

require_root_tools() {
    if [[ ! -f "${ENV_FILE}" ]]; then
        echo "Missing ${ENV_FILE}" >&2
        exit 1
    fi
}

install_packages() {
    sudo apt update
    sudo apt install -y fail2ban ufw unattended-upgrades apt-listchanges
}

configure_unattended_upgrades() {
    sudo tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
}

configure_fail2ban() {
    load_env

    sudo mkdir -p /etc/fail2ban/jail.d
    sudo tee "${FAIL2BAN_JAIL}" > /dev/null <<EOF
[sshd]
enabled = true
port = ${SSH_PORT:-22}
logpath = %(sshd_log)s
backend = systemd
maxretry = 5
bantime = 1h
findtime = 10m

[nginx-http-auth]
enabled = true

[nginx-botsearch]
enabled = true
EOF

    sudo systemctl enable --now fail2ban
    sudo systemctl restart fail2ban
}

configure_ufw() {
    load_env

    if [[ "${SKIP_UFW:-0}" == "1" ]]; then
        echo "Skipping UFW setup because SKIP_UFW=1"
        return
    fi

    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow "${SSH_PORT:-22}"/tcp
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw allow 3478/tcp
    sudo ufw allow 3478/udp
    sudo ufw allow 49152:65535/udp
    sudo ufw --force enable
}

configure_sysctl() {
    sudo tee "${SYSCTL_FILE}" > /dev/null <<'EOF'
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
EOF
    sudo sysctl --system
}

main() {
    require_root_tools
    install_packages
    configure_unattended_upgrades
    configure_fail2ban
    configure_ufw
    configure_sysctl

    echo
    echo "Hardening finished."
    echo "Verify with: sudo ufw status verbose && sudo fail2ban-client status"
}

main "$@"