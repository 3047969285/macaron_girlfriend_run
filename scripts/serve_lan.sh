#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

build=1
for arg in "$@"; do
  case "$arg" in
    --no-build) build=0 ;;
    -h|--help) echo '用法：scripts/serve_lan.sh [--no-build]'; exit 0 ;;
    *) echo "未知参数：$arg" >&2; exit 2 ;;
  esac
done

if ! command -v flutter >/dev/null 2>&1; then
  export PATH="${FLUTTER_ROOT:-$HOME/development/flutter}/bin:$PATH"
fi
if [ "$build" -eq 1 ]; then
  flutter build web --release --no-web-resources-cdn --no-wasm-dry-run
fi
exec python3 scripts/serve_lan.py
