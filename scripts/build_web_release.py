#!/usr/bin/env python3
"""构建国内网络友好的 Flutter Web 包。

做三件事：
1. release + 本地 CanvasKit（不访问 Google CDN）；
2. 写入 .last_build_id，供离线引导判断版本；
3. 为 JS / JSON / wasm / 字体等文本资源生成 .gz，配合 nginx gzip_static 使用。

用法：
    py -3 scripts/build_web_release.py
    py -3 scripts/build_web_release.py --base-href /macaron_girlfriend_run/
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build" / "web"

TEXT_SUFFIXES = {
    ".js",
    ".json",
    ".html",
    ".css",
    ".svg",
    ".wasm",
    ".ttf",
    ".otf",
    ".txt",
    ".xml",
}
SKIP_NAMES = {".last_build_id"}


def find_flutter() -> str:
    found = shutil.which("flutter")
    if found:
        return found
    roots = []
    if os.environ.get("FLUTTER_ROOT"):
        roots.append(os.environ["FLUTTER_ROOT"])
    roots += [r"D:\flutter", r"C:\flutter", "/opt/flutter", "/usr/local/flutter"]
    for root in roots:
        for name in ("flutter.bat", "flutter"):
            candidate = Path(root) / "bin" / name
            if candidate.is_file():
                return str(candidate)
    raise SystemExit("找不到 flutter，请先把它加入 PATH 或设置 FLUTTER_ROOT。")


def run_flutter(flutter: str, base_href: str, output: Path) -> None:
    args = [
        "build",
        "web",
        "--release",
        f"--base-href={base_href}",
        f"--output={output}",
        "--no-web-resources-cdn",
        "--no-wasm-dry-run",
    ]
    command = [flutter, *args]
    if os.name == "nt" and flutter.lower().endswith(".bat"):
        command = ["cmd", "/c", *command]
    print("==>", " ".join(command), flush=True)
    subprocess.run(command, cwd=ROOT, check=True)


def prune_engine(build: Path) -> int:
    """删除本构建用不到的渲染器，减小上传体积。

    构建只用 CanvasKit（flutter_bootstrap 里 renderer=canvaskit），skwasm /
    wimp / experimental_webparagraph 以及 *.symbols 调试符号都不会被加载。
    """
    removed = 0
    for path in sorted(build.rglob("*"), reverse=True):
        if not path.is_file():
            continue
        rel = path.relative_to(build)
        if rel.parts[0] != "canvaskit":
            continue
        unused = (
            path.name.startswith(("skwasm", "wimp"))
            or path.name.endswith(".symbols")
            or (len(rel.parts) > 1 and rel.parts[1] == "experimental_webparagraph")
        )
        if unused:
            path.unlink()
            removed += 1
    for path in sorted(build.rglob("experimental_webparagraph"), reverse=True):
        if path.is_dir() and not any(path.iterdir()):
            path.rmdir()
    return removed


def write_build_id() -> str:
    """构建标识覆盖代码和资源，避免只换图集时离线缓存不失效。"""
    digest = hashlib.sha256()
    for path in sorted(BUILD.rglob("*")):
        if not path.is_file() or path.suffix == ".gz" or path.name in SKIP_NAMES:
            continue
        rel = path.relative_to(BUILD).as_posix().encode()
        digest.update(rel)
        data = path.read_bytes()
        digest.update(len(data).to_bytes(8, "little"))
        digest.update(data)
    build_id = digest.hexdigest()
    (BUILD / ".last_build_id").write_text(build_id, encoding="utf-8")
    return build_id


def compress(build: Path) -> tuple[int, int, int]:
    """生成 *.gz；返回（文件数, 原始字节, 压缩后字节）。"""
    for old in build.rglob("*.gz"):
        old.unlink()
    count = raw_total = gz_total = 0
    for path in sorted(build.rglob("*")):
        if not path.is_file() or path.name in SKIP_NAMES:
            continue
        if path.suffix.lower() not in TEXT_SUFFIXES:
            continue
        data = path.read_bytes()
        packed = gzip.compress(data, compresslevel=9, mtime=0)
        if len(packed) >= len(data) * 0.98:
            continue
        path.with_name(path.name + ".gz").write_bytes(packed)
        count += 1
        raw_total += len(data)
        gz_total += len(packed)
    return count, raw_total, gz_total


def main() -> None:
    global BUILD
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-href", default="/")
    parser.add_argument(
        "--output",
        default="build/web",
        help="输出目录（相对项目根目录或绝对路径），默认 build/web",
    )
    args = parser.parse_args()
    BUILD = Path(args.output)
    if not BUILD.is_absolute():
        BUILD = (ROOT / BUILD).resolve()

    run_flutter(find_flutter(), args.base_href, BUILD)
    removed = prune_engine(BUILD)
    build_id = write_build_id()
    count, raw_total, gz_total = compress(BUILD)

    print()
    print(f"构建标识: {build_id}")
    print(f"裁剪未用渲染器: {removed} 个文件")
    print(f"预压缩: {count} 个文件, {raw_total / 1048576:.2f} MB -> {gz_total / 1048576:.2f} MB")
    print(f"输出目录: {BUILD}")
    print("部署时请把整个 build/web 上传；服务器 nginx 参考 deploy/nginx-macaron.conf（需开启 gzip_static）。")


if __name__ == "__main__":
    main()
