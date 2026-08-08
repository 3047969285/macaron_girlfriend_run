import 'package:flutter/material.dart';
import 'package:macaron_girlfriend_run/theme/macaron_colors.dart';
import 'package:macaron_girlfriend_run/ui/home_page.dart';

/// 开屏页
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void initState() {
    super.initState();
    _c.forward();
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) {
        return;
      }
      Navigator.pushReplacement(
        context,
        PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => const HomePage(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 450),
        ),
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [MacaronColors.blush, MacaronColors.cream, MacaronColors.mint],
          ),
        ),
        child: FadeTransition(
          opacity: _c,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🍬', style: TextStyle(fontSize: 56)),
              SizedBox(height: 12),
              Text(
                '马卡龙女友跑酷',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: MacaronColors.cocoa,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Macaron Girlfriend Run',
                style: TextStyle(
                  letterSpacing: 1.5,
                  color: MacaronColors.cocoa,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
