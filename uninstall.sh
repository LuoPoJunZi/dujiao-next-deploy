#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
setup_error_trap

DEPLOY_DIR="$DUJIAO_DEPLOY_DIR_DEFAULT"
PURGE="no"

usage() {
  cat <<'EOF'
Usage: sudo ./uninstall.sh [--deploy-dir DIR] [--purge]

Default behavior stops containers and backs up/removes the Nginx site config.
Use --purge to delete deployment data after two confirmations.
EOF
}

while (($# > 0)); do
  case "$1" in
    --deploy-dir) DEPLOY_DIR="${2:-}"; shift 2 ;;
    --purge) PURGE="yes"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "未知参数：$1" ;;
  esac
done

main() {
  require_root
  warn "卸载会停止 Dujiao-Next 容器，并备份后移除 Nginx 站点配置。"
  confirm "确认继续卸载？" "no" || die "已取消。"
  if [[ -f "$DEPLOY_DIR/.env" ]]; then
    compose_run "$DEPLOY_DIR" down || warn "停止容器失败，请手动检查。"
  fi

  if [[ -e "$DUJIAO_NGINX_CONF" || -L "$DUJIAO_NGINX_LINK" ]]; then
    backup_existing_file "$DUJIAO_NGINX_CONF"
    rm -f "$DUJIAO_NGINX_LINK"
    rm -f "$DUJIAO_NGINX_CONF"
    nginx -t && systemctl reload nginx || warn "Nginx reload 失败，请执行 nginx -t 排查。"
  fi

  if [[ "$PURGE" == "yes" ]]; then
    warn "--purge 将删除部署目录和其中的数据：$DEPLOY_DIR"
    confirm "再次确认删除全部 Dujiao-Next 数据？" "no" || die "已取消删除数据。"
    read -r -p "请输入完整部署目录以确认删除： " typed_dir
    [[ "$typed_dir" == "$DEPLOY_DIR" ]] || die "输入不匹配，已取消删除数据。"
    rm -rf --one-file-system "$DEPLOY_DIR"
    success "已删除部署目录：$DEPLOY_DIR"
  else
    success "已停止服务并保留数据目录：$DEPLOY_DIR"
  fi
}

main "$@"
