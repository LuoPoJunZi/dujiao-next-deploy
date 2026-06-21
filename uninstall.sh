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

Default behavior:
  - Stop Dujiao-Next containers.
  - Back up and remove the Nginx site config.
  - Remove the local dujiao-next CLI wrapper.
  - Keep deployment data.

Use --purge to delete deployment data after two confirmations.
EOF
}

while (($# > 0)); do
  case "$1" in
    --deploy-dir) DEPLOY_DIR="$(require_arg_value "$1" "${2:-}")"; shift 2 ;;
    --purge) PURGE="yes"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "未知参数：$1" ;;
  esac
done

remove_nginx_site() {
  if [[ ! -e "$DUJIAO_NGINX_CONF" && ! -L "$DUJIAO_NGINX_LINK" ]]; then
    warn "未发现 Dujiao-Next Nginx 站点配置，跳过。"
    return
  fi

  backup_existing_file "$DUJIAO_NGINX_CONF"
  rm -f "$DUJIAO_NGINX_LINK"
  rm -f "$DUJIAO_NGINX_CONF"

  if has_cmd nginx; then
    nginx -t
  fi
  if has_cmd systemctl; then
    systemctl reload nginx
  else
    warn "systemctl 不存在，请手动 reload Nginx。"
  fi
  success "已移除 Nginx 站点配置。"
}

remove_runtime_files() {
  if [[ -e "$DUJIAO_MENU_BIN" || -L "$DUJIAO_MENU_BIN" ]]; then
    rm -f "$DUJIAO_MENU_BIN"
    success "已移除命令入口：$DUJIAO_MENU_BIN"
  fi
  if [[ -d "$DUJIAO_RUNTIME_DIR" ]]; then
    rm -rf --one-file-system "$DUJIAO_RUNTIME_DIR"
    success "已移除运行脚本目录：$DUJIAO_RUNTIME_DIR"
  fi
}

resolve_path() {
  local path="$1"
  if has_cmd realpath; then
    realpath -m "$path"
  else
    printf '%s\n' "$path"
  fi
}

purge_deploy_dir() {
  local resolved_deploy_dir typed_dir resolved_typed_dir
  resolved_deploy_dir="$(resolve_path "$DEPLOY_DIR")"

  warn "--purge 将删除部署目录和其中的数据：$resolved_deploy_dir"
  confirm "再次确认删除全部 Dujiao-Next 数据？" "no" || die "已取消删除数据。"
  read -r -p "请输入完整部署目录以确认删除： " typed_dir
  resolved_typed_dir="$(resolve_path "$typed_dir")"

  [[ "$resolved_typed_dir" == "$resolved_deploy_dir" ]] || die "输入不匹配，已取消删除数据。"
  [[ "$resolved_deploy_dir" == "$DUJIAO_DEPLOY_DIR_DEFAULT" || "$resolved_deploy_dir" == */dujiao-next ]] || die "拒绝删除非 Dujiao-Next 部署目录：$resolved_deploy_dir"
  [[ "$resolved_deploy_dir" != "/" && "$resolved_deploy_dir" != "/opt" && "$resolved_deploy_dir" != "/usr" && "$resolved_deploy_dir" != "/var" ]] || die "拒绝删除系统目录：$resolved_deploy_dir"
  [[ -d "$resolved_deploy_dir" ]] || die "部署目录不存在：$resolved_deploy_dir"

  rm -rf --one-file-system "$resolved_deploy_dir"
  success "已删除部署目录：$resolved_deploy_dir"
}

main() {
  require_root
  warn "卸载会停止 Dujiao-Next 容器，并备份后移除 Nginx 站点配置。"
  [[ "$PURGE" == "no" ]] && warn "默认不会删除部署数据：$DEPLOY_DIR"
  confirm "确认继续卸载？" "no" || die "已取消。"

  if [[ -f "$DEPLOY_DIR/.env" ]]; then
    compose_run "$DEPLOY_DIR" down --remove-orphans
  else
    warn "找不到 $DEPLOY_DIR/.env，跳过容器停止。"
  fi

  remove_nginx_site
  remove_runtime_files

  if [[ "$PURGE" == "yes" ]]; then
    purge_deploy_dir
  else
    success "已停止服务并保留数据目录：$DEPLOY_DIR"
  fi
}

main "$@"
