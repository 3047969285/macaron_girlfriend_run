#!/usr/bin/env bash
# 在 Mac 上执行：bash scripts/build_ios.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> flutter pub get"
flutter pub get

echo "==> pod install"
cd ios
if ! command -v pod >/dev/null 2>&1; then
  echo "请先安装 CocoaPods: sudo gem install cocoapods"
  exit 1
fi
pod install
cd ..

echo "==> flutter build ipa (release)"
flutter build ipa --release

echo ""
echo "完成。IPA 目录:"
ls -la build/ios/ipa/ 2>/dev/null || ls -la build/ios/ 2>/dev/null || true
echo "详见 docs/BUILD_IOS.md"
