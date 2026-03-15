# Deployment Checklist

Use this checklist after copying the repository to the VPS.

## Preflight

- `golibas.online` resolves to the VPS public IP.
- Debian 12 host access works over the intended SSH port.
- Ports `80/tcp`, `443/tcp`, `3478/tcp`, `3478/udp`, and `49152-65535/udp` are allowed by the VPS provider.
- `deploy/compose/.env` values were reviewed, especially `POSTGRES_PASSWORD`, `REGISTRATION_SHARED_SECRET`, `PASSWORD_PEPPER`, `TURN_SECRET`, `CERTBOT_EMAIL`, and `SSH_PORT`.
- A backup destination exists for `.env`, Synapse keys, and PostgreSQL data.

## Bring-up

- Run `bash deploy/scripts/first-boot-debian12.sh` from the repository root on the VPS.
- If `CERTBOT_EMAIL` was empty, run `sudo certbot --nginx -d golibas.online` and then `bash deploy/scripts/switch-nginx-to-tls.sh`.
- Verify `docker compose --env-file .env ps` shows `postgres` and `synapse` as running.
- Run `bash deploy/scripts/post-install-hardening-debian12.sh`.
- Create the first admin user with `bash deploy/scripts/create-admin-user.sh`.
- Run `bash deploy/scripts/smoke-test.sh`.

## Smoke Test

- Open `https://golibas.online/` and confirm Element Web loads.
- Open `https://golibas.online/config.json` and confirm the homeserver URL is `https://golibas.online/` or `https://golibas.online`.
- Open `https://golibas.online/_matrix/client/versions` and confirm Synapse responds with JSON.
- Log in with the admin account.
- Confirm the local onboarding room appears for newly registered users.
- Create an encrypted direct message room with a second account.
- Send a text message in both directions.
- Upload a file and an image.
- Start a 1:1 voice call and confirm TURN relay works from a different network if possible.

## Post-Deploy Checks

- `sudo nginx -t` succeeds.
- `sudo systemctl status nginx coturn fail2ban` shows active services.
- `sudo ufw status verbose` matches the expected open ports.
- `sudo fail2ban-client status` shows active jails.
- `docker compose --env-file .env logs --tail=100 synapse postgres` contains no recurring startup errors.

## Ongoing Ops

- Back up `deploy/compose/.env`, `deploy/synapse/*.key`, and PostgreSQL data after the first successful login.
- Rotate `TURN_SECRET` only by updating both coturn and Synapse together, then rerendering configs.
- Re-run the smoke test after package upgrades, Synapse image upgrades, or TLS renewal changes.
