import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/game/player/girlfriend_player.dart';

void main() {
  test('plant buddy turns toward its shot and its recoil settles', () async {
    GirlfriendPlayer makePlayer() =>
        GirlfriendPlayer(role: PlayerRole.girlfriend, cosmeticId: 'pea_buddy')
          ..onGround = true;

    Future<List<int>> pixelsOf(GirlfriendPlayer player) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..translate(40, 40);
      player.render(canvas);
      final picture = recorder.endRecording();
      final image = await picture.toImage(160, 160);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final pixels = List<int>.of(
        data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      image.dispose();
      picture.dispose();
      return pixels;
    }

    final right = makePlayer();
    final left = makePlayer()..plantFacingRight = false;
    final firing = makePlayer()..plantFired(toRight: false);
    expect(await pixelsOf(left), isNot(equals(await pixelsOf(right))));
    expect(await pixelsOf(firing), isNot(equals(await pixelsOf(left))));
    firing.update(0.2);
    left.update(0.2);
    expect(await pixelsOf(firing), equals(await pixelsOf(left)));
    expect(firing.size.x, GirlfriendPlayer.standWidth);
    expect(firing.hitHeight, GirlfriendPlayer.standHeight);
  });

  test(
    'player and vehicle variants render without changing gameplay bounds',
    () {
      for (final role in PlayerRole.values) {
        final player = GirlfriendPlayer(role: role);
        for (final poweredUp in [false, true]) {
          player.poweredUp = poweredUp;
          player.isDriving = poweredUp;
          player.vehicleBoosting = poweredUp;
          final recorder = ui.PictureRecorder();
          player.render(Canvas(recorder));
          recorder.endRecording().dispose();

          expect(player.size.x, GirlfriendPlayer.standWidth);
          expect(player.size.y, GirlfriendPlayer.standHeight);
        }
      }
    },
  );

  test(
    'idle, run, fall and pound poses are visually distinct and cosmetic',
    () async {
      final player = GirlfriendPlayer(role: PlayerRole.girlfriend);

      Future<List<int>> renderPose({
        required bool onGround,
        required double velocityX,
        required double velocityY,
        bool pounding = false,
      }) async {
        player
          ..onGround = onGround
          ..velocity.setValues(velocityX, velocityY)
          ..pounding = pounding
          ..skillDashing = false
          ..ducking = false
          ..invincibleTimer = 0;
        player.update(0.12);
        final recorder = ui.PictureRecorder();
        player.render(Canvas(recorder));
        final picture = recorder.endRecording();
        final image = await picture.toImage(128, 128);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final pixels = data!.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final result = List<int>.of(pixels);
        image.dispose();
        picture.dispose();

        expect(player.size.x, GirlfriendPlayer.standWidth);
        expect(player.size.y, GirlfriendPlayer.standHeight);
        expect(player.hitHeight, GirlfriendPlayer.standHeight);
        return result;
      }

      final idle = await renderPose(onGround: true, velocityX: 0, velocityY: 0);
      final run = await renderPose(
        onGround: true,
        velocityX: 180,
        velocityY: 0,
      );
      final fall = await renderPose(
        onGround: false,
        velocityX: 0,
        velocityY: 260,
      );
      final pound = await renderPose(
        onGround: false,
        velocityX: 0,
        velocityY: 1800,
        pounding: true,
      );

      expect(run, isNot(equals(idle)));
      expect(fall, isNot(equals(run)));
      expect(pound, isNot(equals(fall)));
    },
  );
}
