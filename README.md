# 马卡龙女友跑酷

Flutter + Flame 手机横屏单机平台跳跃。马卡龙配色、低多边形角色、9×11=99 关，无服务器。

## 位置

`桌面\macaron_girlfriend_run`

## 运行

```bash
cd %USERPROFILE%\Desktop\macaron_girlfriend_run
flutter pub get
flutter run
```

设置里可切换帧率档（自适应 / 60 / 90 / 120）与女友/男友外观。

## 操作

- 左：← →
- 右：跳、跑

## 说明

- 联机未做（仅角色形态预留）
- 设计见 `docs/DESIGN.md`

## 音乐署名

- “Slow Jam” — Kevin MacLeod，来自 [incompetech](https://incompetech.com/music/royalty-free/index.html?Search=Search&isrc=USUAN1600015)，按 [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) 授权。
- “Smooth Lovin” — Kevin MacLeod，来自 [incompetech](https://incompetech.com/music/royalty-free/index.html?Search=Search&isrc=USUAN1700077)，按 [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) 授权。

曲目用于游戏内背景音乐；音频文件位于 `assets/audio/`。

## Android

桌面 `马卡龙女友跑酷-debug.apk` 或：

```bash
flutter build apk --debug
```

## iOS

**Windows 不能直接打 ipa**，需 Mac + Xcode。工程已含 `ios/` 目录，配置已锁横屏、ProMotion。

- **没有 Mac？** 看 **`docs/NO_MAC_IOS.md`**（推荐先用 iPhone Safari / 添加到主屏幕）
- 有 Mac：看 **`docs/BUILD_IOS.md`**，或 `bash scripts/build_ios.sh`
- 云构建模板：`codemagic.yaml`

