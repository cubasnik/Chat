# Quick Runbook

This is the shortest copy-paste path to bring up the private Matrix stack for `golibas.online`.

## 1. Package on Windows

Run in PowerShell on the local machine:

```powershell
Compress-Archive -Path C:\Users\Alexey\Desktop\min\Chat\* -DestinationPath C:\Users\Alexey\Desktop\min\chat-deploy.zip -Force
scp C:\Users\Alexey\Desktop\min\chat-deploy.zip user@YOUR_VPS_IP:/tmp/chat-deploy.zip
```

## 2. Prepare the VPS

Run on Debian 12:

```bash
sudo apt update
sudo apt install -y unzip
sudo mkdir -p /opt/chat
sudo chown "$USER":"$USER" /opt/chat
cd /opt/chat
unzip -o /tmp/chat-deploy.zip
```

## 3. Set required values

Run on the VPS:

```bash
cd /opt/chat
sed -i 's/^CERTBOT_EMAIL=.*/CERTBOT_EMAIL=admin@golibas.online/' deploy/compose/.env
sed -n '1,80p' deploy/compose/.env
```

Confirm these are set and not placeholders:

- `POSTGRES_PASSWORD`
- `REGISTRATION_SHARED_SECRET`
- `PASSWORD_PEPPER`
- `TURN_SECRET`

## 4. Bootstrap the stack

```bash
cd /opt/chat
bash deploy/scripts/first-boot-debian12.sh
```

If you left `CERTBOT_EMAIL` empty, run:

```bash
sudo certbot --nginx -d golibas.online
bash deploy/scripts/switch-nginx-to-tls.sh
```

## 5. Harden the VPS

```bash
cd /opt/chat
bash deploy/scripts/post-install-hardening-debian12.sh
```

## 6. Create the first admin

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

## 7. Validate the server

```bash
cd /opt/chat
bash deploy/scripts/smoke-test.sh
```

## 8. Send the first welcome notice

```bash
cd /opt/chat
export MATRIX_ADMIN_USER=alexey
export MATRIX_ADMIN_PASSWORD='CHANGE_ME_STRONG_PASSWORD'
bash deploy/scripts/send-server-notice.sh '@alexey:golibas.online' 'Welcome to golibas.online Chat. Start in #general and use encrypted direct messages for private conversations.'
```

## 9. Create the first backup

```bash
cd /opt/chat
bash deploy/scripts/backup-state.sh
```

## 10. Final manual checks

- Open `https://golibas.online/`.
- Log in through Element Web.
- Confirm `#general:golibas.online` exists.
- Create a second user and test encrypted DM, image upload, file upload, and 1:1 call.

If anything fails during launch, use `docs/cutover-checklist.md` and `docs/rollback-guide.md`.
