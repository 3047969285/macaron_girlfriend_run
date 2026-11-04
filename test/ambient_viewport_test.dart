import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/game/effects/fx_layer.dart';

void main() {
  test(
    'ambient particles stay bounded around moving and jumping viewports',
    () async {
      final ambient = AmbientSparkles(
        mapWidth: 20000,
        tint: Colors.pink,
        kind: AmbientKind.petal,
      );
      ambient.syncViewport(640, 1280);
      await ambient.onLoad();
      expect(ambient.debugParticleX, hasLength(34));
      expect(ambient.debugParticleX.every((x) => x >= 0 && x <= 1460), isTrue);
      ambient.syncViewport(10000, 1280);
      expect(ambient.debugParticleX, hasLength(34));
      expect(
        ambient.debugParticleX.every((x) => x >= 9180 && x <= 10820),
        isTrue,
      );
      ambient.syncViewport(10050, 1280);
      expect(
        ambient.debugParticleX.every((x) => x >= 9230 && x <= 10870),
        isTrue,
      );
      ambient.update(1 / 60);
      expect(ambient.debugParticleX, hasLength(34));
    },
  );
}
