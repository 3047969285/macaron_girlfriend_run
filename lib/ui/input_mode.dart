import 'package:flutter/foundation.dart';

/// 输入模式：触屏显示虚拟按键，键盘显示技能条和按键说明。
enum InputMode { touch, keyboard }

/// 输入模式规则与操作说明的唯一来源。
class InputModeRules {
  InputModeRules._();

  /// macOS / Windows / Linux → keyboard；其他 → touch。
  static InputMode initialFor(TargetPlatform platform) {
    switch (platform) {
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return InputMode.keyboard;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return InputMode.touch;
    }
  }

  /// 触屏说明，每行一条，必须有一行包含「换」。
  static const List<String> touchLines = [
    '← → 移动，按住「跑」加速，「蹲」下蹲',
    '「跳」按住跳更高',
    '右下技能键放技能，点「换」切换六种技能',
    '看头顶预警再出手',
  ];

  /// 键盘说明，每行一条，必须包含「F」射击与「Esc」暂停。
  static const List<String> keyboardLines = [
    'A/D 或方向键移动，Shift 跑，S 蹲',
    '空格 / W 跳，长按更高',
    'J 闪冲 · K 糖盾 · Q 花弹 · 1 下砸 · 2 二段跳 · 3 糖线 · F 射击',
    'Esc / P 暂停',
  ];

  /// 按模式返回上面两者之一。
  static List<String> linesFor(InputMode mode) =>
      mode == InputMode.touch ? touchLines : keyboardLines;
}
