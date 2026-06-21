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
  ((${#args[@]} == 1)) || die "只能指定一个目标 TAG。"
  TARGET_TAG="${args[0]}"
fi

env_value() {
  local env_file="$1"
  local key="$2"
  awk -F= -v key="$key" '$1 == key { print substr($0, length(key) + 2); exit }' "$env_file"
}

rollback_to_previous_tag() {
  local previous_tag="$1"
  if [[ -z "$previous_tag" ]]; then
    warn "未找到升级前 TAG，无法自动回滚。"
    return
  fi

  warn "尝试回滚到升级前 TAG=${previous_tag}"
  replace_env_key "$DEPLOY_DIR/.env" "TAG" "$previous_tag"
  if compose_run "$DEPLOY_DIR" up -d; then
    warn "已尝试回滚容器，请执行 sudo dujiao-next status 确认状态。"
  else
    warn "自动回滚启动失败，请手动检查 $DEPLOY_DIR/.env 和容器日志。"
  fi
}

main() {
  local previous_tag

  require_root
  require_cmds curl docker awk sed grep
  [[ -d "$DEPLOY_DIR" ]] || die "部署目录不存在：$DEPLOY_DIR"
  [[ -f "$DEPLOY_DIR/.env" ]] || die "找不到 $DEPLOY_DIR/.env"
  [[ -x "$SCRIPT_DIR/backup.sh" ]] || die "找不到可执行备份脚本：$SCRIPT_DIR/backup.sh"
  [[ -n "$TARGET_TAG" ]] || TARGET_TAG="$(get_latest_tag)"
  is_valid_tag "$TARGET_TAG" || die "目标 TAG 格式不合法：$TARGET_TAG"
  ! tag_looks_like_domain "$TARGET_TAG" || die "目标 TAG 看起来像域名，请填写版本号，例如 latest 或 v1.2.3。"

  previous_tag="$(env_value "$DEPLOY_DIR/.env" "TAG")"
  info "升级目标：${previous_tag:-unknown} -> ${TARGET_TAG}"

  "$SCRIPT_DIR/backup.sh" --deploy-dir "$DEPLOY_DIR"
  replace_env_key "$DEPLOY_DIR/.env" "TAG" "$TARGET_TAG"
  info "已更新 TAG=${TARGET_TAG}"
  if ! compose_run "$DEPLOY_DIR" pull; then
    error "拉取镜像失败。"
    rollback_to_previous_tag "$previous_tag"
    exit 1
  fi
  if ! compose_run "$DEPLOY_DIR" up -d; then
    error "启动新版本容器失败。"
    rollback_to_previous_tag "$previous_tag"
    exit 1
  fi
  if ! wait_for_http "http://127.0.0.1:8080/health" "API health" 80 3; then
    error "升级后健康检查失败。"
    rollback_to_previous_tag "$previous_tag"
    exit 1
  fi
  wait_for_head "http://127.0.0.1:8081" "User 前台" 30 2 || warn "User 前台本地检查未通过，请查看日志。"
  wait_for_head "http://127.0.0.1:8082" "Admin 后台" 30 2 || warn "Admin 后台本地检查未通过，请查看日志。"
  success "升级完成：${TARGET_TAG}"
}

main "$@"
