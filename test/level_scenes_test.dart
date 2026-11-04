// 地图多样性（场景组合）验收测试，对应 docs/地图多样性/PRD.md 的 S1–S7。
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/level_catalog.dart';
import 'package:macaron_girlfriend_run/data/level_scenes.dart';

const _worlds = GameConstants.worldCount;
const _levels = GameConstants.levelsPerWorld;
const _solidChars = '#=?DUXOI';

bool _isSolid(String c) => _solidChars.contains(c);

typedef _Lv = ({int w, int l, LevelData level, LevelData base, List<PlacedScene> scenes});

final List<_Lv> _all = [];

List<_Lv> _loadAll() {
  if (_all.isEmpty) {
    for (var w = 0; w < _worlds; w++) {
      for (var l = 0; l < _levels; l++) {
        _all.add((
          w: w,
          l: l,
          level: LevelCatalog.load(w, l),
          base: LevelCatalog.loadBase(w, l),
          scenes: LevelCatalog.scenesOf(w, l),
        ));
      }
    }
  }
  return _all;
}

String _why(_Lv v) => 'world ${v.w} level ${v.l}';

Iterable<(int, int)> _solids(PlacedScene s) => [
  for (final e in s.cells.entries)
    if ('=?'.contains(e.value)) e.key,
];

int _topRow(PlacedScene s) => _solids(s).map((e) => e.$2).reduce(math.min);

/// 同一行里连续的砖，按列排序，返回 (行, 起列, 长度)。
List<(int, int, int)> _runs(PlacedScene s) {
  final byRow = <int, List<int>>{};
  for (final (c, r) in _solids(s)) {
    byRow.putIfAbsent(r, () => []).add(c);
  }
  final out = <(int, int, int)>[];
  for (final e in byRow.entries) {
    final cols = e.value..sort();
    var start = cols.first;
    var prev = start;
    for (final c in cols.skip(1)) {
      if (c != prev + 1) {
        out.add((e.key, start, prev - start + 1));
        start = c;
      }
      prev = c;
    }
    out.add((e.key, start, prev - start + 1));
  }
  out.sort((a, b) => a.$2 != b.$2 ? a.$2.compareTo(b.$2) : a.$1.compareTo(b.$1));
  return out;
}

String _shapeKey(PlacedScene s) {
  String encode(bool mirror) {
    final cells = [
      for (final e in s.cells.entries)
        (mirror ? -e.key.$1 : e.key.$1, e.key.$2, e.value),
    ];
    final minC = cells.map((e) => e.$1).reduce(math.min);
    final minR = cells.map((e) => e.$2).reduce(math.min);
    final norm = [for (final e in cells) '${e.$1 - minC},${e.$2 - minR}${e.$3}']..sort();
    return norm.join(';');
  }

  final a = encode(false);
  final b = encode(true);
  return a.compareTo(b) <= 0 ? a : b;
}

/// 保守的可达性搜索：从地面站立格出发，返回所有能站到的格子。
Set<(int, int)> _reachable(List<String> rows) {
  final h = rows.length;
  final w = rows.first.length;
  final g = h - 3;
  bool solid(int c, int r) => c >= 0 && c < w && r >= 0 && r < h && _isSolid(rows[r][c]);
  bool standing(int c, int r) =>
      c >= 0 && c < w && r >= 0 && r < h - 1 && !solid(c, r) && solid(c, r + 1) && !solid(c, r - 1) && !solid(c, r - 2);
  final seen = <(int, int)>{};
  final queue = <(int, int)>[];
  for (var c = 0; c < w; c++) {
    if (rows[g + 1][c] == '#' && standing(c, g)) {
      seen.add((c, g));
      queue.add((c, g));
    }
  }
  while (queue.isNotEmpty) {
    final (c, r) = queue.removeLast();
    for (var c2 = c - 5; c2 <= c + 5; c2++) {
      final dx = (c2 - c).abs();
      for (var r2 = r - 4; r2 <= r + 12; r2++) {
        final rise = r - r2;
        final ok = rise >= 0 ? ((rise <= 3 && dx <= 4) || (rise == 4 && dx <= 3)) : dx <= 5;
        if (!ok || seen.contains((c2, r2)) || !standing(c2, r2)) {
          continue;
        }
        seen.add((c2, r2));
        queue.add((c2, r2));
      }
    }
  }
  return seen;
}

/// 入口砖（k=3，行 g-3）所在列 c 必须满足的条件：和既有关卡测试对坑、敌人、隧道、台阶带平台的要求一致。
bool _entryOk(List<String> base, int c) {
  final g = base.length - 3;
  final w = base.first.length;
  bool inRange(int i) => i >= 0 && i < w;
  bool isGap(int i) => base[g + 1][i] == ' ' && base[g + 2][i] == ' ';
  for (var i = c - 1; i <= c + 1; i++) {
    if (!inRange(i) || base[g + 1][i] != '#' || base[g + 2][i] != '#') {
      return false;
    }
  }
  for (var i = c - 3; i <= c + 3; i++) {
    if (!inRange(i)) {
      return false;
    }
    if (base[g - 2][i] == 'D' || (base[g][i] == 'S')) {
      return false;
    }
    final gapStart = isGap(i) && (i == 0 || !isGap(i - 1));
    if (gapStart && i >= c - 3 && i <= c + 2) {
      return false;
    }
  }
  for (var i = c - 2; i <= c + 2; i++) {
    if ('AEGRTLYJ'.contains(base[g][i]) || 'UXOI'.contains(base[g - 3][i])) {
      return false;
    }
  }
  return true;
}

void main() {
  test('S7 全部生成很快，且深渊关没有场景', () {
    final sw = Stopwatch()..start();
    _loadAll();
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(6000));
    for (var w = 0; w < _worlds; w++) {
      expect(LevelCatalog.scenesOf(w, GameConstants.depthLevelIndex), isEmpty);
    }
  });

  test('S7 同一关多次加载完全一致', () {
    for (final (w, l) in [(0, 0), (3, 5), (8, 9), (6, 10)]) {
      expect(LevelCatalog.load(w, l).rows, LevelCatalog.load(w, l).rows);
      expect(
        LevelCatalog.scenesOf(w, l).map((s) => '${s.kind}@${s.x}'),
        LevelCatalog.scenesOf(w, l).map((s) => '${s.kind}@${s.x}'),
      );
    }
  });

  test('S1 数量与多样性', () {
    for (final v in _loadAll()) {
      final planned = LevelScenes.plannedCount(v.base.width);
      final n = v.scenes.length;
      final validEntries = [
        for (var c = 3; c < v.base.width - 3; c++)
          if (_entryOk(v.base.rows, c)) c,
      ].length;
      final required = validEntries < 60 ? 2 : math.max(3, (planned * 0.5).ceil());
      expect(n, greaterThanOrEqualTo(required), reason: '${_why(v)} 入口列 $validEntries');
      expect(n, lessThanOrEqualTo(planned), reason: _why(v));
      expect(v.scenes.map((s) => s.kind).toSet().length, greaterThanOrEqualTo(math.min(n >= 8 ? 5 : 4, n)), reason: _why(v));
      final counts = <SceneKind, int>{};
      for (final s in v.scenes) {
        counts[s.kind] = (counts[s.kind] ?? 0) + 1;
      }
      for (final e in counts.entries) {
        expect(e.value, lessThanOrEqualTo((n / 3).ceil() + 1), reason: '${_why(v)} ${e.key}');
      }
      for (var i = 1; i < n; i++) {
        expect(v.scenes[i].x, greaterThanOrEqualTo(v.scenes[i - 1].x + v.scenes[i - 1].width), reason: '${_why(v)} 场景不能重叠');
        expect(v.scenes[i].kind, isNot(v.scenes[i - 1].kind), reason: '${_why(v)} 相邻重复');
      }
      expect(v.scenes.map(_topRow).toSet().length, greaterThanOrEqualTo(n >= 7 ? 3 : 2), reason: _why(v));
    }
  });

  test('S1 计划数量规则与权重表', () {
    expect(LevelScenes.plannedCount(140), 4);
    expect(LevelScenes.plannedCount(300), 10);
    expect(LevelScenes.plannedCount(464), 14);
    expect(LevelScenes.kindWeights, hasLength(_worlds));
    for (final row in LevelScenes.kindWeights) {
      expect(row, hasLength(SceneKind.values.length));
    }
    for (var w = 0; w < _worlds; w++) {
      for (var l = 0; l < _levels; l++) {
        final plan = LevelScenes.planKinds(w, l);
        expect(plan, hasLength(LevelScenes.plannedCount(140 + w * 18 + l * 18)));
        final n = plan.length;
        expect(plan.toSet().length, greaterThanOrEqualTo(math.min(6, n)), reason: 'w$w l$l');
        for (var i = 1; i < n; i++) {
          expect(plan[i], isNot(plan[i - 1]));
        }
        if (l > 0) {
          final prev = LevelScenes.planKinds(w, l - 1);
          final m = math.min(n, prev.length);
          var same = 0;
          for (var i = 0; i < m; i++) {
            if (plan[i] == prev[i]) {
              same++;
            }
          }
          expect(same / m, lessThanOrEqualTo(0.5), reason: 'w$w l$l 与上一关计划太像');
        }
      }
    }
  });

  test('S2 关与关之间不重复', () {
    final all = _loadAll();
    final signatures = <String>{};
    for (final v in all) {
      expect(signatures.add(v.scenes.map((s) => '${s.kind.name}@${s.x}').join(',')), isTrue, reason: _why(v));
    }
    for (var w = 0; w < _worlds; w++) {
      for (var l = 1; l < _levels; l++) {
        final a = all.firstWhere((v) => v.w == w && v.l == l - 1).scenes;
        final b = all.firstWhere((v) => v.w == w && v.l == l).scenes;
        final m = math.min(a.length, b.length);
        var same = 0;
        for (var i = 0; i < m; i++) {
          if (a[i].kind == b[i].kind) {
            same++;
          }
        }
        expect(same / m, lessThanOrEqualTo(0.8), reason: 'world $w level $l 和上一关太像');
      }
    }
  });

  test('S2 每种场景至少有 5 种不同形状', () {
    final shapes = {for (final k in SceneKind.values) k: <String>{}};
    for (final v in _loadAll()) {
      for (final s in v.scenes) {
        shapes[s.kind]!.add(_shapeKey(s));
      }
    }
    for (final e in shapes.entries) {
      expect(e.value.length, greaterThanOrEqualTo(5), reason: '${e.key}');
    }
  });

  test('S3 九个世界各有性格', () {
    final freq = List.generate(_worlds, (_) => List.filled(SceneKind.values.length, 0.0));
    for (final v in _loadAll()) {
      for (final s in v.scenes) {
        freq[v.w][s.kind.index]++;
      }
    }
    for (final row in freq) {
      final total = row.reduce((a, b) => a + b);
      for (var i = 0; i < row.length; i++) {
        row[i] /= total;
      }
    }
    for (var a = 0; a < _worlds; a++) {
      for (var b = a + 1; b < _worlds; b++) {
        var d = 0.0;
        for (var i = 0; i < SceneKind.values.length; i++) {
          d += (freq[a][i] - freq[b][i]).abs();
        }
        expect(d, greaterThanOrEqualTo(0.15), reason: 'world $a 与 $b 场景占比太像 ($d)');
      }
    }
  });

  test('S4 不破坏地面主路线', () {
    for (final v in _loadAll()) {
      final h = v.base.height;
      final g = h - 3;
      final w = v.base.width;
      expect(v.level.height, h, reason: _why(v));
      expect(v.level.width, w, reason: _why(v));
      final written = <(int, int)>{};
      var sceneCoins = 0;
      var sceneM = 0;
      for (final s in v.scenes) {
        for (final e in s.cells.entries) {
          final (c, r) = e.key;
          expect('=?CM'.contains(e.value), isTrue, reason: '${_why(v)} 写入了 ${e.value}');
          expect(written.add(e.key), isTrue, reason: '${_why(v)} 格子被重复写入 $c,$r');
          expect(v.base.rows[r][c], ' ', reason: '${_why(v)} 覆盖了已有内容 $c,$r');
          expect(v.level.rows[r][c], e.value, reason: _why(v));
          if ('=?'.contains(e.value)) {
            expect(r == g - 3 || (r >= g - 10 && r <= g - 7), isTrue, reason: '${_why(v)} 砖的高度 $c,$r');
          } else {
            expect(r, inInclusiveRange(g - 12, g - 4), reason: '${_why(v)} 奖励的高度 $c,$r');
          }
          if (e.value == 'C') {
            sceneCoins++;
          }
          if (e.value == 'M') {
            sceneM++;
          }
          if (r == g - 3 && '=?'.contains(e.value)) {
            expect(_entryOk(v.base.rows, c), isTrue, reason: '${_why(v)} 入口砖 $c,$r 的地面不合格');
          }
        }
        expect(_runs(s).any((run) => run.$1 == g - 3 && run.$3 >= 1), isTrue, reason: '${_why(v)} ${s.kind} 缺入口');
      }
      for (var r = 0; r < h; r++) {
        for (var c = 0; c < w; c++) {
          if (v.base.rows[r][c] != v.level.rows[r][c]) {
            expect(written.contains((c, r)), isTrue, reason: '${_why(v)} 有未登记的改动 $c,$r');
          }
        }
      }
      expect(sceneCoins, lessThanOrEqualTo(12), reason: _why(v));
      expect(sceneM, lessThanOrEqualTo(1), reason: _why(v));
      final baseCoins = v.base.rows.join().split('C').length - 1;
      final finalCoins = v.level.rows.join().split('C').length - 1;
      expect(finalCoins, lessThanOrEqualTo(math.max(96, baseCoins)), reason: _why(v));

      if (v.l == _levels - 1) {
        final boss = v.base.rows[g].indexOf('B');
        expect(boss, greaterThanOrEqualTo(0));
        for (final (c, _) in written) {
          expect((c - boss).abs(), greaterThan(14), reason: '${_why(v)} 场景离 Boss 太近');
        }
      }
      for (var c = 0; c < w; c++) {
        if (v.base.rows[g][c] != 'S') {
          continue;
        }
        for (final e in v.scenes.expand((s) => s.cells.entries)) {
          final (wc, wr) = e.key;
          if ('=?'.contains(e.value) && wr >= g - 7) {
            expect(wc < c - 3 || wc > c + 9, isTrue, reason: '${_why(v)} 地面弹簧 $c 的飞行通道里有砖 $wc,$wr');
          }
        }
      }
      for (var r = 0; r < g; r++) {
        for (var c = 0; c < w; c++) {
          if (v.base.rows[r][c] != 'S') {
            continue;
          }
          for (final (wc, _) in written) {
            expect(wc < c - 3 || wc > c + 11, isTrue, reason: '${_why(v)} 场景挡住了天空弹簧通道 $c');
          }
        }
      }
    }
  });

  test('S5 场景都走得上去', () {
    for (final v in _loadAll()) {
      final reach = _reachable(v.level.rows);
      bool solid(int c, int r) => _isSolid(v.level.rows[r][c]);
      for (final s in v.scenes) {
        for (final run in _runs(s)) {
          final (r, c0, len) = run;
          final exposed = [
            for (var c = c0; c < c0 + len; c++)
              if (r > 0 && !solid(c, r - 1)) c,
          ];
          if (exposed.isEmpty) {
            continue;
          }
          expect(
            exposed.any((c) => reach.contains((c, r - 1))),
            isTrue,
            reason: '${_why(v)} ${s.kind}@${s.x} 行 $r 列 $c0 起的 $len 块砖上不去',
          );
        }
        for (final e in s.cells.entries) {
          if (e.value == 'M') {
            expect(reach.contains(e.key), isTrue, reason: '${_why(v)} ${s.kind} 的马卡龙拿不到 ${e.key}');
          }
        }
      }
    }
  });

  test('S6 每种场景长得对', () {
    final seen = {for (final k in SceneKind.values) k: 0};
    for (final v in _loadAll()) {
      for (final s in v.scenes) {
        seen[s.kind] = seen[s.kind]! + 1;
        final runs = _runs(s);
        final why = '${_why(v)} ${s.kind}@${s.x}';
        switch (s.kind) {
          case SceneKind.staircase:
            final rows = [for (final r in runs) r.$1];
            expect(rows.toSet().length, greaterThanOrEqualTo(3), reason: why);
            final desc = [for (var i = 1; i < rows.length; i++) rows[i] < rows[i - 1]].every((b) => b);
            final asc = [for (var i = 1; i < rows.length; i++) rows[i] > rows[i - 1]].every((b) => b);
            expect(desc || asc, isTrue, reason: '$why 不是单调的阶梯 $rows');
          case SceneKind.archipelago:
            expect(runs.length, greaterThanOrEqualTo(4), reason: why);
          case SceneKind.tower:
            expect(runs.map((r) => r.$1).toSet().length, greaterThanOrEqualTo(4), reason: why);
            expect(s.width, lessThanOrEqualTo(10), reason: why);
          case SceneKind.skyBridge:
            expect(runs.any((r) => r.$3 >= 8), isTrue, reason: why);
          case SceneKind.ziggurat:
            var found = false;
            for (final a in runs) {
              for (final b in runs) {
                for (final c in runs) {
                  if (b.$1 == a.$1 - 1 && c.$1 == a.$1 - 2 && a.$3 > b.$3 && b.$3 > c.$3 && b.$2 >= a.$2 && b.$2 + b.$3 <= a.$2 + a.$3 && c.$2 >= b.$2 && c.$2 + c.$3 <= b.$2 + b.$3) {
                    found = true;
                  }
                }
              }
            }
            expect(found, isTrue, reason: why);
          case SceneKind.valley:
            final rows = [for (final r in runs) r.$1];
            var trough = false;
            for (var i = 1; i < rows.length - 1; i++) {
              if (rows[i - 1] <= rows[i] - 3 && rows[i + 1] <= rows[i] - 3) {
                trough = true;
              }
            }
            expect(trough, isTrue, reason: '$why $rows');
          case SceneKind.cloudRoom:
            var room = false;
            for (final floor in runs) {
              for (final roof in runs) {
                final overlap = math.min(floor.$2 + floor.$3, roof.$2 + roof.$3) - math.max(floor.$2, roof.$2);
                if (roof.$1 <= floor.$1 - 3 && overlap >= 6) {
                  room = true;
                }
              }
            }
            expect(room, isTrue, reason: why);
            expect(s.cells.values.contains('?'), isTrue, reason: why);
          case SceneKind.hangingGarden:
            var garden = false;
            for (final deck in runs.where((r) => r.$3 >= 8)) {
              var hangers = 0;
              for (var c = deck.$2; c < deck.$2 + deck.$3; c++) {
                if (s.cells[(c, deck.$1 + 1)] == '=') {
                  hangers++;
                }
              }
              if (hangers >= 2) {
                garden = true;
              }
            }
            expect(garden, isTrue, reason: why);
          case SceneKind.coinWave:
            final coinRows = [for (final e in s.cells.entries) if (e.value == 'C') e.key.$2];
            expect(coinRows.length, greaterThanOrEqualTo(6), reason: why);
            expect(coinRows.toSet().length, greaterThanOrEqualTo(3), reason: why);
        }
      }
    }
    for (final e in seen.entries) {
      expect(e.value, greaterThan(0), reason: '${e.key} 一次都没出现');
    }
  });
}
