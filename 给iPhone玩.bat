@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo.
echo [马卡龙] 正在构建 iPhone 网页版（Safari 可玩 + 可添加到主屏幕）...
echo.
echo  提示：若不想同 Wi-Fi，请改用「部署iPhone公网.bat」部署到 Netlify/GitHub。
echo.
flutter build web --release --no-web-resources-cdn --no-wasm-dry-run
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

echo ========================================
echo  iPhone 安装方式（无需 Mac）
echo ========================================
echo.
echo  方式 A - 同一 Wi-Fi 在线玩：
echo    1. 手机和电脑连同一个 Wi-Fi
echo    2. iPhone 用 Safari 打开：
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4"') do (
  for /f "tokens=1" %%b in ("%%a") do echo       http://%%b:8080
)
echo    3. 横屏玩；分享 - 添加到主屏幕 = 桌面图标
echo.
echo  方式 B - 离线文件夹（拷到 iPhone 需用文件 App + 在线服务）：
echo    桌面文件夹「马卡龙-iPhone网页版」
echo.
echo  方式 C - 真 .ipa 包（需 Mac 或 Codemagic 云构建）：
echo    见 docs/BUILD_IOS.md 与 codemagic.yaml
echo.
echo  按 Ctrl+C 可停止网页服务
echo ========================================
echo.
cd build\web
python -m http.server 8080
