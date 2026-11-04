import 'dart:math' as math;

import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/lyric_world.dart';
import 'package:macaron_girlfriend_run/data/song_profile.dart';

/// 场景种类，顺序与 [LevelScenes.kindWeights] 的列一致。
enum SceneKind { staircase, archipelago, tower, skyBridge, ziggurat, valley, cloudRoom, hangingGarden, coinWave }

/// 一个已放置的场景。坐标是最终关卡行数据里的绝对 (列, 行)。
class PlacedScene {
  const PlacedScene({
    required this.kind,
    required this.x,
    required this.width,
    required this.mirrored,
    required this.cells,
    this.climax = false,
    this.motif = false,
    this.lyricRoute,
  });

  /// 种类。
  final SceneKind kind;

  /// 占地左端列（含）。
  final int x;

  /// 占地列数。
  final int width;

  /// 是否左右镜像。
  final bool mirrored;

  /// (列, 行) -> '=' | '?' | 'C' | 'M'，只含本场景写入的格子。
  final Map<(int, int), String> cells;

  /// 本关响度最高点最近的场景。
  final bool climax;

  /// 糖果波摆成了歌的标志造型。
  final bool motif;
  final String? lyricRoute;

  /// 同一个场景，标为高潮。
  PlacedScene asClimax() => PlacedScene(kind: kind, x: x, width: width, mirrored: mirrored, cells: cells, climax: true, motif: motif, lyricRoute: lyricRoute);
}

/// 带场景的关卡行数据，场景按 x 从左到右。
class SceneResult {
  const SceneResult(this.rows, this.scenes);

  final List<String> rows;
  final List<PlacedScene> scenes;
}

/// 形状单元：(相对列, 离地高度 k, 字符)。
typedef _Cell = (int, int, String);

/// 天空层之上的场景组合：每关按世界权重规划种类，再在地面上方找空位放置。
class LevelScenes {
  LevelScenes._();

  /// 世界权重，下标 = 世界，列 = [SceneKind.index]。
  static const List<List<int>> kindWeights = [
    [4, 1, 1, 4, 1, 2, 1, 1, 4],
    [3, 1, 1, 1, 4, 1, 1, 4, 2],
    [1, 4, 4, 1, 1, 1, 1, 1, 4],
    [1, 6, 2, 4, 1, 1, 1, 1, 1],
    [3, 1, 1, 3, 1, 5, 1, 1, 3],
    [1, 1, 4, 1, 2, 1, 2, 4, 1],
    [3, 1, 1, 1, 1, 4, 3, 2, 1],
    [1, 1, 2, 1, 4, 1, 3, 5, 1],
    [2, 2, 2, 2, 2, 2, 2, 2, 2],
  ];

  /// 种类的响度分，顺序同 [SceneKind.values]。
  static const List<double> kindLoudness = [0.7, 0.3, 1.0, 0.4, 0.9, 0.5, 0.8, 0.3, 0.1];

  /// 计划场景数：clamp(关卡宽度 ÷ 30, 4, 14)。
  static int plannedCount(int width) => (width ~/ 30).clamp(4, 14);

  /// 关卡的场景种类计划（与 [compose] 同一套种子）。种类先按响度匹配到槽位，再要求相邻不重复、
  /// 相邻两关按位置对齐的相同比例不超过一半；换盐重抽最多 40 次。
  static List<SceneKind> planKinds(int world, int level) {
    final count = plannedCount(_levelWidth(world, level));
    final prev = level > 0 ? planKinds(world, level - 1) : null;
    for (var t = 0; t < 40; t++) {
      final salt = t * 1000;
      final plan = _loudnessMatch(_rawPlan(world, level, salt, count), world, level, salt);
      if (_adjacentFree(plan) && (prev == null || _sameShare(plan, prev) <= 0.5)) {
        return plan;
      }
    }
    return _rawPlan(world, level, 0, count);
  }

  static int _levelWidth(int world, int level) => 140 + world * 18 + level * 18;

  /// 场景槽位的左右范围：[_lo, _hi(width)]。
  static const int _lo = 18;
  static int _hi(int width) => width - 22;

  /// 槽位列：在 [_lo, _hi] 上按 0.15 + 响度加权做逆累积分布取点，吸附到最近的小节线（_lo + k × 小节长度），
  /// 与前一个槽位至少隔半小节（不够就顺延到下一条小节线）。
  static List<int> _slotColumns(int world, int level, int n, int width) {
    final hi = _hi(width);
    final bar = SongProfile.barTiles(world);
    final cum = List<double>.filled(hi - _lo + 1, 0);
    var total = 0.0;
    for (var x = _lo; x <= hi; x++) {
      total += 0.15 + SongProfile.levelEnergyAt(world, level, (x - _lo) / (hi - _lo));
      cum[x - _lo] = total;
    }
    final cols = <int>[];
    var x = _lo;
    for (var i = 0; i < n; i++) {
      final target = (i + 0.5) / n * total;
      while (x < hi && cum[x - _lo] < target) {
        x++;
      }
      var c = _lo + (x - _lo + bar ~/ 2) ~/ bar * bar;
      if (cols.isNotEmpty && c < cols.last + bar ~/ 2) {
        c = _lo + (cols.last + bar ~/ 2 - _lo + bar - 1) ~/ bar * bar;
      }
      cols.add(math.min(c, hi));
    }
    return cols;
  }

  /// 响度匹配：计划里的种类按响度从低到高，与槽位（响度加 ±0.1 抖动）按响度从低到高一一对应；结果仍按槽位从左到右排列。
  static List<SceneKind> _loudnessMatch(List<SceneKind> raw, int world, int level, int salt) {
    final n = raw.length;
    final width = _levelWidth(world, level);
    final rnd = math.Random(world * 1009 + level * 37 + 11 + salt + 1);
    final loud = [
      for (final c in _slotColumns(world, level, n, width))
        SongProfile.levelEnergyAt(world, level, (c - _lo) / (_hi(width) - _lo)) + rnd.nextDouble() * 0.2 - 0.1,
    ];
    final slotRank = [for (var i = 0; i < n; i++) i]..sort((a, b) => loud[a].compareTo(loud[b]));
    final byLoudness = [...raw]..sort((a, b) =>
      (kindLoudness[a.index] + LyricWorld.sceneBias(world, level, a.index)).compareTo(
        kindLoudness[b.index] + LyricWorld.sceneBias(world, level, b.index)));
    final out = [...raw];
    for (var r = 0; r < n; r++) {
      out[slotRank[r]] = byLoudness[r];
    }
    return out;
  }

  static bool _adjacentFree(List<SceneKind> plan) => [for (var i = 1; i < plan.length; i++) plan[i] != plan[i - 1]].every((b) => b);

  /// 在 [rows]（已含天空层）上方放置场景。地面站立行 g = rows.length - 3。
  /// 最高砖行、种类不够多样，或高潮不够高时换种子重放，最多 4 次，取得分最高的一次。
  static SceneResult compose(List<String> rows, int world, int level) {
    SceneResult? best;
    var bestScore = -1;
    final want = plannedCount(rows.first.length) - 2;
    final g = rows.length - 3;
    for (var salt = 0; salt < 4; salt++) {
      final r = _composeOnce(rows, world, level, salt);
      final n = r.scenes.length;
      final topOk = r.scenes.map(_topRow).toSet().length >= (n >= 7 ? 3 : 2);
      final kindOk = r.scenes.map((s) => s.kind).toSet().length >= math.min(n >= 8 ? 5 : 4, n);
      final climaxOk = r.scenes.every((s) => !s.climax || _topRow(s) <= g - 9);
      final score = (topOk ? 400 : 0) + (kindOk ? 200 : 0) + (climaxOk ? 100 : 0) + math.min<int>(n, want);
      if (score > bestScore) {
        best = r;
        bestScore = score;
      }
      if (topOk && kindOk && climaxOk && n >= want) {
        break;
      }
    }
    return best!;
  }

  static SceneResult _composeOnce(List<String> rows, int world, int level, int salt) {
    final grid = [for (final r in rows) r.split('')];
    final g = grid.length - 3;
    final w = grid.first.length;
    final banned = List.filled(w, false);
    for (var r = 0; r < g; r++) {
      for (var c = 0; c < w; c++) {
        if (grid[r][c] == 'S') {
          for (var x = math.max(0, c - 3); x <= math.min(w - 1, c + 11); x++) {
            banned[x] = true;
          }
        }
      }
    }
    // 地面弹簧的飞行区（左 3、右 11 列，同天空弹簧）：弹起的玩家落在基础台阶上时，这里的砖不能挡住它。
    final springZone = List.filled(w, false);
    for (var c = 0; c < w; c++) {
      if (grid[g][c] == 'S') {
        for (var x = math.max(0, c - 3); x <= math.min(w - 1, c + 11); x++) {
          springZone[x] = true;
        }
      }
    }
    final baseCoins = rows.fold(0, (n, r) => n + 'C'.allMatches(r).length);
    final boss = level == GameConstants.levelsPerWorld - 1 ? grid[g].indexOf('B') : -1;
    final writer = _Writer(grid, banned, springZone, boss, math.max(0, math.min(12, 96 - baseCoins)), SongProfile.of(world).motif, SongProfile.songIndexOf(world), level);
    final kinds = planKinds(world, level);
    final seed = world * 1009 + level * 37 + 11 + salt * 100003;
    final slots = _slotColumns(world, level, kinds.length, w);
    final seg = (_hi(w) - _lo) ~/ kinds.length;
    final placed = <PlacedScene>[];
    final pending = <int>[];
    for (var i = 0; i < kinds.length; i++) {
      final rnd = math.Random(seed + i * 17);
      final last = placed.isEmpty ? null : placed.last;
      final minX = last == null ? _lo : math.max(_lo, last.x + last.width + 2);
      final s = _fallback(writer, kinds[i], last?.kind, null, rnd, slots[i], seg ~/ 2, minX, w - 20, near: 2);
      if (s != null) {
        placed.add(s);
      } else {
        pending.add(i);
      }
    }
    // 第二轮（实现增补）：段内放不下的，去已放场景之间的空隙里找位置，列表保持从左到右。
    for (final i in pending) {
      final target = slots[i];
      int gapLeft(int j) => j == 0 ? _lo : placed[j - 1].x + placed[j - 1].width + 2;
      int gapRight(int j) => j == placed.length ? w - 20 : placed[j].x - 3;
      final order = [for (var j = 0; j <= placed.length; j++) j]
        ..sort((a, b) => ((gapLeft(a) + gapRight(a)) ~/ 2 - target).abs().compareTo(((gapLeft(b) + gapRight(b)) ~/ 2 - target).abs()));
      // 种类不足 5 种时先试本关还没有的种类，保证至少 min(5, n) 种。
      final have = {for (final s in placed) s.kind};
      final cands = have.length < 5 ? [for (final k in SceneKind.values) if (!have.contains(k)) k, kinds[i]] : [kinds[i]];
      done:
      for (final kind in cands) {
        for (final j in order) {
          final minX = gapLeft(j);
          final maxX = gapRight(j);
          if (maxX - minX < 6) {
            continue;
          }
          final s = _fallback(writer, kind, j == 0 ? null : placed[j - 1].kind, j == placed.length ? null : placed[j].kind,
              math.Random(seed + i * 17 + 7), (minX + maxX) ~/ 2, (maxX - minX) ~/ 2, minX, maxX);
          if (s != null) {
            placed.insert(j, s);
            break done;
          }
        }
      }
    }
    _climax(writer, placed, world, level, w, g, math.Random(seed + 97));
    return SceneResult([for (final r in grid) r.join()], placed);
  }

  /// 离全关响度最高点最近的场景标为高潮。它的最高砖不到 g − 9 时，换成 tower / ziggurat / cloudRoom 中第一个放得下的；都放不下则保留原样。
  static void _climax(_Writer writer, List<PlacedScene> placed, int world, int level, int width, int g, math.Random rnd) {
    if (placed.isEmpty) {
      return;
    }
    final hi = _hi(width);
    var peak = _lo;
    var peakE = -1.0;
    for (var x = _lo; x <= hi; x++) {
      final e = SongProfile.levelEnergyAt(world, level, (x - _lo) / (hi - _lo));
      if (e > peakE) {
        peakE = e;
        peak = x;
      }
    }
    double dist(PlacedScene s) => (s.x + s.width / 2 - peak).abs();
    var idx = 0;
    for (var i = 1; i < placed.length; i++) {
      if (dist(placed[i]) < dist(placed[idx])) {
        idx = i;
      }
    }
    final old = placed[idx];
    if (_topRow(old) <= g - 9) {
      placed[idx] = old.asClimax();
      return;
    }
    final left = idx > 0 ? placed[idx - 1] : null;
    final right = idx < placed.length - 1 ? placed[idx + 1] : null;
    final minX = left == null ? _lo : left.x + left.width + 2;
    final maxX = right == null ? width - 20 : right.x - 3;
    final cap = (placed.length + 2) ~/ 3 + 1;
    writer.release(old);
    for (final kind in const [SceneKind.tower, SceneKind.ziggurat, SceneKind.cloudRoom]) {
      final used = placed.where((s) => s.kind == kind).length - (old.kind == kind ? 1 : 0);
      if (used + 1 > cap) {
        continue;
      }
      final taller = writer.place(kind, left?.kind, right?.kind, rnd, old.x + old.width ~/ 2, maxX - minX, minX, maxX);
      if (taller != null) {
        placed[idx] = taller.asClimax();
        return;
      }
    }
    writer.reclaim(old);
    placed[idx] = old.asClimax();
  }

  static int _topRow(PlacedScene s) => s.cells.entries.where((e) => '=?'.contains(e.value)).map((e) => e.key.$2).reduce(math.min);

  /// 先试吸附后的列 ±[near]，再用 ±[span] 搜索；都放不下再用糖果波（糖果波本身放不下就返回 null）。
  static PlacedScene? _fallback(_Writer writer, SceneKind kind, SceneKind? left, SceneKind? right, math.Random rnd, int target, int span,
      int minX, int maxX, {int near = 0}) {
    final s = writer.place(kind, left, right, rnd, target, span, minX, maxX, near: near);
    if (s != null || kind == SceneKind.coinWave) {
      return s;
    }
    return writer.place(SceneKind.coinWave, left, right, rnd, target, span, minX, maxX, near: near);
  }

  static List<SceneKind> _rawPlan(int world, int level, int salt, int count) {
    final rnd = math.Random(world * 1009 + level * 37 + 11 + salt);
    final wts = kindWeights[world];
    final n = SceneKind.values.length;
    final cap = (count + 2) ~/ 3;
    final distinct = math.min(6, count);
    for (var tries = 0; tries < 200; tries++) {
      final bag = List.filled(n, 0);
      for (var i = 0; i < distinct; i++) {
        final k = _pick(rnd, [for (var j = 0; j < n; j++) if (bag[j] == 0) j], wts);
        bag[k] = 1;
      }
      for (var i = distinct; i < count; i++) {
        final k = _pick(rnd, [for (var j = 0; j < n; j++) if (bag[j] < cap) j], wts);
        bag[k]++;
      }
      // 每关至少一个糖果波（标志造型只能摆在糖果波里）：没有就换掉出现最多的一种。
      final coin = SceneKind.coinWave.index;
      if (bag[coin] == 0) {
        final most = bag.reduce(math.max);
        bag[_pick(rnd, [for (var j = 0; j < n; j++) if (bag[j] == most) j], wts)]--;
        bag[coin]++;
      }
      final story = LyricWorld.preferredScene(world, level);
      if (bag[story] == 0) {
        final candidates = [for (var j = 0; j < n; j++) if (bag[j] > 1 && j != coin) j];
        if (candidates.isNotEmpty) {
          bag[_pick(rnd, candidates, wts)]--;
          bag[story]++;
        }
      }
      final lyric = _lyricKinds[SongProfile.songIndexOf(world)].index;
      if ((SongProfile.songIndexOf(world) == 3 || level == 0) && bag[lyric] == 0) {
        final candidates = [for (var j = 0; j < n; j++) if (bag[j] > 0 && j != coin && j != story) j];
        if (candidates.isNotEmpty) {
          final repeated = candidates.where((j) => bag[j] > 1).toList();
          bag[_pick(rnd, repeated.isEmpty ? candidates : repeated, wts)]--;
          bag[lyric]++;
        }
      }
      final seq = <SceneKind>[];
      for (var i = 0; i < count; i++) {
        final cands = [for (var j = 0; j < n; j++) if (bag[j] > 0 && (seq.isEmpty || seq.last.index != j)) j];
        if (cands.isEmpty) {
          break;
        }
        final k = _pick(rnd, cands, wts);
        bag[k]--;
        seq.add(SceneKind.values[k]);
      }
      if (seq.length == count) {
        return seq;
      }
    }
    return [for (var i = 0; i < count; i++) SceneKind.values[i % n]];
  }

  static int _pick(math.Random rnd, List<int> cands, List<int> wts) {
    var roll = rnd.nextInt([for (final k in cands) wts[k]].reduce((a, b) => a + b));
    for (final k in cands) {
      roll -= wts[k];
      if (roll < 0) {
        return k;
      }
    }
    return cands.last;
  }

  static double _sameShare(List<SceneKind> a, List<SceneKind> b) {
    final m = math.min(a.length, b.length);
    var same = 0;
    for (var i = 0; i < m; i++) {
      if (a[i] == b[i]) {
        same++;
      }
    }
    return same / m;
  }
}

/// 一次放置的候选：随机参数和奖励预算都在这里决定。
class _Pen {
  _Pen(this.rnd, this.coins, this.mLeft, this.entryCap, this.songMotif);

  final math.Random rnd;
  final int entryCap;
  final List<(int, int)> songMotif;
  int coins;
  int mLeft;
  bool ok = true;
  bool usedMotif = false;
  String? lyricRoute;

  /// 留给糖果波标志造型的糖果名额：其他种类不能用掉它。
  int reserve = 0;
  final List<_Cell> cells = [];

  /// 一段砖（k 行，从 start 起 len 块）；dx == q 的那块是 `?`。k=3 的入口段长度不超过 [entryCap]。
  void bricks(int k, int start, int len, {int q = -1}) {
    final n = k == 3 ? math.min(len, entryCap) : len;
    for (var i = 0; i < n; i++) {
      cells.add((start + i, k, start + i == q ? '?' : '='));
    }
  }

  /// 可选糖果：预算够且随机命中才放。
  void coin(int dx, int k) {
    if (coins > reserve && rnd.nextBool()) {
      coins--;
      cells.add((dx, k, 'C'));
    }
  }

  /// 顶部奖励：有 M 名额时随机放马卡龙，否则放糖果。
  void top(int dx, int k) {
    if (mLeft > 0 && rnd.nextBool()) {
      mLeft--;
      cells.add((dx, k, 'M'));
    } else if (coins > reserve) {
      coins--;
      cells.add((dx, k, 'C'));
    }
  }
}

void _draw(SceneKind kind, _Pen p) {
  switch (kind) {
    case SceneKind.staircase:
      _staircase(p);
    case SceneKind.archipelago:
      _archipelago(p);
    case SceneKind.tower:
      _tower(p);
    case SceneKind.skyBridge:
      _skyBridge(p);
    case SceneKind.ziggurat:
      _ziggurat(p);
    case SceneKind.valley:
      _valley(p);
    case SceneKind.cloudRoom:
      _cloudRoom(p);
    case SceneKind.hangingGarden:
      _hangingGarden(p);
    case SceneKind.coinWave:
      _coinWave(p);
  }
}

const _lyricKinds = [SceneKind.cloudRoom, SceneKind.skyBridge, SceneKind.tower,
  SceneKind.hangingGarden, SceneKind.tower, SceneKind.valley];

bool _drawLyricRoute(int song, int level, SceneKind kind, _Pen p) {
  final phase = (level.clamp(0, 10) * 3 ~/ 11).clamp(0, 2);
  if (kind != _lyricKinds[song]) return false;
  p.lyricRoute = ['街角屋檐', '白马三关', '倒影双塔', '心跳花园', '时钟街区', '夜行归路'][song];
  switch (song) {
    case 0:
      p.bricks(3, 0, 3);
      final length = 8 + phase;
      p.bricks(7, 4, length, q: 7);
      p.bricks(10, 5, length - 2);
      p.top(4, 8);
    case 1:
      p.bricks(3, 0, 2);
      p.bricks(7, 3, 2);
      p.bricks(9, 6, 8 + phase);
      p.coin(7, 10);
      p.coin(10, 10);
      p.coin(13, 10);
    case 2:
      p.bricks(3, 0, 3);
      p.bricks(7, 3, 2 + phase % 2);
      p.bricks(9, 0, 2 + phase % 2);
      p.bricks(10, 5, 2 + phase);
      p.top(6, 11);
    case 3:
      p.bricks(3, 0, 2);
      p.bricks(7, 3, 2);
      p.bricks(8, 6, 8 + phase);
      p.bricks(7, 8, 1);
      p.bricks(7, 12, 1);
      p.coin(10, 5);
      p.coin(13, 5);
    case 4:
      p.bricks(3, 0, 3);
      p.bricks(7, 4, 2);
      p.bricks(9, 1, 3);
      p.bricks(10, 5, 2 + phase);
      p.top(5, 11);
    case 5:
      p.bricks(3, 0, 2);
      p.bricks(7, 3, 2);
      p.bricks(10, 6, 2);
      p.bricks(7, 10, 2 + phase);
      p.bricks(10, 14 + phase, 2);
      p.coin(10, 8);
  }
  return true;
}

void _staircase(_Pen p) {
  final r = p.rnd;
  var x = 2 + r.nextInt(2);
  p.bricks(3, 0, x);
  var k = 3;
  var start = 0;
  var len = x;
  for (final next in [7, 9, if (r.nextBool()) 10]) {
    start = x + 1 + r.nextInt(2);
    len = next == 10 ? 3 + r.nextInt(3) : 2 + r.nextInt(2);
    p.bricks(next, start, len);
    x = start + len;
    k = next;
  }
  p.top(start + len ~/ 2, k + 1);
}

void _archipelago(_Pen p) {
  final r = p.rnd;
  p.bricks(3, 0, 3);
  var x = 3;
  var prevK = 3;
  final n = 3 + r.nextInt(3);
  final islands = <(int, int, int)>[];
  for (var i = 0; i < n; i++) {
    final last = i == n - 1;
    final k = i == 0 ? 7 : (prevK + r.nextInt(7) - 3).clamp(7, 10);
    final gap = i == 0 ? 1 + r.nextInt(2) : 1 + r.nextInt(3);
    final start = x + gap;
    final len = last ? 3 + r.nextInt(2) : 2 + r.nextInt(3);
    p.bricks(k, start, len, q: last ? start + len ~/ 2 : -1);
    islands.add((start, len, k));
    x = start + len;
    prevK = k;
  }
  final (s, l, k) = islands[r.nextInt(n - 1)];
  p.coin(s + l ~/ 2, k + 1);
}

void _tower(_Pen p) {
  final r = p.rnd;
  p.bricks(3, 0, 3);
  p.bricks(7, 3, 2 + r.nextInt(2));
  p.bricks(9, 1, 2 + r.nextInt(2));
  const s3 = 4;
  final l3 = 2 + r.nextInt(2);
  p.bricks(10, s3, l3);
  if (r.nextInt(5) < 2) {
    final s4 = s3 + l3 + 1;
    p.bricks(10, s4, 2);
    p.top(s4, 11);
  } else {
    p.top(s3 + l3 ~/ 2, 11);
  }
}

void _skyBridge(_Pen p) {
  final r = p.rnd;
  p.bricks(3, 0, 2);
  var start = 3 + r.nextInt(2);
  p.bricks(7, start, 2);
  var x = start + 2;
  final bk = r.nextBool() ? 8 : 9;
  final bl = 10 + r.nextInt(7);
  start = x + 1;
  final hole = r.nextInt(5) < 2 ? 1 + r.nextInt(bl - 9) : -1;
  for (var i = 0; i < bl; i++) {
    if (i != hole) {
      p.cells.add((start + i, bk, '='));
    }
  }
  final off = r.nextInt(3);
  final cn = 3 + r.nextInt(3);
  for (var i = off, n = 0; i < bl && n < cn; i += 2, n++) {
    p.coin(start + i, bk + 1);
  }
  x = start + bl;
  start = x + 1;
  p.bricks(7, start, 2);
  x = start + 2;
  p.bricks(3, x + 1 + r.nextInt(2), 2);
}

void _ziggurat(_Pen p) {
  final r = p.rnd;
  p.bricks(3, 0, 3);
  final s = 4 + r.nextInt(2);
  final len = 7 + r.nextInt(3);
  p.bricks(7, s, len);
  p.bricks(8, s + 1, len - 2);
  p.bricks(9, s + 2, len - 4);
  p.top(s + 2 + (len - 4) ~/ 2, 10);
}

void _valley(_Pen p) {
  final r = p.rnd;
  p.bricks(3, 0, 2);
  var x = 2;
  var start = 0;
  void tier(int k, int len, int gapLo, int gapHi) {
    start = x + gapLo + r.nextInt(gapHi - gapLo + 1);
    p.bricks(k, start, len);
    x = start + len;
  }

  tier(7, 2, 1, 2);
  tier(10, 3, 1, 2);
  final tl = 3 + r.nextInt(3);
  tier(7, tl, 2, 3);
  p.coin(start + tl ~/ 2, 8);
  tier(10, 3, 1, 2);
  tier(7, 2, 2, 3);
  tier(3, 2, 1, 2);
}

void _cloudRoom(_Pen p) {
  final r = p.rnd;
  p.bricks(3, 0, 3);
  final fs = 4 + r.nextInt(2);
  final fl = 8 + r.nextInt(3);
  p.bricks(7, fs, fl, q: fs + fl ~/ 2);
  p.bricks(10, fs + 1, fl - 2);
  p.top(fs, 8);
}

void _hangingGarden(_Pen p) {
  final r = p.rnd;
  p.bricks(3, 0, 2);
  final s = 2 + 1 + r.nextInt(2);
  p.bricks(7, s, 2);
  final d = s + 3;
  final dl = 10 + r.nextInt(5);
  p.bricks(8, d, dl);
  for (var c = d + 3; c < d + dl; c += 3 + r.nextInt(2)) {
    p.cells.add((c, 7, '='));
    if (c + 1 < d + dl) {
      p.coin(c + 1, 5);
    }
  }
}

void _coinWave(_Pen p) {
  final r = p.rnd;
  p.bricks(3, 0, 3);
  final s = 4 + r.nextInt(2);
  p.bricks(7, s, 2);
  if (p.coins < 6) {
    p.ok = false;
    return;
  }
  final motif = p.songMotif;
  if (r.nextInt(10) < 7 && p.coins >= motif.length) {
    for (final (dx, dk) in motif) {
      p.cells.add((s + 3 + dx, 5 + dk, 'C'));
    }
    p.coins -= motif.length;
    p.usedMotif = true;
    return;
  }
  final n = math.min(p.coins, 6 + r.nextInt(5));
  final type = r.nextInt(3);
  for (var i = 0; i < n; i++) {
    final k = switch (type) {
      0 => 7 + (1.5 * math.sin(2 * math.pi * i / n)).round(),
      1 => 5 + math.min<int>(i, n - 1 - i),
      _ => 5 + i % 3,
    };
    p.cells.add((s + 3 + i, k, 'C'));
  }
  p.coins -= n;
}

/// 一个关卡内的放置状态：按顺序放场景，失败则回滚。
class _Writer {
  _Writer(this.grid, this.banned, this.springZone, this.boss, this.coins, this.motif, this.song, this.level);

  final List<List<String>> grid;
  final List<bool> banned;
  final List<bool> springZone;
  final int boss;
  final List<(int, int)> motif;
  final int song;
  final int level;
  int coins;
  int mLeft = 1;
  final Set<int> owned = {};

  int get h => grid.length;
  int get w => grid.first.length;
  int get g => h - 3;

  /// 在 [target] 附近找一个能放下的位置：先试 ±[near] 列（吸附小节线），再试 ±[span] 列；形状失败时重抽参数。
  PlacedScene? place(SceneKind kind, SceneKind? left, SceneKind? right, math.Random rnd, int target, int span, int minX, int maxX,
      {int near = 0}) {
    if (kind == left || kind == right) {
      return null;
    }
    for (final reach in [if (near > 0) near, span]) {
      for (var attempt = 0; attempt < 24; attempt++) {
        final pen = _Pen(rnd, coins, mLeft, attempt % 3 == 2 ? 1 : (attempt % 3 == 1 ? 2 : 3), motif)
          ..reserve = kind == SceneKind.coinWave ? 0 : motif.length;
        if (attempt >= 8 || !_drawLyricRoute(song, level, kind, pen)) {
          _draw(kind, pen);
        }
        if (!pen.ok) {
          return null;
        }
        final width = pen.cells.map((e) => e.$1).reduce(math.max) + 1;
        for (var d = 0; d <= reach; d++) {
          for (final x in d == 0 ? [target] : [target - d, target + d]) {
            if (x < minX || x + width - 1 > maxX) {
              continue;
            }
            for (final mirror in [false, true]) {
              final s = _commit(kind, pen, width, x, mirror);
              if (s != null) {
                return s;
              }
            }
          }
        }
      }
    }
    return null;
  }

  /// 撤掉一个已放置的场景（高潮换种类前用）；[reclaim] 把它原样写回。
  void release(PlacedScene s) {
    for (final e in s.cells.entries) {
      final (c, r) = e.key;
      grid[r][c] = ' ';
      if ('=?'.contains(e.value)) {
        owned.remove(r * w + c);
      }
      if (e.value == 'C') {
        coins++;
      }
      if (e.value == 'M') {
        mLeft++;
      }
    }
  }

  void reclaim(PlacedScene s) {
    for (final e in s.cells.entries) {
      final (c, r) = e.key;
      grid[r][c] = e.value;
      if ('=?'.contains(e.value)) {
        owned.add(r * w + c);
      }
      if (e.value == 'C') {
        coins--;
      }
      if (e.value == 'M') {
        mLeft--;
      }
    }
  }

  PlacedScene? _commit(SceneKind kind, _Pen pen, int width, int x, bool mirror) {
    int col(int dx) => x + (mirror ? width - 1 - dx : dx);
    for (final (dx, k, ch) in pen.cells) {
      final c = col(dx);
      final r = g - k;
      if (r < 0 || grid[r][c] != ' ' || banned[c] || (r >= g - 5 && r <= g - 3 && _liftShaft(c))) {
        return null;
      }
      if ('=?'.contains(ch) && ((r > g - 7 && r != g - 3) || (r >= g - 7 && springZone[c]))) {
        return null;
      }
      if (boss >= 0 && (c - boss).abs() <= 14) {
        return null;
      }
      if ((ch == '=' || ch == '?') && (!_isolated(c, r) || (r == g - 3 && !_entryOk(c)))) {
        return null;
      }
    }
    final cells = <(int, int), String>{};
    for (final (dx, k, ch) in pen.cells) {
      cells[(col(dx), g - k)] = ch;
    }
    for (final e in cells.entries) {
      grid[e.key.$2][e.key.$1] = e.value;
    }
    if (!_verify(cells)) {
      for (final key in cells.keys) {
        grid[key.$2][key.$1] = ' ';
      }
      return null;
    }
    for (final e in cells.entries) {
      if (e.value == '=' || e.value == '?') {
        owned.add(e.key.$2 * w + e.key.$1);
      }
    }
    coins -= cells.values.where((v) => v == 'C').length;
    mLeft -= cells.values.where((v) => v == 'M').length;
    return PlacedScene(kind: kind, x: x, width: width, mirrored: mirror, cells: cells, motif: pen.usedMotif, lyricRoute: pen.lyricRoute);
  }

  /// 升降台通道（行 g-5…g-3，列 I-1…I+3）不放场景，免得挡住 stage_platform 的升降路径。
  bool _liftShaft(int c) {
    for (var i = c - 3; i <= c + 1; i++) {
      if (i >= 0 && i < w && grid[g - 4][i] == 'I') {
        return true;
      }
    }
    return false;
  }

  /// 砖上方 3 格必须空（落脚格和两格头顶）；下方 3 格不能有已放场景的砖，否则会挡住它们的落脚点。
  bool _isolated(int c, int r) {
    if (_sol(c, r - 1) || _sol(c, r - 2)) {
      return false;
    }
    for (var y = r + 1; y <= math.min(h - 1, r + 3); y++) {
      if (owned.contains(y * w + c)) {
        return false;
      }
    }
    return true;
  }

  /// 入口砖（k=3）所在列的地面条件，见 API.md 1.2。
  bool _entryOk(int c) {
    bool gap(int i) => grid[g + 1][i] == ' ' && grid[g + 2][i] == ' ';
    for (var i = c - 1; i <= c + 1; i++) {
      if (i < 0 || i >= w || grid[g + 1][i] != '#' || grid[g + 2][i] != '#') {
        return false;
      }
    }
    for (var i = c - 3; i <= c + 3; i++) {
      if (i < 0 || i >= w || grid[g - 2][i] == 'D' || grid[g][i] == 'S') {
        return false;
      }
      if (i <= c + 2 && gap(i) && (i == 0 || !gap(i - 1))) {
        return false;
      }
    }
    for (var i = c - 2; i <= c + 2; i++) {
      if ('AEGRTLYJ'.contains(grid[g][i]) || 'UXOI'.contains(grid[g - 3][i])) {
        return false;
      }
    }
    return true;
  }

  /// 保守可达性：每段砖（露出的一面）和 M 都要能从地面跳到。
  bool _verify(Map<(int, int), String> cells) {
    final cols = [for (final k in cells.keys) k.$1];
    final seen = _reach(math.max(0, cols.reduce(math.min) - 8), math.min(w - 1, cols.reduce(math.max) + 8));
    final bricks = [for (final e in cells.entries) if (e.value == '=' || e.value == '?') e.key]
      ..sort((a, b) => a.$2 != b.$2 ? a.$2.compareTo(b.$2) : a.$1.compareTo(b.$1));
    for (var i = 0; i < bricks.length;) {
      var j = i;
      while (j + 1 < bricks.length && bricks[j + 1].$2 == bricks[i].$2 && bricks[j + 1].$1 == bricks[j].$1 + 1) {
        j++;
      }
      final r = bricks[i].$2;
      var exposed = false;
      var reached = false;
      for (var c = bricks[i].$1; c <= bricks[j].$1; c++) {
        if (r > 0 && !_sol(c, r - 1)) {
          exposed = true;
          reached = reached || seen.contains((r - 1) * w + c);
        }
      }
      if (exposed && !reached) {
        return false;
      }
      i = j + 1;
    }
    return cells.entries.every((e) => e.value != 'M' || seen.contains(e.key.$2 * w + e.key.$1));
  }

  /// 从 [lo, hi] 列内的地面出发，BFS 出所有能站到的格子（编码 r * w + c）。
  Set<int> _reach(int lo, int hi) {
    final seen = <int>{};
    final q = <(int, int)>[];
    for (var c = lo; c <= hi; c++) {
      if (grid[g + 1][c] == '#' && _stand(c, g)) {
        seen.add(g * w + c);
        q.add((c, g));
      }
    }
    for (var i = 0; i < q.length; i++) {
      final (c, r) = q[i];
      for (var c2 = math.max(lo, c - 5); c2 <= math.min(hi, c + 5); c2++) {
        final dx = (c2 - c).abs();
        for (var r2 = math.max(g - 11, r - 4); r2 <= math.min(g, r + 12); r2++) {
          final rise = r - r2;
          final ok = rise >= 0 ? (rise <= 3 && dx <= 4) || (rise == 4 && dx <= 3) : dx <= 5;
          if (ok && _stand(c2, r2) && seen.add(r2 * w + c2)) {
            q.add((c2, r2));
          }
        }
      }
    }
    return seen;
  }

  bool _sol(int c, int r) => r >= 0 && r < h && c >= 0 && c < w && '#=?DUXOI'.contains(grid[r][c]);

  bool _stand(int c, int r) => r >= 0 && r < h - 1 && !_sol(c, r) && _sol(c, r + 1) && !_sol(c, r - 1) && !_sol(c, r - 2);
}
