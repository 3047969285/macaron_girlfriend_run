(()=>{var C={blink:!0,gecko:!1,webkit:!1,unknown:!1},A=()=>navigator.vendor==="Google Inc."||navigator.userAgent.includes("Edg/")?"blink":navigator.vendor==="Apple Computer, Inc."?"webkit":navigator.vendor===""&&navigator.userAgent.includes("Firefox")?"gecko":"unknown",T=A(),x=()=>typeof ImageDecoder>"u"?!1:T==="blink",R=()=>typeof Intl.v8BreakIterator<"u"&&typeof Intl.Segmenter<"u",j=()=>typeof window.TextCluster<"u",B=()=>{let n=[0,97,115,109,1,0,0,0,1,5,1,95,1,120,0];return WebAssembly.validate(new Uint8Array(n))},K=()=>{let n=document.createElement("canvas");return n.width=1,n.height=1,n.getContext("webgl2")!=null?2:n.getContext("webgl")!=null?1:-1},$=()=>window.chrome&&chrome.runtime&&chrome.runtime.id,f={browserEngine:T,hasImageCodecs:x(),hasChromiumBreakIterators:R(),hasTextCluster:j(),supportsWasmGC:B(),crossOriginIsolated:window.crossOriginIsolated,webGLVersion:K(),isChromeExtension:$()};function m(...n){return new URL(W(...n),document.baseURI).toString()}function W(...n){return n.filter(e=>!!e).map((e,s)=>s===0?L(e):F(L(e))).filter(e=>e.length).join("/")}function F(n){let e=0;for(;e<n.length&&n.charAt(e)==="/";)e++;return n.substring(e)}function L(n){let e=n.length;for(;e>0&&n.charAt(e-1)==="/";)e--;return n.substring(0,e)}function _(n,e){return n.canvasKitBaseUrl?n.canvasKitBaseUrl:e.engineRevision&&!e.useLocalCanvasKit?W("https://www.gstatic.com/flutter-canvaskit",e.engineRevision):"canvaskit"}var g=class{constructor(){this._scriptLoaded=!1}setTrustedTypesPolicy(e){this._ttPolicy=e}async loadEntrypoint(e){let{entrypointUrl:s=m("main.dart.js"),onEntrypointLoaded:t,nonce:r}=e||{};return this._loadJSEntrypoint(s,t,r)}async load(e,s,t,r,i){i??=a=>{a.initializeEngine(t).then(l=>l.runApp())};let{entrypointBaseUrl:o}=t,{entryPointBaseUrl:c}=t;if(!o&&c&&(console.warn("[deprecated] `entryPointBaseUrl` is deprecated and will be removed in a future release. Use `entrypointBaseUrl` instead."),o=c),e.compileTarget==="dart2wasm")return this._loadWasmEntrypoint(e,s,o,i);{let a=e.mainJsPath??"main.dart.js",l=m(o,a);return this._loadJSEntrypoint(l,i,r)}}didCreateEngineInitializer(e){typeof this._didCreateEngineInitializerResolve=="function"&&(this._didCreateEngineInitializerResolve(e),this._didCreateEngineInitializerResolve=null,delete _flutter.loader.didCreateEngineInitializer),typeof this._onEntrypointLoaded=="function"&&this._onEntrypointLoaded(e)}_loadJSEntrypoint(e,s,t){let r=typeof s=="function";if(!this._scriptLoaded){this._scriptLoaded=!0;let i=this._createScriptTag(e,t);if(r)console.debug("Injecting <script> tag. Using callback."),this._onEntrypointLoaded=s,document.head.append(i);else return new Promise((o,c)=>{console.debug("Injecting <script> tag. Using Promises. Use the callback approach instead!"),this._didCreateEngineInitializerResolve=o,i.addEventListener("error",c),document.head.append(i)})}}async _loadWasmEntrypoint(e,s,t,r){if(!this._scriptLoaded){this._scriptLoaded=!0,this._onEntrypointLoaded=r;let{mainWasmPath:i,jsSupportRuntimePath:o}=e,c=m(t,i),a=m(t,o);this._ttPolicy!=null&&(a=this._ttPolicy.createScriptURL(a));let p=(await import(a)).compileStreaming(fetch(c)),d;e.renderer==="skwasm"?d=(async()=>{let u=await s.skwasm;return window._flutter_skwasmInstance=u,{skwasm:u.wasmExports,skwasmWrapper:u,ffi:{memory:u.wasmMemory}}})():d=Promise.resolve({}),await(await(await p).instantiate(await d)).invokeMain()}}_createScriptTag(e,s){let t=document.createElement("script");t.type="application/javascript",s&&(t.nonce=s);let r=e;return this._ttPolicy!=null&&(r=this._ttPolicy.createScriptURL(e)),t.src=r,t}};async function E(n,e,s){if(e<0)return n;let t,r=new Promise((i,o)=>{t=setTimeout(()=>{o(new Error(`${s} took more than ${e}ms to resolve. Moving on.`,{cause:E}))},e)});return Promise.race([n,r]).finally(()=>{clearTimeout(t)})}var v=class{setTrustedTypesPolicy(e){this._ttPolicy=e}loadServiceWorker(e){if(!e||!("serviceWorker"in navigator))return Promise.resolve();let s=()=>{console.warn(`Loading the service worker using Flutter bootstrap is deprecated and will stop working in a future release.
For more details, see: https://github.com/flutter/flutter/issues/156910`)},t=()=>{let{serviceWorkerVersion:r,serviceWorkerUrl:i=m(`flutter_service_worker.js?v=${r}`),timeoutMillis:o=4e3}=e,c=i;this._ttPolicy!=null&&(c=this._ttPolicy.createScriptURL(c));let a=navigator.serviceWorker.register(c).then(l=>this._getNewServiceWorker(l,r)).then(this._waitForServiceWorkerActivation);return E(a,o,"prepareServiceWorker")};return e.serviceWorkerUrl!=null?(s(),t()):navigator.serviceWorker.getRegistration().then(r=>r?t():Promise.resolve())}async _getNewServiceWorker(e,s){if(!e.active&&(e.installing||e.waiting))return console.debug("Installing/Activating first service worker."),e.installing||e.waiting;if(e.active.scriptURL.endsWith(s))return console.debug("Loading from existing service worker."),e.active;{let t=await e.update();return console.debug("Updating service worker."),t.installing||t.waiting||t.active}}async _waitForServiceWorkerActivation(e){if(!e||e.state==="activated")if(e){console.debug("Service worker already active.");return}else throw new Error("Cannot activate a null service worker!");return new Promise((s,t)=>{e.addEventListener("statechange",()=>{e.state==="activated"&&(console.debug("Activated new service worker."),s())})})}};var y=class{constructor(e,s="flutter-js"){let t=e||[/\.js$/,/\.mjs$/];window.trustedTypes&&(this.policy=trustedTypes.createPolicy(s,{createScriptURL:function(r){if(r.startsWith("blob:"))return r;let i=new URL(r,window.location),o=i.pathname.split("/").pop();if(t.some(a=>a.test(o)))return i.toString();console.error("URL rejected by TrustedTypes policy",s,":",r,"(download prevented)")}}))}};var b=(n,e)=>{let s=window._flutter?.buildConfig?.wasmHashes,t=s?.[e];if(!t&&e.includes("/")){let a=e.split("/").pop();t=s?.[a]}let r="crossOriginStorage"in navigator&&"requestFileHandles"in navigator.crossOriginStorage;r&&console.log("Cross-Origin Storage is supported. See https://wicg.github.io/cross-origin-storage/ for more details.");let i=async a=>{let l={algorithm:"SHA-256",value:a};try{let[p]=await navigator.crossOriginStorage.requestFileHandles([l]),d=await p.getFile();return new Response(d,{headers:{"Content-Type":"application/wasm"}})}catch(p){p.name==="NotAllowedError"?console.warn(`Not allowed to retrieve ${e} (hash: ${a}).`):p.name!=="NotFoundError"&&console.warn(`Unexpected error during retrieval of ${e} (hash: ${a}).`,p)}},o=async()=>{if(r&&t){let l=await i(t);if(l)return l}let a=await fetch(n);if(r&&t&&a.ok){let l={algorithm:"SHA-256",value:t},p=a.clone();(async()=>{try{let d=await p.blob(),[h]=await navigator.crossOriginStorage.requestFileHandles([l],{create:!0}),w=await h.createWritable();await w.write(d),await w.close()}catch(d){console.warn(`Error storing ${e} (hash: ${t}):`,d)}})()}return a},c=WebAssembly.compileStreaming(o());return(a,l)=>((async()=>{let p=await c,d=await WebAssembly.instantiate(p,a);l(d,p)})(),{})};var I=(n,e,s,t)=>(window.flutterCanvasKitLoaded=(async()=>{if(window.flutterCanvasKit)return window.flutterCanvasKit;let r=s.hasChromiumBreakIterators&&s.hasImageCodecs;if(!r&&e.canvasKitVariant=="chromium")throw"Chromium CanvasKit variant specifically requested, but unsupported in this browser";let i=r&&e.canvasKitVariant!=="full",o=i&&e.preferWebParagraph&&s.hasTextCluster,c=t;o?c=m(c,"webparagraph"):i&&(c=m(c,"chromium"));let a=m(c,"canvaskit.js");n.flutterTT.policy&&(a=n.flutterTT.policy.createScriptURL(a));let l="canvaskit.wasm";o?l="webparagraph/canvaskit.wasm":i&&(l="chromium/canvaskit.wasm");let p=b(m(c,"canvaskit.wasm"),l),d=await import(a);return window.flutterCanvasKit=await d.default({instantiateWasm:p}),window.flutterCanvasKit})(),window.flutterCanvasKitLoaded);var U=async(n,e,s,t)=>{let i=!s.hasImageCodecs||!s.hasChromiumBreakIterators?"skwasm_heavy":e.enableWimp?"wimp":"skwasm",o=m(t,`${i}.js`),c=o;n.flutterTT.policy&&(c=n.flutterTT.policy.createScriptURL(c));let a=b(m(t,`${i}.wasm`),`${i}.wasm`),l=await import(c);return!s.crossOriginIsolated&&!e.forceSingleThreadedSkwasm&&!e.suppressMultithreadingWarning&&console.warn(`Flutter Web: Skwasm uses multi-threading and web workers for better performance, but your page needs to be cross-origin isolated to support multi-threading. Skwasm will run in single-threaded mode.
To enable multithreading, serve your app with these HTTP response headers:
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Embedder-Policy: require-corp
See https://web.dev/articles/coop-coep for guidance.
To silence this warning, set \`suppressMultithreadingWarning: true\` in your Flutter configuration.`),await l.default({skwasmSingleThreaded:e.enableWimp||!s.crossOriginIsolated||s.isChromeExtension||e.forceSingleThreadedSkwasm,instantiateWasm:a,locateFile:(p,d)=>p.endsWith(".ww.js")?URL.createObjectURL(new Blob([`
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
`],{type:"application/javascript"})):m(t,p),mainScriptUrlOrBlob:o})};var P=f.supportsWasmGC,k=class{async loadEntrypoint(e){let{serviceWorker:s,...t}=e||{},r=new y,i=new v;i.setTrustedTypesPolicy(r.policy),await i.loadServiceWorker(s).catch(c=>{console.warn("Exception while loading service worker:",c)});let o=new g;return o.setTrustedTypesPolicy(r.policy),this.didCreateEngineInitializer=o.didCreateEngineInitializer.bind(o),o.loadEntrypoint(t)}async load({serviceWorkerSettings:e,onEntrypointLoaded:s,nonce:t,config:r}={}){r??={};let i=_flutter.buildConfig;if(!i)throw"FlutterLoader.load requires _flutter.buildConfig to be set";let o=r.wasmAllowList?.[f.browserEngine]??C[f.browserEngine],c=u=>{switch(u){case"skwasm":return P?f.webGLVersion>0?o?null:`Skwasm is disabled by your wasmAllowList configuration for browser engine "${f.browserEngine}".`:"Skwasm requires WebGL support; this browser does not provide it.":"Skwasm requires WasmGC support; this browser does not implement it yet.";default:return null}},a=u=>u.compileTarget==="dart2wasm"&&!P?"dart2wasm requires WasmGC support; this browser does not implement it yet.":r.renderer&&r.renderer!=u.renderer?`The application is configured to use the "${r.renderer}" renderer; this build targets "${u.renderer}".`:c(u.renderer),l,p=[];for(let u of i.builds){let S=a(u);if(S===null){l=u;break}p.push({candidate:u,reason:S})}if(r.verboseBuildSelection)for(let u of p)console.warn(`Flutter Web: build ${u.candidate.compileTarget}/${u.candidate.renderer} was skipped: ${u.reason}`);if(!l)throw console.warn("Flutter Web: no compatible build found for this browser."+(r.verboseBuildSelection?"":" Set `verboseBuildSelection: true` in your Flutter configuration to see why each candidate was rejected.")),new Error("FlutterLoader could not find a build compatible with configuration and environment.");let d={};d.flutterTT=new y,e&&(d.serviceWorkerLoader=new v,d.serviceWorkerLoader.setTrustedTypesPolicy(d.flutterTT.policy),await d.serviceWorkerLoader.loadServiceWorker(e).catch(u=>{console.warn("Exception while loading service worker:",u)}));let h=_(r,i);l.renderer==="canvaskit"?d.canvasKit=I(d,r,f,h):l.renderer==="skwasm"&&(d.skwasm=U(d,r,f,h));let w=new g;return w.setTrustedTypesPolicy(d.flutterTT.policy),this.didCreateEngineInitializer=w.didCreateEngineInitializer.bind(w),w.load(l,d,r,t,s)}};window._flutter||(window._flutter={});window._flutter.loader||(window._flutter.loader=new k);})();
//# sourceMappingURL=flutter.js.map

if (!window._flutter) {
  window._flutter = {};
}
_flutter.buildConfig = {"engineRevision":"deb287481e3ce9468f3434937ced4240a70539ca","wasmHashes":{"wimp.wasm":"e924eaafd801d41e017d178f3fd5cf8a417f641fe35c9ed34a4e1d7582283e0c","webparagraph/canvaskit.wasm":"0ce1b05082efdc8529550e8a01f6ff0593972d55525035010e26f5600aa9f254","skwasm.wasm":"e540fd5e8303b7b68ec2718cb49e9c421f8ade3075b15e02a7059a62654df9a1","chromium/canvaskit.wasm":"ae8ff1d858140f7b1300ced3fa89fb8c9dce0a400a0f4f1e11f6dcfb3315fdcf","canvaskit.wasm":"fbed517a43e82452404446683f00f2e876d835aed84410695759e67b6bb01cd3","skwasm_heavy.wasm":"565f5cc1cca6ab120f11934b105f01fec4b58b480c82e0889dca93af8e6f8635"},"builds":[{"compileTarget":"dart2js","renderer":"canvaskit","mainJsPath":"main.dart.js"}],"useLocalCanvasKit":true};


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
