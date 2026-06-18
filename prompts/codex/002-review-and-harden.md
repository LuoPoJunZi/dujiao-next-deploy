请对刚才生成的 Dujiao-Next 一键部署项目做一次严格代码审查和安全审查。

重点检查：
1. 是否有任何真实密钥、密码、域名、邮箱、token 被提交。
2. .gitignore 是否覆盖 .env、config.yml、data/、backups/、*.sql、*.tar.gz。
3. Redis/PostgreSQL 是否完全没有 ports。
4. API/User/Admin 是否只绑定 127.0.0.1。
5. Nginx 是否正确反代：
   - 前台 /
   - 前台 /api/
   - 前台 /uploads/
   - 前台 /sitemap.xml
   - 前台 /robots.txt
   - 后台 /
   - 后台 /api/
   - 后台 /uploads/
6. config.yml 是否自动替换 jwt.secret、user_jwt.secret、Redis 密码、PostgreSQL DSN。
7. install.sh 重复执行时是否会误删数据。
8. uninstall.sh 是否默认不删除数据，只有 --purge 才删除。
9. backup.sh 是否能备份 PostgreSQL、uploads、.env、config.yml、compose 文件。
10. update.sh 是否先备份再升级。
11. 是否有 bash -n / shellcheck 错误。
12. README 是否和脚本实际参数一致。
13. 是否存在 apt、docker、nginx、certbot 命令失败后继续执行的问题。
14. 是否有未加引号的变量导致路径空格或特殊字符问题。
15. 是否有 chmod 777 范围过大问题；如必须使用，请解释原因并限制到官方要求的数据目录。

请直接修复发现的问题，然后重新运行检查，并提交一个新的 git commit：
git commit -m "chore: harden scripts and documentation"