# Installation

## DNS and HTTPS Prerequisites

Production deployment is expected to use HTTPS. Before running the installer, create two A records in Cloudflare or your DNS provider:

- Frontend domain, for example `shop.example.com` -> this server public IP
- Admin domain, for example `admin.example.com` -> this server public IP

If you use the Cloudflare proxy, switch the records to DNS-only mode while Certbot requests the certificate. After certificate issuance succeeds, you can enable the proxy again if needed.

The installer first collects domains, email, deployment directory, image tag and other choices, then automatically installs Docker, Nginx and Certbot, writes configuration, starts containers, and performs health checks.

## Interactive Install

```bash
sudo ./install.sh
```

The installer asks for:

- Frontend domain
- Admin domain
- Admin username, default `admin`
- Deployment directory, default `/opt/dujiao-next`
- Dujiao-Next image tag
- Database profile
- Whether to request HTTPS, recommended for production
- ACME email if HTTPS is enabled
- Whether to handle host firewall rules
- Whether to remove old Docker conflict packages

The production default is PostgreSQL + Redis.
Interactive mode prints a final summary before making system changes.

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

Use `--no-https` only for temporary private-network or debugging installs.

## Generated Credentials

The installer writes generated values to `/opt/dujiao-next/.env`.

Important fields:

- `DJ_DEFAULT_ADMIN_USERNAME`
- `DJ_DEFAULT_ADMIN_PASSWORD`
- `REDIS_PASSWORD`
- `POSTGRES_PASSWORD`

The default admin account is only used during the first API initialization. Log in once and change the password immediately.

## DNS

Before enabling HTTPS, point both domains to the server public IP. If you use Cloudflare or another proxy CDN, use DNS-only mode until Certbot succeeds.
