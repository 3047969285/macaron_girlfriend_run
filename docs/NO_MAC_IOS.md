# 没有 Mac 怎么上 iPhone

苹果规定：**正式 `.ipa` 必须在 Mac + Xcode（或云端 Mac）签名**。  
没有苹果电脑时，按目标选下面一路。

---

## 方案对比（架构师推荐顺序）

| 方案 | 能否装到 iPhone | 要不要钱 | 是不是真 App | 难度 | 推荐 |
|---|---|---|---|---|---|
| **A. iPhone 网页 / 添加到主屏幕（PWA）** | 能玩 | 免费 | 像 App，不是 App Store 包 | 低 | **首选，马上能玩** |
| **B. 租云 Mac 打一次包** | 真机安装 | 按小时（约几十～上百） | 真 ipa（免费 Apple ID 约 7 天） | 中 | 要「图标点开那种」时 |
| **C. Codemagic 云构建** | 真 ipa / TestFlight | 免费额度 + 建议付费开发者账号 | 真 App | 中高 | 以后要上架 |
| **D. 借朋友 Mac / 去苹果店旁人帮签** | 真机 | 看人情 | 真 App | 低 | 有熟人时 |

**架构师结论**：现在没有 Mac → **先走 A**，iPhone 今天就能玩；真要 App Store / 长期安装再走 B 或 C。

---

## A. iPhone 网页玩 — 同 Wi-Fi（本机已准备）

### 电脑开服务（Windows）

在工程目录：

```bat
给iPhone玩.bat
```

或：

```bat
flutter build web --release
cd build\web
python -m http.server 8080
```

### 手机操作

1. 手机和电脑连**同一 Wi‑Fi**  
2. Safari 打开：`http://电脑局域网IP:8080`  
3. 横屏玩  
4. 想当桌面图标：Safari → 分享 → **添加到主屏幕** → 名字「马卡龙」

---

## A2. iPhone 网页玩 — **不用同 Wi-Fi（公网部署）**

> 推荐：部署一次，iPhone 随时 Safari 打开，可「添加到主屏幕」。

### 方式 1：Netlify 拖拽（最快，约 2 分钟）

1. 运行 `部署iPhone公网.bat`（会构建并复制到桌面「马卡龙-iPhone网页版」）  
2. 浏览器打开 [app.netlify.com/drop](https://app.netlify.com/drop)  
3. 把「马卡龙-iPhone网页版」文件夹**拖进去**  
4. 得到 `https://xxx.netlify.app` 公网地址 → iPhone Safari 打开即可  

### 方式 2：GitHub Pages（永久免费）

1. 工程推到 GitHub  
2. 仓库 **Settings → Pages → Source** 选 **GitHub Actions**  
3. 推送 `main` 后 Actions 自动部署  
4. 访问 `https://<用户名>.github.io/<仓库名>/`  

（仓库内已有 `.github/workflows/deploy-web.yml`）

### 方式 3：Cloudflare 隧道（临时公网，电脑需开着）

```bat
winget install Cloudflare.cloudflared
部署iPhone公网.bat
```

脚本会输出 `trycloudflare.com` 链接，复制到 iPhone Safari。

详细说明见工程根目录 `部署Netlify拖拽说明.txt`。

---

## B. 租云 Mac（打真 ipa）

可选：MacinCloud、AWS Mac、国内云 Mac 等。

1. 租一台带 Xcode 的云桌面  
2. 把 `macaron_girlfriend_run` 上传上去  
3. 按 `docs/BUILD_IOS.md`：`pod install` → Xcode 签名 → 真机 / Archive  
4. 用免费 Apple ID 装自己手机（约 **7 天**要重签）  

**注意**：免费账号不能随便给别人装；长期建议 Apple Developer（约 $99/年）。

---

## C. Codemagic（云端自动打 ipa）

1. 工程推到 GitHub（私有仓即可）  
2. [codemagic.io](https://codemagic.io) 接仓库  
3. 用仓库里的 `codemagic.yaml`  
4. **真机可装的 ipa** 通常需要：  
   - Apple Developer 付费账号  
   - 证书 + Provisioning Profile（Codemagic 可代管）  

适合：以后要上架 / TestFlight。

---

## D. 借 Mac

拷贝整个 `macaron_girlfriend_run` 文件夹，打开 `docs/BUILD_IOS.md` 按步骤即可。

---

## 不能指望的路

- Windows 直接 `flutter build ipa` → **做不到**  
- 网上「一键转 ipa」不明工具 → **别用，风险大**  
- 只给安卓 apk 改后缀装 iPhone → **装不上**  

---

## 建议你怎么选

1. **今天就要在 iPhone 上玩** → 方案 A（我帮你开服务）  
2. **只要桌面图标、不在乎 App Store** → A 的「添加到主屏幕」  
3. **一定要真正的 App 图标且长期用** → B 或 C + 开发者账号  
