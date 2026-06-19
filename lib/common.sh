#!/usr/bin/env bash
set -Eeuo pipefail

DUJIAO_DEPLOY_DIR_DEFAULT="/opt/dujiao-next"
DUJIAO_RUNTIME_DIR="/usr/local/lib/dujiao-next-deploy"
DUJIAO_MENU_BIN="/usr/local/bin/dujiao-next"
DUJIAO_NGINX_CONF="/etc/nginx/sites-available/dujiao-next.conf"
DUJIAO_NGINX_LINK="/etc/nginx/sites-enabled/dujiao-next.conf"
DUJIAO_CONFIG_URL="https://raw.githubusercontent.com/dujiao-next/dujiao-next/main/config.yml.example"
DUJIAO_GITHUB_LATEST_URL="https://api.github.com/repos/dujiao-next/dujiao-next/releases/latest"

if [[ -t 1 ]]; then
  COLOR_INFO=$'\033[1;34m'
  COLOR_WARN=$'\033[1;33m'
  COLOR_ERROR=$'\033[1;31m'
  COLOR_OK=$'\033[1;32m'
  COLOR_RESET=$'\033[0m'
else
  COLOR_INFO=""
  COLOR_WARN=""
  COLOR_ERROR=""
  COLOR_OK=""
  COLOR_RESET=""
fi

log() { printf '%s\n' "$*"; }
info() { printf '%s[INFO]%s %s\n' "$COLOR_INFO" "$COLOR_RESET" "$*"; }
warn() { printf '%s[WARN]%s %s\n' "$COLOR_WARN" "$COLOR_RESET" "$*" >&2; }
error() { printf '%s[ERROR]%s %s\n' "$COLOR_ERROR" "$COLOR_RESET" "$*" >&2; }
success() { printf '%s[OK]%s %s\n' "$COLOR_OK" "$COLOR_RESET" "$*"; }
die() { error "$*"; exit 1; }

setup_error_trap() {
  trap 'dujiao_on_error "$LINENO" "$BASH_COMMAND" "$?"' ERR
}

dujiao_on_error() {
  local line="$1"
  local command="$2"
  local status="$3"
  error "脚本在第 ${line} 行失败，退出码：${status}"
  error "失败命令：${command}"
  warn "排查建议：先执行 sudo dujiao-next status；再查看 API 日志：sudo dujiao-next logs api；若是 Nginx/证书问题，执行 sudo nginx -t 和 sudo certbot certificates。"
  exit "$status"
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "请使用 root 或 sudo 运行。"
  fi
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

require_cmds() {
  local missing=()
  local cmd
  for cmd in "$@"; do
    if ! has_cmd "$cmd"; then
      missing+=("$cmd")
    fi
  done
  if ((${#missing[@]} > 0)); then
    die "缺少必要命令：${missing[*]}"
  fi
}

require_arg_value() {
  local option="$1"
  local value="${2:-}"
  if [[ -z "$value" || "$value" == --* ]]; then
    die "参数 ${option} 需要提供值。"
  fi
  printf '%s\n' "$value"
}

timestamp() {
  date '+%Y%m%d-%H%M%S'
}

confirm() {
  local prompt="$1"
  local default="${2:-no}"
  local answer
  local suffix="[y/N]"
  if [[ "$default" == "yes" ]]; then
    suffix="[Y/n]"
  fi
  read -r -p "${prompt} ${suffix} " answer
  answer="${answer:-$default}"
  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

random_hex() {
  local bytes="${1:-32}"
  if has_cmd openssl; then
    openssl rand -hex "$bytes"
    return
  fi
  od -An -N "$bytes" -tx1 /dev/urandom | tr -d ' \n'
}

backup_existing_file() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    local backup
    backup="${path}.bak-$(timestamp)"
    cp -a "$path" "$backup"
    warn "已备份已有文件：$path -> $backup"
  fi
}

safe_mkdir_deploy_tree() {
  local deploy_dir="$1"
  mkdir -p \
    "$deploy_dir/config" \
    "$deploy_dir/data/db" \
    "$deploy_dir/data/uploads" \
    "$deploy_dir/data/logs" \
    "$deploy_dir/data/redis" \
    "$deploy_dir/data/postgres" \
    "$deploy_dir/backups"
  chmod 0777 \
    "$deploy_dir/data/logs" \
    "$deploy_dir/data/db" \
    "$deploy_dir/data/uploads" \
    "$deploy_dir/data/redis" \
    "$deploy_dir/data/postgres"
}

load_env_file() {
  local env_file="$1"
  [[ -f "$env_file" ]] || die "找不到环境文件：$env_file"
  set -a
  # shellcheck disable=SC1090
  . "$env_file"
  set +a
}

escape_sed_replacement() {
  printf '%s' "$1" | sed -e 's/[\/&|\\]/\\&/g'
}

render_template() {
  local input="$1"
  local output="$2"
  local user_domain="${3:-}"
  local admin_domain="${4:-}"
  local api_port="${5:-8080}"
  local user_port="${6:-8081}"
  local admin_port="${7:-8082}"
  sed \
    -e "s|__USER_DOMAIN__|$(escape_sed_replacement "$user_domain")|g" \
    -e "s|__ADMIN_DOMAIN__|$(escape_sed_replacement "$admin_domain")|g" \
    -e "s|__API_PORT__|$(escape_sed_replacement "$api_port")|g" \
    -e "s|__USER_PORT__|$(escape_sed_replacement "$user_port")|g" \
    -e "s|__ADMIN_PORT__|$(escape_sed_replacement "$admin_port")|g" \
    "$input" >"$output"
}

find_project_root() {
  local script_dir="$1"
  if [[ -d "$script_dir/templates" && -d "$script_dir/lib" ]]; then
    printf '%s\n' "$script_dir"
  elif [[ -d "$DUJIAO_RUNTIME_DIR/templates" && -d "$DUJIAO_RUNTIME_DIR/lib" ]]; then
    printf '%s\n' "$DUJIAO_RUNTIME_DIR"
  else
    die "无法定位项目模板目录。"
  fi
}

compose_profile_file() {
  local deploy_dir="$1"
  if [[ -f "$deploy_dir/.deployment-profile" ]]; then
    case "$(cat "$deploy_dir/.deployment-profile")" in
      sqlite) printf '%s\n' "docker-compose.sqlite.yml" ;;
      *) printf '%s\n' "docker-compose.postgres.yml" ;;
    esac
  else
    printf '%s\n' "docker-compose.postgres.yml"
  fi
}

compose_run() {
  local deploy_dir="$1"
  shift
  local compose_file
  compose_file="$(compose_profile_file "$deploy_dir")"
  docker compose --env-file "$deploy_dir/.env" -f "$deploy_dir/$compose_file" "$@"
}

get_latest_tag() {
  local tag
  tag="$(curl -fsSL --max-time 10 "$DUJIAO_GITHUB_LATEST_URL" 2>/dev/null | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1 || true)"
  if [[ -n "$tag" ]]; then
    printf '%s\n' "$tag"
  else
    warn "自动获取 GitHub latest release 失败，将使用 latest。"
    printf '%s\n' "latest"
  fi
}

replace_env_key() {
  local env_file="$1"
  local key="$2"
  local value="$3"
  local tmp_file
  tmp_file="$(mktemp)"
  awk -v key="$key" -v value="$value" '
    BEGIN { done = 0 }
    $0 ~ "^" key "=" {
      print key "=" value
      done = 1
      next
    }
    { print }
    END {
      if (done == 0) {
        print key "=" value
      }
    }
  ' "$env_file" >"$tmp_file"
  install -m 0600 "$tmp_file" "$env_file"
  rm -f "$tmp_file"
}

wait_for_http() {
  local url="$1"
  local label="$2"
  local tries="${3:-60}"
  local delay="${4:-3}"
  local i
  for ((i = 1; i <= tries; i++)); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      success "$label 已就绪：$url"
      return 0
    fi
    sleep "$delay"
  done
  return 1
}

wait_for_head() {
  local url="$1"
  local label="$2"
  local tries="${3:-30}"
  local delay="${4:-2}"
  local i
  for ((i = 1; i <= tries; i++)); do
    if curl -fsSI "$url" >/dev/null 2>&1; then
      success "$label 已响应：$url"
      return 0
    fi
    sleep "$delay"
  done
  return 1
}

print_access_summary() {
  local user_domain="$1"
  local admin_domain="$2"
  local https_enabled="$3"
  local scheme="http"
  if [[ "$https_enabled" == "yes" ]]; then
    scheme="https"
  fi
  success "安装完成。"
  log "前台地址：${scheme}://${user_domain}"
  log "后台地址：${scheme}://${admin_domain}"
  log "部署目录：${DEPLOY_DIR:-$DUJIAO_DEPLOY_DIR_DEFAULT}"
}
