import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/game/effects/fx_layer.dart';
import 'package:macaron_girlfriend_run/game/macaron_game.dart';
import 'package:macaron_girlfriend_run/game/player/hero_sprites.dart';
import 'package:macaron_girlfriend_run/ui/controls.dart';

void main() {
  test('pose transitions advance consistently with elapsed time', () {
    HeroPoseAnimator animate(int steps) {
      final animator = HeroPoseAnimator();
      animator.advance(HeroPose.stand, 0);
      animator.advance(HeroPose.jump, 0);
      for (var i = 0; i < steps; i++) {
        animator.advance(HeroPose.jump, 0.12 / steps);
      }
      return animator;
    }

    final slow = animate(6);
    final fast = animate(24);
    expect(slow.blend, closeTo(fast.blend, 0.00001));
    expect(slow.stretch, closeTo(fast.stretch, 0.00001));
    expect(slow.blend, inInclusiveRange(0.0, 1.0));
    expect(slow.stretch, greaterThan(1));
  });

  test('landing briefly compresses and returns to the resting shape', () {
    final animator = HeroPoseAnimator();
    animator.advance(HeroPose.fall, 0);
    animator.advance(HeroPose.stand, 0);
    expect(animator.stretch, lessThan(1));
    animator.advance(HeroPose.stand, 1);
    expect(animator.stretch, closeTo(1, 0.0001));
    expect(animator.blend, 1);
  });

  test('camera damping gives the same result at different frame rates', () {
    double follow(int steps) {
      var value = 0.0;
      for (var i = 0; i < steps; i++) {
        value = MacaronGame.dampCamera(value, 100, 8, 1 / steps);
      }
      return value;
    }

    expect(follow(30), closeTo(follow(120), 0.00001));
    expect(follow(60), lessThan(100));
  });

  test('effect particles and auxiliary effects are bounded and recycled', () {
    final fx = FxLayer();
    for (var i = 0; i < 300; i++) {
      fx.stompKill(Vector2.zero());
      fx.eyeBeam(Vector2.zero(), Vector2(10, 0));
    }
    expect(fx.particleCount, lessThanOrEqualTo(GameConstants.maxFxParticles));
    expect(fx.auxiliaryEffectCount, lessThanOrEqualTo(96));
    final allocated = fx.particleAllocations;
    final auxiliaryAllocated = fx.auxiliaryAllocations;
    fx.update(5);
    expect(fx.particleCount, 0);
    fx.stompKill(Vector2.zero());
    fx.eyeBeam(Vector2.zero(), Vector2(10, 0));
    expect(fx.particleAllocations, allocated);
    expect(fx.auxiliaryAllocations, auxiliaryAllocated);
  });

  testWidgets('jump button visibly eases when pressed and released', (
    tester,
  ) async {
    final events = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: TouchControls(
                  onLeft: (_) {},
                  onRight: (_) {},
                  onRun: (_) {},
                  onJumpHeld: events.add,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final scale = find
        .ancestor(of: find.text('跳'), matching: find.byType(AnimatedScale))
        .first;
    expect(tester.widget<AnimatedScale>(scale).scale, 1);
    final press = await tester.startGesture(tester.getCenter(find.text('跳')));
    await tester.pump();
    expect(tester.widget<AnimatedScale>(scale).scale, 0.92);
    await press.up();
    await tester.pump();
    expect(tester.widget<AnimatedScale>(scale).scale, 1);
    expect(events, [true, false]);
  });
}
