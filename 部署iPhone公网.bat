@echo off
chcp 65001 >nul
cd /d "%~dp0"
title 马卡龙 - iPhone 公网部署

echo.
echo ========================================
echo  马卡龙女友跑酷 - iPhone 公网访问
echo  （不需要手机和电脑同一 Wi-Fi）
echo ========================================
echo.

echo [1/3] 构建网页版...
flutter build web --release
if errorlevel 1 (
  echo 构建失败
  pause
  exit /b 1
)

set "OUT=%USERPROFILE%\Desktop\马卡龙-iPhone网页版"
if exist "%OUT%" rmdir /s /q "%OUT%"
mkdir "%OUT%"
xcopy /E /I /Y "build\web\*" "%OUT%\" >nul
echo 已复制到桌面：%OUT%
echo.

echo [2/3] 选择部署方式（任选其一）：
echo.
echo  ┌─ 方式 A：GitHub Pages（推荐·永久免费公网地址）
echo  │  1. 本工程推到 GitHub
echo  │  2. 仓库 Settings - Pages - Source 选 GitHub Actions
echo  │  3. 推送后自动部署，地址形如：
echo  │     https://你的用户名.github.io/仓库名/
echo  │  4. iPhone Safari 打开 - 分享 - 添加到主屏幕
echo  │
echo  ├─ 方式 B：Netlify 拖拽（最快·不用写代码）
echo  │  1. 浏览器打开 https://app.netlify.com/drop
echo  │  2. 把文件夹拖进去：%OUT%
echo  │  3. 得到 https://xxx.netlify.app 公网链接
echo  │  4. iPhone Safari 打开即可
echo  │
echo  ├─ 方式 C：Cloudflare 隧道（本机临时公网，电脑要开着）
echo  │  未安装 cloudflared 可执行：
echo  │    winget install Cloudflare.cloudflared
echo  │
echo  └─ 方式 D：真 App Store ipa → docs/BUILD_IOS.md
echo.

where cloudflared >nul 2>&1
if errorlevel 1 (
  echo [3/3] 未检测到 cloudflared，跳过隧道模式。
  echo.
  echo  想用方式 C：先安装 cloudflared 再重新运行本脚本。
  echo  想用永久公网：优先方式 A 或 B。
  echo.
  pause
  exit /b 0
)

echo [3/3] 启动 Cloudflare 公网隧道（电脑关闭后链接失效）...
echo      本地服务 + 隧道启动中，请稍候...
echo      下方会出现 trycloudflare.com 开头的地址，复制到 iPhone Safari 打开。
echo      按 Ctrl+C 停止。
echo.

start "macaron-web" /MIN cmd /c "cd /d "%~dp0build\web" && python -m http.server 8080"
timeout /t 2 /nobreak >nul
cloudflared tunnel --url http://127.0.0.1:8080
