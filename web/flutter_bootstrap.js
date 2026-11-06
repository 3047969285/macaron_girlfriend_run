{{flutter_js}}
{{flutter_build_config}}

(async function () {
  const BUILD_KEY = 'macaron.build';
  const WARM_KEY = 'macaron.warm';
  const META_CACHE = 'macaron-offline-meta-v1';
  const BUNDLE_PREFIX = 'macaron-offline-bundle-';
  const ACTIVE_URL = new URL('__offline_active__', document.baseURI).href;
  let sourceAvailable = false;
  const status = document.getElementById('offline-status');
  const showStatus = (message, autoHide = false) => {
    if (!status) return;
    status.textContent = message;
    status.hidden = false;
    if (autoHide) setTimeout(() => { status.hidden = true; }, 6000);
  };

  // 隐私窗口或禁用存储时 localStorage 会抛错：读不到当作没有存档，写失败只影响离线兜底。
  const readStored = (key) => {
    try {
      return localStorage.getItem(key);
    } catch (_) {
      return null;
    }
  };
  const writeStored = (key, value) => {
    try {
      localStorage.setItem(key, value);
    } catch (_) {
      // 无法存档时照常启动
    }
  };

  // 离线 Service Worker 在启动前注册；不等待结果，挂起或失败都不阻塞游戏。
  const registerOfflineWorker = async () => {
    if (!('serviceWorker' in navigator)) {
      console.warn('当前页面不是安全上下文（需要 https 或 localhost），不启用离线缓存');
      return;
    }
    try {
      await navigator.serviceWorker.register('offline_sw.js', { scope: './' });
    } catch (err) {
      console.warn('离线缓存注册失败，游戏照常运行', err);
    }
  };

  // 在线使用来源的构建标识；离线使用上次完整缓存的版本。
  const resolveBuildId = async () => {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 3000);
    try {
      const url = new URL('.last_build_id', document.baseURI);
      url.searchParams.set('check', String(Date.now())); // 查询串用于绕过 CDN 缓存
      const response = await fetch(url, {
        cache: 'no-store',
        signal: controller.signal,
        headers: { 'X-Macaron-Warm': '1' },
      });
      if (response.ok) {
        const buildId = (await response.text()).trim();
        if (/^[a-zA-Z0-9_-]{8,128}$/.test(buildId)) {
          sourceAvailable = true;
          return buildId;
        }
      }
    } catch (err) {
      console.warn('构建标识不可用，改用本地存档', err);
    } finally {
      clearTimeout(timer);
    }
    return readStored(BUILD_KEY) || String(Date.now());
  };

  // Flutter 3.47 启动时读取 AssetManifest.bin.json：内容是 StandardMessageCodec 二进制的 base64 字符串。
  // 旧版 Flutter 生成 AssetManifest.json（普通 JSON 对象），两种都支持。
  const loadAssetKeys = async () => {
    const legacy = await fetch(new URL('assets/AssetManifest.json', document.baseURI));
    if (legacy.ok) return Object.keys(await legacy.json());
    const response = await fetch(new URL('assets/AssetManifest.bin.json', document.baseURI));
    if (!response.ok) throw new Error(`资源清单不可用（${response.status}）`);
    const bytes = Uint8Array.from(atob(await response.json()), (c) => c.charCodeAt(0));
    return decodeAssetKeys(bytes);
  };

  // 解码 StandardMessageCodec 的 map<String, …>，只支持清单用到的类型，返回顶层资源键。
  const decodeAssetKeys = (bytes) => {
    const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    const text = new TextDecoder();
    let pos = 0;
    const readSize = () => {
      const first = bytes[pos++];
      if (first < 254) return first;
      const size = first === 254 ? view.getUint16(pos, true) : view.getUint32(pos, true);
      pos += first === 254 ? 2 : 4;
      return size;
    };
    const readValue = () => {
      const tag = bytes[pos++];
      if (tag === 0) return null;
      if (tag === 1) return true;
      if (tag === 2) return false;
      if (tag === 7) {
        const size = readSize();
        const value = text.decode(bytes.subarray(pos, pos + size));
        pos += size;
        return value;
      }
      if (tag === 12) return Array.from({ length: readSize() }, () => readValue());
      if (tag === 13) {
        const map = new Map();
        for (let count = readSize(); count > 0; count--) map.set(readValue(), readValue());
        return map;
      }
      throw new Error(`资源清单含不支持的类型 ${tag}`);
    };
    const manifest = readValue();
    if (!(manifest instanceof Map)) throw new Error('资源清单格式不对');
    return [...manifest.keys()];
  };

  // 预热范围：启动用到的核心文件 + 本页已加载的同源资源（含 canvaskit 实际用到的那一套）+ 清单里的全部资源。
  const warmUpUrls = async () => {
    const base = document.baseURI;
    const core = [
      base,
      new URL('index.html', base).href,
      new URL('.last_build_id', base).href,
      new URL('flutter.js', base).href,
      new URL('flutter_bootstrap.js', base).href,
      new URL('manifest.json', base).href,
      new URL('offline_fonts.json', base).href,
      new URL('assets/FontManifest.json', base).href,
      new URL('assets/AssetManifest.bin.json', base).href,
      new URL('assets/AssetManifest.bin', base).href,
      new URL('icons/Icon-192.png', base).href,
      new URL('icons/Icon-512.png', base).href,
      new URL('icons/Icon-maskable-192.png', base).href,
      new URL('icons/Icon-maskable-512.png', base).href,
      ..._flutter.buildConfig.builds.map((build) => build.mainJsPath).filter(Boolean),
    ];
    // 必须先于清单请求取快照，否则 AssetManifest.json 的探测请求（可能 404）会混进来。
    const loaded = performance
      .getEntriesByType('resource')
      .filter((entry) => new URL(entry.name).origin === location.origin && !(entry.responseStatus >= 400))
      .map((entry) => entry.name);
    const urls = new Set([...core, ...loaded]);
    const fonts = await fetch(new URL('offline_fonts.json', base), {
      cache: 'no-store',
      headers: { 'X-Macaron-Warm': '1' },
    });
    if (!fonts.ok) throw new Error(`离线字体清单不可用（${fonts.status}）`);
    for (const path of await fonts.json()) {
      if (typeof path !== 'string' || !/^fonts\/[a-zA-Z0-9_./-]+\.woff2$/.test(path) || path.includes('..')) {
        throw new Error('离线字体清单格式不对');
      }
      urls.add(new URL(path, base).href);
    }
    for (const key of await loadAssetKeys()) urls.add(new URL(`assets/${key}`, base).href);
    return [...urls];
  };

  // 读完整个响应，确保 Service Worker 把它写进缓存；任一失败就停止其余请求。
  const fetchAll = async (urls, concurrency, cache) => {
    let next = 0;
    let failed = false;
    const worker = async () => {
      while (!failed && next < urls.length) {
        const url = new URL(urls[next++], document.baseURI);
        const response = await fetch(url.href, {
          cache: 'no-store',
          headers: { 'X-Macaron-Warm': '1' },
        });
        if (!response.ok) throw new Error(`预热失败：${response.status} ${response.url}`);
        url.search = '';
        await cache.put(url.href, response);
      }
    };
    try {
      await Promise.all(Array.from({ length: concurrency }, worker));
    } catch (err) {
      failed = true;
      throw err;
    }
  };

  // 首帧后在后台预热：在线、没开省流量、本版本还没预热过才做；全部成功才记下版本键。
  const warmUp = async (buildId) => {
    if (!('serviceWorker' in navigator)) {
      showStatus('此地址无法保存离线资源，请使用受信任的 HTTPS 地址。');
      return;
    }
    if (!sourceAvailable) {
      if (readStored(WARM_KEY) !== buildId) {
        showStatus('离线资源尚未完整准备，请联网后重新打开。');
      }
      return;
    }
    if (navigator.connection?.saveData) {
      showStatus('省流量模式已开启，离线资源尚未准备。');
      return;
    }
    const sw = navigator.serviceWorker;
    if (!sw.controller) {
      // 首次访问时 Service Worker 可能刚接管页面；等它接管，否则请求不会进入缓存。
      await new Promise((resolve) => {
        const timer = setTimeout(resolve, 15000);
        sw.addEventListener(
          'controllerchange',
          () => {
            clearTimeout(timer);
            resolve();
          },
          { once: true },
        );
      });
      if (!sw.controller) throw new Error('离线服务未接管页面');
    }
    const urls = await warmUpUrls();
    const meta = await caches.open(META_CACHE);
    const active = await meta.match(ACTIVE_URL);
    const currentBundle = active ? await active.text() : null;
    if (readStored(WARM_KEY) === buildId) {
      if (currentBundle?.startsWith(BUNDLE_PREFIX) && (await caches.keys()).includes(currentBundle)) {
        const cache = await caches.open(currentBundle);
        const entries = await Promise.all(urls.map((url) => cache.match(url, { ignoreSearch: true })));
        if (entries.every(Boolean)) return;
      }
    }
    showStatus('正在准备离线资源，请保持联网并不要关闭页面。');
    const nextBundle = `${BUNDLE_PREFIX}${buildId}-${Date.now()}-${Math.random().toString(36).slice(2)}`;
    try {
      const cache = await caches.open(nextBundle);
      await fetchAll(urls, 4, cache);
      const latest = await fetch(new URL('.last_build_id', document.baseURI), {
        cache: 'no-store',
        headers: { 'X-Macaron-Warm': '1' },
      });
      if (!latest.ok || (await latest.text()).trim() !== buildId) {
        throw new Error('缓存过程中版本发生变化');
      }
      await meta.put(ACTIVE_URL, new Response(nextBundle));
      writeStored(BUILD_KEY, buildId);
      writeStored(WARM_KEY, buildId);
    } catch (err) {
      await caches.delete(nextBundle);
      throw err;
    }
    if (currentBundle && currentBundle !== nextBundle) {
      await caches.delete(currentBundle).catch(() => {});
    }
    showStatus('离线资源准备完成，现在可以断网游玩。', true);
  };

  registerOfflineWorker();
  const buildId = await resolveBuildId();
  for (const build of _flutter.buildConfig.builds) {
    if (build.mainJsPath) {
      const entrypoint = new URL(build.mainJsPath, document.baseURI);
      entrypoint.searchParams.set('v', buildId);
      build.mainJsPath = entrypoint.href;
    }
  }
  window.addEventListener(
    'flutter-first-frame',
    () => {
      warmUp(buildId).catch((err) => {
        showStatus('离线资源未准备完成，请保持联网并重新打开。');
        console.warn('离线预热未完成，下次打开会重试', err);
      });
    },
    { once: true },
  );
  // 字体回退地址指向本站（web/fonts），不再访问 fonts.gstatic.com。
  _flutter.loader.load({
    config: {
      fontFallbackBaseUrl: new URL('fonts/', document.baseURI).href,
    },
  });
})();
