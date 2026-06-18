# dujiao-next-deploy

`dujiao-next-deploy` is an unofficial Bash deployment toolkit for Dujiao-Next on Ubuntu/Debian servers.

It installs Docker Engine, Docker Compose, Nginx and optional Certbot HTTPS, then deploys Dujiao-Next with a production PostgreSQL + Redis profile by default.

This project is not an official Dujiao-Next project. Dujiao-Next belongs to its original authors and maintainers.

## Supported Systems

- Ubuntu 22.04+
- Debian 12+

Run as `root` or with `sudo`.

## Quick Start

```bash
git clone https://github.com/<USER>/dujiao-next-deploy.git
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

Skip HTTPS:

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
- Whether to request HTTPS
- Certbot email
- Whether to handle `ufw` firewall rules

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

## Status And Logs

```bash
sudo ./status.sh
sudo dujiao-next status
sudo dujiao-next logs api
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

Check that both domains resolve to the server. If you use Cloudflare, switch to DNS-only mode during certificate issuance.

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
- Deployment record by luopojunzi: https://blog.luopojunzi.com/p/Dujiao-Next/

This repository is an independent implementation and does not copy or fork `slobys/dujiao-next-one-click`.
