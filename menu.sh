#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
setup_error_trap

DEPLOY_DIR="${DEPLOY_DIR:-$DUJIAO_DEPLOY_DIR_DEFAULT}"

show_menu() {
  cat <<'EOF'
Dujiao-Next 管理菜单

1) 安装
2) 升级
3) 备份
4) 查看状态
5) 查看日志
6) 重启服务
7) 检查更新
8) 恢复提示
9) 卸载
0) 退出
EOF
}

restore_help() {
  cat <<EOF
恢复需要人工确认备份内容后执行，脚本不会自动覆盖数据库和上传文件。

备份目录通常在：
  $DEPLOY_DIR/backups
  /root/dujiao-next-backups

建议流程：
  1. sudo dujiao-next backup
  2. tar -tzf <backup-file>.tar.gz
  3. 停止服务：cd "$DEPLOY_DIR" && docker compose --env-file .env -f $(compose_profile_file "$DEPLOY_DIR") down
  4. 还原 .env、config.yml、data/uploads
  5. PostgreSQL 使用备份中的 postgres.sql 经 psql 导入
  6. 启动服务并检查：sudo dujiao-next status
EOF
}

show_logs() {
  local service="${1:-}"
  if [[ -z "$service" ]]; then
    read -r -p "服务名 api/user/admin/redis/postgres [api]: " service
    service="${service:-api}"
  fi
  compose_run "$DEPLOY_DIR" logs --tail=100 -f "$service"
}

restart_services() {
  compose_run "$DEPLOY_DIR" restart
  wait_for_http "http://127.0.0.1:8080/health" "API health" 60 3 || warn "重启后 API health 未通过。"
}

dispatch_command() {
  local cmd="${1:-menu}"
  shift || true
  case "$cmd" in
    install) "$SCRIPT_DIR/install.sh" "$@" ;;
    update|upgrade) "$SCRIPT_DIR/update.sh" "$@" ;;
    backup) "$SCRIPT_DIR/backup.sh" "$@" ;;
    check-updates|version) "$SCRIPT_DIR/check-updates.sh" "$@" ;;
    status) "$SCRIPT_DIR/status.sh" "$@" ;;
    logs) show_logs "${1:-}" ;;
    restart) restart_services ;;
    restore-help) restore_help ;;
    uninstall) "$SCRIPT_DIR/uninstall.sh" "$@" ;;
    menu) interactive_menu ;;
    -h|--help)
      log "Usage: sudo dujiao-next [install|upgrade|backup|check-updates|status|logs|restart|restore-help|uninstall]"
      ;;
    *) die "未知命令：$cmd" ;;
  esac
}

interactive_menu() {
  require_root
  while true; do
    show_menu
    read -r -p "请选择: " choice
    case "$choice" in
      1) "$SCRIPT_DIR/install.sh" ;;
      2) "$SCRIPT_DIR/update.sh" ;;
      3) "$SCRIPT_DIR/backup.sh" ;;
      4) "$SCRIPT_DIR/status.sh" ;;
      5) show_logs ;;
      6) restart_services ;;
      7) "$SCRIPT_DIR/check-updates.sh" ;;
      8) restore_help ;;
      9) "$SCRIPT_DIR/uninstall.sh" ;;
      0) exit 0 ;;
      *) warn "无效选择。" ;;
    esac
  done
}

dispatch_command "${1:-menu}" "${@:2}"
