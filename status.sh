#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
setup_error_trap

DEPLOY_DIR="$DUJIAO_DEPLOY_DIR_DEFAULT"

usage() {
  cat <<'EOF'
Usage: sudo ./status.sh [--deploy-dir DIR]

Shows deployment metadata, Docker Compose status, local health checks,
Nginx status, and Certbot certificate information.
EOF
}

while (($# > 0)); do
  case "$1" in
    --deploy-dir) DEPLOY_DIR="$(require_arg_value "$1" "${2:-}")"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "未知参数：$1" ;;
  esac
done

env_value() {
  local key="$1"
  local env_file="$DEPLOY_DIR/.env"
  awk -F= -v key="$key" '$1 == key { print substr($0, length(key) + 2); exit }' "$env_file"
}

print_deployment_summary() {
  local profile="postgres"
  local compose_file tag api_port user_port admin_port
  if [[ -f "$DEPLOY_DIR/.deployment-profile" ]]; then
    profile="$(<"$DEPLOY_DIR/.deployment-profile")"
  fi
  compose_file="$(compose_profile_file "$DEPLOY_DIR")"
  tag="$(env_value TAG)"
  api_port="$(env_value API_PORT)"
  user_port="$(env_value USER_PORT)"
  admin_port="$(env_value ADMIN_PORT)"

  info "部署信息"
  log "部署目录：$DEPLOY_DIR"
  log "部署方案：$profile"
  log "Compose 文件：$compose_file"
  log "镜像 TAG：${tag:-unknown}"
  log "本地端口：API ${api_port:-8080}, User ${user_port:-8081}, Admin ${admin_port:-8082}"
}

print_nginx_status() {
  info "Nginx 状态"
  if ! has_cmd systemctl; then
    warn "systemctl 不存在，跳过 Nginx 状态检查。"
    return
  fi
  if systemctl is-active --quiet nginx; then
    success "Nginx 正在运行。"
  else
    warn "Nginx 未运行或状态异常。"
    systemctl status nginx --no-pager -l || true
  fi
}

main() {
  require_root
  require_cmds awk curl
  [[ -d "$DEPLOY_DIR" ]] || die "部署目录不存在：$DEPLOY_DIR"
  [[ -f "$DEPLOY_DIR/.env" ]] || die "找不到 $DEPLOY_DIR/.env"

  print_deployment_summary

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

  print_nginx_status

  info "Certbot 证书"
  if has_cmd certbot; then
    certbot certificates || warn "无法读取 Certbot 证书信息。"
  else
    warn "未安装 certbot。"
  fi

  log "查看最近 100 行 API 日志：sudo dujiao-next logs api"
}

main "$@"
