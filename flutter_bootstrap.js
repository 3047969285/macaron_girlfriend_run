(()=>{var _={blink:!0,gecko:!1,webkit:!1,unknown:!1},K=()=>navigator.vendor==="Google Inc."||navigator.userAgent.includes("Edg/")?"blink":navigator.vendor==="Apple Computer, Inc."?"webkit":navigator.vendor===""&&navigator.userAgent.includes("Firefox")?"gecko":"unknown",C=K(),R=()=>typeof ImageDecoder>"u"?!1:C==="blink",B=()=>typeof Intl.v8BreakIterator<"u"&&typeof Intl.Segmenter<"u",z=()=>{let i=[0,97,115,109,1,0,0,0,1,5,1,95,1,120,0];return WebAssembly.validate(new Uint8Array(i))},M=()=>{let i=document.createElement("canvas");return i.width=1,i.height=1,i.getContext("webgl2")!=null?2:i.getContext("webgl")!=null?1:-1},D=()=>window.chrome&&chrome.runtime&&chrome.runtime.id,w={browserEngine:C,hasImageCodecs:R(),hasChromiumBreakIterators:B(),supportsWasmGC:z(),crossOriginIsolated:window.crossOriginIsolated,webGLVersion:M(),isChromeExtension:D()};function c(...i){return new URL(I(...i),document.baseURI).toString()}function I(...i){return i.filter(e=>!!e).map((e,n)=>n===0?S(e):F(S(e))).filter(e=>e.length).join("/")}function F(i){let e=0;for(;e<i.length&&i.charAt(e)==="/";)e++;return i.substring(e)}function S(i){let e=i.length;for(;e>0&&i.charAt(e-1)==="/";)e--;return i.substring(0,e)}function E(i,e){return i.canvasKitBaseUrl?i.canvasKitBaseUrl:e.engineRevision&&!e.useLocalCanvasKit?I("https://www.gstatic.com/flutter-canvaskit",e.engineRevision):"canvaskit"}var v=class{constructor(){this._scriptLoaded=!1}setTrustedTypesPolicy(e){this._ttPolicy=e}async loadEntrypoint(e){let{entrypointUrl:n=c("main.dart.js"),onEntrypointLoaded:t,nonce:r}=e||{};return this._loadJSEntrypoint(n,t,r)}async load(e,n,t,r,a){a??=l=>{l.initializeEngine(t).then(u=>u.runApp())};let{entrypointBaseUrl:s}=t,{entryPointBaseUrl:o}=t;if(!s&&o&&(console.warn("[deprecated] `entryPointBaseUrl` is deprecated and will be removed in a future release. Use `entrypointBaseUrl` instead."),s=o),e.compileTarget==="dart2wasm")return this._loadWasmEntrypoint(e,n,s,a);{let l=e.mainJsPath??"main.dart.js",u=c(s,l);return this._loadJSEntrypoint(u,a,r)}}didCreateEngineInitializer(e){typeof this._didCreateEngineInitializerResolve=="function"&&(this._didCreateEngineInitializerResolve(e),this._didCreateEngineInitializerResolve=null,delete _flutter.loader.didCreateEngineInitializer),typeof this._onEntrypointLoaded=="function"&&this._onEntrypointLoaded(e)}_loadJSEntrypoint(e,n,t){let r=typeof n=="function";if(!this._scriptLoaded){this._scriptLoaded=!0;let a=this._createScriptTag(e,t);if(r)console.debug("Injecting <script> tag. Using callback."),this._onEntrypointLoaded=n,document.head.append(a);else return new Promise((s,o)=>{console.debug("Injecting <script> tag. Using Promises. Use the callback approach instead!"),this._didCreateEngineInitializerResolve=s,a.addEventListener("error",o),document.head.append(a)})}}async _loadWasmEntrypoint(e,n,t,r){if(!this._scriptLoaded){this._scriptLoaded=!0,this._onEntrypointLoaded=r;let{mainWasmPath:a,jsSupportRuntimePath:s}=e,o=c(t,a),l=c(t,s);this._ttPolicy!=null&&(l=this._ttPolicy.createScriptURL(l));let d=(await import(l)).compileStreaming(fetch(o)),p;e.renderer==="skwasm"?p=(async()=>{let h=await n.skwasm;return window._flutter_skwasmInstance=h,{skwasm:h.wasmExports,skwasmWrapper:h,ffi:{memory:h.wasmMemory}}})():p=Promise.resolve({}),await(await(await d).instantiate(await p,{loadDynamicModule:async(h,j)=>{let A=fetch(c(t,h)),L=c(t,j);this._ttPolicy!=null&&(L=this._ttPolicy.createScriptURL(L));let x=import(L);return[await A,await x]}})).invokeMain()}}_createScriptTag(e,n){let t=document.createElement("script");t.type="application/javascript",n&&(t.nonce=n);let r=e;return this._ttPolicy!=null&&(r=this._ttPolicy.createScriptURL(e)),t.src=r,t}};async function T(i,e,n){if(e<0)return i;let t,r=new Promise((a,s)=>{t=setTimeout(()=>{s(new Error(`${n} took more than ${e}ms to resolve. Moving on.`,{cause:T}))},e)});return Promise.race([i,r]).finally(()=>{clearTimeout(t)})}var g=class{setTrustedTypesPolicy(e){this._ttPolicy=e}loadServiceWorker(e){if(!e||!("serviceWorker"in navigator))return Promise.resolve();let n=()=>{console.warn(`Loading the service worker using Flutter bootstrap is deprecated and will stop working in a future release.
For more details, see: https://github.com/flutter/flutter/issues/156910`)},t=()=>{let{serviceWorkerVersion:r,serviceWorkerUrl:a=c(`flutter_service_worker.js?v=${r}`),timeoutMillis:s=4e3}=e,o=a;this._ttPolicy!=null&&(o=this._ttPolicy.createScriptURL(o));let l=navigator.serviceWorker.register(o).then(u=>this._getNewServiceWorker(u,r)).then(this._waitForServiceWorkerActivation);return T(l,s,"prepareServiceWorker")};return e.serviceWorkerUrl!=null?(n(),t()):navigator.serviceWorker.getRegistration().then(r=>r?t():Promise.resolve())}async _getNewServiceWorker(e,n){if(!e.active&&(e.installing||e.waiting))return console.debug("Installing/Activating first service worker."),e.installing||e.waiting;if(e.active.scriptURL.endsWith(n))return console.debug("Loading from existing service worker."),e.active;{let t=await e.update();return console.debug("Updating service worker."),t.installing||t.waiting||t.active}}async _waitForServiceWorkerActivation(e){if(!e||e.state==="activated")if(e){console.debug("Service worker already active.");return}else throw new Error("Cannot activate a null service worker!");return new Promise((n,t)=>{e.addEventListener("statechange",()=>{e.state==="activated"&&(console.debug("Activated new service worker."),n())})})}};var y=class{constructor(e,n="flutter-js"){let t=e||[/\.js$/,/\.mjs$/];window.trustedTypes&&(this.policy=trustedTypes.createPolicy(n,{createScriptURL:function(r){if(r.startsWith("blob:"))return r;let a=new URL(r,window.location),s=a.pathname.split("/").pop();if(t.some(l=>l.test(s)))return a.toString();console.error("URL rejected by TrustedTypes policy",n,":",r,"(download prevented)")}}))}};var k=i=>{let e=WebAssembly.compileStreaming(fetch(i));return(n,t)=>((async()=>{let r=await e,a=await WebAssembly.instantiate(r,n);t(a,r)})(),{})};var U=(i,e,n,t)=>(window.flutterCanvasKitLoaded=(async()=>{if(window.flutterCanvasKit)return window.flutterCanvasKit;let r=n.hasChromiumBreakIterators&&n.hasImageCodecs;if(!r&&e.canvasKitVariant=="chromium")throw"Chromium CanvasKit variant specifically requested, but unsupported in this browser";let a=r&&e.canvasKitVariant!=="full",s=t;e.canvasKitVariant=="experimentalWebParagraph"?s=c(s,"experimental_webparagraph"):a&&(s=c(s,"chromium"));let o=c(s,"canvaskit.js");i.flutterTT.policy&&(o=i.flutterTT.policy.createScriptURL(o));let l=k(c(s,"canvaskit.wasm")),u=await import(o);return window.flutterCanvasKit=await u.default({instantiateWasm:l}),window.flutterCanvasKit})(),window.flutterCanvasKitLoaded);var W=async(i,e,n,t)=>{let a=!n.hasImageCodecs||!n.hasChromiumBreakIterators?"skwasm_heavy":e.enableWimp?"wimp":"skwasm",s=c(t,`${a}.js`),o=s;i.flutterTT.policy&&(o=i.flutterTT.policy.createScriptURL(o));let l=k(c(t,`${a}.wasm`));return await(await import(o)).default({skwasmSingleThreaded:e.enableWimp||!n.crossOriginIsolated||n.isChromeExtension||e.forceSingleThreadedSkwasm,instantiateWasm:l,locateFile:(d,p)=>d.endsWith(".ww.js")?URL.createObjectURL(new Blob([`
"use strict";

let eventListener;
eventListener = (message) => {
    const pendingMessages = [];
    const data = message.data;
    data["instantiateWasm"] = (info,receiveInstance) => {
        const instance = new WebAssembly.Instance(data["wasm"], info);
        return receiveInstance(instance, data["wasm"])
    };
    import(data.js).then(async (skwasm) => {
        await skwasm.default(data);

        removeEventListener("message", eventListener);
        for (const message of pendingMessages) {
            dispatchEvent(message);
        }
    });
    removeEventListener("message", eventListener);
    eventListener = (message) => {

        pendingMessages.push(message);
    };

    addEventListener("message", eventListener);
};
addEventListener("message", eventListener);
`],{type:"application/javascript"})):c(t,d),mainScriptUrlOrBlob:s})};var P=w.supportsWasmGC,G=P&&w.webGLVersion>0,b=class{async loadEntrypoint(e){let{serviceWorker:n,...t}=e||{},r=new y,a=new g;a.setTrustedTypesPolicy(r.policy),await a.loadServiceWorker(n).catch(o=>{console.warn("Exception while loading service worker:",o)});let s=new v;return s.setTrustedTypesPolicy(r.policy),this.didCreateEngineInitializer=s.didCreateEngineInitializer.bind(s),s.loadEntrypoint(t)}async load({serviceWorkerSettings:e,onEntrypointLoaded:n,nonce:t,config:r}={}){r??={};let a=_flutter.buildConfig;if(!a)throw"FlutterLoader.load requires _flutter.buildConfig to be set";let s=r.wasmAllowList?.[w.browserEngine]??_[w.browserEngine],o=m=>{switch(m){case"skwasm":return G&&s;default:return!0}},l=m=>m.compileTarget==="dart2wasm"&&!P||r.renderer&&r.renderer!=m.renderer?!1:o(m.renderer),u=a.builds.find(l);if(!u)throw"FlutterLoader could not find a build compatible with configuration and environment.";let d={};d.flutterTT=new y,e&&(d.serviceWorkerLoader=new g,d.serviceWorkerLoader.setTrustedTypesPolicy(d.flutterTT.policy),await d.serviceWorkerLoader.loadServiceWorker(e).catch(m=>{console.warn("Exception while loading service worker:",m)}));let p=E(r,a);u.renderer==="canvaskit"?d.canvasKit=U(d,r,w,p):u.renderer==="skwasm"&&(d.skwasm=W(d,r,w,p));let f=new v;return f.setTrustedTypesPolicy(d.flutterTT.policy),this.didCreateEngineInitializer=f.didCreateEngineInitializer.bind(f),f.load(u,d,r,t,n)}};window._flutter||(window._flutter={});window._flutter.loader||(window._flutter.loader=new b);})();
//# sourceMappingURL=flutter.js.map

if (!window._flutter) {
  window._flutter = {};
}
_flutter.buildConfig = {"engineRevision":"5a2a6a42cce67f965cf540fcecf616faca624aa1","builds":[{"compileTarget":"dart2js","renderer":"canvaskit","mainJsPath":"main.dart.js"}],"useLocalCanvasKit":true};


(async function () {
  const BUILD_KEY = 'macaron.build';
  const WARM_KEY = 'macaron.warm';
  const bootStartedAt = performance.now();
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

  // 慢网不自动预热：后台把 1Mbps 带宽吃满会让游戏一直卡。
  // Safari 没有 Network Information API，所以再用首帧耗时兜底判断。
  const isSlowNetwork = (firstFrameMs) => {
    const connection = navigator.connection;
    if (connection) {
      if (connection.saveData) return true;
      if (connection.effectiveType === 'slow-2g' || connection.effectiveType === '2g' || connection.effectiveType === '3g') {
        return true;
      }
      if (typeof connection.downlink === 'number' && connection.downlink > 0 && connection.downlink < 2) {
        return true;
      }
    }
    return firstFrameMs > 12000;
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
    for (const key of await loadAssetKeys()) {
      // 歌曲体积最大（几十 MB），播放时由 Service Worker 按需缓存，不参与启动后预热。
      if (key.startsWith('assets/audio/')) continue;
      urls.add(new URL(`assets/${key}`, base).href);
    }
    return [...urls];
  };

  // 读完整个响应，确保 Service Worker 把它写进缓存；任一失败就停止其余请求。
  const fetchAll = async (urls, concurrency, cache) => {
    let next = 0;
    let failed = false;
    const worker = async () => {
      while (!failed && next < urls.length) {
        const url = new URL(urls[next++], document.baseURI);
        // 已经在浏览器缓存里的文件直接复制进新离线包，不再重新下载一遍。
        const existing = await caches.match(url.href, { ignoreSearch: true });
        if (existing) {
          await cache.put(url.href, existing.clone());
          continue;
        }
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
  const warmUp = async (buildId, firstFrameMs) => {
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
    if (isSlowNetwork(firstFrameMs)) {
      showStatus('网络较慢，已跳过后台离线下载，游戏会更流畅。', true);
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
      await fetchAll(urls, 2, cache);
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
    showStatus('核心离线资源已准备，歌曲会在首次播放后缓存。', true);
  };

  // 新构建上线后旧缓存里的字体和图片都是过期文件，Service Worker 却会优先返回它们。
  // 所以在加载游戏资源前先清掉全部离线缓存；本次访问会在后台重新准备。
  const invalidateCaches = async (buildId) => {
    if (!sourceAvailable || readStored(BUILD_KEY) === buildId) return;
    if (!('caches' in window)) return;
    try {
      const keys = await caches.keys();
      await Promise.all(
        keys.filter((key) => key.startsWith('macaron-offline')).map((key) => caches.delete(key)),
      );
    } catch (err) {
      console.warn('旧离线缓存清理失败，本次仍会加载新版本资源', err);
    }
  };

  registerOfflineWorker();
  const buildId = await resolveBuildId();
  await invalidateCaches(buildId);
  // 记下已经看到过的版本；离线预热是否完整仍以 WARM_KEY 为准。
  writeStored(BUILD_KEY, buildId);
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
      const firstFrameMs = performance.now() - bootStartedAt;
      // 首帧后先让菜单和第一关资源喘口气，再开始后台离线下载。
      setTimeout(() => {
        warmUp(buildId, firstFrameMs).catch((err) => {
          showStatus('离线资源未准备完成，请保持联网并重新打开。');
          console.warn('离线预热未完成，下次打开会重试', err);
        });
      }, 3000);
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
