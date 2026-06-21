<div align="center">

# dujiao-next-deploy

**A safer one-command deployment toolkit for Dujiao-Next**

English | [中文](README.md)

[![Shellcheck](https://github.com/LuoPoJunZi/dujiao-next-deploy/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/LuoPoJunZi/dujiao-next-deploy/actions/workflows/shellcheck.yml)
![Ubuntu 22.04+](https://img.shields.io/badge/Ubuntu-22.04%2B-E95420?logo=ubuntu&logoColor=white)
![Debian 12+](https://img.shields.io/badge/Debian-12%2B-A81D33?logo=debian&logoColor=white)
![Bash](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnubash&logoColor=white)

</div>

## Overview

`dujiao-next-deploy` is an unofficial Bash deployment toolkit for Dujiao-Next on Ubuntu/Debian servers. It is designed for fresh public HTTPS deployments.

The installer collects domains, email, deployment directory, and image tag first, then automatically installs Docker Engine, Docker Compose, Nginx and Certbot, generates configuration, and starts services. The default profile is PostgreSQL + Redis for production, with SQLite + Redis also supported.

This project is not an official Dujiao-Next project. Dujiao-Next belongs to its original authors and maintainers.

| Capability | Details |
| --- | --- |
| Automated setup | Installs Docker, Compose, Nginx and Certbot, then writes system configuration |
| HTTPS certificates | Requests Certbot certificates and documents the Cloudflare/DNS-only flow |
| Secure defaults | Redis/PostgreSQL are not published; app ports bind to `127.0.0.1` only |
| Maintenance | Includes backup, update, status, version check, and data-preserving uninstall scripts |

## Supported Systems

- Ubuntu 22.04+
- Debian 12+

Run as `root` or with `sudo`.

## Before You Start

Production deployment is expected to use HTTPS. Before running the installer, create two A records in Cloudflare or your DNS provider:

- Frontend domain, for example `shop.example.com` -> this server public IP
- Admin domain, for example `admin.example.com` -> this server public IP

If you use the Cloudflare proxy, switch the records to DNS-only mode during Certbot issuance. After the certificate succeeds, you can enable the proxy if your setup needs it.

The installer first collects domains, email, deployment directory, image tag and other choices, then automatically installs Docker, Nginx and Certbot, generates configuration, and starts services.

## Quick Start

```bash
git clone https://github.com/LuoPoJunZi/dujiao-next-deploy.git
cd dujiao-next-deploy
sudo ./install.sh
```

After installation:

```bash
sudo dujiao-next
```

## One-command Install

```bash
sudo ./install.sh \
  --user-domain shop.example.com \
  --admin-domain admin.example.com \
  --email me@example.com \
  --tag latest \
  --yes \
  --https
```

Temporarily skip HTTPS, for private-network or debugging use only:

```bash
sudo ./install.sh \
  --user-domain shop.example.com \
  --admin-domain admin.example.com \
  --tag latest \
  --yes \
  --no-https
```

## Interactive Install

```bash
sudo ./install.sh
```

The installer asks for:

- Frontend domain
- Admin domain
- Admin username, default `admin`
- Image tag, default GitHub latest release; fallback `latest`
- Deployment directory, default `/opt/dujiao-next`
- Deployment profile `postgres|sqlite`
- Whether to request HTTPS, recommended for production
- Certbot email
- Whether to handle host firewall rules
- Whether to remove old Docker conflict packages

Before changing the system, the installer prints a summary and asks for one final confirmation in interactive mode.

The admin password is generated with `openssl rand` and printed once at the end of installation. Save it immediately and change it after first login.

## Non-interactive Options

```text
--user-domain DOMAIN
--admin-domain DOMAIN
--admin-user USER
--email EMAIL
--tag TAG
--deploy-dir DIR
--profile postgres|sqlite
--https
--no-https
--firewall yes|no
--remove-old-docker yes|no
--renew-check
--yes
```

## Directory Structure

Repository:

```text
.
├── install.sh
├── update.sh
├── backup.sh
├── check-updates.sh
├── status.sh
├── uninstall.sh
├── menu.sh
├── lib/common.sh
├── templates/
├── docs/
└── .github/workflows/shellcheck.yml
```

Server deployment:

```text
/opt/dujiao-next
├── config/config.yml
├── data/db
├── data/uploads
├── data/logs
├── data/redis
├── data/postgres
├── backups
├── docker-compose.postgres.yml
├── docker-compose.sqlite.yml
└── .env
```

## Ports

Public:

- Nginx: `80`, `443`

Loopback only:

- API: `127.0.0.1:8080:8080`
- User frontend: `127.0.0.1:8081:80`
- Admin frontend: `127.0.0.1:8082:80`

Not published:

- Redis `6379`
- PostgreSQL `5432`

## Nginx Routing

Frontend domain:

- `/` -> `http://127.0.0.1:8081`
- `/api/` -> `http://127.0.0.1:8080/api/`
- `/uploads/` -> `http://127.0.0.1:8080/uploads/`
- `/sitemap.xml` -> `http://127.0.0.1:8080/sitemap.xml`
- `/robots.txt` -> `http://127.0.0.1:8080/robots.txt`

Admin domain:

- `/` -> `http://127.0.0.1:8082`
- `/api/` -> `http://127.0.0.1:8080/api/`
- `/uploads/` -> `http://127.0.0.1:8080/uploads/`

## Security Notes

- `.env` permissions are set to `0600`.
- Generated secrets use `openssl rand` or `/dev/urandom`.
- Existing Nginx config with the same name is backed up before replacement.
- Existing deployments are not overwritten in non-interactive mode.
- Uninstall keeps data by default; `--purge` requires two confirmations and typing the deployment path.
- Runtime `config/config.yml` is written with `0600` permissions because it contains generated JWT, Redis, and PostgreSQL secrets.
- Writable mode `0777` is limited to the official bind-mounted data directories (`data/db`, `data/uploads`, `data/logs`, `data/redis`, `data/postgres`) so containers with unknown runtime UIDs can write there. The installer does not recursively chmod existing files.

## Backup

```bash
sudo ./backup.sh
sudo dujiao-next backup
```

Backups go to `/opt/dujiao-next/backups` when writable, otherwise `/root/dujiao-next-backups`.

Each backup includes `.env`, `config.yml`, `.deployment-profile`, existing Compose files, and `data/uploads` when present.

The PostgreSQL profile also uses:

```bash
docker exec dujiaonext-postgres pg_dump -U ${POSTGRES_USER} -d ${POSTGRES_DB}
```

## Upgrade

```bash
sudo ./update.sh
sudo ./update.sh v1.2.3
sudo dujiao-next upgrade v1.2.3
```

Without a tag, the updater fetches the latest GitHub release and falls back to `latest`.

## Version Check

```bash
./check-updates.sh
sudo dujiao-next check-updates
```

The checker compares the deployed `TAG` with the latest GitHub release and prints the upgrade command when a newer tag is available.

## Status And Logs

```bash
sudo ./status.sh
sudo dujiao-next status
sudo dujiao-next logs api
sudo dujiao-next check-updates
sudo dujiao-next restore-help
```

## Uninstall

Stop containers and keep data:

```bash
sudo ./uninstall.sh
```

Delete data after explicit confirmations:

```bash
sudo ./uninstall.sh --purge
```

## FAQ

### Certbot failed

Check that both domains have A records in Cloudflare or your DNS provider and resolve to the server public IP. If you use the Cloudflare proxy, switch to DNS-only mode during certificate issuance.

### API health check failed

Run:

```bash
sudo dujiao-next status
sudo dujiao-next logs api
```

Then check `/opt/dujiao-next/config/config.yml` and `/opt/dujiao-next/.env`.

### I already have a deployment

Interactive install offers upgrade, backup, or exit. Non-interactive install exits to avoid damaging existing data.

## Documentation

- [Architecture](docs/architecture.md)
- [Commands](docs/commands.md)
- [Security](docs/security.md)
- [Troubleshooting](docs/troubleshooting.md)

## References

- Official Dujiao-Next Docker Compose documentation: https://dujiao-next.com/deploy/docker-compose
