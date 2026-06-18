#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
setup_error_trap

USER_DOMAIN=""
ADMIN_DOMAIN=""
ADMIN_USERNAME="admin"
ADMIN_EMAIL=""
IMAGE_TAG=""
DEPLOY_DIR="$DUJIAO_DEPLOY_DIR_DEFAULT"
PROFILE="postgres"
HTTPS_MODE=""
HANDLE_FIREWALL=""
ASSUME_YES="no"
RUN_RENEW_CHECK="no"

usage() {
  cat <<'EOF'
Usage: sudo ./install.sh [options]

Options:
  --user-domain DOMAIN       Frontend domain, for example shop.example.com
  --admin-domain DOMAIN      Admin domain, for example admin.example.com
  --admin-user USER          Initial admin username, default: admin
  --email EMAIL              Email used by Certbot
  --tag TAG                  Dujiao-Next image tag, default: GitHub latest release or latest
  --deploy-dir DIR           Deployment directory, default: /opt/dujiao-next
  --profile postgres|sqlite  Deployment profile, default: postgres
  --https                    Request HTTPS certificate
  --no-https                 Skip HTTPS certificate
  --firewall yes|no          Allow 80/443 with ufw when ufw exists
  --renew-check              Run certbot renew --dry-run after issuance
  --yes                      Non-interactive mode
  -h, --help                 Show help
EOF
}

while (($# > 0)); do
  case "$1" in
    --user-domain) USER_DOMAIN="${2:-}"; shift 2 ;;
    --admin-domain) ADMIN_DOMAIN="${2:-}"; shift 2 ;;
    --admin-user) ADMIN_USERNAME="${2:-}"; shift 2 ;;
    --email) ADMIN_EMAIL="${2:-}"; shift 2 ;;
    --tag) IMAGE_TAG="${2:-}"; shift 2 ;;
    --deploy-dir) DEPLOY_DIR="${2:-}"; shift 2 ;;
    --profile) PROFILE="${2:-}"; shift 2 ;;
    --https) HTTPS_MODE="yes"; shift ;;
    --no-https) HTTPS_MODE="no"; shift ;;
    --firewall) HANDLE_FIREWALL="${2:-}"; shift 2 ;;
    --renew-check) RUN_RENEW_CHECK="yes"; shift ;;
    --yes) ASSUME_YES="yes"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "未知参数：$1" ;;
  esac
done

prompt_if_needed() {
  if [[ "$ASSUME_YES" == "yes" ]]; then
    [[ -n "$USER_DOMAIN" ]] || die "非交互模式必须提供 --user-domain。"
    [[ -n "$ADMIN_DOMAIN" ]] || die "非交互模式必须提供 --admin-domain。"
    [[ "$HTTPS_MODE" != "yes" || -n "$ADMIN_EMAIL" ]] || die "启用 --https 时必须提供 --email。"
    HTTPS_MODE="${HTTPS_MODE:-no}"
    HANDLE_FIREWALL="${HANDLE_FIREWALL:-no}"
    return
  fi

  if [[ -z "$USER_DOMAIN" ]]; then
    read -r -p "前台域名，例如 shop.example.com: " USER_DOMAIN
  fi
  if [[ -z "$ADMIN_DOMAIN" ]]; then
    read -r -p "后台域名，例如 admin.example.com: " ADMIN_DOMAIN
  fi
  read -r -p "管理员用户名 [${ADMIN_USERNAME}]: " input_admin_user
  ADMIN_USERNAME="${input_admin_user:-$ADMIN_USERNAME}"
  read -r -p "部署目录 [${DEPLOY_DIR}]: " input_deploy_dir
  DEPLOY_DIR="${input_deploy_dir:-$DEPLOY_DIR}"
  read -r -p "Dujiao-Next 镜像 TAG [自动 latest release]: " input_tag
  IMAGE_TAG="${input_tag:-$IMAGE_TAG}"
  read -r -p "部署方案 postgres/sqlite [${PROFILE}]: " input_profile
  PROFILE="${input_profile:-$PROFILE}"
  if [[ -z "$HTTPS_MODE" ]]; then
    if confirm "是否申请 HTTPS 证书？" "yes"; then
      HTTPS_MODE="yes"
    else
      HTTPS_MODE="no"
    fi
  fi
  if [[ "$HTTPS_MODE" == "yes" && -z "$ADMIN_EMAIL" ]]; then
    read -r -p "Certbot 邮箱: " ADMIN_EMAIL
  fi
  if [[ -z "$HANDLE_FIREWALL" ]]; then
    if confirm "是否尝试处理 ufw 防火墙，放行 80/443？" "no"; then
      HANDLE_FIREWALL="yes"
    else
      HANDLE_FIREWALL="no"
    fi
  fi
}

validate_inputs() {
  [[ -n "$USER_DOMAIN" ]] || die "前台域名不能为空。"
  [[ -n "$ADMIN_DOMAIN" ]] || die "后台域名不能为空。"
  [[ "$USER_DOMAIN" != "$ADMIN_DOMAIN" ]] || die "前台域名和后台域名不能相同。"
  [[ "$PROFILE" == "postgres" || "$PROFILE" == "sqlite" ]] || die "--profile 只支持 postgres 或 sqlite。"
  [[ "$HTTPS_MODE" == "yes" || "$HTTPS_MODE" == "no" ]] || die "HTTPS 选项必须是 yes/no。"
  if [[ "$HTTPS_MODE" == "yes" ]]; then
    [[ -n "$ADMIN_EMAIL" ]] || die "申请 HTTPS 时邮箱不能为空。"
  fi
}

detect_os() {
  [[ -r /etc/os-release ]] || die "无法读取 /etc/os-release。"
  # shellcheck disable=SC1091
  . /etc/os-release
  local os_id="${ID:-}"
  local version="${VERSION_ID:-0}"
  case "$os_id" in
    ubuntu)
      awk "BEGIN { exit !($version >= 22.04) }" || die "仅支持 Ubuntu 22.04+，当前版本：$version"
      ;;
    debian)
      awk "BEGIN { exit !($version >= 12) }" || die "仅支持 Debian 12+，当前版本：$version"
      ;;
    *)
      die "仅支持 Ubuntu/Debian，当前系统：$os_id"
      ;;
  esac
  success "系统检查通过：${PRETTY_NAME:-$os_id $version}"
}

check_resources() {
  local mem_mb disk_mb
  mem_mb="$(awk '/MemTotal/ { printf "%.0f", $2 / 1024 }' /proc/meminfo)"
  disk_mb="$(df -Pm "$(dirname "$DEPLOY_DIR")" 2>/dev/null | awk 'NR==2 {print $4}')"
  if [[ -z "$disk_mb" ]]; then
    disk_mb="$(df -Pm /opt 2>/dev/null | awk 'NR==2 {print $4}')"
  fi
  ((mem_mb >= 1024)) || warn "内存小于 1GB，生产环境可能不稳定：${mem_mb}MB"
  ((disk_mb >= 5120)) || warn "可用磁盘小于 5GB，建议扩容后部署：${disk_mb}MB"
}

port_is_listening() {
  local port="$1"
  ss -H -ltn | awk '{print $4}' | grep -Eq "(:|\\])${port}$"
}

check_ports() {
  local port
  for port in 80 443; do
    if port_is_listening "$port"; then
      warn "端口 $port 已被占用。如果是现有 Nginx，安装会复用并 reload；如果是其他服务，请先处理。"
    fi
  done
  for port in 8080 8081 8082; do
    if port_is_listening "$port"; then
      die "端口 $port 已被占用，Dujiao-Next 本地容器端口不能继续使用。"
    fi
  done
}

ipv4_to_int() {
  local ip="$1"
  local a b c d
  IFS=. read -r a b c d <<<"$ip"
  printf '%u\n' "$(((a << 24) + (b << 16) + (c << 8) + d))"
}

cidr_contains() {
  local ip="$1"
  local cidr="$2"
  local range="${cidr%/*}"
  local bits="${cidr#*/}"
  local ip_int range_int mask
  ip_int="$(ipv4_to_int "$ip")"
  range_int="$(ipv4_to_int "$range")"
  mask=$((0xFFFFFFFF << (32 - bits) & 0xFFFFFFFF))
  (( (ip_int & mask) == (range_int & mask) ))
}

is_cloudflare_ip() {
  local ip="$1"
  local cidr
  local ranges=(
    "173.245.48.0/20" "103.21.244.0/22" "103.22.200.0/22" "103.31.4.0/22"
    "141.101.64.0/18" "108.162.192.0/18" "190.93.240.0/20" "188.114.96.0/20"
    "197.234.240.0/22" "198.41.128.0/17" "162.158.0.0/15" "104.16.0.0/13"
    "104.24.0.0/14" "172.64.0.0/13" "131.0.72.0/22"
  )
  for cidr in "${ranges[@]}"; do
    if cidr_contains "$ip" "$cidr"; then
      return 0
    fi
  done
  return 1
}

check_dns() {
  local public_ip resolved_ip domain
  public_ip="$(curl -fsS --max-time 6 https://api.ipify.org 2>/dev/null || true)"
  [[ -n "$public_ip" ]] || { warn "无法获取服务器公网 IP，跳过 DNS 严格检查。"; return; }
  for domain in "$USER_DOMAIN" "$ADMIN_DOMAIN"; do
    resolved_ip="$(getent ahostsv4 "$domain" | awk '{print $1; exit}' || true)"
    if [[ -z "$resolved_ip" ]]; then
      warn "域名 $domain 暂无 A 记录或本机无法解析。"
      continue
    fi
    if is_cloudflare_ip "$resolved_ip"; then
      warn "$domain 当前解析到 Cloudflare IP。申请证书阶段建议先切换为灰云/仅 DNS。"
    elif [[ "$resolved_ip" != "$public_ip" ]]; then
      warn "$domain 解析到 $resolved_ip，但本机公网 IP 是 $public_ip。Certbot 可能失败。"
    else
      success "$domain DNS 指向当前服务器。"
    fi
  done
}

preflight() {
  require_root
  require_cmds curl openssl sed awk grep ss systemctl
  detect_os
  check_resources
  check_ports
  check_dns
}

handle_existing_deploy() {
  if [[ ! -e "$DEPLOY_DIR/.env" && ! -e "$DEPLOY_DIR/docker-compose.postgres.yml" && ! -e "$DEPLOY_DIR/docker-compose.sqlite.yml" ]]; then
    return
  fi
  warn "检测到已有部署目录：$DEPLOY_DIR"
  if [[ "$ASSUME_YES" == "yes" ]]; then
    die "非交互模式不会覆盖已有部署。请先运行 ./update.sh 或 ./backup.sh。"
  fi
  log "请选择："
  log "  1) 升级现有部署"
  log "  2) 立即备份"
  log "  3) 退出"
  read -r -p "输入 1/2/3: " choice
  case "$choice" in
    1) "$SCRIPT_DIR/update.sh"; exit 0 ;;
    2) "$SCRIPT_DIR/backup.sh" --deploy-dir "$DEPLOY_DIR"; exit 0 ;;
    *) die "已退出，未修改现有部署。" ;;
  esac
}

install_apt_dependencies() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y ca-certificates curl gnupg openssl python3 python3-yaml sed gawk grep iproute2 nginx certbot python3-certbot-nginx
}

install_docker() {
  local remove_old="no"
  warn "将检查并移除可能冲突的旧 Docker 包：docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc"
  if [[ "$ASSUME_YES" == "yes" ]] || confirm "是否继续处理旧 Docker 包？" "yes"; then
    remove_old="yes"
  fi
  if [[ "$remove_old" == "yes" ]]; then
    apt-get remove -y docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc || true
  fi

  # shellcheck disable=SC1091
  . /etc/os-release
  local os_id="${ID:?}"
  local codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:?}}"
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/${os_id}/gpg" -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/%s %s stable\n' \
    "$(dpkg --print-architecture)" "$os_id" "$codename" >/etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
  docker compose version >/dev/null
  success "Docker 与 Docker Compose 安装完成。"
}

write_env_file() {
  local env_file="$DEPLOY_DIR/.env"
  local admin_password redis_password postgres_password
  admin_password="Admin$(random_hex 12)"
  redis_password="$(random_hex 24)"
  postgres_password="$(random_hex 24)"
  umask 077
  cat >"$env_file" <<EOF
TAG=${IMAGE_TAG}
TZ=Asia/Shanghai
API_PORT=8080
USER_PORT=8081
ADMIN_PORT=8082
DJ_DEFAULT_ADMIN_USERNAME=${ADMIN_USERNAME}
DJ_DEFAULT_ADMIN_PASSWORD=${admin_password}
REDIS_PASSWORD=${redis_password}
POSTGRES_DB=dujiao_next
POSTGRES_USER=dujiao
POSTGRES_PASSWORD=${postgres_password}
EOF
  chmod 0600 "$env_file"
  success "已生成 $env_file"
  log "初始管理员用户名：${ADMIN_USERNAME}"
  log "初始管理员密码：${admin_password}"
  warn "请现在保存初始管理员密码。它只会在安装完成时打印一次，首次登录后请立即修改。"
}

write_compose_files() {
  local root="$1"
  cp "$root/templates/docker-compose.postgres.yml.tpl" "$DEPLOY_DIR/docker-compose.postgres.yml"
  cp "$root/templates/docker-compose.sqlite.yml.tpl" "$DEPLOY_DIR/docker-compose.sqlite.yml"
  printf '%s\n' "$PROFILE" >"$DEPLOY_DIR/.deployment-profile"
  success "已写入 Docker Compose 文件。"
}

download_and_patch_config() {
  local config_file="$DEPLOY_DIR/config/config.yml"
  local jwt_secret user_jwt_secret
  curl -fsSL "$DUJIAO_CONFIG_URL" -o "$config_file"
  chmod 0644 "$config_file"
  load_env_file "$DEPLOY_DIR/.env"
  jwt_secret="$(random_hex 32)"
  user_jwt_secret="$(random_hex 32)"
  export CONFIG_FILE="$config_file" DEPLOY_PROFILE="$PROFILE" JWT_SECRET="$jwt_secret" USER_JWT_SECRET="$user_jwt_secret"
  python3 - <<'PY'
import os
from pathlib import Path
import yaml

path = Path(os.environ.get("CONFIG_FILE", "/opt/dujiao-next/config/config.yml"))
cfg = yaml.safe_load(path.read_text()) or {}
profile = os.environ["DEPLOY_PROFILE"]

cfg.setdefault("server", {})
cfg.setdefault("database", {})
cfg.setdefault("redis", {})
cfg.setdefault("queue", {})
cfg.setdefault("jwt", {})
cfg.setdefault("user_jwt", {})
cfg.setdefault("bootstrap", {})

if profile == "sqlite":
    cfg["database"]["driver"] = "sqlite"
    cfg["database"]["dsn"] = "/app/db/dujiao.db"
else:
    cfg["database"]["driver"] = "postgres"
    cfg["database"]["dsn"] = (
        f"host=postgres user={os.environ['POSTGRES_USER']} "
        f"password={os.environ['POSTGRES_PASSWORD']} "
        f"dbname={os.environ['POSTGRES_DB']} "
        "port=5432 sslmode=disable TimeZone=Asia/Shanghai"
    )

cfg["redis"].update({
    "enabled": True,
    "host": "redis",
    "port": 6379,
    "password": os.environ["REDIS_PASSWORD"],
})
cfg["queue"].update({
    "enabled": True,
    "host": "redis",
    "port": 6379,
    "password": os.environ["REDIS_PASSWORD"],
})
cfg["jwt"]["secret"] = os.environ["JWT_SECRET"]
cfg["user_jwt"]["secret"] = os.environ["USER_JWT_SECRET"]
cfg["bootstrap"]["default_admin_username"] = os.environ["DJ_DEFAULT_ADMIN_USERNAME"]
cfg["bootstrap"]["default_admin_password"] = os.environ["DJ_DEFAULT_ADMIN_PASSWORD"]

path.write_text(yaml.safe_dump(cfg, allow_unicode=True, sort_keys=False))
PY
  success "已下载并更新 config/config.yml。"
}

write_nginx_config() {
  local root="$1"
  local tmp_conf
  mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
  tmp_conf="$(mktemp)"
  render_template "$root/templates/nginx.dujiao-next.conf.tpl" "$tmp_conf" "$USER_DOMAIN" "$ADMIN_DOMAIN" "8080" "8081" "8082"
  backup_existing_file "$DUJIAO_NGINX_CONF"
  install -m 0644 "$tmp_conf" "$DUJIAO_NGINX_CONF"
  rm -f "$tmp_conf"
  ln -sf "$DUJIAO_NGINX_CONF" "$DUJIAO_NGINX_LINK"
  nginx -t
  systemctl enable --now nginx
  systemctl reload nginx
  success "Nginx 反向代理配置完成。"
}

handle_firewall() {
  [[ "$HANDLE_FIREWALL" == "yes" ]] || return
  if ! has_cmd ufw; then
    warn "未安装 ufw，跳过防火墙处理。"
    return
  fi
  ufw allow 80/tcp
  ufw allow 443/tcp
  success "已通过 ufw 放行 80/443。"
}

request_https() {
  [[ "$HTTPS_MODE" == "yes" ]] || { warn "已跳过 HTTPS 证书申请。"; return; }
  certbot --nginx \
    -d "$USER_DOMAIN" \
    -d "$ADMIN_DOMAIN" \
    --email "$ADMIN_EMAIL" \
    --agree-tos \
    --no-eff-email \
    --redirect
  success "HTTPS 证书申请完成。"
  if [[ "$RUN_RENEW_CHECK" == "yes" ]]; then
    certbot renew --dry-run
  fi
}

start_services() {
  cd "$DEPLOY_DIR"
  docker compose --env-file .env -f "docker-compose.${PROFILE}.yml" pull
  docker compose --env-file .env -f "docker-compose.${PROFILE}.yml" up -d
  docker compose --env-file .env -f "docker-compose.${PROFILE}.yml" ps
  wait_for_http "http://127.0.0.1:8080/health" "API health" 80 3 || die "API health check 失败。"
  wait_for_head "http://127.0.0.1:8081" "User 前台" 40 2 || die "User 前台本地检查失败。"
  wait_for_head "http://127.0.0.1:8082" "Admin 后台" 40 2 || die "Admin 后台本地检查失败。"
}

install_cli_runtime() {
  local root="$1"
  install -d -m 0755 "$DUJIAO_RUNTIME_DIR"
  cp -a "$root/install.sh" "$root/update.sh" "$root/backup.sh" "$root/status.sh" "$root/uninstall.sh" "$root/menu.sh" "$DUJIAO_RUNTIME_DIR/"
  cp -a "$root/lib" "$root/templates" "$DUJIAO_RUNTIME_DIR/"
  chmod +x "$DUJIAO_RUNTIME_DIR/"*.sh
  ln -sf "$DUJIAO_RUNTIME_DIR/menu.sh" "$DUJIAO_MENU_BIN"
  success "管理入口已安装：sudo dujiao-next"
}

main() {
  prompt_if_needed
  validate_inputs
  [[ -n "$IMAGE_TAG" ]] || IMAGE_TAG="$(get_latest_tag)"
  preflight
  handle_existing_deploy
  local root
  root="$(find_project_root "$SCRIPT_DIR")"
  install_apt_dependencies
  install_docker
  safe_mkdir_deploy_tree "$DEPLOY_DIR"
  write_env_file
  write_compose_files "$root"
  download_and_patch_config
  write_nginx_config "$root"
  handle_firewall
  start_services
  request_https
  install_cli_runtime "$root"
  print_access_summary "$USER_DOMAIN" "$ADMIN_DOMAIN" "$HTTPS_MODE"
}

main "$@"
