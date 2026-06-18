# AGENTS.md

## Project Rules

- Write all runtime scripts in Bash and keep them compatible with Ubuntu 22.04+ and Debian 12+.
- Every shell script must use `set -Eeuo pipefail`, shared logging helpers, and error traps from `lib/common.sh`.
- Keep generated secrets, real domains, emails, tokens, `.env`, `config.yml`, data directories, SQL dumps, and backups out of Git.
- Do not expose Redis or PostgreSQL ports in Compose.
- Keep API/User/Admin container ports bound to `127.0.0.1`.
- Back up user-owned files before replacing Nginx configuration.
- Avoid destructive actions unless the user requested them and confirmed them twice.
- Prefer shellcheck-friendly Bash over clever one-liners.

## Verification

Before committing:

```bash
bash -n *.sh lib/*.sh
if command -v shellcheck >/dev/null 2>&1; then shellcheck *.sh lib/*.sh; fi
```

Also inspect README command examples whenever script arguments change.
