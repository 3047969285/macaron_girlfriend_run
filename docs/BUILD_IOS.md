# iOS 打包说明

> 同一套 Flutter 代码，Android 打 `.apk`，iOS 打 `.ipa`。  
> **必须在 macOS + Xcode 上完成**，Windows 无法直接生成可安装的 iOS 包。

## 前置条件

| 项 | 说明 |
|---|---|
| 电脑 | Mac（macOS 13+ 建议） |
| Xcode | App Store 安装最新稳定版 |
| Flutter | 与 Windows 同版本即可（3.35+） |
| 账号 | 免费 Apple ID 可装自己手机（约 7 天需重签）；上架需付费开发者 $99/年 |

## 1. 把工程拷到 Mac

整个文件夹复制到 Mac，例如：

`~/Desktop/macaron_girlfriend_run`

## 2. 安装依赖

```bash
cd ~/Desktop/macaron_girlfriend_run
flutter pub get
cd ios && pod install && cd ..
```

若未装 CocoaPods：

```bash
sudo gem install cocoapods
```

## 3. 真机调试（最快试玩）

1. iPhone 用数据线连 Mac，信任电脑  
2. Xcode 打开 `ios/Runner.xcworkspace`  
3. 顶部选你的 iPhone 设备  
4. **Signing & Capabilities** → Team 选你的 Apple ID  
5. 终端执行：

```bash
flutter run -d <你的iPhone设备id>
```

或 Xcode 点 ▶ 运行。

## 4. 导出 IPA（给别人装 / 自留）

### 方式 A：Xcode Archive（推荐）

1. 打开 `ios/Runner.xcworkspace`  
2. Product → Archive  
3. Distribute App → **Development** 或 **Ad Hoc**（需注册设备 UDID）  
4. 导出 `.ipa`

### 方式 B：命令行（需已配置签名）

```bash
flutter build ipa --release
```

产物通常在：

`build/ios/ipa/*.ipa`

## 5. 装到 iPhone

- **Development / 真机 run**：直接 Xcode / flutter run  
- **Ad Hoc ipa**：用 Apple Configurator、爱思助手（Mac）、或 TestFlight（需开发者账号）

## iOS 与 Android 差异

| 项 | iOS |
|---|---|
| 高刷 | 跟随系统 ProMotion，设置里「自动」即可 |
| 帧率插件 | `flutter_displaymode` 仅 Android，iOS 无影响 |
| 横屏 | 已在 Info.plist + AppDelegate 锁横屏 |
| 包名 | `com.macaron.macaronGirlfriendRun` |

## 常见问题

**Q：Windows 能不能打 ipa？**  
不能。只能准备代码，打包必须 Mac。

**Q：没有 Mac 怎么办？**  
- 借 Mac / 云 Mac（Codemagic、GitHub Actions macOS _runner）  
- 或继续用 Android apk

**Q：免费 Apple ID 装别人手机？**  
不行，只能装绑定自己账号的开发设备，且签名约 7 天过期需重跑。
