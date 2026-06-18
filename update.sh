#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
setup_error_trap

DEPLOY_DIR="$DUJIAO_DEPLOY_DIR_DEFAULT"
TARGET_TAG=""

usage() {
  cat <<'EOF'
Usage: sudo ./update.sh [tag] [--deploy-dir DIR]

Examples:
  sudo ./update.sh
  sudo ./update.sh v1.2.3
EOF
}

args=()
while (($# > 0)); do
  case "$1" in
    --deploy-dir) DEPLOY_DIR="$(require_arg_value "$1" "${2:-}")"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) args+=("$1"); shift ;;
  esac
done
if ((${#args[@]} > 0)); then
  TARGET_TAG="${args[0]}"
fi

main() {
  require_root
  require_cmds curl docker awk sed grep
  [[ -d "$DEPLOY_DIR" ]] || die "部署目录不存在：$DEPLOY_DIR"
  [[ -f "$DEPLOY_DIR/.env" ]] || die "找不到 $DEPLOY_DIR/.env"
  [[ -n "$TARGET_TAG" ]] || TARGET_TAG="$(get_latest_tag)"
  "$SCRIPT_DIR/backup.sh" --deploy-dir "$DEPLOY_DIR"
  replace_env_key "$DEPLOY_DIR/.env" "TAG" "$TARGET_TAG"
  info "已更新 TAG=${TARGET_TAG}"
  compose_run "$DEPLOY_DIR" pull
  compose_run "$DEPLOY_DIR" up -d
  if ! wait_for_http "http://127.0.0.1:8080/health" "API health" 80 3; then
    error "升级后健康检查失败。"
    warn "回滚提示：编辑 $DEPLOY_DIR/.env，将 TAG 改回上一个版本，然后执行：docker compose --env-file .env -f $(compose_profile_file "$DEPLOY_DIR") up -d"
    exit 1
  fi
  wait_for_head "http://127.0.0.1:8081" "User 前台" 30 2 || warn "User 前台本地检查未通过，请查看日志。"
  wait_for_head "http://127.0.0.1:8082" "Admin 后台" 30 2 || warn "Admin 后台本地检查未通过，请查看日志。"
  success "升级完成：${TARGET_TAG}"
}

main "$@"
