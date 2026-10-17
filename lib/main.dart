import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macaron_girlfriend_run/data/audio_service.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/theme/macaron_colors.dart';
import 'package:macaron_girlfriend_run/ui/controls.dart';
import 'package:macaron_girlfriend_run/ui/game_viewport.dart';
import 'package:macaron_girlfriend_run/ui/splash_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Web / iPhone 上强制横屏可能失败，不阻塞启动
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  } catch (_) {}
  await SaveService.instance.init();
  try {
    await AudioService.instance.init();
  } catch (_) {}
  // 高刷失败不阻塞启动
  // ignore: unawaited_futures
  FpsBootstrap.applyFromSave();
  runApp(const MacaronApp());
}

/// 整个应用统一按横屏布局：竖屏手机上菜单、选关、商店也会旋转成横屏画面，
/// 不再把标题和按钮挤成一列。游戏页内部已有的 GameViewport 在横屏约束下不会二次旋转。
Widget macaronAppShell(BuildContext context, Widget? child) =>
    GameViewport(child: child ?? const SizedBox.shrink());

/// 应用根
class MacaronApp extends StatelessWidget {
  const MacaronApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '马卡龙女友跑酷',
      debugShowCheckedModeBanner: false,
      builder: macaronAppShell,
      theme: MacaronColors.theme.copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const SplashPage(),
    );
  }
}
