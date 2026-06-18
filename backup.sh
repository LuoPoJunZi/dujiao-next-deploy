#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
setup_error_trap

DEPLOY_DIR="$DUJIAO_DEPLOY_DIR_DEFAULT"

usage() {
  cat <<'EOF'
Usage: sudo ./backup.sh [--deploy-dir DIR]
EOF
}

while (($# > 0)); do
  case "$1" in
    --deploy-dir) DEPLOY_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "未知参数：$1" ;;
  esac
done

main() {
  require_root
  require_cmds docker tar awk sed grep
  [[ -d "$DEPLOY_DIR" ]] || die "部署目录不存在：$DEPLOY_DIR"
  [[ -f "$DEPLOY_DIR/.env" ]] || die "找不到 $DEPLOY_DIR/.env"
  load_env_file "$DEPLOY_DIR/.env"
  local backup_root backup_name tmp_dir profile compose_file
  if [[ -d "$DEPLOY_DIR/backups" && -w "$DEPLOY_DIR/backups" ]]; then
    backup_root="$DEPLOY_DIR/backups"
  else
    backup_root="/root/dujiao-next-backups"
    mkdir -p "$backup_root"
  fi
  profile="$(cat "$DEPLOY_DIR/.deployment-profile" 2>/dev/null || printf '%s' postgres)"
  compose_file="$(compose_profile_file "$DEPLOY_DIR")"
  backup_name="dujiao-next-${profile}-$(timestamp)"
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT
  mkdir -p "$tmp_dir/$backup_name"

  cp -a "$DEPLOY_DIR/.env" "$tmp_dir/$backup_name/.env"
  cp -a "$DEPLOY_DIR/config/config.yml" "$tmp_dir/$backup_name/config.yml"
  cp -a "$DEPLOY_DIR/$compose_file" "$tmp_dir/$backup_name/$compose_file"
  if [[ -d "$DEPLOY_DIR/data/uploads" ]]; then
    mkdir -p "$tmp_dir/$backup_name/data"
    cp -a "$DEPLOY_DIR/data/uploads" "$tmp_dir/$backup_name/data/uploads"
  fi

  if [[ "$profile" == "sqlite" ]]; then
    if [[ -d "$DEPLOY_DIR/data/db" ]]; then
      mkdir -p "$tmp_dir/$backup_name/data"
      cp -a "$DEPLOY_DIR/data/db" "$tmp_dir/$backup_name/data/db"
    fi
  else
    docker exec dujiaonext-postgres pg_dump -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" >"$tmp_dir/$backup_name/postgres.sql"
  fi

  tar -C "$tmp_dir" -czf "$backup_root/${backup_name}.tar.gz" "$backup_name"
  chmod 0600 "$backup_root/${backup_name}.tar.gz"
  success "备份完成：$backup_root/${backup_name}.tar.gz"
}

main "$@"
