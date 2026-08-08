import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macaron_girlfriend_run/data/audio_service.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/theme/macaron_colors.dart';
import 'package:macaron_girlfriend_run/ui/controls.dart';
import 'package:macaron_girlfriend_run/ui/splash_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SaveService.instance.init();
  await AudioService.instance.init();
  // 高刷失败不阻塞启动
  // ignore: unawaited_futures
  FpsBootstrap.applyFromSave();
  runApp(const MacaronApp());
}

/// 应用根
class MacaronApp extends StatelessWidget {
  const MacaronApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '马卡龙女友跑酷',
      debugShowCheckedModeBanner: false,
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
