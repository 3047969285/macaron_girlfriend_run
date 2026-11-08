#!/usr/bin/env bash
# 把 build/web_server 上传到服务器并原子切换，可选安装 nginx 配置。
#
# 用法：
#   bash deploy/deploy_server.sh            # 只发布网页
#   bash deploy/deploy_server.sh --nginx    # 发布网页并安装 nginx 配置
#
# 可用环境变量覆盖：
#   SSH_USER=root SSH_HOST=47.104.137.7 SSH_PORT=22 \
#   SSH_KEY=~/.ssh/macaron_ecs_deploy_ed25519 \
#   REMOTE_ROOT=/var/www/macaron bash deploy/deploy_server.sh
#
# 服务器目录约定（与现有部署一致）：
#   /var/www/macaron/releases/<构建号>-<时间>  每次发布一个新目录
#   /var/www/macaron/current -> releases/...  软链原子切换，可随时回滚
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE="${BUNDLE:-$ROOT/build/web_server}"
SSH_HOST="${SSH_HOST:-47.104.137.7}"
SSH_USER="${SSH_USER:-root}"
SSH_PORT="${SSH_PORT:-22}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/macaron_ecs_deploy_ed25519}"
KNOWN_HOSTS="${KNOWN_HOSTS:-$HOME/.ssh/macaron_ecs_known_hosts}"
REMOTE_ROOT="${REMOTE_ROOT:-/var/www/macaron}"
RELEASES_DIR="$REMOTE_ROOT/releases"
CURRENT_LINK="$REMOTE_ROOT/current"
INSTALL_NGINX=0
if [ "${1:-}" = "--nginx" ]; then
  INSTALL_NGINX=1
fi

if [ ! -f "$BUNDLE/index.html" ]; then
  echo "找不到 $BUNDLE，请先运行："
  echo "  MSYS_NO_PATHCONV=1 py -3 scripts/build_web_release.py --base-href / --output build/web_server"
  exit 1
fi
if [ ! -f "$SSH_KEY" ]; then
  echo "找不到 SSH 私钥 $SSH_KEY"
  exit 1
fi

BUILD_ID="$(tr -d '[:space:]' < "$BUNDLE/.last_build_id" 2>/dev/null || true)"
BUILD_SHORT="${BUILD_ID:0:12}"
[ -n "$BUILD_SHORT" ] || BUILD_SHORT="$(date -u +%Y%m%d%H%M%S)"
RELEASE="$BUILD_SHORT-$(date -u +%Y%m%d%H%M%S)"

TARGET="$SSH_USER@$SSH_HOST"
SSH=(ssh -p "$SSH_PORT" -i "$SSH_KEY" -o UserKnownHostsFile="$KNOWN_HOSTS" -o StrictHostKeyChecking=accept-new)
SCP=(scp -P "$SSH_PORT" -i "$SSH_KEY" -o UserKnownHostsFile="$KNOWN_HOSTS" -o StrictHostKeyChecking=accept-new)

ARCHIVE="$(mktemp "${TMPDIR:-/tmp}/macaron-web.XXXXXX.tar.gz")"
trap 'rm -f "$ARCHIVE"' EXIT
echo "==> 打包 $BUNDLE"
tar -czf "$ARCHIVE" -C "$BUNDLE" .
echo "    包大小：$(du -h "$ARCHIVE" | cut -f1)"

echo "==> 上传到 $TARGET:/tmp/macaron-web.tar.gz"
"${SCP[@]}" "$ARCHIVE" "$TARGET:/tmp/macaron-web.tar.gz"

echo "==> 发布新版本 $RELEASE"
"${SSH[@]}" "$TARGET" "bash -s -- '$RELEASES_DIR' '$CURRENT_LINK' '$RELEASE'" <<'REMOTE'
set -euo pipefail
releases=$1
current=$2
name=$3
mkdir -p "$releases"
tmp="$releases/.incoming-$name"
rm -rf "$tmp"
mkdir -p "$tmp"
tar -xzf /tmp/macaron-web.tar.gz -C "$tmp"
chmod -R a+rX "$tmp"
mv "$tmp" "$releases/$name"
ln -sfn "$releases/$name" "$current.new"
mv -Tf "$current.new" "$current"
rm -f /tmp/macaron-web.tar.gz
now=$(readlink -f "$current")
# 保留当前版本和最近两个旧版本，方便回滚。
ls -dt "$releases"/* 2>/dev/null | grep -vx "$now" | tail -n +3 | xargs -r rm -rf
echo "已切换 $current -> $(readlink "$current")"
REMOTE

if [ "$INSTALL_NGINX" = 1 ]; then
  echo "==> 安装 nginx 配置"
  "${SCP[@]}" "$ROOT/deploy/nginx-macaron-http.conf" "$TARGET:/tmp/macaron-nginx.conf"
  "${SSH[@]}" "$TARGET" "bash -s -- '${NGINX_CONF:-/etc/nginx/conf.d/macaron.conf}'" <<'REMOTE'
set -euo pipefail
conf=$1
if ! nginx -V 2>&1 | grep -q gzip_static; then
  sed -i '/gzip_static on;/d' /tmp/macaron-nginx.conf
  echo "当前 nginx 未编译 gzip_static，已改用动态 gzip"
fi
backup=""
if [ -f "$conf" ]; then
  backup="$conf.bak.$(date +%Y%m%d%H%M%S)"
  cp "$conf" "$backup"
fi
install -m 644 /tmp/macaron-nginx.conf "$conf"
rm -f /tmp/macaron-nginx.conf
if ! nginx -t; then
  if [ -n "$backup" ]; then
    mv "$backup" "$conf"
    nginx -t || true
  else
    rm -f "$conf"
  fi
  echo "nginx 配置校验失败，已回滚" >&2
  exit 1
fi
nginx -s reload 2>/dev/null || systemctl reload nginx
echo "nginx 已重载"
REMOTE
fi

echo "==> 完成：http://$SSH_HOST/"
