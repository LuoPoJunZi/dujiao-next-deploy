#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
setup_error_trap

DEPLOY_DIR="$DUJIAO_DEPLOY_DIR_DEFAULT"

while (($# > 0)); do
  case "$1" in
    --deploy-dir) DEPLOY_DIR="$(require_arg_value "$1" "${2:-}")"; shift 2 ;;
    -h|--help) echo "Usage: sudo ./status.sh [--deploy-dir DIR]"; exit 0 ;;
    *) die "未知参数：$1" ;;
  esac
done

main() {
  require_root
  [[ -d "$DEPLOY_DIR" ]] || die "部署目录不存在：$DEPLOY_DIR"
  if has_cmd docker && [[ -f "$DEPLOY_DIR/.env" ]]; then
    info "Docker Compose 状态"
    compose_run "$DEPLOY_DIR" ps || warn "docker compose ps 执行失败。"
  else
    warn "Docker 或 .env 不存在，跳过容器状态。"
  fi

  info "API health"
  if curl -fsS http://127.0.0.1:8080/health; then
    printf '\n'
  else
    warn "API health 检查失败。"
  fi

  info "Nginx 状态"
  if has_cmd systemctl; then
    systemctl status nginx --no-pager -l || warn "Nginx 未运行或状态异常。"
  fi

  info "Certbot 证书"
  if has_cmd certbot; then
    certbot certificates || warn "无法读取 Certbot 证书信息。"
  else
    warn "未安装 certbot。"
  fi

  log "查看最近 100 行 API 日志：sudo dujiao-next logs api"
}

main "$@"
