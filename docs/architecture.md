# Architecture

`dujiao-next-deploy` installs Dujiao-Next behind Nginx on a single Ubuntu/Debian server.

```text
Internet
   |
   v
Nginx :80/:443
   |
   +--> frontend domain /          -> 127.0.0.1:8081
   +--> frontend domain /api/      -> 127.0.0.1:8080/api/
   +--> frontend domain /uploads/  -> 127.0.0.1:8080/uploads/
   +--> frontend domain /sitemap.xml -> 127.0.0.1:8080/sitemap.xml
   +--> frontend domain /robots.txt  -> 127.0.0.1:8080/robots.txt
   |
   +--> admin domain /             -> 127.0.0.1:8082
   +--> admin domain /api/         -> 127.0.0.1:8080/api/
   +--> admin domain /uploads/     -> 127.0.0.1:8080/uploads/
```

Docker services:

- `dujiaonext-api`: API service, image `dujiaonext/api:${TAG}`
- `dujiaonext-user`: user frontend, image `dujiaonext/user:${TAG}`
- `dujiaonext-admin`: admin frontend, image `dujiaonext/admin:${TAG}`
- `dujiaonext-redis`: Redis cache and queue backend
- `dujiaonext-postgres`: PostgreSQL database for the production profile

The default profile is PostgreSQL + Redis. SQLite + Redis is available as an advanced profile and keeps a reserved `data/db` directory.

Data lives under `/opt/dujiao-next` by default:

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
