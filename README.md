# golibas.online Matrix Deployment

This repository contains a deployment scaffold for a private Matrix stack on Debian 12.

Target stack:

- Synapse in Docker
- PostgreSQL in Docker
- nginx on the host
- coturn on the host
- Element Web from the Debian package

The files in `deploy/` are templates and examples intended to be adapted on the VPS.

## Structure

- `deploy/compose/docker-compose.yml`: Synapse and PostgreSQL services
- `deploy/compose/.env.example`: deployment variables to copy into `.env`
- `deploy/synapse/homeserver.yaml.template`: Synapse configuration template
- `deploy/nginx/matrix.conf.template`: nginx site template
- `deploy/nginx/matrix-http.conf.template`: nginx bootstrap HTTP-only site template
- `deploy/coturn/turnserver.conf.template`: coturn template
- `deploy/element-web/config.json.template`: Element Web runtime config
- `deploy/scripts/render-templates.sh`: renders templates from `deploy/compose/.env`
- `deploy/scripts/first-boot-debian12.sh`: Debian 12 bootstrap automation script
- `deploy/scripts/validate-synapse-config.sh`: validates the rendered Synapse config before startup
- `deploy/scripts/post-install-hardening-debian12.sh`: post-install host hardening script
- `deploy/scripts/create-admin-user.sh`: first local Matrix admin helper
- `deploy/scripts/send-server-notice.sh`: sends a Synapse server notice to a local user via the admin API
- `deploy/scripts/switch-nginx-to-tls.sh`: switches nginx from bootstrap HTTP to the final TLS config
- `deploy/scripts/smoke-test.sh`: server-side smoke test for endpoints and host services
- `deploy/scripts/backup-state.sh`: creates a config/key archive and PostgreSQL dump
- `deploy/scripts/retry-git-push.ps1`: retries `git push` over SSH when GitHub network access is flaky
- `docs/README.md`: documentation entry point and reading order
- `docs/bootstrap-debian12.md`: Debian 12 bootstrap and service bring-up guide
- `docs/deployment-checklist.md`: deployment validation and smoke-test checklist
- `docs/vps-runbook.md`: literal copy-paste operator runbook for the VPS
- `docs/quick-runbook.md`: shortest command-by-command bring-up path
- `docs/cutover-checklist.md`: launch-day checklist for DNS, health checks, and acceptance
- `docs/rollback-guide.md`: rollback flow using logs and backups

## Recommended values

- Domain: `golibas.online`
- Synapse image: `ghcr.io/element-hq/synapse:v1.149.1`
- PostgreSQL image: `postgres:16`
- Synapse DB name: `synapse`
- Synapse DB user: `synapse_user`
- Upload limit: `50M`
- Message retention max: `180d`
- Remote media retention: `30d`
- Default onboarding room: `#general:golibas.online`
- Timezone: `UTC`

## Suggested implementation order

1. Review `deploy/compose/.env` and rotate secrets if needed.
2. Generate the initial Synapse config and signing keys on the server.
3. Render all templates with `deploy/scripts/render-templates.sh`.
4. Start PostgreSQL and Synapse with Docker Compose.
5. Install the rendered nginx, coturn, and Element Web configs on Debian 12.
6. Obtain TLS certificates and enable the nginx site.
7. Create the first admin user.
8. Run post-install hardening on the host.
9. Verify Element Web login, encrypted rooms, file uploads, and 1:1 calls over TURN.

## Notes

- This scaffold intentionally excludes federation, Synapse workers, Redis, SSO, and self-hosted group-call infrastructure.
- Element Web is configured for a private deployment and disables custom homeserver URLs by default.
- The Synapse template includes private-server defaults for admin bootstrap, room privacy, profile lookup restrictions, E2EE-by-default for private rooms, and data retention.
- The Synapse template also includes stable password peppering, server notices, and a local auto-join onboarding room.
- Keep generated Synapse keys and the PostgreSQL data directory backed up.
- See `docs/bootstrap-debian12.md` for the exact host bootstrap sequence.
- See `docs/README.md` for the recommended documentation order.
- For near one-command host setup, use `deploy/scripts/first-boot-debian12.sh` on the VPS.
- Run `deploy/scripts/post-install-hardening-debian12.sh` after base bring-up to enable firewall, fail2ban, unattended upgrades, and kernel/network hardening.
- Use `docs/deployment-checklist.md` for the final acceptance pass.
- Use `docs/vps-runbook.md` if you want the exact command order for first deployment.
- Use `docs/quick-runbook.md` if you want the shortest linear command sequence.
- Use `docs/cutover-checklist.md` and `docs/rollback-guide.md` for launch-day control and rollback.
- If GitHub SSH is flaky from Windows, run `pwsh -File deploy/scripts/retry-git-push.ps1` from the repo root.
