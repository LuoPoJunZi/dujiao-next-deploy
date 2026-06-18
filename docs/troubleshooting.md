# Troubleshooting

## First Checks

```bash
sudo dujiao-next status
sudo dujiao-next logs api
sudo nginx -t
```

## API Health Fails

Run:

```bash
curl -fsS http://127.0.0.1:8080/health
docker compose --env-file /opt/dujiao-next/.env -f /opt/dujiao-next/docker-compose.postgres.yml ps
```

Check:

- `/opt/dujiao-next/config/config.yml`
- `database.driver`
- `database.dsn`
- Redis password in `.env` and `config.yml`
- PostgreSQL password in `.env` and `config.yml`

## Frontend Loads But API Fails

Confirm Nginx has these routes:

- Frontend `/api/` -> `http://127.0.0.1:8080/api/`
- Frontend `/uploads/` -> `http://127.0.0.1:8080/uploads/`
- Admin `/api/` -> `http://127.0.0.1:8080/api/`
- Admin `/uploads/` -> `http://127.0.0.1:8080/uploads/`

## SEO Files 404

The frontend domain must proxy:

- `/sitemap.xml` -> `http://127.0.0.1:8080/sitemap.xml`
- `/robots.txt` -> `http://127.0.0.1:8080/robots.txt`

## Certbot Fails

Check:

- Both domains resolve to this server.
- Port `80` is reachable.
- Cloudflare proxy is disabled during issuance.
- `sudo nginx -t` passes.

Run:

```bash
sudo certbot certificates
```

## Port Conflict

Check listeners:

```bash
sudo ss -ltnp | grep -E ':80|:443|:8080|:8081|:8082'
```

Ports `8080`, `8081`, and `8082` must be free before install.
