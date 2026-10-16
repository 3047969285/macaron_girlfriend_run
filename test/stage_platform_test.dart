import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/level_catalog.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/game/entities/entities.dart';
import 'package:macaron_girlfriend_run/game/macaron_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('non-boss levels place one-way, crumble, and moving platforms', () {
    for (var world = 0; world < GameConstants.worldCount; world++) {
      for (var level = 0; level < GameConstants.levelsPerWorld; level++) {
        final data = LevelCatalog.load(world, level);
        final ground = data.height - 3;
        final y = ground - 3;
        final where = 'world $world level $level';
        if (level == 10) {
          expect(
            data.rows.any((row) => row.contains(RegExp('[UXO]'))),
            isFalse,
            reason: where,
          );
          continue;
        }
        final row = data.rows[y];
        final highest = (data.height - 8).clamp(4, data.height - 5);
        final lowest = (data.height - 4).clamp(highest, data.height - 3);
        expect(y, inInclusiveRange(highest, lowest), reason: where);
        for (final marker in ['U', 'X', 'O']) {
          final start = row.indexOf(marker);
          expect(start, greaterThanOrEqualTo(0), reason: '$where $marker');
          final len = marker == 'O' ? 2 : 3;
          final margin = marker == 'O' ? 2 : 1;
          for (var i = 0; i < len; i++) {
            expect(row[start + i], marker, reason: '$where $marker run');
          }
          for (var i = -margin; i < len + margin; i++) {
            expect(data.tileAt(start + i, ground + 1), '#', reason: where);
            expect(data.tileAt(start + i, ground + 2), '#', reason: where);
          }
        }
        final liftRow = data.rows[ground - 4];
        final liftStart = liftRow.indexOf('I');
        expect(liftStart >= 0, level % 3 == 2, reason: where);
        if (liftStart >= 0) {
          for (var i = 0; i < 3; i++) {
            expect(liftRow[liftStart + i], 'I', reason: '$where vertical lift');
          }
          for (var col = liftStart - 1; col <= liftStart + 3; col++) {
            for (
              var rowIndex = ground - 5;
              rowIndex <= ground - 3;
              rowIndex++
            ) {
              final tile = data.tileAt(col, rowIndex);
              expect(
                '#=?D'.contains(tile),
                isFalse,
                reason: '$where lift path',
              );
              if (tile != 'I') {
                expect(
                  'UXO'.contains(tile),
                  isFalse,
                  reason: '$where lift path',
                );
              }
            }
            expect(data.tileAt(col, ground + 1), '#', reason: '$where lift');
            expect(data.tileAt(col, ground + 2), '#', reason: '$where lift');
          }
        }
      }
    }
  });

  test('opening level introduces the three starter platforms in order', () {
    final data = LevelCatalog.load(0, 0);
    final ground = data.height - 3;
    final row = data.rows[ground - 3];
    final oneWay = row.indexOf('U');
    final crumble = row.indexOf('X');
    final horizontal = row.indexOf('O');

    expect(oneWay, inInclusiveRange(16, 22));
    expect(crumble, greaterThan(oneWay));
    expect(horizontal, greaterThan(crumble));
    expect(horizontal, lessThan(data.width ~/ 4));
    expect(crumble - oneWay, lessThanOrEqualTo(8));
    expect(horizontal - crumble, lessThanOrEqualTo(8));
  });

  testWidgets('one-way platforms catch a fall and let a jump pass through', (
    tester,
  ) async {
    final game = await _boot(tester, 0, 0);
    final platform = game.stagePlatforms.singleWhere(
      (item) => item.kind == StagePlatformKind.oneWay,
    );
    game.player
      ..position.setValues(platform.rect.center.dx, platform.rect.top - 4)
      ..velocity.setValues(0, 700)
      ..onGround = false;
    for (var frame = 0; frame < 12 && !game.player.onGround; frame++) {
      game.update(1 / 30);
    }
    expect(game.player.onGround, isTrue);
    expect(game.player.position.y, platform.rect.top);

    final below = platform.rect.top + 48;
    game.player
      ..position.setValues(platform.rect.center.dx, below)
      ..velocity.setValues(0, -900)
      ..onGround = false;
    game.update(1 / 30);
    expect(game.player.position.y, lessThan(below));
    expect(game.player.position.y, isNot(platform.rect.top));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a crumble platform drops after it is stood on', (tester) async {
    final game = await _boot(tester, 0, 1);
    final platform = game.stagePlatforms.singleWhere(
      (item) => item.kind == StagePlatformKind.crumble,
    );
    game.player
      ..position.setValues(platform.rect.center.dx, platform.rect.top - 4)
      ..velocity.setValues(0, 700)
      ..onGround = false;
    for (var frame = 0; frame < 8 && !game.player.onGround; frame++) {
      game.update(1 / 30);
    }
    expect(platform.solid, isTrue);
    for (var frame = 0; frame < 20 && platform.solid; frame++) {
      game.update(1 / 30);
    }
    expect(platform.solid, isFalse);
    final droppedFrom = game.player.position.y;
    for (var frame = 0; frame < 8; frame++) {
      game.update(1 / 30);
    }
    expect(game.player.position.y, greaterThan(droppedFrom));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a moving platform carries the player with it', (tester) async {
    final game = await _boot(tester, 0, 2);
    final platform = game.stagePlatforms.singleWhere(
      (item) => item.kind == StagePlatformKind.mover,
    );
    game.player
      ..position.setValues(platform.rect.center.dx, platform.rect.top - 4)
      ..velocity.setValues(0, 700)
      ..onGround = false;
    for (var frame = 0; frame < 8 && !game.player.onGround; frame++) {
      game.update(1 / 30);
    }
    expect(game.player.onGround, isTrue);
    final start = game.player.position.x;
    for (var frame = 0; frame < 20; frame++) {
      game.update(1 / 30);
    }
    expect(game.player.onGround, isTrue);
    expect((game.player.position.x - start).abs(), greaterThan(8));
    expect(
      (game.player.position.x - platform.rect.center.dx).abs(),
      lessThan(GameConstants.tileSize),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a vertical lift is one-way and carries a standing player', (
    tester,
  ) async {
    final game = await _boot(tester, 0, 2);
    final platform = game.stagePlatforms.singleWhere(
      (item) => item.kind == StagePlatformKind.verticalMover,
    );

    final below = platform.rect.top + 72;
    game.player
      ..position.setValues(platform.rect.center.dx, below)
      ..velocity.setValues(0, -900)
      ..onGround = false;
    game.update(1 / 30);
    expect(game.player.position.y, lessThan(below));
    expect(game.player.position.y, greaterThan(platform.rect.top));

    game.player
      ..position.setValues(platform.rect.center.dx, platform.rect.top - 4)
      ..velocity.setValues(0, 700)
      ..onGround = false;
    for (var frame = 0; frame < 8 && !game.player.onGround; frame++) {
      game.update(1 / 30);
    }
    expect(game.player.onGround, isTrue);
    expect((game.player.position.y - platform.rect.top).abs(), lessThan(0.01));

    final startY = platform.rect.top;
    for (var frame = 0; frame < 100; frame++) {
      game.update(1 / 30);
    }
    expect(game.player.onGround, isTrue);
    expect((game.player.position.y - platform.rect.top).abs(), lessThan(0.01));
    expect(game.player.position.y, lessThan(startY - 20));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<MacaronGame> _boot(WidgetTester tester, int world, int level) async {
  SharedPreferences.setMockInitialValues({
    'sound_on': false,
    'music_on': false,
    'haptic_on': false,
  });
  await SaveService.instance.init();
  final game = MacaronGame(
    worldIndex: world,
    levelIndex: level,
    role: PlayerRole.girlfriend,
  );
  await tester.pumpWidget(GameWidget(game: game));
  await tester.pump(const Duration(milliseconds: 100));
  expect(game.levelReady, isTrue);
  game.pauseEngine();
  game.player.resetInput();
  return game;
}
