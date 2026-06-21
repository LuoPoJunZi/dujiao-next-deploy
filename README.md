# dujiao-next-deploy

中文 | [English](README.en.md)

`dujiao-next-deploy` 是一个非官方的 Dujiao-Next Bash 一键部署工具，适用于 Ubuntu / Debian 服务器。

它会安装 Docker Engine、Docker Compose、Nginx，并通过 Certbot 申请 HTTPS 证书；默认使用 PostgreSQL + Redis 生产方案部署 Dujiao-Next。

本项目不是 Dujiao-Next 官方项目。Dujiao-Next 的版权归原项目作者和维护者所有。

## 支持系统

- Ubuntu 22.04+
- Debian 12+

请使用 `root` 或 `sudo` 运行安装、升级、备份和卸载脚本。

## 部署前准备

生产部署默认需要 HTTPS 证书。运行安装脚本前，请先到 Cloudflare（CF）或你的 DNS 服务商添加两条 A 记录：

- 前台域名，例如 `shop.example.com` -> 当前服务器公网 IP
- 后台域名，例如 `admin.example.com` -> 当前服务器公网 IP

如果使用 Cloudflare 代理，申请证书阶段建议先切换为 DNS-only（灰云），等 Certbot 证书申请成功后再按需开启代理。

安装脚本会先集中收集域名、邮箱、部署目录、镜像 TAG 等信息，然后自动安装 Docker、Nginx、Certbot，生成配置并启动服务。

## 快速开始

```bash
git clone https://github.com/LuoPoJunZi/dujiao-next-deploy.git
cd dujiao-next-deploy
sudo ./install.sh
```

安装完成后，可以使用管理入口：

```bash
sudo dujiao-next
```

## 一行安装

生产部署（HTTPS）：

```bash
sudo ./install.sh \
  --user-domain shop.example.com \
  --admin-domain admin.example.com \
  --email me@example.com \
  --tag latest \
  --yes \
  --https
```

临时跳过 HTTPS（仅用于内网或调试）：

```bash
sudo ./install.sh \
  --user-domain shop.example.com \
  --admin-domain admin.example.com \
  --tag latest \
  --yes \
  --no-https
```

## 交互安装

```bash
sudo ./install.sh
```

安装脚本会先集中收集信息，然后再自动执行部署流程。

安装脚本会询问：

- 前台域名
- 后台域名
- 管理员用户名，默认 `admin`
- 镜像 TAG，默认 GitHub latest release，失败回退 `latest`
- 部署目录，默认 `/opt/dujiao-next`
- 部署方案 `postgres|sqlite`
- 是否申请 HTTPS，生产部署建议启用
- Certbot 邮箱
- 是否处理主机防火墙规则
- 是否移除旧 Docker 冲突包

在修改系统前，交互模式会打印配置汇总并进行最终确认。

初始管理员密码会自动生成，只在安装结束时打印一次。请立即保存并在首次登录后修改。

## 非交互参数

```text
--user-domain DOMAIN
--admin-domain DOMAIN
--admin-user USER
--email EMAIL
--tag TAG
--deploy-dir DIR
--profile postgres|sqlite
--https
--no-https
--firewall yes|no
--remove-old-docker yes|no
--renew-check
--yes
```

## 目录结构

仓库结构：

```text
.
├── install.sh
├── update.sh
├── backup.sh
├── check-updates.sh
├── status.sh
├── uninstall.sh
├── menu.sh
├── lib/common.sh
├── templates/
├── docs/
└── .github/workflows/shellcheck.yml
```

服务器部署目录：

```text
/opt/dujiao-next
├── config/config.yml
├── data/db
├── data/uploads
├── data/logs
├── data/redis
├── data/postgres
├── backups
├── docker-compose.postgres.yml
├── docker-compose.sqlite.yml
└── .env
```

## 端口

公网入口：

- Nginx: `80`, `443`

仅绑定本机回环地址：

- API: `127.0.0.1:8080:8080`
- 前台 User: `127.0.0.1:8081:80`
- 后台 Admin: `127.0.0.1:8082:80`

不发布到宿主机：

- Redis `6379`
- PostgreSQL `5432`

## Nginx 路由

前台域名：

- `/` -> `http://127.0.0.1:8081`
- `/api/` -> `http://127.0.0.1:8080/api/`
- `/uploads/` -> `http://127.0.0.1:8080/uploads/`
- `/sitemap.xml` -> `http://127.0.0.1:8080/sitemap.xml`
- `/robots.txt` -> `http://127.0.0.1:8080/robots.txt`

后台域名：

- `/` -> `http://127.0.0.1:8082`
- `/api/` -> `http://127.0.0.1:8080/api/`
- `/uploads/` -> `http://127.0.0.1:8080/uploads/`

## 安全说明

- `.env` 权限为 `0600`。
- `config/config.yml` 权限为 `0600`，因为其中包含 JWT、Redis 和 PostgreSQL 密钥。
- 密钥和密码使用 `openssl rand` 或 `/dev/urandom` 生成。
- 替换同名 Nginx 配置前会先备份。
- 非交互安装不会覆盖已有部署。
- 卸载默认保留数据；只有 `--purge` 才删除数据，并要求二次确认和输入完整路径。
- `0777` 只用于官方要求的容器挂载数据目录：`data/db`、`data/uploads`、`data/logs`、`data/redis`、`data/postgres`，并且不会递归放大已有文件权限。

## 备份

```bash
sudo ./backup.sh
sudo dujiao-next backup
```

备份默认写入 `/opt/dujiao-next/backups`；如果不可写，则写入 `/root/dujiao-next-backups`。

备份内容包括 `.env`、`config.yml`、`.deployment-profile`、已有 Compose 文件，以及存在时的 `data/uploads`。

PostgreSQL 方案还会执行：

```bash
docker exec dujiaonext-postgres pg_dump -U ${POSTGRES_USER} -d ${POSTGRES_DB}
```

## 升级

```bash
sudo ./update.sh
sudo ./update.sh v1.2.3
sudo dujiao-next upgrade v1.2.3
```

未指定 TAG 时，升级脚本会获取 GitHub latest release，失败时回退到 `latest`。升级前会先备份。

## 版本检查

```bash
./check-updates.sh
sudo dujiao-next check-updates
```

版本检查会比较当前部署的 `TAG` 和 GitHub latest release，并在发现新版本时打印升级命令。

## 状态与日志

```bash
sudo ./status.sh
sudo dujiao-next status
sudo dujiao-next logs api
sudo dujiao-next check-updates
sudo dujiao-next restore-help
```

## 卸载

停止容器并保留数据：

```bash
sudo ./uninstall.sh
```

删除数据，需要明确确认：

```bash
sudo ./uninstall.sh --purge
```

## 常见问题

### Certbot 失败

确认两个域名都已在 Cloudflare（CF）或 DNS 服务商添加 A 记录并解析到当前服务器公网 IP。如果使用 Cloudflare 代理，申请证书时建议切换为 DNS-only（灰云）。

### API 健康检查失败

执行：

```bash
sudo dujiao-next status
sudo dujiao-next logs api
```

然后检查 `/opt/dujiao-next/config/config.yml` 和 `/opt/dujiao-next/.env`。

### 已有部署怎么办

交互安装会提供升级、备份或退出选项。非交互安装会直接退出，避免破坏已有数据。

## 文档

- [Architecture](docs/architecture.md)
- [Commands](docs/commands.md)
- [Security](docs/security.md)
- [Troubleshooting](docs/troubleshooting.md)

## 参考

- Dujiao-Next 官方 Docker Compose 文档： https://dujiao-next.com/deploy/docker-compose
