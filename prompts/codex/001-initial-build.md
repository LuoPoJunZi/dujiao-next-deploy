你是资深 Linux 运维工程师 + Bash 工程师。请从零创建一个新的开源项目：dujiao-next-deploy，目标是在 Ubuntu / Debian 服务器上一键部署 Dujiao-Next。

重要：不要 fork、复制或照搬 https://github.com/slobys/dujiao-next-one-click 的代码。它只能作为功能范围参考。请用自己的目录结构、脚本实现、函数命名、文档表达和错误处理方式完成。

参考资料：
1. 官方 Docker Compose 文档：
   https://dujiao-next.com/deploy/docker-compose
2. 可参考但不要照搬的项目：
   https://github.com/slobys/dujiao-next-one-click
3. 我的实际部署记录博客：
   https://blog.luopojunzi.com/p/Dujiao-Next/

项目目标：
做一个 Linux 上的 Dujiao-Next 一键部署脚本仓库，支持：
- Docker / Docker Compose 自动安装
- Nginx 自动安装与反向代理配置
- Certbot 自动申请 HTTPS，可选择跳过
- Dujiao-Next Docker Compose 部署
- 默认使用 PostgreSQL + Redis 生产方案
- 可选 SQLite + Redis 轻量方案，作为高级选项或后续功能
- 自动生成 .env
- 自动下载并修改 config/config.yml
- 自动生成强随机密钥和密码
- 自动创建 /opt/dujiao-next 目录结构
- 自动处理权限
- 自动启动容器
- 自动做健康检查
- 提供升级、备份、恢复提示、卸载、状态检查、菜单入口
- 生成 README、CHANGELOG、LICENSE、docs/ 文档
- 最终提交到 Git，并在有权限时 push 到 GitHub；如果当前环境没有 GitHub 权限，则完成本地 commit，并输出清晰的 push 命令。

官方部署要求必须遵守：
- 镜像：
  - dujiaonext/api:${TAG}
  - dujiaonext/user:${TAG}
  - dujiaonext/admin:${TAG}
- 部署目录：
  - /opt/dujiao-next/config
  - /opt/dujiao-next/data/uploads
  - /opt/dujiao-next/data/logs
  - /opt/dujiao-next/data/redis
  - /opt/dujiao-next/data/postgres
  - /opt/dujiao-next/data/db 可为 SQLite 预留
- API 配置文件挂载到容器内 /app/config.yml
- 生产默认使用 PostgreSQL + Redis：
  - PostgreSQL 容器名：dujiaonext-postgres
  - Redis 容器名：dujiaonext-redis
  - API 容器名：dujiaonext-api
  - User 容器名：dujiaonext-user
  - Admin 容器名：dujiaonext-admin
- Redis 和 PostgreSQL 绝对不能映射到公网端口
- API/User/Admin 端口必须只绑定 127.0.0.1：
  - API: 127.0.0.1:8080:8080
  - User: 127.0.0.1:8081:80
  - Admin: 127.0.0.1:8082:80
- Nginx 对公网开放 80/443，反代到本机 127.0.0.1
- 前台域名需要反代：
  - / -> http://127.0.0.1:8081
  - /api/ -> http://127.0.0.1:8080/api/
  - /uploads/ -> http://127.0.0.1:8080/uploads/
  - /sitemap.xml -> http://127.0.0.1:8080/sitemap.xml
  - /robots.txt -> http://127.0.0.1:8080/robots.txt
- 后台域名需要反代：
  - / -> http://127.0.0.1:8082
  - /api/ -> http://127.0.0.1:8080/api/
  - /uploads/ -> http://127.0.0.1:8080/uploads/
- config.yml 中必须自动替换：
  - database.driver
  - database.dsn
  - redis.enabled
  - redis.host = redis
  - redis.port = 6379
  - redis.password = 自动生成的 REDIS_PASSWORD
  - queue.enabled
  - queue.host = redis
  - queue.port = 6379
  - queue.password = 同 REDIS_PASSWORD
  - jwt.secret = 自动生成 32 位以上强随机字符串
  - user_jwt.secret = 自动生成 32 位以上强随机字符串
- .env 中必须包含：
  - TAG
  - TZ
  - API_PORT
  - USER_PORT
  - ADMIN_PORT
  - DJ_DEFAULT_ADMIN_USERNAME
  - DJ_DEFAULT_ADMIN_PASSWORD
  - REDIS_PASSWORD
  - POSTGRES_DB
  - POSTGRES_USER
  - POSTGRES_PASSWORD

脚本设计要求：
1. 用 Bash 编写，兼容 Ubuntu 22.04+ / Debian 12+。
2. 所有脚本必须使用：
   - set -Eeuo pipefail
   - 清晰的 log/info/warn/error/success 函数
   - trap 捕获错误，输出失败行号和下一步排查建议
3. 不要使用危险的无提示删除。
4. 不要把真实密码、域名、邮箱、token、SSH key 写进仓库。
5. .env、config.yml、backup/、data/、*.tar.gz、*.sql 必须加入 .gitignore。
6. 所有生成的密码和密钥必须通过 openssl rand 或 /dev/urandom 生成，不要写死默认弱密码。
7. 管理员默认密码也应自动生成，安装完成后打印一次，并提示用户保存。
8. 安装过程需要交互式询问：
   - 前台域名，例如 shop.example.com
   - 后台域名，例如 admin.example.com
   - 管理员用户名，默认 admin
   - Dujiao-Next 镜像 TAG，默认自动获取 GitHub latest release；失败时使用 latest，不要写死旧版本
   - 部署目录，默认 /opt/dujiao-next
   - 是否申请 HTTPS
   - 申请 HTTPS 的邮箱
   - 是否处理防火墙
9. 需要支持非交互模式参数，例如：
   ./install.sh --user-domain shop.example.com --admin-domain admin.example.com --email me@example.com --tag latest --yes --https
10. 安装前预检：
   - 必须 root 或 sudo
   - 检测系统发行版和版本
   - 检测内存、磁盘空间
   - 检测 80/443/8080/8081/8082 端口占用
   - 检测 DNS 是否解析到当前服务器公网 IP，可失败但给出警告
   - 检测 Cloudflare 代理时给出“申请证书阶段建议灰云/仅 DNS”的提示
   - 检测 curl、openssl、sed、awk、grep、ss、systemctl 是否可用
11. Docker 安装：
   - 优先使用 Docker 官方 apt 源
   - 卸载可能冲突的旧 docker.io / docker-compose / podman-docker 等包时要提示
   - 安装 docker-ce、docker-ce-cli、containerd.io、docker-buildx-plugin、docker-compose-plugin
   - systemctl enable --now docker
   - docker compose version 校验
12. Nginx：
   - apt install nginx
   - mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
   - 写入 /etc/nginx/sites-available/dujiao-next.conf
   - ln -sf 到 sites-enabled
   - 不要直接覆盖用户已有同名配置，若存在则备份为 .bak-时间戳
   - nginx -t 通过后 reload
13. Certbot：
   - apt install certbot python3-certbot-nginx
   - certbot --nginx -d 前台域名 -d 后台域名 --email 邮箱 --agree-tos --no-eff-email --redirect
   - certbot renew --dry-run 作为可选检查
14. Compose：
   - 生成 docker-compose.postgres.yml
   - 可选生成 docker-compose.sqlite.yml
   - 服务包含 redis、postgres、api、user、admin
   - redis/postgres 加 healthcheck
   - api 加 healthcheck: http://127.0.0.1:8080/health
   - user/admin depends_on api healthy
   - redis/postgres 不写 ports
   - api/user/admin 只绑定 127.0.0.1
15. 启动：
   - docker compose --env-file .env -f docker-compose.postgres.yml pull
   - docker compose --env-file .env -f docker-compose.postgres.yml up -d
   - 等待 health check
   - curl -fsS http://127.0.0.1:8080/health
   - curl -I http://127.0.0.1:8081
   - curl -I http://127.0.0.1:8082
   - 输出公网访问地址
16. 升级脚本 update.sh：
   - 先备份
   - 支持 ./update.sh 或 ./update.sh v1.2.3
   - 未传 tag 时自动取 latest release，失败使用 latest
   - 更新 .env 的 TAG
   - docker compose pull
   - docker compose up -d
   - 健康检查
   - 若失败，给出回滚提示
17. 备份脚本 backup.sh：
   - 备份 .env、config/config.yml、docker-compose.postgres.yml、data/uploads
   - PostgreSQL 使用 docker exec dujiaonext-postgres pg_dump -U ${POSTGRES_USER} -d ${POSTGRES_DB}
   - 备份输出到 /opt/dujiao-next/backups 或 /root/dujiao-next-backups
   - 文件名包含日期时间
18. 状态脚本 status.sh：
   - docker compose ps
   - API health
   - Nginx 状态
   - Certbot 证书信息
   - 最近 100 行 API 日志入口提示
19. 卸载脚本 uninstall.sh：
   - 强制二次确认
   - 默认只停容器，不删除数据
   - 提供 --purge 才删除 /opt/dujiao-next 数据
   - 删除 Nginx 配置前备份
20. 菜单脚本 menu.sh：
   - 安装
   - 升级
   - 备份
   - 查看状态
   - 查看日志
   - 重启服务
   - 卸载
21. docs：
   - docs/architecture.md：说明部署架构
   - docs/troubleshooting.md：收录常见问题
   - docs/security.md：说明安全边界
   - docs/commands.md：常用命令
22. README：
   - 项目介绍
   - 支持系统
   - 快速开始
   - 一键命令
   - 交互安装
   - 非交互安装
   - 目录结构
   - 端口说明
   - 安全说明
   - 备份/升级/卸载
   - 常见问题
   - 声明：本项目是非官方部署辅助脚本，Dujiao-Next 版权归原项目所有
23. License 使用 MIT。
24. 添加 shellcheck 友好的写法；如果环境有 shellcheck，则运行 shellcheck *.sh。
25. 生成 GitHub Actions：
   - .github/workflows/shellcheck.yml
   - 对 *.sh 运行 shellcheck
26. 创建 AGENTS.md，写明以后维护该项目时的开发规范。

请完成以下交付物：
- install.sh
- update.sh
- backup.sh
- status.sh
- uninstall.sh
- menu.sh
- lib/common.sh
- templates/docker-compose.postgres.yml.tpl
- templates/docker-compose.sqlite.yml.tpl
- templates/nginx.dujiao-next.conf.tpl
- README.md
- CHANGELOG.md
- LICENSE
- AGENTS.md
- docs/architecture.md
- docs/troubleshooting.md
- docs/security.md
- docs/commands.md
- .gitignore
- .github/workflows/shellcheck.yml

实现完成后：
1. 运行 bash -n 检查所有 shell 脚本。
2. 如果有 shellcheck，运行 shellcheck。
3. 检查 README 中的命令是否和脚本参数一致。
4. 初始化 git 仓库。
5. git add .
6. git commit -m "feat: initial Dujiao-Next one-click deploy toolkit"
7. 如果当前环境已配置 GitHub 远程仓库和权限，则 push 到 main。
8. 如果没有 GitHub 权限，不要伪造结果；请输出我应该执行的命令，例如：
   git remote add origin git@github.com:<USER>/<REPO>.git
   git branch -M main
   git push -u origin main

验收标准：
- 不能提交 .env、config.yml、真实域名、真实邮箱、真实密码、数据库、备份文件。
- Redis/PostgreSQL 不能暴露公网端口。
- API/User/Admin 必须只绑定 127.0.0.1。
- Nginx 必须包含 /api/、/uploads/、/sitemap.xml、/robots.txt 的正确反代。
- 安装脚本重复执行时不能破坏已有数据；如果检测到已有部署，应提示升级、备份、重装或退出。
- 所有危险操作必须二次确认。
- README 要能让新手照着跑。