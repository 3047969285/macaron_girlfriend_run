# 接口文档：按钮精简（v1.6）

对应需求见 [PRD.md](PRD.md)，编号 R1–R10 与之一致。测试见 `test/button_simplify_test.dart`。

## 1. 新文件 `lib/ui/input_mode.dart`（R3、R9）

```dart
import 'package:flutter/foundation.dart';

enum InputMode { touch, keyboard }

/// 输入模式规则与操作说明的唯一来源。
class InputModeRules {
  InputModeRules._();

  /// macOS / Windows / Linux → keyboard；其他 → touch。
  static InputMode initialFor(TargetPlatform platform);

  /// 触屏说明，每行一条，必须有一行包含「换」。
  static const List<String> touchLines;

  /// 键盘说明，每行一条，必须包含「F」射击与「Esc」暂停。
  static const List<String> keyboardLines;

  /// 按模式返回上面两者之一。
  static List<String> linesFor(InputMode mode);
}
```

建议文案（可微调，但须满足上面的约束）：

- touchLines：
  - `← → 移动，按住「跑」加速，「蹲」下蹲`
  - `「跳」按住跳更高`
  - `右下技能键放技能，点「换」切换六种技能`
  - `看头顶预警再出手`
- keyboardLines：
  - `A/D 或方向键移动，Shift 跑，S 蹲`
  - `空格 / W 跳，长按更高`
  - `J 闪冲 · K 糖盾 · Q 花弹 · 1 下砸 · 2 二段跳 · 3 糖线 · F 射击`
  - `Esc / P 暂停`

## 2. `MacaronGame`（`lib/game/macaron_game.dart`，R3、R10）

新增：

```dart
/// 触屏技能键当前会放的技能；构造时等于 activeSkill（当关技能）。
HeroSkill get selectedSkill;

/// 按 HeroSkill.values 顺序切到下一个，末尾回到开头；之后通知 HUD 刷新。
/// 暂停或结算时也允许切换（只改选择，不放技能）。
void cycleSelectedSkill();
```

改动：

| 成员 | 改前 | 改后 |
|---|---|---|
| `skillButtonLabel` | `activeSkill.shortLabel` | `selectedSkill.shortLabel` |
| `skillCooldownRatio` | `cooldownRatioOf(activeSkill)` | `cooldownRatioOf(selectedSkill)` |
| `activateSkill([HeroSkill? skill])` | 无参 → `activeSkill` | 无参 → `selectedSkill`；有参照旧，且不改 `selectedSkill` |
| `tapJump()` | 存在 | 删除 |

`activeSkill` 保持原义（当关技能）不变。

## 3. `TouchControls`（`lib/ui/controls.dart`，R3）

新增可选参数：

```dart
/// 非空时，在技能键旁显示文字为「换」的小按钮，点按调用它。
final VoidCallback? onCycleSkill;
```

- 点「换」也要调用 `onInteract`（与其他按钮一致，用于解锁音频和切回触屏模式）。
- 小按钮的直径约为技能键的 0.6 倍，随 `scale` 缩放；宽 320 的竖屏和横屏手机都不能溢出。
- 不传时与现在完全一致。

## 4. `PlayPage`（`lib/ui/play_page.dart`，R3、R4、R5、R9）

```dart
enum PlayOrigin { home, map }

enum LevelSelectAction { pop, replaceWithMap }

class PlayNavigation {
  PlayNavigation._();
  /// map → pop；home → replaceWithMap。
  static LevelSelectAction levelSelectActionFor(PlayOrigin origin);
}

class PlayPage extends StatefulWidget {
  const PlayPage({
    super.key,
    required this.worldIndex,
    required this.levelIndex,
    this.origin = PlayOrigin.map,
  });
  final PlayOrigin origin;
}
```

行为：

- 状态 `_inputMode` 初值 `InputModeRules.initialFor(defaultTargetPlatform)`；`_onKey` 收到 `KeyDownEvent` 时置为 keyboard；`_onControlInteract` 被调用时置为 touch。值变化时才 `setState`。
- `_SkillStrip` 只在 `_inputMode == keyboard` 且 `game.levelReady` 时显示。
- `TouchControls` 传入 `onCycleSkill: game.cycleSelectedSkill`。
- `_GameHudHeader` 去掉 `onExit` 参数和左上返回芯片，左侧只留世界名、关名、难度。
- 私有方法 `_goToLevelSelect()`：按 `PlayNavigation.levelSelectActionFor(widget.origin)`，pop 时 `Navigator.pop(context, true)`；replaceWithMap 时 `Navigator.pushReplacement(... WorldMapPage(initialWorld: widget.worldIndex))`。
  - 用在：普通过关和世界通关弹窗的「选关」、`_confirmExit` 的「确认退出」。
  - 全通弹窗「回首页庆祝」和失败弹窗「返回」保持 pop 不变。
- 「下一关」「下一世界」「再来一局」「重试本关」新建的 `PlayPage` 都传 `origin: widget.origin`。
- `_PauseOverlay` 非后台暂停时的说明改为 `InputModeRules.linesFor(mode).join(' · ')` 加原来的平台说明行（「蓝台可从下穿过 · 黄台会塌 · 紫台会带着走」）。需新增参数 `required InputMode inputMode`。
- `TutorialOverlay` 新增参数 `this.inputMode = InputMode.touch`，正文改为 `InputModeRules.linesFor(inputMode)` 逐行显示（前面加「• 」）。

## 5. `home_page.dart`（R1、R2、R5、R6、R7、R9）

- `HomePage`：删「iPhone 版」按钮及弹窗、删「关于与上架说明」TextButton。「继续冒险」进关时传 `origin: PlayOrigin.home`。
- `WorldMapPage`：

  ```dart
  const WorldMapPage({super.key, this.initialWorld = 0});
  final int initialWorld; // 超出 0..worldCount-1 时夹紧
  ```

  `_WorldMapPageState.world` 初值取 `initialWorld`。从地图进关时传 `origin: PlayOrigin.map`（即默认值）。
- `HowToPlayPage`「操作」卡片正文：`'触控：' + touchLines.join(' · ') + '\n键盘：' + keyboardLines.join(' · ')`。
- `AboutPage`：删除包含 Android 上架、iPhone/Codemagic/BUILD_IOS 的两段 Text。
- `SettingsPage`：
  - 删除「操作音效」「背景音乐」两个 `SwitchListTile`。
  - 两个滑块的值与回调用下面的纯函数：

    ```dart
    class AudioSliderRules {
      AudioSliderRules._();
      /// enabled 为 false 时返回 0，否则返回 volume。
      static double display({required bool enabled, required double volume});
      /// 返回新的开关和音量：(enabled: value > 0, volume: value)。
      static ({bool enabled, double volume}) apply(double value);
    }
    ```

    回调里依次写 `setSoundEnabled / setSoundVolume`（音乐同理用 music 系列），再 `AudioService.instance.applyVolumes()`。音乐从 >0 变 0 调 `stopBgm()`，从 0 变 >0 调 `resumeBgm()`。
  - 「帧率」小节标题和芯片只在 `FpsBootstrap.isSupported` 为真时显示。
  - 列表最后加 `ListTile(title: Text('关于'), trailing: Icon(CupertinoIcons.info))`，点按 push `AboutPage`。

## 6. `FpsBootstrap`（`lib/ui/controls.dart`，R7）

```dart
/// 只有 Android 原生能切刷新率。读 defaultTargetPlatform，测试可用
/// debugDefaultTargetPlatformOverride 覆盖。
static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
```

## 7. `ShopPage`（`lib/ui/shop_page.dart`，R8）

- 已穿戴（`on == true`）时 `CupertinoButton.onPressed` 传 `null`；显示颜色仍为 mint（用 `disabledColor: MacaronColors.mint`），文字仍为「穿戴中」。

## 8. 不变的东西

- 存档键、`SaveService` 接口、`AudioService` 接口不改。
- 关卡、敌人、数值、技能效果不改。
- 键盘按键绑定不改。
