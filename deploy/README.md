# 服务器部署（47.104.137.7）

## 1. 构建服务器包

服务器站点在根路径 `/`，与 GitHub Pages 的 `/macaron_girlfriend_run/` 不同：

```bash
MSYS_NO_PATHCONV=1 py -3 scripts/build_web_release.py \
  --base-href / --output build/web_server
```

产物在 `build/web_server`，同时生成 `.gz` 预压缩文件，供 nginx `gzip_static` 直接发送。

## 2. 授权 SSH 公钥

当前部署私钥：`~/.ssh/macaron_ecs_deploy_ed25519`

需要把对应公钥加到服务器账号的 `~/.ssh/authorized_keys`（在阿里云控制台的
Workbench / 远程连接里执行）：

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
cat >> ~/.ssh/authorized_keys <<'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH2kRR1R1V861r++/9brRneNHtvjgsD/u+0oYENJk2Q2 macaron-ecs-deploy
EOF
chmod 600 ~/.ssh/authorized_keys
restorecon -R ~/.ssh 2>/dev/null || true
```

然后用有 sudo 权限的账号执行一次部署。

## 3. 发布

```bash
# 只更新网页
bash deploy/deploy_server.sh

# 同时安装 nginx 配置（首次或配置有变化时）
SSH_USER=root bash deploy/deploy_server.sh --nginx
```

脚本会：

1. 把 `build/web_server` 打成 tar.gz 上传到 `/tmp`；
2. 旧站点改名为 `/var/www/macaron.bak.<时间>`，新包解压到 `/var/www/macaron`；
3. 只保留最近 3 个备份；
4. `--nginx` 时安装 `deploy/nginx-macaron-http.conf`，`nginx -t` 失败会自动回滚。

可用环境变量：`SSH_USER`、`SSH_HOST`、`SSH_PORT`、`SSH_KEY`、`REMOTE_DIR`、`NGINX_CONF`。

如果站点是宝塔/其他面板管理的，nginx 配置通常不在 `/etc/nginx/conf.d/`，
请把 `NGINX_CONF` 指到实际站点配置文件（例如
`/www/server/panel/vhost/nginx/47.104.137.7.conf`），或把配置内容合并进去，
避免出现两个 `server_name` 相同的 server 块。

## 4. 服务器侧优化内容

- `gzip_static`：`main.dart.js` 2.8MB → 0.8MB，`canvaskit.wasm` 7.2MB → 2.9MB；
- 入口文件 `no-cache`，图集 10 分钟、字体 1 天、音频/canvaskit 7 天；
- `sendfile`、`tcp_nopush`、`open_file_cache`、keepalive；
- 纯 HTTP 下不注册 Service Worker，也不会再弹离线准备失败的提示（代码已跳过）。

## 5. 当前阻断

服务器返回 `root@47.104.137.7: Permission denied (publickey)`，说明公钥尚未写入
服务器。完成第 2 步后即可直接执行第 3 步。
