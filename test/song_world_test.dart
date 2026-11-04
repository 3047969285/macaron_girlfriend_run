// 歌曲世界验收测试，对应 docs/歌曲世界/PRD.md 的 W1–W6。
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/audio_service.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/level_catalog.dart';
import 'package:macaron_girlfriend_run/data/level_scenes.dart';
import 'package:macaron_girlfriend_run/data/song_profile.dart';

const _bpm = [84.5, 130.5, 143.0, 88.0, 125.0, 136.0];

const _energy = <List<double>>[
  [0.00, 0.06, 0.16, 0.26, 0.35, 0.48, 0.55, 0.61, 0.74, 0.81, 0.97, 0.94, 0.84, 0.65, 0.19, 0.10, 0.13, 0.23, 0.29, 0.39, 0.52, 0.58, 0.71, 0.77, 0.90, 1.00, 0.87, 0.68, 0.32, 0.45, 0.42, 0.03],
  [0.00, 0.06, 0.10, 0.16, 0.19, 0.23, 0.26, 0.29, 0.35, 0.52, 0.58, 0.55, 0.45, 0.39, 0.42, 0.48, 0.61, 0.84, 0.81, 0.77, 0.87, 0.97, 0.94, 0.71, 0.68, 0.74, 0.90, 1.00, 0.65, 0.32, 0.13, 0.03],
  [0.03, 0.06, 0.23, 0.35, 0.29, 0.32, 0.19, 0.16, 0.10, 0.13, 0.26, 0.39, 0.42, 0.48, 0.52, 0.55, 0.58, 0.61, 0.68, 0.71, 0.74, 0.81, 0.94, 1.00, 0.90, 0.84, 0.87, 0.97, 0.77, 0.65, 0.45, 0.00],
  [0.06, 0.10, 0.16, 0.19, 0.23, 0.29, 0.45, 0.55, 0.71, 1.00, 0.97, 0.65, 0.52, 0.32, 0.26, 0.35, 0.42, 0.48, 0.61, 0.68, 0.74, 0.84, 0.94, 0.90, 0.81, 0.87, 0.77, 0.58, 0.39, 0.13, 0.03, 0.00],
  [0.03, 0.06, 0.10, 0.32, 0.55, 0.65, 0.52, 0.58, 0.39, 0.29, 0.16, 0.13, 0.19, 0.26, 0.45, 0.97, 0.90, 0.74, 0.68, 0.84, 0.77, 0.42, 0.35, 0.48, 1.00, 0.94, 0.81, 0.61, 0.71, 0.87, 0.23, 0.00],
  [0.03, 0.06, 0.13, 0.29, 0.58, 0.87, 0.77, 0.68, 0.65, 0.61, 0.74, 0.90, 0.94, 0.71, 0.55, 0.52, 0.45, 0.35, 0.16, 0.10, 0.19, 0.32, 0.23, 0.39, 0.42, 0.48, 0.81, 1.00, 0.97, 0.84, 0.26, 0.00],
];

const _motifs = <String>[
  '.C.C.\nC...C\n.C.C.\n..C..\n.....',
  '.CCC.\nC...C\nC...C\nC...C\n.....',
  '.CCC.\n....C\n..CC.\n.....\n..C..',
  '.CC..\nC....\nC....\nC....\n.CC..',
  '..C..\n.C.C.\nC.C.C\n.C.C.\n..C..',
  '..C..\n...C.\nCCCCC\n...C.\n..C..',
];

const _loud = [0.7, 0.3, 1.0, 0.4, 0.9, 0.5, 0.8, 0.3, 0.1];

Set<(int, int)> _parse(String art) {
  final rows = art.split('\n');
  return {
    for (var r = 0; r < rows.length; r++)
      for (var c = 0; c < rows[r].length; c++)
        if (rows[r][c] == 'C') (c, 4 - r),
  };
}

Set<(int, int)> _normalize(Iterable<(int, int)> cells) {
  final minC = cells.map((e) => e.$1).reduce(math.min);
  final minR = cells.map((e) => e.$2).reduce(math.min);
  return {for (final e in cells) (e.$1 - minC, e.$2 - minR)};
}

bool _sameSet(Set<(int, int)> a, Set<(int, int)> b) => a.length == b.length && a.every(b.contains);

Set<(int, int)> _mirror(Set<(int, int)> cells) {
  final maxC = cells.map((e) => e.$1).reduce(math.max);
  return {for (final e in cells) (maxC - e.$1, e.$2)};
}

typedef _Lv = ({int w, int l, int width, int g, List<PlacedScene> scenes});

List<_Lv> _levels() => [
  for (var w = 0; w < GameConstants.worldCount; w++)
    for (var l = 0; l < GameConstants.levelsPerWorld; l++)
      (
        w: w,
        l: l,
        width: LevelCatalog.loadBase(w, l).width,
        g: LevelCatalog.loadBase(w, l).height - 3,
        scenes: LevelCatalog.scenesOf(w, l),
      ),
];

double _centerEnergy(_Lv v, PlacedScene s) {
  const lo = 18;
  final hi = v.width - 22;
  final t = ((s.x + s.width / 2 - lo) / (hi - lo)).clamp(0.0, 1.0);
  return SongProfile.levelEnergyAt(v.w, v.l, t);
}

int _topRow(PlacedScene s) =>
    s.cells.entries.where((e) => '=?'.contains(e.value)).map((e) => e.key.$2).reduce(math.min);

void main() {
  test('W1 歌曲数据与映射', () {
    expect(SongProfile.songs, hasLength(6));
    expect(SongProfile.worldSongs, [0, 1, 2, 3, 4, 5, 5, 1, 0]);
    for (var i = 0; i < 6; i++) {
      final s = SongProfile.songs[i];
      expect(s.title, AudioService.songs[i].title);
      expect(s.bpm, _bpm[i]);
      expect(s.energy, hasLength(32));
      for (var k = 0; k < 32; k++) {
        expect(s.energy[k], closeTo(_energy[i][k], 1e-9), reason: '${s.title} 点 $k');
      }
      expect(s.energy.reduce(math.max), greaterThanOrEqualTo(0.95));
      expect(s.energy.reduce(math.min), lessThanOrEqualTo(0.1));
      expect(s.bpm, inInclusiveRange(60, 180));
      expect(_normalize(s.motif.map((e) => (e.$1, e.$2))), _normalize(_parse(_motifs[i])), reason: '${s.title} 糖果造型');
      expect(s.motif.length, lessThanOrEqualTo(10));
    }
    for (var w = 0; w < GameConstants.worldCount; w++) {
      expect(SongProfile.of(w).title, AudioService.songTitleFor(w), reason: 'world $w');
    }
    expect(SongProfile.songIndexOf(-3), 0);
    expect(SongProfile.songIndexOf(40), SongProfile.worldSongs.last);
    final shapes = {for (final s in SongProfile.songs) _normalize(s.motif.map((e) => (e.$1, e.$2))).toList().toString()};
    expect(shapes, hasLength(6));
  });

  test('W1 小节长度', () {
    for (var w = 0; w < GameConstants.worldCount; w++) {
      final b = SongProfile.barTiles(w);
      expect(b, inInclusiveRange(12, 24));
      expect(b, (1840 / SongProfile.of(w).bpm).round().clamp(12, 24));
    }
    expect(SongProfile.barTiles(0), 22);
    expect(SongProfile.barTiles(2), 13);
  });

  test('W2 关卡在歌里的位置', () {
    expect(SongProfile.windowStart(0), 0);
    expect(SongProfile.windowStart(10), closeTo(0.5, 1e-12));
    for (var w = 0; w < GameConstants.worldCount; w++) {
      final e = SongProfile.of(w).energy;
      expect(SongProfile.levelEnergyAt(w, 0, 0), closeTo(e.first, 1e-12));
      expect(SongProfile.levelEnergyAt(w, 10, 1), closeTo(e.last, 1e-12));
      expect(SongProfile.levelEnergyAt(w, 5, -1), SongProfile.levelEnergyAt(w, 5, 0));
      expect(SongProfile.levelEnergyAt(w, 5, 2), SongProfile.levelEnergyAt(w, 5, 1));
      // 窗口中点在 31 点曲线上的线性插值
      final pos = (0.25 + 0.5 * 0.5) * 31;
      final i = pos.floor();
      final want = e[i] + (e[i + 1] - e[i]) * (pos - i);
      expect(SongProfile.levelEnergyAt(w, 5, 0.5), closeTo(want, 1e-9));
      for (var l = 1; l < 11; l++) {
        expect(SongProfile.windowStart(l), greaterThan(SongProfile.windowStart(l - 1)));
      }
    }
  });

  test('W3 场景疏密和种类跟着响度走', () {
    expect(LevelScenes.kindLoudness, _loud);
    final all = _levels();
    final energies = [for (final v in all) for (final s in v.scenes) _centerEnergy(v, s)];
    final loud = energies.where((e) => e > 0.5).length;
    final quiet = energies.where((e) => e <= 0.5).length;
    expect(loud / quiet, greaterThanOrEqualTo(1.25), reason: '响 $loud 轻 $quiet');

    final xs = energies;
    final ys = [for (final v in all) for (final s in v.scenes) _loud[s.kind.index]];
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

  test('W4 场景起点落在小节线上', () {
    var near = 0;
    var total = 0;
    for (final v in _levels()) {
      final bar = SongProfile.barTiles(v.w);
      for (final s in v.scenes) {
        final off = (s.x - 18) % bar;
        total++;
        if (math.min(off, bar - off) <= 2) {
          near++;
        }
      }
    }
    expect(near / total, greaterThanOrEqualTo(0.5), reason: '$near / $total');
  });

  test('W5 每关一个高潮场景，且够高', () {
    for (final v in _levels()) {
      if (v.scenes.length < 5) {
        continue;
      }
      final why = 'world ${v.w} level ${v.l}';
      final climax = v.scenes.where((s) => s.climax).toList();
      expect(climax, hasLength(1), reason: why);
      const lo = 18;
      final hi = v.width - 22;
      var peakX = lo;
      var peakE = -1.0;
      for (var x = lo; x <= hi; x++) {
        final e = SongProfile.levelEnergyAt(v.w, v.l, (x - lo) / (hi - lo));
        if (e > peakE) {
          peakE = e;
          peakX = x;
        }
      }
      double dist(PlacedScene s) => (s.x + s.width / 2 - peakX).abs();
      final nearest = v.scenes.reduce((a, b) => dist(a) <= dist(b) ? a : b);
      expect(identical(nearest, climax.single) || dist(climax.single) <= dist(nearest) + 8, isTrue, reason: '$why 高潮不在最高点附近');
      expect(_topRow(climax.single), lessThanOrEqualTo(v.g - 9), reason: '$why 高潮不够高');
    }
  });

  test('W6 糖果波用歌的标志造型', () {
    final perWorld = List.filled(GameConstants.worldCount, 0);
    var waves = 0;
    var motifs = 0;
    for (final v in _levels()) {
      final song = SongProfile.songIndexOf(v.w);
      final want = _normalize(_parse(_motifs[song]));
      final wantMirror = _mirror(want);
      for (final s in v.scenes) {
        if (s.kind == SceneKind.coinWave) {
          waves++;
        }
        if (!s.motif) {
          continue;
        }
        motifs++;
        perWorld[v.w]++;
        expect(s.kind, SceneKind.coinWave, reason: 'world ${v.w} level ${v.l}');
        final coins = _normalize([for (final e in s.cells.entries) if (e.value == 'C') (e.key.$1, -e.key.$2)]);
        expect(_sameSet(coins, want) || _sameSet(coins, wantMirror), isTrue, reason: 'world ${v.w} level ${v.l} 造型和 ${SongProfile.of(v.w).title} 不一致');
      }
    }
    for (var w = 0; w < GameConstants.worldCount; w++) {
      expect(perWorld[w], greaterThan(0), reason: 'world $w 没有标志造型');
    }
    expect(motifs / waves, inInclusiveRange(0.5, 0.9), reason: '$motifs / $waves');
  });
}
