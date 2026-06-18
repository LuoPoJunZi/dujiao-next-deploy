# Commands

## Install

Interactive:

```bash
sudo ./install.sh
```

Non-interactive:

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

## Menu

```bash
sudo dujiao-next
```

## Upgrade

```bash
sudo ./update.sh
sudo ./update.sh v1.2.3
sudo dujiao-next upgrade v1.2.3
```

## Backup

```bash
sudo ./backup.sh
sudo dujiao-next backup
```

## Status

```bash
sudo ./status.sh
sudo dujiao-next status
```

## Logs

```bash
sudo dujiao-next logs api
sudo dujiao-next logs user
sudo dujiao-next logs admin
sudo dujiao-next logs redis
sudo dujiao-next logs postgres
```

## Restart

```bash
sudo dujiao-next restart
```

## Restore Guidance

```bash
sudo dujiao-next restore-help
```

## Uninstall

Stop services and keep data:

```bash
sudo ./uninstall.sh
```

Stop services and delete data after two confirmations:

```bash
sudo ./uninstall.sh --purge
```
