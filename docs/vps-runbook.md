# VPS Runbook

This is the exact operator flow for a fresh Debian 12 VPS for `golibas.online`.

## 1. Copy the repository to the VPS

From the local machine, package the current workspace and upload it:

```powershell
Compress-Archive -Path C:\Users\Alexey\Desktop\min\Chat\* -DestinationPath C:\Users\Alexey\Desktop\min\chat-deploy.zip -Force
scp C:\Users\Alexey\Desktop\min\chat-deploy.zip user@YOUR_VPS_IP:/tmp/chat-deploy.zip
```

On the VPS:

```bash
sudo apt update
sudo apt install -y unzip
sudo mkdir -p /opt/chat
sudo chown "$USER":"$USER" /opt/chat
cd /opt/chat
unzip /tmp/chat-deploy.zip
```

## 2. Review deployment values

```bash
cd /opt/chat
sed -n '1,200p' deploy/compose/.env
```

At minimum, verify these values are final and not placeholders:

- `POSTGRES_PASSWORD`
- `REGISTRATION_SHARED_SECRET`
- `PASSWORD_PEPPER`
- `TURN_SECRET`
- retention values such as `MESSAGE_RETENTION_MAX` and `REMOTE_MEDIA_RETENTION`

Set your email for certbot before bootstrap:

```bash
sed -i 's/^CERTBOT_EMAIL=.*/CERTBOT_EMAIL=admin@golibas.online/' deploy/compose/.env
```

Optional: if SSH is not on port `22`, set it before hardening:

```bash
sed -i 's/^SSH_PORT=.*/SSH_PORT=22/' deploy/compose/.env
```

## 3. Bootstrap the host and services

```bash
cd /opt/chat
bash deploy/scripts/first-boot-debian12.sh
```

If you intentionally left `CERTBOT_EMAIL` empty, do the TLS step manually:

```bash
sudo certbot --nginx -d golibas.online
bash deploy/scripts/switch-nginx-to-tls.sh
```

## 4. Harden the VPS

```bash
cd /opt/chat
bash deploy/scripts/post-install-hardening-debian12.sh
```

## 5. Create the first Matrix admin

Interactive mode:

```bash
cd /opt/chat
bash deploy/scripts/create-admin-user.sh
```

Non-interactive mode:

```bash
cd /opt/chat
export MATRIX_ADMIN_USER=alexey
export MATRIX_ADMIN_PASSWORD='CHANGE_ME_STRONG_PASSWORD'
bash deploy/scripts/create-admin-user.sh
```

## 6. Run the smoke test

```bash
cd /opt/chat
bash deploy/scripts/smoke-test.sh
```

Optional: send a welcome notice to a local user:

```bash
cd /opt/chat
export MATRIX_ADMIN_USER=alexey
export MATRIX_ADMIN_PASSWORD='CHANGE_ME_STRONG_PASSWORD'
bash deploy/scripts/send-server-notice.sh '@alexey:golibas.online' 'Welcome to golibas.online Chat. Use #general for onboarding and direct messages for private conversations.'
```

Then finish the manual checks from `docs/deployment-checklist.md`:

- Login through Element Web.
- Create an encrypted DM with a second account.
- Exchange messages in both directions.
- Upload an image and a file.
- Test a 1:1 voice call from a different network if possible.

## 7. Back up critical state

```bash
cd /opt/chat
bash deploy/scripts/backup-state.sh
```

This creates a config archive and a PostgreSQL dump. Copy both artifacts off-host.

## 8. Launch-day controls

Before public rollout, use:

- `docs/cutover-checklist.md`
- `docs/rollback-guide.md`
