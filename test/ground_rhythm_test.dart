// 地面节奏验收测试，对应 docs/地面节奏/PRD.md 的 G1–G5。
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/level_catalog.dart';
import 'package:macaron_girlfriend_run/data/song_profile.dart';

typedef _Pit = (int start, int len);
typedef _Lv = ({int w, int l, int width, List<_Pit> pits});

List<_Pit> _pitsOf(List<String> rows) {
  final h = rows.length;
  final width = rows.first.length;
  final pits = <_Pit>[];
  for (var x = 2; x <= width - 3;) {
    if (rows[h - 1][x] == ' ' && rows[h - 2][x] == ' ') {
      final start = x;
      while (x <= width - 3 && rows[h - 1][x] == ' ' && rows[h - 2][x] == ' ') {
        x++;
      }
      pits.add((start, x - start));
    } else {
      x++;
    }
  }
  return pits;
}

List<_Lv> _levels() => [
  for (var w = 0; w < GameConstants.worldCount; w++)
    for (var l = 0; l < GameConstants.levelsPerWorld; l++)
      (
        w: w,
        l: l,
        width: LevelCatalog.loadBase(w, l).width,
        pits: _pitsOf(LevelCatalog.loadBase(w, l).rows),
      ),
];

List<int> _spacings(List<_Pit> pits) => [for (var i = 1; i < pits.length; i++) pits[i].$1 - pits[i - 1].$1];

void main() {
  final all = _levels();
  final normal = all.where((v) => v.l != GameConstants.levelsPerWorld - 1).toList();

  test('G1 间隔不等距', () {
    for (final v in normal) {
      if (v.pits.length < 6) {
        continue;
      }
      final sp = _spacings(v.pits);
      for (var i = 0; i + 2 < sp.length; i++) {
        expect(sp[i] == sp[i + 1] && sp[i + 1] == sp[i + 2], isFalse, reason: 'world ${v.w} level ${v.l} 连续三个相同间隔 ${sp[i]} @${v.pits[i].$1}');
      }
      expect(sp.toSet().length, greaterThanOrEqualTo(4), reason: 'world ${v.w} level ${v.l} 间隔种类太少 $sp');
    }
  });

  test('G2 宽度混用', () {
    for (final v in normal) {
      if (v.pits.length < 8) {
        continue;
      }
      final widths = v.pits.map((p) => p.$2).toSet();
      expect(widths, containsAll([1, 2]), reason: 'world ${v.w} level ${v.l} $widths');
      expect(widths.every((w) => w <= 2), isTrue, reason: 'world ${v.w} level ${v.l} 坑宽 ≤ 2');
    }
  });

  test('G3 双坑', () {
    var eligible = 0;
    var withDouble = 0;
    for (final v in normal) {
      if (v.pits.length < 6) {
        continue;
      }
      eligible++;
      for (var i = 1; i < v.pits.length; i++) {
        if (v.pits[i].$1 == v.pits[i - 1].$1 + v.pits[i - 1].$2 + 2) {
          withDouble++;
          break;
        }
      }
    }
    expect(eligible, greaterThan(20));
    expect(withDouble / eligible, greaterThanOrEqualTo(0.3), reason: '$withDouble / $eligible');
  });

  test('G4 疏密跟着响度', () {
    final xs = <double>[];
    final ys = <double>[];
    for (final v in normal) {
      for (var bin = 1; bin < (v.width - 20) ~/ 10; bin++) {
        final lo = bin * 10;
        final count = v.pits.where((p) => p.$1 >= lo && p.$1 < lo + 10).length;
        xs.add(SongProfile.levelEnergyAt(v.w, v.l, (lo + 5) / v.width));
        ys.add(count.toDouble());
      }
    }
    final mx = xs.reduce((a, b) => a + b) / xs.length;
    final my = ys.reduce((a, b) => a + b) / ys.length;
    var sxy = 0.0, sxx = 0.0, syy = 0.0;
    for (var i = 0; i < xs.length; i++) {
      sxy += (xs[i] - mx) * (ys[i] - my);
      sxx += (xs[i] - mx) * (xs[i] - mx);
      syy += (ys[i] - my) * (ys[i] - my);
    }
    expect(sxy / math.sqrt(sxx * syy), greaterThan(0.15));
  });

  test('G5 确定性，且起点终点地面完整', () {
    for (final (w, l) in [(0, 0), (4, 5), (8, 9)]) {
      expect(LevelCatalog.loadBase(w, l).rows, LevelCatalog.loadBase(w, l).rows);
    }
    for (final v in all) {
      final rows = LevelCatalog.loadBase(v.w, v.l).rows;
      final h = rows.length;
      for (final x in [2, v.width - 3]) {
        expect(rows[h - 1][x], '#', reason: 'world ${v.w} level ${v.l} 端点地面 $x');
        expect(rows[h - 2][x], '#', reason: 'world ${v.w} level ${v.l} 端点地面 $x');
      }
      for (final p in v.pits) {
        expect(p.$2, lessThanOrEqualTo(2), reason: 'world ${v.w} level ${v.l} 坑宽');
      }
    }
  });
}
