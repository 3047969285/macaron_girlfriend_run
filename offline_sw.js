// 马卡龙离线缓存。网络优先：4 秒内拿到 200 就返回并写入缓存，否则用缓存；
// 带 Range 的请求（音频）从完整缓存里切出字节范围，返回 206。
const CACHE = 'macaron-offline-v2';
const META_CACHE = 'macaron-offline-meta-v1';
const BUNDLE_PREFIX = 'macaron-offline-bundle-';
const ACTIVE_URL = new URL('__offline_active__', self.registration.scope).href;
const NETWORK_TIMEOUT_MS = 4000;

self.addEventListener('install', (event) => event.waitUntil(self.skipWaiting()));

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys.filter((key) => /^macaron-offline-v\d+$/.test(key) && key !== CACHE).map((key) => caches.delete(key)),
        ),
      )
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET' || new URL(request.url).origin !== self.location.origin) return;
  if (request.headers.get('X-Macaron-Warm') === '1') {
    event.respondWith(fetch(request));
    return;
  }
  event.respondWith(
    request.headers.has('Range')
      ? rangeFromCache(request)
      : isImmutable(request.url)
        ? cacheFirst(event)
        : networkFirst(event),
  );
});

// 图集、字体、音频等文件在同一个构建里不会变：有缓存就直接返回，
// 不再为每个文件等 4 秒网络超时。页面、清单和 main.dart.js 仍走网络优先。
function isImmutable(url) {
  const { pathname } = new URL(url);
  return pathname.includes('/canvaskit/') ||
    pathname.includes('/assets/assets/') ||
    pathname.includes('/fonts/') ||
    pathname.includes('/icons/');
}

async function cacheFirst(event) {
  const { request } = event;
  const cached = await matchCache(request);
  if (cached) return cached;
  const response = await fetch(request);
  if (response.status === 200) {
    const cache = await caches.open(CACHE).catch((err) => {
      console.warn('[offline] 缓存不可用，直接走网络', err);
      return null;
    });
    if (cache) {
      // 写缓存失败只影响下次离线，不影响本次响应。
      event.waitUntil(
        cache.put(cacheKey(request.url), response.clone()).catch((err) => {
          console.warn('[offline] 缓存写入失败', err);
        }),
      );
    }
  }
  return response;
}

// 缓存键去掉查询串，同一文件的新旧版本只保留一份。
function cacheKey(url) {
  const key = new URL(url);
  key.search = '';
  return key.href;
}

// 缓存不可用（存储被禁用等）时当作没有缓存，页面照常走网络。
async function matchCache(request) {
  try {
    const meta = await caches.open(META_CACHE);
    const marker = await meta.match(ACTIVE_URL);
    const bundle = marker && await marker.text();
    if (bundle?.startsWith(BUNDLE_PREFIX)) {
      const stored = await (await caches.open(bundle)).match(request, { ignoreSearch: true });
      if (stored) return stored;
    }
    return await (await caches.open(CACHE)).match(request, { ignoreSearch: true });
  } catch (err) {
    console.warn('[offline] 读取缓存失败', err);
    return undefined;
  }
}

async function networkFirst(event) {
  const { request } = event;
  const network = fetch(request);
  const cache = await caches.open(CACHE).catch((err) => {
    console.warn('[offline] 缓存不可用，直接走网络', err);
    return null;
  });
  if (cache) {
    // 完整的 200 写入缓存；写入失败只影响下次离线，不影响本次响应。
    event.waitUntil(
      network.then(
        (response) => {
          if (response.status === 200) {
            return cache
              .put(cacheKey(request.url), response.clone())
              .catch((err) => console.warn('[offline] 缓存写入失败', err));
          }
        },
        () => {}, // 网络错误由下面的回退处理
      ),
    );
  }
  // 超时只决定先用谁：网络请求仍在后台完成，结果照常写入缓存。
  const timeout = new Promise((resolve) => setTimeout(resolve, NETWORK_TIMEOUT_MS));
  let response = null;
  try {
    response = await Promise.race([network, timeout]);
  } catch (_) {
    // 网络失败：优先用缓存；没有缓存时下面会把网络错误交给浏览器。
  }
  if (response?.ok) return response;
  return (await matchCache(request)) || network;
}

// 缓存里有完整文件就切片返回 206；否则走网络（206 从不写入缓存）。
async function rangeFromCache(request) {
  const cached = await matchCache(request);
  if (!cached || cached.status !== 200) return fetch(request);
  const bytes = await cached.arrayBuffer();
  const range = parseRange(request.headers.get('Range'), bytes.byteLength);
  if (!range) return fetch(request);
  const { start, end } = range;
  const body = bytes.slice(start, end + 1);
  return new Response(body, {
    status: 206,
    statusText: 'Partial Content',
    headers: {
      'Content-Type': cached.headers.get('Content-Type') || 'application/octet-stream',
      'Content-Range': `bytes ${start}-${end}/${bytes.byteLength}`,
      'Content-Length': String(body.byteLength),
      'Accept-Ranges': 'bytes',
    },
  });
}

// 只处理单段 bytes=a-b / bytes=a- / bytes=-n；多段或越界返回 null，交给网络判定。
function parseRange(header, size) {
  const match = /^bytes=(\d*)-(\d*)$/.exec(header || '');
  if (!match || (match[1] === '' && match[2] === '')) return null;
  const [, from, to] = match;
  const start = from === '' ? Math.max(size - Number(to), 0) : Number(from);
  const end = from === '' || to === '' ? size - 1 : Math.min(Number(to), size - 1);
  return start <= end && start < size ? { start, end } : null;
}
