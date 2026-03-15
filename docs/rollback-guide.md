# Rollback Guide

Use this if the first public launch fails and you need to stabilize fast.

## 1. Contain the change

- Stop announcing the service publicly.
- If DNS was changed during cutover, revert `golibas.online` to the previous IP or maintenance endpoint.
- Keep SSH access open and do not enable new firewall rules until you confirm current access.

## 2. Capture evidence before changing more

```bash
cd /opt/chat/deploy/compose
docker compose --env-file .env ps
docker compose --env-file .env logs --tail=200 synapse postgres
sudo journalctl -u nginx -u coturn --since "30 minutes ago" --no-pager
```

## 3. Restore the last known-good state

If you created backups with `deploy/scripts/backup-state.sh`, restore from the latest artifacts.

Restore config and keys:

```bash
cd /opt/chat
tar -xzf /path/to/chat-backup-YYYYMMDD-HHMMSS-config.tgz
```

Restore PostgreSQL from dump:

```bash
cd /opt/chat/deploy/compose
gunzip -c /path/to/chat-backup-YYYYMMDD-HHMMSS-postgres.sql.gz | \
docker compose --env-file .env exec -T postgres psql -U synapse_user -d synapse
```

Then rerender and restart services:

```bash
cd /opt/chat
bash deploy/scripts/render-templates.sh
cd /opt/chat/deploy/compose
docker compose --env-file .env up -d postgres synapse
sudo nginx -t && sudo systemctl restart nginx
sudo systemctl restart coturn
```

## 4. Verify minimum service health

```bash
cd /opt/chat
bash deploy/scripts/smoke-test.sh
```

Confirm:

- `https://golibas.online/_matrix/client/versions` responds.
- Element Web loads.
- The admin account can log in.

## 5. Decide the next move

- If the rollback restored service, freeze changes and investigate offline.
- If the rollback did not restore service, keep DNS pointed away from the VPS and continue debugging privately.
