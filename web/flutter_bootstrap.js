{{flutter_js}}
{{flutter_build_config}}

(async function () {
  let version = String(Date.now());
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 3000);
  try {
    const manifest = new URL('.last_build_id', document.baseURI);
    manifest.searchParams.set('check', version);
    const response = await fetch(manifest, {
      cache: 'no-store',
      signal: controller.signal,
    });
    if (response.ok) {
      const buildId = (await response.text()).trim();
      if (/^[a-zA-Z0-9_-]{8,128}$/.test(buildId)) version = buildId;
    }
  } catch (_) {
    // 构建标识不可用时仍加载游戏，用本次访问的版本键避开旧脚本。
  } finally {
    clearTimeout(timeout);
  }

  for (const build of _flutter.buildConfig.builds) {
    if (build.mainJsPath) {
      const entrypoint = new URL(build.mainJsPath, document.baseURI);
      entrypoint.searchParams.set('v', version);
      build.mainJsPath = entrypoint.href;
    }
  }
  _flutter.loader.load();
})();
