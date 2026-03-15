# Debian 12 Bootstrap

This guide applies the files in this repository to a private Matrix deployment on Debian 12 for `golibas.online`.

## What this bootstraps

- Docker Engine and Docker Compose plugin
- `nginx`, `coturn`, `element-web`, `gettext-base`
- local rendering of server config files from `deploy/compose/.env`
- validation of `homeserver.yaml` before the backend is started
- optional non-interactive certbot run when `CERTBOT_EMAIL` is set
- first Synapse config generation
- service startup order for PostgreSQL, Synapse, nginx, coturn, and Element Web

## Fast path

If you want the shortest path, run the bootstrap script from the repository root on the VPS:

```bash
export CERTBOT_EMAIL=admin@golibas.online
bash deploy/scripts/first-boot-debian12.sh
```

If `CERTBOT_EMAIL` is not set, the script installs everything, leaves the HTTP-only nginx bootstrap config in place, and prints the manual certbot command plus the final nginx switch step.

After the base bootstrap finishes, continue with:

```bash
bash deploy/scripts/post-install-hardening-debian12.sh
bash deploy/scripts/create-admin-user.sh
bash deploy/scripts/smoke-test.sh
bash deploy/scripts/send-server-notice.sh
```

## 1. Install host packages

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release gettext-base nginx coturn element-web certbot python3-certbot-nginx
```

Install Docker from the official repository if it is not already present:

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

## 2. Copy this repository to the VPS

Place the repository anywhere convenient, for example:

```bash
sudo mkdir -p /opt/chat
sudo chown "$USER":"$USER" /opt/chat
```

Then upload the repository contents into `/opt/chat`.

## 3. Review deployment variables

The repository already contains a ready `.env` at `deploy/compose/.env`. Review these values before using them on the server:

- `DOMAIN`
- `PUBLIC_BASEURL`
- `SYNAPSE_IMAGE`
- `POSTGRES_PASSWORD`
- `REGISTRATION_SHARED_SECRET`
- `PASSWORD_PEPPER`
- `TURN_SECRET`

The default Synapse template also enables private-server policy defaults for:

- encrypted private rooms by default
- stricter password rules
- private-only room directory behavior
- message retention and media retention
- stricter profile lookup behavior
- server notices and a default local `#general` onboarding room

If you rotate secrets later, update both Synapse and coturn from the same `.env` and rerender templates.

## 4. Generate Synapse base config

Run this once before the main startup so Synapse creates signing keys and baseline files:

```bash
cd /opt/chat/deploy/compose
docker compose --env-file .env run --rm \
  -e SYNAPSE_SERVER_NAME=golibas.online \
  -e SYNAPSE_REPORT_STATS=no \
  synapse generate
```

This writes generated files into `deploy/synapse/`.

## 5. Render repository templates

```bash
cd /opt/chat
bash deploy/scripts/render-templates.sh
```

This creates:

- `deploy/synapse/homeserver.yaml`
- `build/nginx/matrix-http.conf`
- `build/nginx/matrix.conf`
- `build/coturn/turnserver.conf`
- `build/element-web/config.json`

Open `deploy/synapse/homeserver.yaml` and merge in any generated secrets or paths that Synapse added and the template did not cover. Do not delete generated signing-key references.

Validate the rendered config manually if needed:

```bash
cd /opt/chat
bash deploy/scripts/validate-synapse-config.sh
```

## 6. Install rendered configs on the host

```bash
sudo cp /opt/chat/build/nginx/matrix.conf /etc/nginx/sites-available/matrix.conf
sudo ln -sf /etc/nginx/sites-available/matrix.conf /etc/nginx/sites-enabled/matrix.conf
sudo cp /opt/chat/build/coturn/turnserver.conf /etc/turnserver.conf
sudo cp /opt/chat/build/element-web/config.json /etc/element-web/config.json
```

Disable the default nginx site if needed:

```bash
sudo rm -f /etc/nginx/sites-enabled/default
```

Ensure coturn is enabled in its defaults file:

```bash
sudo sed -i 's/^#TURNSERVER_ENABLED=.*/TURNSERVER_ENABLED=1/' /etc/default/coturn
sudo sed -i 's/^TURNSERVER_ENABLED=.*/TURNSERVER_ENABLED=1/' /etc/default/coturn
```

## 7. Obtain TLS

Start nginx with the HTTP-only bootstrap site on port 80, then request the certificate:

```bash
sudo nginx -t
sudo systemctl restart nginx
sudo certbot --nginx -d golibas.online
```

After certbot updates the nginx config or certificates, replace the bootstrap site with the final TLS config and reload nginx again:

```bash
sudo cp /opt/chat/build/nginx/matrix.conf /etc/nginx/sites-available/matrix.conf
sudo nginx -t
sudo systemctl reload nginx
```

## 8. Start the backend services

```bash
cd /opt/chat/deploy/compose
docker compose --env-file .env up -d postgres synapse
sudo systemctl enable --now coturn nginx
```

## 9. Create the first admin user

```bash
cd /opt/chat/deploy/compose
docker compose --env-file .env exec synapse \
  register_new_matrix_user -c /data/homeserver.yaml http://localhost:8008
```

## 10. Validate the deployment

Check these URLs from a browser:

- `https://golibas.online/`
- `https://golibas.online/config.json`
- `https://golibas.online/_matrix/client/versions`

Check service health:

```bash
cd /opt/chat/deploy/compose
docker compose --env-file .env ps
docker compose --env-file .env logs --tail=100 synapse postgres
sudo systemctl status nginx coturn
```

## Operating notes

- Keep `deploy/compose/.env`, `deploy/synapse/*.key`, and PostgreSQL data backups outside the VPS.
- TURN and Synapse must always share the same `TURN_SECRET`.
- `REGISTRATION_SHARED_SECRET` is required for `register_new_matrix_user` and `deploy/scripts/create-admin-user.sh`.
- `PASSWORD_PEPPER` must be treated as stable once users begin logging in.
- This setup is private-only. It does not publish federation metadata and does not open Matrix federation ports.
- Run `deploy/scripts/post-install-hardening-debian12.sh` after the base services are up.
- Use `deploy/scripts/create-admin-user.sh` to create the first local admin without putting the password into repository files.
- Use `deploy/scripts/send-server-notice.sh` to send the first welcome or policy notice to a local user.
- Use `deploy/scripts/switch-nginx-to-tls.sh` after manual certbot issuance if you did not set `CERTBOT_EMAIL` in `.env`.
- Use `deploy/scripts/smoke-test.sh` for the first server-side verification pass.
- Use `docs/deployment-checklist.md` as the final bring-up and smoke-test list.
