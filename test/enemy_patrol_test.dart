import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/enemy_kind.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/game/enemy_patrol.dart';

const _tile = GameConstants.tileSize;
const _height = 14;

String _spaces(int n) => List.filled(n, ' ').join();

/// 合成关卡：`groundRow` 写在地面行（height-3），默认整条地面实心，
/// 可用 [gaps] 挖空指定列的两层地面，用来验证巡逻是否会踩进坑口。
LevelData _level(String groundRow, {Set<int> gaps = const {}}) {
  final width = groundRow.length;
  final rows = List.generate(_height, (_) => List.filled(width, ' '));
  for (var x = 0; x < width; x++) {
    if (!gaps.contains(x)) {
      rows[_height - 1][x] = '#';
      rows[_height - 2][x] = '#';
    }
    rows[_height - 3][x] = groundRow[x];
  }
  return LevelData(
    worldIndex: 0,
    levelIndex: 0,
    title: 'synthetic',
    rows: rows.map((row) => row.join()).toList(),
    difficulty: 1,
  );
}

int _tileOf(double pixelBound) => (pixelBound / _tile - 0.5).round();

void main() {
  test('a lone walker patrols two tiles to either side', () {
    final level = _level('${_spaces(20)}E${_spaces(20)}');
    final (left, right) = EnemyPatrol.boundsFor(
      level: level,
      spawnX: 20 * _tile,
      kind: EnemyKind.walker,
    );
    expect(_tileOf(left), 18);
    expect(_tileOf(right), 22);
  });

  test('patrol never extends across a gap', () {
    final level = _level('${_spaces(20)}E${_spaces(20)}', gaps: {22});
    final (left, right) = EnemyPatrol.boundsFor(
      level: level,
      spawnX: 20 * _tile,
      kind: EnemyKind.walker,
    );
    expect(_tileOf(left), 18);
    expect(_tileOf(right), 21);
  });

  test('adjacent patrols keep a reaction gap', () {
    final level = _level('${_spaces(20)}E${_spaces(3)}E${_spaces(16)}');
    final (leftA, rightA) = EnemyPatrol.boundsFor(
      level: level,
      spawnX: 20 * _tile,
      kind: EnemyKind.walker,
    );
    final (leftB, _) = EnemyPatrol.boundsFor(
      level: level,
      spawnX: 24 * _tile,
      kind: EnemyKind.walker,
    );
    final required = EnemyPatrol.halfWidthOf(EnemyKind.walker) * 2 + _tile;
    expect(leftB - rightA, greaterThanOrEqualTo(required - 0.001));
  });

  test('a bruiser is wider than a walker', () {
    expect(
      EnemyPatrol.halfWidthOf(EnemyKind.bruiser),
      greaterThan(EnemyPatrol.halfWidthOf(EnemyKind.walker)),
    );
  });

  test('patrol bounds always contain the spawn center', () {
    for (final kind in EnemyKind.values) {
      final level = _level('${_spaces(20)}E${_spaces(20)}');
      final (left, right) = EnemyPatrol.boundsFor(
        level: level,
        spawnX: 20 * _tile,
        kind: kind,
      );
      final center = 20 * _tile + _tile / 2;
      expect(center, greaterThanOrEqualTo(left - 0.001), reason: '$kind left');
      expect(center, lessThanOrEqualTo(right + 0.001), reason: '$kind right');
    }
  });

  test('every ground marker maps to its enemy kind', () {
    expect(EnemyPatrol.kindOfMarker('E'), EnemyKind.walker);
    expect(EnemyPatrol.kindOfMarker('G'), EnemyKind.hopper);
    expect(EnemyPatrol.kindOfMarker('R'), EnemyKind.bruiser);
    expect(EnemyPatrol.kindOfMarker('T'), EnemyKind.trapper);
    expect(EnemyPatrol.kindOfMarker('A'), EnemyKind.swooper);
    expect(EnemyPatrol.kindOfMarker('L'), EnemyKind.shell);
    expect(EnemyPatrol.kindOfMarker('Y'), EnemyKind.roller);
    expect(EnemyPatrol.kindOfMarker('J'), EnemyKind.popper);
    expect(EnemyPatrol.kindOfMarker('P'), isNull);
    expect(EnemyPatrol.kindOfMarker(' '), isNull);
  });
}
