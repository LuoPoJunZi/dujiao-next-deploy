#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
setup_error_trap

DEPLOY_DIR="$DUJIAO_DEPLOY_DIR_DEFAULT"
CURRENT_TAG=""

usage() {
  cat <<'EOF'
Usage: ./check-updates.sh [--deploy-dir DIR] [--current-tag TAG]

Checks the latest Dujiao-Next release tag and compares it with the deployed TAG when available.
EOF
}

while (($# > 0)); do
  case "$1" in
    --deploy-dir) DEPLOY_DIR="$(require_arg_value "$1" "${2:-}")"; shift 2 ;;
    --current-tag) CURRENT_TAG="$(require_arg_value "$1" "${2:-}")"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "未知参数：$1" ;;
  esac
done

main() {
  require_cmds curl sed awk

  if [[ -z "$CURRENT_TAG" && -f "$DEPLOY_DIR/.env" ]]; then
    load_env_file "$DEPLOY_DIR/.env"
    CURRENT_TAG="${TAG:-}"
  fi

  if [[ -n "$CURRENT_TAG" ]]; then
    is_valid_tag "$CURRENT_TAG" || die "当前 TAG 格式不合法：$CURRENT_TAG"
  fi

  local latest_tag
  latest_tag="$(get_latest_tag)"
  is_valid_tag "$latest_tag" || die "最新 TAG 格式不合法：$latest_tag"

  if [[ -z "$CURRENT_TAG" ]]; then
    warn "未找到当前部署 TAG。可使用 --current-tag 指定，或在已部署目录中运行。"
    log "最新版本：$latest_tag"
    return
  fi

  log "当前版本：$CURRENT_TAG"
  log "最新版本：$latest_tag"
  if [[ "$CURRENT_TAG" == "$latest_tag" ]]; then
    success "当前已是最新版本。"
  else
    warn "发现可用更新。"
    log "升级命令：sudo dujiao-next upgrade $latest_tag"
  fi
}

main "$@"
