# Security

## Network Boundary

Nginx is the only public entry point. It listens on `80` and `443`.

Dujiao-Next containers bind only to loopback:

- API: `127.0.0.1:${API_PORT}:8080`
- User: `127.0.0.1:${USER_PORT}:80`
- Admin: `127.0.0.1:${ADMIN_PORT}:80`

Redis and PostgreSQL do not define `ports`, so Docker does not publish them to the host network.

## Host Firewall

When requested, the installer can add allow rules for `22`, `80`, and `443` on `ufw`, or `ssh`, `http`, and `https` services on `firewalld`.
For active `nftables` or existing `iptables` environments, it prints manual guidance instead of rewriting existing policies.

## Secrets

The installer generates secrets with `openssl rand`. If OpenSSL is unavailable in a later helper context, `/dev/urandom` is used.

Generated values include:

- Admin bootstrap password
- Redis password
- PostgreSQL password
- `jwt.secret`
- `user_jwt.secret`

The `.env` file is written with `0600` permissions.
The runtime `config/config.yml` file is also written with `0600` permissions because it contains generated JWT secrets and service credentials.

## Existing Files

Before replacing `/etc/nginx/sites-available/dujiao-next.conf`, the installer creates a timestamped `.bak-YYYYmmdd-HHMMSS` copy.

Existing deployments are detected before installation. Non-interactive installation exits rather than overwriting data.
The installer treats existing `.env`, Compose files, `config/config.yml`, `data/`, or `backups/` under the deployment directory as an existing deployment.

Only these bind-mounted data directories are made world-writable for container UID compatibility:

- `data/db`
- `data/uploads`
- `data/logs`
- `data/redis`
- `data/postgres`

The permission change is not recursive, so existing user files are not widened.

## Dangerous Operations

`uninstall.sh` keeps data by default.

`uninstall.sh --purge` requires:

- Confirmation to uninstall
- Confirmation to delete all data
- Typing the full deployment path

Only then does it delete the deployment directory.
