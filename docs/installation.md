# Installation

## Interactive Install

```bash
sudo ./install.sh
```

The installer asks for:

- Frontend domain
- Admin domain
- ACME email if HTTPS is enabled
- Dujiao-Next image tag
- Time zone
- Database profile

The production default is PostgreSQL + Redis.

## Non-interactive Install

```bash
sudo ./install.sh \
  --user-domain shop.example.com \
  --admin-domain admin.example.com \
  --email admin@example.com \
  --tag latest \
  --profile postgres \
  --yes \
  --https
```

Use `--no-https` to skip Certbot.

## Generated Credentials

The installer writes generated values to `/opt/dujiao-next/.env`.

Important fields:

- `DJ_DEFAULT_ADMIN_USERNAME`
- `DJ_DEFAULT_ADMIN_PASSWORD`
- `REDIS_PASSWORD`
- `POSTGRES_PASSWORD`

The default admin account is only used during the first API initialization. Log in once and change the password immediately.

## DNS

Before enabling HTTPS, point both domains to the server.

If you use a proxy CDN, use DNS-only mode until Certbot succeeds.
