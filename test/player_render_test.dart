import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/game/player/girlfriend_player.dart';

void main() {
  test('player face variants render without changing gameplay bounds', () {
    for (final role in PlayerRole.values) {
      final player = GirlfriendPlayer(role: role);
      for (final poweredUp in [false, true]) {
        player.poweredUp = poweredUp;
        final recorder = ui.PictureRecorder();
        player.render(Canvas(recorder));
        recorder.endRecording().dispose();

        expect(player.size.x, GirlfriendPlayer.standWidth);
        expect(player.size.y, GirlfriendPlayer.standHeight);
      }
    }
  });
}
