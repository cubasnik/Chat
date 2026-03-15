# Cutover Checklist

Use this on the actual launch day for `golibas.online`.

## Before DNS or public announcement

- Confirm the VPS provider firewall allows `80/tcp`, `443/tcp`, `3478/tcp`, `3478/udp`, and `49152-65535/udp`.
- Confirm `deploy/compose/.env` contains the final `POSTGRES_PASSWORD`, `TURN_SECRET`, `CERTBOT_EMAIL`, and `SSH_PORT`.
- Run `bash deploy/scripts/backup-state.sh` after the first successful bootstrap and store the artifacts off-host.
- Verify `bash deploy/scripts/smoke-test.sh` succeeds.
- Verify Element Web login works with the first admin user.
- Verify encrypted DM, file upload, and at least one 1:1 call.

## Cutover window

- Point `golibas.online` DNS to the VPS public IP if not already done.
- Wait for DNS propagation from a second network.
- Run `curl -I https://golibas.online/` and confirm `200` or `304`.
- Run `curl -fsSL https://golibas.online/_matrix/client/versions` and confirm Synapse responds.
- Confirm `sudo systemctl status nginx coturn fail2ban` is healthy.
- Confirm `docker compose --env-file .env ps` shows `postgres` and `synapse` up.

## Immediately after cutover

- Log in from Element Web.
- Log in from one mobile client.
- Create a second local account if needed and verify messaging in both directions.
- Verify one image upload and one file download.
- Verify one call from a different network if possible.
- Run `bash deploy/scripts/backup-state.sh` again after the first successful post-cutover login.

## Abort conditions

- TLS certificate issuance fails and `https://golibas.online/` is unavailable.
- `/_matrix/client/versions` fails or returns gateway errors.
- Synapse cannot start cleanly after bootstrap.
- Admin login fails on a known-good password.
- File upload or basic messaging is broken after cutover.

## If abort is needed

- Stop public rollout.
- Revert DNS if it was changed during the cutover window.
- Follow `docs/rollback-guide.md`.
