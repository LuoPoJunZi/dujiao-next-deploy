# Operations

Run the menu:

```bash
sudo dujiao-next
```

Useful direct commands:

```bash
sudo dujiao-next status
sudo dujiao-next logs api
sudo dujiao-next upgrade latest
sudo dujiao-next backup
sudo dujiao-next restore-help
sudo dujiao-next uninstall
```

## Upgrade

```bash
sudo dujiao-next upgrade v1.2.3
```

This updates `TAG` in `/opt/dujiao-next/.env`, pulls images, recreates containers, and runs health checks.
The updater creates a backup before changing `TAG` or pulling new images.

## Backup

```bash
sudo dujiao-next backup
```

Backups are written to `/opt/dujiao-next/backups`.

For PostgreSQL deployments, the backup includes:

- `.env`
- `config/config.yml`
- `.deployment-profile`
- Docker Compose files
- uploaded files
- PostgreSQL dump created with `pg_dump`

For SQLite deployments, the backup includes `data/db` instead of a PostgreSQL dump.

## Restore

The project prints restore guidance rather than running destructive restore automatically. Restores replace databases and uploaded assets, so review the generated backup first.
