import 'dart:math' as math;

import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/level_names.dart';

/// 99 关全量目录（每关独立构图规则，按世界主题手调）
class LevelCatalog {
  LevelCatalog._();

  static LevelData load(int worldIndex, int levelIndex) {
    final w = worldIndex.clamp(0, GameConstants.worldCount - 1);
    if (levelIndex >= GameConstants.depthLevelIndex) {
      return LevelData(
        worldIndex: w,
        levelIndex: GameConstants.depthLevelIndex,
        title: LevelNames.fullTitle(w, GameConstants.depthLevelIndex),
        rows: _buildDepthRows(w),
        difficulty: _difficulty(w, 5),
      );
    }
    final l = levelIndex.clamp(0, GameConstants.levelsPerWorld - 1);
    final rows = _addSkyLayer(_buildRows(w, l), w, l);
    return LevelData(
      worldIndex: w,
      levelIndex: l,
      title: LevelNames.fullTitle(w, l),
      rows: rows,
      difficulty: _difficulty(w, l),
    );
  }

  /// 「歌曲深处」：一座向下走的纵向地图。出生在最高处，沿着平台一层层往下，
  /// 最底下一条长地面，旗杆在右端。路线由世界编号做种子随机生成，所以每个世界
  /// 都不一样：平台长短、左右走向、缺口、立柱、岔路和隐藏小房间都不同。
  /// 平台每层相隔 5 行（一次跳跃的高度以内），相邻两层在边缘处重叠，
  /// 从边缘走下去必定落在下一层上（见 [depthLayers]）。
  static const int depthWidth = 72;
  static const int depthHeight = 48;
  static const int depthFirstRow = 6;
  static const int depthRowGap = 5;
  static const int depthLayerCount = 8;

  /// 某个世界下探关每一层平台的 (起始列, 长度, 中间留空的格数, 方向：1 向右走 / -1 向左走)。
  /// 下一层一定盖住从上一层边缘走出去的落点。
  static List<(int, int, int, int)> depthLayers(int world) {
    final rnd = math.Random(world * 977 + 31);
    const maxX = depthWidth - 2;
    final layers = <(int, int, int, int)>[];
    var dir = rnd.nextBool() ? 1 : -1;
    var len = 20 + rnd.nextInt(16);
    var x0 = dir > 0 ? 3 + rnd.nextInt(8) : maxX - len - 3 - rnd.nextInt(8);
    for (var k = 0; k < depthLayerCount; k++) {
      final last = k == depthLayerCount - 1;
      if (last) {
        // 最后一层：别把人送到旗杆右边的墙根。
        dir = x0 + len + 1 > 58 ? -1 : dir;
      }
      final gap = (len >= 24 && rnd.nextInt(4) == 0) ? 4 : 0;
      layers.add((x0, len, gap, dir));
      if (last) {
        break;
      }
      final beyond = dir > 0 ? x0 + len + 1 : x0 - 2;
      final lo = dir > 0 ? beyond : beyond - 2; // 下一层至少盖住 lo..hi
      final hi = dir > 0 ? beyond + 2 : beyond;
      var next = (0, 0, 0);
      for (var attempt = 0; attempt < 40; attempt++) {
        final nd = rnd.nextInt(10) < 6 ? -dir : dir;
        final nlen = 14 + rnd.nextInt(24);
        final minX = math.max(3, hi - nlen + 1);
        final maxStart = math.min(lo, maxX - nlen);
        if (minX > maxStart) {
          continue;
        }
        final nx0 = minX + rnd.nextInt(maxStart - minX + 1);
        // 走出去的那一侧要留够落脚的空间。
        if (nd > 0 && nx0 + nlen + 4 > maxX) {
          continue;
        }
        if (nd < 0 && nx0 - 4 < 2) {
          continue;
        }
        next = (nx0, nlen, nd);
        break;
      }
      if (next.$2 == 0) {
        // 退路：和原来一样的左右交错。
        final nd = -dir;
        next = nd > 0 ? (4, 34, nd) : (34, 34, nd);
      }
      x0 = next.$1;
      len = next.$2;
      dir = next.$3;
    }
    return layers;
  }

  static List<String> _buildDepthRows(int world) {
    const width = depthWidth;
    const height = depthHeight;
    final rnd = math.Random(world * 313 + 5);
    final grid = List.generate(height, (_) => List.filled(width, ' '));
    // 两侧的墙。
    for (var y = 0; y < height; y++) {
      grid[y][0] = '#';
      grid[y][width - 1] = '#';
    }
    // 底部长地面。
    for (var x = 0; x < width; x++) {
      grid[height - 1][x] = '#';
      grid[height - 2][x] = '#';
    }
    bool isFree(int x, int y) =>
        x > 0 && x < width - 1 && y >= 0 && y < height && grid[y][x] == ' ';
    final layers = depthLayers(world);
    for (var k = 0; k < layers.length; k++) {
      final row = depthFirstRow + k * depthRowGap;
      final (x0, len, gap, dir) = layers[k];
      final mid = x0 + len ~/ 2;
      bool inGap(int x) =>
          gap > 0 && x >= mid - gap ~/ 2 - 1 && x < mid + (gap + 1) ~/ 2 + 1;
      for (var x = x0; x < x0 + len; x++) {
        if (gap > 0 && x >= mid - gap ~/ 2 && x < mid + (gap + 1) ~/ 2) {
          continue;
        }
        grid[row][x] = '=';
      }
      // 立柱：平台上一格高的石墩，要跳过去。离两端和缺口都留几格。
      final pillars = <int>{};
      final pillarCount = len >= 20 ? rnd.nextInt(3) : rnd.nextInt(2);
      for (var i = 0; i < pillarCount; i++) {
        final px = x0 + 6 + rnd.nextInt(math.max(1, len - 12));
        if (inGap(px) || pillars.any((p) => (p - px).abs() < 4)) {
          continue;
        }
        pillars.add(px);
        grid[row - 1][px] = '#';
      }
      // 糖果的摆法每层不同：一排、高处一排、成对。
      final style = rnd.nextInt(3);
      final count = (len ~/ 3).clamp(4, 9);
      for (var i = 0; i < count; i++) {
        final cx = dir > 0 ? x0 + 3 + i * 3 : x0 + len - 4 - i * 3;
        if (cx <= x0 || cx >= x0 + len - 1 || grid[row][cx] != '=') {
          continue;
        }
        final cy = switch (style) {
          0 => row - 1,
          1 => row - 2 - (i.isEven ? 0 : 1),
          _ => row - 1 - (i % 3 == 2 ? 2 : 0),
        };
        if (grid[cy][cx] == ' ') {
          grid[cy][cx] = 'C';
        }
      }
      // 检查点、心、能量马卡龙：放在平台上第一个空着的落脚格。
      void placeOnLedge(String c, {required bool fromEnd}) {
        for (var i = 2; i < len - 2; i++) {
          final cx = fromEnd ? x0 + len - 1 - i : x0 + i;
          if (grid[row][cx] == '=' && grid[row - 1][cx] == ' ') {
            grid[row - 1][cx] = c;
            return;
          }
        }
      }

      if (k == 3 || k == 5) {
        placeOnLedge('K', fromEnd: false);
      }
      if (k == 2) {
        placeOnLedge('H', fromEnd: true);
      }
      if (k == 6) {
        placeOnLedge('M', fromEnd: true);
      }
      // 岔路：主路相反的一侧悬着一间小平台，隔 3 格能跳过去；
      // 平台上有弹簧，弹到更高的一块隐藏台，上面有糖和心。
      if (k >= 1 && k <= 6 && rnd.nextInt(2) == 0) {
        final bLen = 8;
        final bx = dir > 0 ? x0 - 3 - bLen : x0 + len + 3;
        var ok = bx >= 2 && bx + bLen < width - 2;
        for (var x = bx; ok && x < bx + bLen; x++) {
          for (var y = row - 8; y <= row; y++) {
            if (!isFree(x, y)) {
              ok = false;
              break;
            }
          }
        }
        if (ok) {
          for (var x = bx; x < bx + bLen; x++) {
            grid[row][x] = '=';
          }
          grid[row - 1][bx + 2] = 'C';
          grid[row - 1][bx + 5] = 'C';
          grid[row - 1][bx + bLen ~/ 2] = 'S';
          final ledgeRow = row - 7;
          for (var x = bx + 1; x < bx + bLen - 1; x++) {
            grid[ledgeRow][x] = '=';
          }
          grid[ledgeRow - 1][bx + 2] = 'C';
          grid[ledgeRow - 1][bx + 3] = 'C';
          grid[ledgeRow - 1][bx + 4] = k.isEven ? 'H' : 'C';
        }
      }
    }
    // 出生点：最高平台的左侧起点附近。
    final (firstX, firstLen, _, _) = layers.first;
    grid[depthFirstRow - 1][firstX + 1] = 'P';
    if (grid[depthFirstRow - 1][firstX + 1] != 'P') {
      grid[depthFirstRow - 1][firstX + firstLen ~/ 2] = 'P';
    }
    // 底部：几只慢走怪，旗杆在右端。
    final surface = height - 3;
    for (final x in [
      22 + rnd.nextInt(4),
      34 + rnd.nextInt(4),
      46 + rnd.nextInt(4),
    ]) {
      grid[surface][x] = 'E';
    }
    grid[surface][width - 3] = 'F';
    for (var x = 8; x < width - 8; x += 6) {
      if (grid[surface][x] == ' ') {
        grid[surface][x] = 'C';
      }
    }
    return [for (final r in grid) r.join()];
  }

  /// 天空层行数：地面关卡上方再加的高度，角色可以沿弹簧路线飞上去。
  static const int skyRows = 14;

  /// 不局限于一个平面：普通关卡在原地图上方加一层“歌曲天空”。
  /// 找一段上方完全空的地面，造「弹簧 → 平台 → 弹簧 → 平台 → 弹簧」的上升路线，
  /// 通向一座空中岛屿（糖果弧线、生命心、能量马卡龙，岛上形状随世界不同）。
  /// 地面关卡本身一格都不动，只是整体下移 [skyRows] 行；找不到空地时不加。
  static List<String> _addSkyLayer(List<String> rows, int world, int level) {
    if (level == GameConstants.levelsPerWorld - 1) {
      return rows; // Boss 关保持原样
    }
    final height = rows.length;
    final width = rows.first.length;
    final surface = height - 3;
    bool free(int x, int fromRow, int toRow) {
      for (var y = fromRow; y <= toRow; y++) {
        final t = rows[y][x];
        if (t != ' ' && t != 'C') {
          return false;
        }
      }
      return true;
    }

    // 只检查路线真正要用到的格子：起跳弹簧的竖直通道，
    // 以及第一块平台和它上方的通道。别的地方有浮空平台也没关系。
    bool windowFree(int x0) {
      // 地面上的怪、弹簧、检查点离出发点要留出空档。
      for (var x = x0 - 4; x < x0 + 9; x++) {
        if (x >= 0 && x < width && 'AEGRTLYJBSWKV'.contains(rows[surface][x])) {
          return false;
        }
      }
      // 前后各留几格实心地面，别和坑的起跳 / 落地区重叠。
      for (var x = x0 - 4; x < x0 + 9; x++) {
        if (x < 0 || x >= width || rows[height - 2][x] != '#') {
          return false;
        }
      }
      // 起跳平台在地面上方两格（下面照常能走过去），弹簧在它上面；
      // 只检查路线真正要用的通道：弹簧上方到第一块平台，以及平台上方。
      for (var x = x0 + 1; x <= x0 + 4; x++) {
        if (!free(x, 0, 8)) {
          return false;
        }
      }
      for (var x = x0 + 5; x <= x0 + 5; x++) {
        if (!free(x, 0, 3)) {
          return false;
        }
      }
      for (var x = x0; x <= x0 + 2; x++) {
        if (!free(x, 9, surface)) {
          return false;
        }
      }
      return true;
    }

    final start = ((width * (0.38 + 0.04 * (world % 4))).round()).clamp(
      6,
      width - 24,
    );
    int? x0;
    for (var d = 0; d < width && x0 == null; d++) {
      for (final x in [start + d, start - d]) {
        if (x >= 6 && x <= width - 24 && windowFree(x)) {
          x0 = x;
          break;
        }
      }
    }
    if (x0 == null) {
      return rows;
    }

    final grid = [
      for (var i = 0; i < skyRows; i++) List.filled(width, ' '),
      for (final r in rows) r.split(''),
    ];
    final s = skyRows + surface; // 新坐标里的地面站立行
    void put(int x, int y, String c) {
      if (x >= 1 && x < width - 1 && y >= 0 && y < grid.length) {
        grid[y][x] = c;
      }
    }

    void bar(int xa, int xb, int y) {
      for (var x = xa; x <= xb; x++) {
        put(x, y, '=');
      }
    }

    final x = x0;
    // 上升路线：每个弹簧约弹 7 格高。起跳弹簧在离地两格的小平台上，
    // 地面路线从它下面走过，不会被意外弹飞。
    bar(x, x + 2, s - 2);
    put(x + 1, s - 3, 'S');
    bar(x + 3, x + 5, s - 8);
    put(x + 4, s - 9, 'S');
    bar(x + 6, x + 8, s - 14);
    put(x + 7, s - 15, 'S'); // 空中岛屿。
    // 空中岛屿：长度、高度、踏脚石、第二座更高的小岛和奖励都由世界 / 关卡
    // 编号做种子随机，各关不一样。岛上的糖果数量很少（糖果总数有上限）。
    final rnd = math.Random(world * 131 + level * 17 + 3);
    final islandLen = 12 + rnd.nextInt(13);
    final islandRow = s - 20 + rnd.nextInt(3) - 1; // 比较高低错落
    final ix0 = x + 9;
    final ix1 = ix0 + islandLen - 1;
    bar(ix0, ix1, islandRow);
    // 岛的形状：有的中间凹下去一块。
    if (islandLen >= 16 && rnd.nextBool()) {
      final dip = ix0 + islandLen ~/ 2;
      for (var d = 0; d < 3; d++) {
        if (dip + d < width - 1) {
          grid[islandRow][dip + d] = ' ';
          put(dip + d, islandRow + 1, '=');
        }
      }
    }
    // 糖果的摆法：弧线、两排、阶梯、成串、散点。
    switch (rnd.nextInt(5)) {
      case 0:
        for (var i = 0; i < 5; i++) {
          put(ix0 + 3 + i * 2, islandRow - 2 - (2 - (i - 2).abs()), 'C');
        }
      case 1:
        for (var i = 0; i < 3; i++) {
          put(ix0 + 3 + i * 3, islandRow - 1, 'C');
          put(ix0 + 4 + i * 3, islandRow - 3, 'C');
        }
      case 2:
        for (var i = 0; i < 5; i++) {
          put(ix0 + 3 + i * 2, islandRow - 1 - i ~/ 2, 'C');
        }
      case 3:
        for (var i = 0; i < 6; i++) {
          put(ix0 + 2 + i, islandRow - 1, 'C');
        }
      default:
        for (var i = 0; i < 4; i++) {
          put(ix0 + 2 + i * 3, islandRow - 1 - rnd.nextInt(3), 'C');
        }
    }
    // 第二座更高的小岛，用踏脚石一级级跳上去，上面放大奖励。
    if (rnd.nextInt(3) != 0 && islandRow - 9 >= 1) {
      final hx = ix1 - 3;
      bar(hx - 2, hx, islandRow - 4);
      bar(hx + 3, hx + 7, islandRow - 8);
      put(hx + 4, islandRow - 9, 'C');
      put(hx + 5, islandRow - 9, 'H');
      put(hx + 6, islandRow - 9, 'C');
    }
    put(ix1 - 1, islandRow - 1, rnd.nextBool() ? 'H' : 'M');
    put(ix0 + 1 + rnd.nextInt(4), islandRow - 1, rnd.nextBool() ? 'M' : 'C');
    return [for (final r in grid) r.join()];
  }

  static int _difficulty(int w, int l) {
    var d = 1 + w + (l ~/ 3);
    if (l == 10) {
      d += 2 + (w ~/ 3);
    }
    return d;
  }

  static List<String> _buildRows(int world, int level) {
    final width = 140 + world * 18 + level * 18;
    final height = 14;
    final grid = List.generate(height, (_) => List.filled(width, ' '));

    // 地面基线
    for (var x = 0; x < width; x++) {
      grid[height - 1][x] = '#';
      grid[height - 2][x] = '#';
    }

    // 出生与终点
    grid[height - 3][2] = 'P';
    grid[height - 3][width - 3] = 'F';
    for (var x = width - 5; x < width; x++) {
      grid[height - 1][x] = '#';
      grid[height - 2][x] = '#';
    }

    // 中段检查点
    final cp1 = (width * 0.33).floor().clamp(8, width - 8);
    final cp2 = (width * 0.66).floor().clamp(8, width - 8);
    grid[height - 3][cp1] = 'K';
    grid[height - 3][cp2] = 'K';

    // 按世界注入手作关卡语法
    switch (world) {
      case 0:
        _worldCreamMeadow(grid, level);
        break;
      case 1:
        _worldStrawberry(grid, level);
        break;
      case 2:
        _worldMint(grid, level);
        break;
      case 3:
        _worldTaroStar(grid, level);
        break;
      case 4:
        _worldLemonBeach(grid, level);
        break;
      case 5:
        _worldRoseCastle(grid, level);
        break;
      case 6:
        _worldBlueberry(grid, level);
        break;
      case 7:
        _worldCaramelMine(grid, level);
        break;
      default:
        _worldHoneymoon(grid, level);
        break;
    }

    // 标志性关卡手调段
    if (level == 0 || level == 4 || level == 7) {
      _signatureSpice(grid, world, level);
    }

    _applyDifficultyPass(grid, world, level);
    _fillLongRun(grid, world, level);
    _addSceneChallenges(grid, world, level);

    // Boss 关最后注入，避免被长关填充覆盖
    if (level == 10) {
      _bossSpice(grid, world);
    }

    _repairGuaranteedGroundRoute(grid);
    // 弹簧与检查点都依赖最终地形，所以在坑口修好之后再校正。
    _repairSpringPlacement(grid);
    _addDuckTunnel(grid, world, level);
    _placeSceneCheckpoints(grid);
    _fillCheckpointGaps(grid);
    _placeSpecialRoster(grid, world, level);
    // Validate patrols after all enemy archetypes have been placed.
    _repairEnemyPatrolRoutes(grid);
    final bossTile = grid[grid.length - 3].indexOf('B');
    if (bossTile >= 0) {
      _placeBossGun(grid, bossTile);
      _repairSpringPlacement(grid, keepAwayFromEnemies: true);
    }
    _placeStagePlatforms(grid, world, level);
    // 最后限流：只删普通巡逻怪，不改动前面各层已经定型的平台与路线。
    _capWalkerDensity(grid, world, level);
    if (world >= 6) {
      final ground = grid.length - 3;
      for (var x = 0; x < grid.first.length; x++) {
        if (grid[ground][x] != 'S') continue;
        for (
          var landing = x + 1;
          landing <= x + 8 && landing < grid.first.length;
          landing++
        ) {
          grid[ground + 1][landing] = '#';
          grid[ground + 2][landing] = '#';
        }
      }
    }

    return grid.map((r) => r.join()).toList();
  }

  /// 每个世界的敌人密度上限（每 100 列），后段关卡按 [densityRampPerLevel] 小幅递增。
  /// 世界函数里固定列距的巡逻怪会让 W3、W5、W8 的密度突然翻倍，这里统一收口。
  static const densityCeilingPer100 = [
    6.0,
    6.8,
    8.0,
    7.5,
    7.8,
    8.6,
    7.5,
    9.0,
    7.0,
  ];
  static const densityRampPerLevel = 0.1;
  static const minWalkersKept = 2;

  /// 超出密度上限时只裁剪普通巡逻怪 E：优先去掉最挤在一起的那些，
  /// 特殊种类与所有地形、奖励、检查点保持不变，因此不会削弱关卡的机制组合。
  static void _capWalkerDensity(List<List<String>> grid, int world, int level) {
    final width = grid.first.length;
    final ground = grid.length - 3;
    final rowChars = grid[ground];
    final ceiling = densityCeilingPer100[world] + level * densityRampPerLevel;
    final budget = (ceiling * width / 100).floor();

    const specialKinds = 'GRTALYJ';
    var specials = 0;
    final walkers = <int>[];
    for (var x = 0; x < width; x++) {
      final tile = rowChars[x];
      if (tile == 'E') {
        walkers.add(x);
      } else if (specialKinds.contains(tile)) {
        specials++;
      }
    }
    if (walkers.length <= minWalkersKept) {
      return;
    }
    final keep = math.max(minWalkersKept, budget - specials);
    var excess = walkers.length - keep;
    if (excess <= 0) {
      return;
    }

    int crowding(int x) {
      var nearest = 99;
      for (var other = 0; other < width; other++) {
        if (other == x || !'AEGRTLYJ'.contains(rowChars[other])) {
          continue;
        }
        nearest = math.min(nearest, (other - x).abs());
      }
      return nearest;
    }

    final ranked = [for (final x in walkers) (x, crowding(x))]
      ..sort(
        (a, b) => a.$2 != b.$2 ? a.$2.compareTo(b.$2) : a.$1.compareTo(b.$1),
      );
    for (final (x, _) in ranked) {
      if (excess == 0) {
        break;
      }
      rowChars[x] = ' ';
      excess--;
    }
  }

  /// 非 Boss 关加入可踩台：U 单向、X 碎裂、O 左右移动；每三关加入 I 垂直移动。
  /// 台子只占空中路线，不改地面通路；移动轨道避开实心块并留在地面上方。
  static void _placeStagePlatforms(
    List<List<String>> grid,
    int world,
    int level,
  ) {
    if (level == 10) {
      return;
    }
    final ground = grid.length - 3;
    final width = grid.first.length;
    final y = ground - 3;
    if (y < 2 || width < 40) {
      return;
    }
    const specs = <(String, int)>[('U', 3), ('X', 3), ('O', 2)];
    final openingTutorial = world == 0 && level == 0;
    var tutorialCursor = 16;
    final usable = width - 32;
    for (var band = 0; band < specs.length; band++) {
      final marker = specs[band].$1;
      final len = specs[band].$2;
      final margin = marker == 'O' ? 2 : 1;
      final regionStart = openingTutorial
          ? tutorialCursor
          : 16 + usable * band ~/ 3;
      final regionEnd = openingTutorial
          ? regionStart + 10
          : 16 + usable * (band + 1) ~/ 3;

      bool fits(int x) {
        if (x < 16 || x + len >= width - 16) {
          return false;
        }
        for (var i = -margin; i < len + margin; i++) {
          final col = x + i;
          if (col < 0 || col >= width) {
            return false;
          }
          if (i >= 0 && i < len && 'UXO'.contains(grid[y][col])) {
            return false;
          }
          if (grid[ground + 1][col] != '#' || grid[ground + 2][col] != '#') {
            return false;
          }
          if (grid[ground - 2][col] == 'D') {
            return false;
          }
        }
        for (var i = 0; i < len; i++) {
          if (grid[y][x + i] != ' ' &&
              !(openingTutorial && grid[y][x + i] == '=')) {
            return false;
          }
          if ('#?D'.contains(grid[y + 1][x + i])) {
            return false;
          }
        }
        return true;
      }

      var placed = false;
      var placedAt = -1;
      for (var x = regionStart; x <= regionEnd - len && !placed; x++) {
        if (!fits(x)) {
          continue;
        }
        for (var i = 0; i < len; i++) {
          grid[y][x + i] = marker;
          if (grid[y + 1][x + i] == '=') {
            grid[y + 1][x + i] = ' ';
          }
        }
        final coinX = x + len ~/ 2;
        if (grid[y - 1][coinX] == ' ') {
          grid[y - 1][coinX] = 'C';
        }
        placed = true;
        placedAt = x;
      }
      if (placed) {
        if (openingTutorial) {
          tutorialCursor = placedAt + len + 1;
        }
        continue;
      }
      final fallbackStart = openingTutorial ? tutorialCursor : 16;
      for (var x = fallbackStart; x < width - 16 - len; x++) {
        if (!fits(x)) {
          continue;
        }
        for (var i = 0; i < len; i++) {
          grid[y][x + i] = marker;
          if (grid[y + 1][x + i] == '=') {
            grid[y + 1][x + i] = ' ';
          }
        }
        final coinX = x + len ~/ 2;
        if (grid[y - 1][coinX] == ' ') {
          grid[y - 1][coinX] = 'C';
        }
        placedAt = x;
        break;
      }
      if (openingTutorial && placedAt >= 0) {
        tutorialCursor = placedAt + len + 1;
      }
    }

    if (level % 3 != 2) {
      return;
    }
    const liftMarker = 'I';
    const liftTiles = 3;
    final liftY = ground - 4;

    bool fitsLift(int x) {
      if (x < 16 || x + liftTiles >= width - 16) {
        return false;
      }
      for (var col = x - 1; col <= x + liftTiles; col++) {
        if (col < 0 || col >= width) {
          return false;
        }
        for (var row = liftY - 1; row <= liftY + 1; row++) {
          final tile = grid[row][col];
          if ('#=?D'.contains(tile) || 'UXO'.contains(tile)) {
            return false;
          }
        }
        if (grid[ground + 1][col] != '#' || grid[ground + 2][col] != '#') {
          return false;
        }
      }
      for (var i = 0; i < liftTiles; i++) {
        if (grid[liftY][x + i] != ' ') {
          return false;
        }
      }
      return true;
    }

    var liftPlaced = false;
    final preferredStart = width * 2 ~/ 3;
    for (var x = preferredStart; x < width - 16 - liftTiles; x++) {
      if (!fitsLift(x)) {
        continue;
      }
      for (var i = 0; i < liftTiles; i++) {
        grid[liftY][x + i] = liftMarker;
      }
      liftPlaced = true;
      break;
    }
    if (liftPlaced) {
      return;
    }
    for (var x = 16; x < preferredStart && !liftPlaced; x++) {
      if (!fitsLift(x)) {
        continue;
      }
      for (var i = 0; i < liftTiles; i++) {
        grid[liftY][x + i] = liftMarker;
      }
      liftPlaced = true;
    }
  }

  /// 弹簧必须架在实地、头顶无遮挡，且与坑口保持起跳缓冲；
  /// 否则玩家踩上去会被直接弹进坑里。优先就近平移，找不到安全位置才撤掉。
  static void _repairSpringPlacement(
    List<List<String>> grid, {
    bool keepAwayFromEnemies = false,
  }) {
    final ground = grid.length - 3;
    final width = grid.first.length;

    bool isGap(int x) =>
        grid[ground + 1][x] == ' ' && grid[ground + 2][x] == ' ';

    bool hasSafeGround(int x) {
      if (x < 8 || x >= width - 8) {
        return false;
      }
      if (grid[ground + 1][x] != '#' || grid[ground + 2][x] != '#') {
        return false;
      }
      // 起跳推进加空中滞留可能跨过三格，坑口两侧都留出余量。
      for (var dx = -3; dx <= 3; dx++) {
        final probe = x + dx;
        if (probe >= 0 && probe < width && isGap(probe)) {
          return false;
        }
      }
      if ('#=?D'.contains(grid[ground - 1][x])) {
        return false;
      }
      for (var dx = -8; dx <= 8; dx++) {
        final probe = x + dx;
        if (probe < 0 || probe >= width) {
          continue;
        }
        // 糖枪到 Boss 这一段要能站稳瞄准。弹簧弹射大约能飞过八格，
        // 垫子离战场太近时，人会被整段弹过 Boss，糖枪时间也耗尽。
        if (grid[ground][probe] == 'W' || grid[ground][probe] == 'B') {
          return false;
        }
      }
      return true;
    }

    bool clearOfEnemies(int x) {
      for (var dx = -6; dx <= 6; dx++) {
        final probe = x + dx;
        if (probe < 0 || probe >= width) {
          continue;
        }
        if ('AEGRTLYJ'.contains(grid[ground][probe])) {
          return false;
        }
      }
      return true;
    }

    for (var x = 0; x < width; x++) {
      if (grid[ground][x] != 'S' || hasSafeGround(x)) {
        continue;
      }
      grid[ground][x] = ' ';
      var relocated = false;
      final searchLimit = keepAwayFromEnemies ? width : 16;
      for (var offset = 1; offset < searchLimit && !relocated; offset++) {
        for (final candidate in [x + offset, x - offset]) {
          if (candidate < 8 ||
              candidate >= width - 8 ||
              grid[ground][candidate] != ' ' ||
              !hasSafeGround(candidate) ||
              (keepAwayFromEnemies && !clearOfEnemies(candidate))) {
            continue;
          }
          grid[ground][candidate] = 'S';
          relocated = true;
          break;
        }
      }
      if (!relocated) {
        grid[ground][x] = 'S';
      }
    }
  }

  /// 检查点间隔上限。按 0.2/0.4/0.6/0.8 比例放置在小图上够密，
  /// 长关卡却会让玩家一次失误就重跑半张图；
  /// 这里反复把最长的一段从中点向外补，直到收进上限或无处可放。
  static void _fillCheckpointGaps(List<List<String>> grid) {
    const maxSpan = 45;
    final ground = grid.length - 3;
    final width = grid.first.length;

    bool isSafeSpot(int x) {
      if (x < 8 || x >= width - 8) {
        return false;
      }
      if (grid[ground][x] != ' ') {
        return false;
      }
      if (grid[ground + 1][x] != '#' || grid[ground + 2][x] != '#') {
        return false;
      }
      // 检查点不能贴着隧道顶，否则玩家正好在低顶处读出档。
      if (grid[ground - 2][x] == 'D') {
        return false;
      }
      if ([
        x - 2,
        x - 1,
        x + 1,
        x + 2,
      ].any((near) => 'AEGRBTWVLYJ'.contains(grid[ground][near]))) {
        return false;
      }
      return true;
    }

    // 每轮只补最长的一段；放不下就停，避免把小图塞满检查点。
    for (var round = 0; round < 32; round++) {
      final points = <int>[2];
      for (var x = 0; x < width; x++) {
        if (grid[ground][x] == 'K') {
          points.add(x);
        }
      }
      points.add(width - 3);

      var from = -1;
      var longest = maxSpan;
      for (var i = 1; i < points.length; i++) {
        final span = points[i] - points[i - 1];
        if (span > longest) {
          longest = span;
          from = points[i - 1];
        }
      }
      if (from < 0) {
        break;
      }

      final to = from + longest;
      final mid = (from + to) ~/ 2;
      var placed = false;
      for (var offset = 0; offset <= longest ~/ 2; offset++) {
        final candidates = offset == 0 ? [mid] : [mid - offset, mid + offset];
        for (final x in candidates) {
          if (x <= from + 3 || x >= to - 3 || !isSafeSpot(x)) {
            continue;
          }
          grid[ground][x] = 'K';
          placed = true;
          break;
        }
        if (placed) {
          break;
        }
      }
      if (!placed) {
        break;
      }
    }
  }

  /// 敌人基础巡逻延伸两格，同时留出安全巡逻间距与起跑反应距离。
  static void _repairEnemyPatrolRoutes(List<List<String>> grid) {
    final ground = grid.length - 3;
    final width = grid.first.length;
    final bossTile = grid[ground].indexOf('B');

    bool hasSafeAnchor(int x) {
      // 终点跑道净空：巡逻最多向两侧各延伸两格，锚点必须离终点至少留出两格缓冲，
      // 否则敌人会压在终点格上，玩家冲线时被迫硬吃伤害。
      if (x < 10 ||
          x >= width - 6 ||
          bossTile >= 0 && (x - bossTile).abs() <= 6 ||
          bossTile >= 0 && x >= bossTile - 16 && x <= bossTile - 7 ||
          (grid[ground + 1][x] != '#' && grid[ground + 2][x] != '#')) {
        return false;
      }
      if ('#=?D'.contains(grid[ground - 1][x])) {
        return false;
      }
      // 坑口需留出起跳与落地缓冲；远程怪不能贴着强制跳跃窗口发射。
      final gapClearanceStart = x - 4 < 0 ? 0 : x - 4;
      final gapClearanceEnd = x + 4 >= width ? width - 1 : x + 4;
      for (var gapX = gapClearanceStart; gapX <= gapClearanceEnd; gapX++) {
        if (grid[ground + 1][gapX] == ' ' && grid[ground + 2][gapX] == ' ') {
          return false;
        }
      }
      final springBufferStart = x - 6 < 0 ? 0 : x - 6;
      final springBufferEnd = x + 6 >= width ? width - 1 : x + 6;
      for (
        var springX = springBufferStart;
        springX <= springBufferEnd;
        springX++
      ) {
        if (grid[ground][springX] == 'S') {
          return false;
        }
      }
      for (var checkpointX = x - 2; checkpointX <= x + 2; checkpointX++) {
        if (checkpointX >= 0 &&
            checkpointX < width &&
            grid[ground][checkpointX] == 'K') {
          return false;
        }
      }
      return true;
    }

    double enemyHalfWidth(String marker) => switch (marker) {
      'R' => 26,
      'L' => 24,
      'Y' => 23,
      _ => 21,
    };

    bool hasEnemyClearance(int x, String enemy) {
      final center = (x + 0.5) * GameConstants.tileSize;
      for (var otherX = 0; otherX < width; otherX++) {
        final other = grid[ground][otherX];
        if (otherX == x || !'AEGRTLYJ'.contains(other)) {
          continue;
        }
        final requiredGap =
            GameConstants.tileSize * 2 +
            enemyHalfWidth(enemy) +
            enemyHalfWidth(other);
        final otherCenter = (otherX + 0.5) * GameConstants.tileSize;
        if ((center - otherCenter).abs() < requiredGap) {
          return false;
        }
      }
      return true;
    }

    bool hasClearApproach(int x) {
      for (var approachX = x - 1; approachX <= x + 1; approachX++) {
        for (var approachY = ground - 3; approachY < ground; approachY++) {
          if ('#=?D'.contains(grid[approachY][approachX])) {
            return false;
          }
        }
      }
      return true;
    }

    bool hasClearSwoopSpace(int x) {
      for (var approachX = x - 2; approachX <= x + 2; approachX++) {
        for (var approachY = ground - 2; approachY < ground; approachY++) {
          if ('#=?D'.contains(grid[approachY][approachX])) {
            return false;
          }
        }
      }
      return true;
    }

    void clearApproach(int x) {
      for (var approachX = x - 1; approachX <= x + 1; approachX++) {
        for (var approachY = ground - 3; approachY < ground; approachY++) {
          if ('#=?'.contains(grid[approachY][approachX])) {
            grid[approachY][approachX] = ' ';
          }
        }
      }
    }

    bool hasClearTunnelBuffer(int x) {
      // 角色需在入口前约 4 格开始落地/下蹲；再为敌人的两格巡逻留余量。
      final bufferStart = x - 6 < 0 ? 0 : x - 6;
      final bufferEnd = x + 6 >= width ? width - 1 : x + 6;
      for (var patrolX = bufferStart; patrolX <= bufferEnd; patrolX++) {
        if (grid[ground - 2][patrolX] == 'D') {
          return false;
        }
      }
      return true;
    }

    final unplacedKinds = <String>{};
    for (var x = 2; x < width - 2; x++) {
      final enemy = grid[ground][x];
      if (!'AEGRTLYJ'.contains(enemy) ||
          (hasSafeAnchor(x) &&
              hasEnemyClearance(x, enemy) &&
              hasClearApproach(x) &&
              hasClearTunnelBuffer(x) &&
              (enemy != 'A' || hasClearSwoopSpace(x)))) {
        continue;
      }

      grid[ground][x] = ' ';
      var destination = -1;
      for (final requireClearApproach in [true, false]) {
        for (var offset = 1; offset < width && destination < 0; offset++) {
          for (final candidate in [x + offset, x - offset]) {
            if (candidate < 10 ||
                candidate >= width - 6 ||
                grid[ground][candidate] != ' ' ||
                !hasSafeAnchor(candidate) ||
                !hasEnemyClearance(candidate, enemy) ||
                !hasClearTunnelBuffer(candidate) ||
                enemy == 'A' && !hasClearSwoopSpace(candidate) ||
                requireClearApproach && !hasClearApproach(candidate)) {
              continue;
            }
            destination = candidate;
            break;
          }
        }
        if (destination >= 0) break;
      }
      if (destination < 0) {
        if (enemy != 'E') {
          unplacedKinds.add(enemy);
        }
        continue;
      }
      clearApproach(destination);
      grid[ground][destination] = enemy;
    }

    for (final enemy in unplacedKinds) {
      if (grid[ground].contains(enemy)) {
        continue;
      }
      if (grid[ground].where((marker) => marker == 'E').length <= 1) {
        break;
      }
      for (var x = 10; x < width - 6; x++) {
        if (grid[ground][x] != 'E' ||
            !hasSafeAnchor(x) ||
            !hasEnemyClearance(x, enemy) ||
            !hasClearApproach(x) ||
            !hasClearTunnelBuffer(x) ||
            enemy == 'A' && !hasClearSwoopSpace(x)) {
          continue;
        }
        grid[ground][x] = enemy;
        break;
      }
    }
  }

  /// 场景按地图长度铺开；核心玩法分散到全程，额外段落补充跳台与战术变化。
  static void _addSceneChallenges(
    List<List<String>> grid,
    int world,
    int level,
  ) {
    final width = grid.first.length;
    final ground = grid.length - 3;
    final sectionCount = ((width - 8 + 35) ~/ 36).clamp(5, 13).toInt();
    final sectionWidth = (width - 8) ~/ sectionCount;
    final difficulty = _difficulty(world, level);
    final rotation = (world * 3 + level) % 5;
    final sequenceStride = level == GameConstants.levelsPerWorld - 1
        ? 1
        : (world + level * 2) % 4 + 1;
    final lastCoreSection = sectionCount - 1;
    final coreSections = [
      0,
      lastCoreSection ~/ 4,
      lastCoreSection ~/ 2,
      lastCoreSection * 3 ~/ 4,
      lastCoreSection,
    ];

    void placeAirCourse(int startX, int phase) {
      for (var step = 0; step < 3; step++) {
        final platformX = startX + step * 4;
        final platformY = ground - (step == 1 && phase.isEven ? 3 : 2);
        if (platformX < 4 || platformX + 1 >= width - 4) {
          continue;
        }
        if (grid[platformY][platformX] != ' ' ||
            grid[platformY][platformX + 1] != ' ') {
          continue;
        }
        _platform(grid, platformX, platformY, 2);
        _coin(grid, platformX + 1, platformY - 1);
      }
    }

    for (var section = 0; section < sectionCount; section++) {
      final start = 4 + section * sectionWidth;
      final x = start + sectionWidth * 2 ~/ 3;
      final coreIndex = coreSections.indexOf(section);
      final scene = coreIndex >= 0
          ? (rotation + coreIndex * sequenceStride) % 5
          : 5 + (world + level + section) % 3;
      final nearBossArena =
          level == GameConstants.levelsPerWorld - 1 &&
          (x - width ~/ 2).abs() < 18;
      if (nearBossArena && coreIndex < 0) {
        continue;
      }
      void placeEnemy(int targetX) => _placeSceneEnemy(
        grid,
        targetX,
        ground,
        difficulty,
        world,
        level,
        section,
      );
      switch (scene) {
        case 0:
          // 弹跳节奏：春垫、短坑与弧形糖轨；地面仍留有直通过法。
          _put(grid, x, ground, 'S');
          _gap(grid, x + 4, 2);
          _platform(grid, x + 6, ground - 3, 3);
          _coin(grid, x + 3, ground - 4);
          _coin(grid, x + 4, ground - 5);
          _coin(grid, x + 5, ground - 5);
          _coin(grid, x + 6, ground - 4);
          break;
        case 1:
          // 花园守线：拾取种子后，植物伙伴会短暂自动瞄准附近敌人。
          _placeGroundPickup(grid, x, ground, 'N');
          placeEnemy(x + 5);
          _coin(grid, x + 2, ground - 2);
          _coin(grid, x + 3, ground - 2);
          break;
        case 2:
          // 横向枪战：先给发射器，再布置有间距的敌人，留下跳跃/冲刺选择。
          _placeGroundPickup(grid, x, ground, 'W');
          placeEnemy(x + 5);
          if (difficulty >= 4) {
            placeEnemy(x + 9);
          }
          break;
        case 3:
          // 载具冲刺：车在障碍前出现，冲撞收益明显；不把车放在坑边。
          _placeGroundPickup(grid, x, ground, 'V');
          placeEnemy(x + 5);
          if (difficulty >= 5) {
            placeEnemy(x + 9);
          }
          _coin(grid, x + 6, ground - 2);
          _coin(grid, x + 7, ground - 2);
          break;
        case 4:
          // 技能对抗：预警型怪物搭配高台糖轨，冲刺与跳跃都能应对。
          placeEnemy(x);
          _platform(grid, x + 4, ground - 3, 3);
          _coin(grid, x + 4, ground - 4);
          if (difficulty >= 5) {
            placeEnemy(x + 7);
          }
          break;
        case 5:
          // 空中弧线：三块错高平台提供可选捷径和糖果，不挡地面通路。
          placeAirCourse(x, world + level + section);
          break;
        case 6:
          // 弹簧奖励段：把奖励放在弹射弧线上，不额外挖坑制造必跳点。
          var springX = -1;
          for (var offset = 0; offset <= 3 && springX < 0; offset++) {
            final candidate = x + offset;
            if (candidate >= width - 8 ||
                grid[ground][candidate] != ' ' ||
                grid[ground + 1][candidate] != '#' ||
                grid[ground + 2][candidate] != '#') {
              continue;
            }
            if ([
              candidate - 1,
              candidate + 1,
            ].any((near) => 'AEGRTBTWVLYJ'.contains(grid[ground][near]))) {
              continue;
            }
            springX = candidate;
          }
          if (springX >= 0) {
            _put(grid, springX, ground, 'S');
            for (var i = 0; i < 5; i++) {
              final height = i == 2 ? 5 : 4;
              _coin(grid, springX + 2 + i, ground - height);
            }
          }
          break;
        case 7:
          // 技能对抗段：一只预警怪守住地面，浮台留出跳跃/技能绕行选择。
          placeEnemy(x);
          placeAirCourse(x + 4, world + level + section);
          break;
      }
    }
  }

  /// 每关加入低顶隧道：下蹲取糖或跳上顶棚绕行，地面保持连续。
  static void _addDuckTunnel(List<List<String>> grid, int world, int level) {
    final width = grid.first.length;
    final ground = grid.length - 3;
    final length = 4 + (world + level) % 3;
    final preferredStart = width ~/ 2 - length ~/ 2;
    final bossTile = grid[ground].indexOf('B');
    var start = -1;
    var enemyRelocations = <(int, String, int)>[];

    for (var offset = 0; offset < width && start < 0; offset++) {
      for (final direction in offset == 0 ? const [0] : const [-1, 1]) {
        final candidate = preferredStart + offset * direction;
        if (candidate < 6 || candidate + length > width - 6) {
          continue;
        }
        // 屋顶也是落脚点，上方不能紧贴另一层平台形成死角。
        if (world < 6 &&
            List.generate(length + 4, (i) => candidate - 2 + i).any(
              (x) =>
                  '#=?D'.contains(grid[ground - 3][x]) ||
                  '#=?D'.contains(grid[ground - 4][x]),
            )) {
          continue;
        }
        final runwayOverlapsBossPatrol =
            bossTile >= 0 &&
            candidate - 3 <= bossTile + 4 &&
            candidate + length + 2 >= bossTile - 3;
        final runwayOverlapsBossGunApproach =
            bossTile >= 0 &&
            candidate - 3 <= bossTile - 8 &&
            candidate + length + 2 >= bossTile - 14;
        if (runwayOverlapsBossPatrol || runwayOverlapsBossGunApproach) {
          continue;
        }
        final springBufferStart = candidate - 8 < 0 ? 0 : candidate - 8;
        var springOverlapsTunnelApproach = false;
        for (
          var springX = springBufferStart;
          springX < candidate + length + 4;
          springX++
        ) {
          if (grid[ground][springX] == 'S') {
            springOverlapsTunnelApproach = true;
            break;
          }
        }
        if (springOverlapsTunnelApproach) {
          continue;
        }
        var clear = true;
        final movingEnemies = <(int, String)>[];
        for (var x = candidate; x < candidate + length; x++) {
          final tile = grid[ground][x];
          if (grid[ground - 1][x] != ' ' ||
              ![' ', '=', 'C'].contains(grid[ground - 2][x]) ||
              'PFBVSW?'.contains(tile)) {
            clear = false;
            break;
          }
          if ('AEGRTLYJ'.contains(tile)) {
            movingEnemies.add((x, tile));
          }
        }
        if (clear) {
          for (var x = candidate - 2; x < candidate + length + 2; x++) {
            if ((x < candidate || x >= candidate + length) &&
                'AEGRBTLYJ'.contains(grid[ground][x])) {
              clear = false;
              break;
            }
          }
        }
        if (!clear) {
          continue;
        }

        final reserved = <int>{};
        final moves = <(int, String, int)>[];
        for (final (enemyX, kind) in movingEnemies) {
          final destination = _duckTunnelEnemyDestination(
            grid,
            ground,
            candidate,
            length,
            reserved,
          );
          if (destination == null) {
            clear = false;
            break;
          }
          reserved.add(destination);
          moves.add((enemyX, kind, destination));
        }
        if (clear) {
          start = candidate;
          enemyRelocations = moves;
          break;
        }
      }
    }
    if (start < 0) {
      return;
    }

    // 保证进出隧道各有三格实地；不能让坑口紧贴低顶，逼玩家边起跳边下蹲。
    for (var x = start - 3; x < start + length + 3; x++) {
      grid[ground + 1][x] = '#';
      grid[ground + 2][x] = '#';
    }

    for (final (enemyX, kind, destination) in enemyRelocations) {
      grid[ground][enemyX] = ' ';
      grid[ground][destination] = kind;
    }
    for (var i = 0; i < length; i++) {
      if (grid[ground - 2][start + i] == 'C' &&
          grid[ground][start + i] == ' ') {
        grid[ground][start + i] = 'C';
      }
      grid[ground - 2][start + i] = 'D';
      if (i.isOdd && grid[ground][start + i] == ' ') {
        grid[ground][start + i] = 'C';
      }
    }

    final guardX = start + length + 3;
    if (_difficulty(world, level) >= 5 &&
        (world + level).isEven &&
        guardX < width - 6 &&
        grid[ground][guardX] == ' ' &&
        grid[ground + 1][guardX] == '#' &&
        grid[ground + 2][guardX] == '#' &&
        ![
          guardX - 2,
          guardX - 1,
          guardX + 1,
          guardX + 2,
        ].any((x) => 'AEGRBTLYJ'.contains(grid[ground][x]))) {
      grid[ground][guardX] = 'T';
    }
  }

  static int? _duckTunnelEnemyDestination(
    List<List<String>> grid,
    int ground,
    int start,
    int length,
    Set<int> reserved,
  ) {
    final width = grid.first.length;
    for (var offset = 4; offset < width; offset++) {
      for (final x in [start - offset, start + length - 1 + offset]) {
        if (x < 6 ||
            x >= width - 6 ||
            x >= start && x < start + length ||
            reserved.contains(x) ||
            grid[ground][x] != ' ' ||
            grid[ground + 1][x] != '#' ||
            grid[ground + 2][x] != '#') {
          continue;
        }
        return x;
      }
    }
    return null;
  }

  static void _placeSceneEnemy(
    List<List<String>> grid,
    int targetX,
    int ground,
    int difficulty,
    int world,
    int level,
    int sceneIndex,
  ) {
    final width = grid.first.length;
    final sceneType = (world + level + sceneIndex * 2) % 5;
    final kind = difficulty < 3
        ? 'E'
        : difficulty < 4
        ? (sceneType == 0 ? 'T' : 'E')
        : switch (sceneType) {
            0 => 'T',
            1 => 'G',
            2 => 'R',
            3 => 'E',
            _ => 'A',
          };
    for (var offset = 0; offset <= 5; offset++) {
      for (final direction in offset == 0 ? const [1] : const [1, -1]) {
        final x = targetX + offset * direction;
        if (x < 8 || x >= width - 8 || grid[ground][x] != ' ') {
          continue;
        }
        if (grid[ground + 1][x] != '#' || grid[ground + 2][x] != '#') {
          continue;
        }
        if ([
          x - 2,
          x - 1,
          x + 1,
          x + 2,
        ].any((near) => 'AEGRBTWVLYJ'.contains(grid[ground][near]))) {
          continue;
        }
        grid[ground][x] = kind;
        return;
      }
    }
  }

  /// 长关每五分之一补一个有地面的检查点，降低连续失误后重跑距离。
  static void _placeSceneCheckpoints(List<List<String>> grid) {
    final width = grid.first.length;
    final ground = grid.length - 3;
    for (final fraction in const [0.2, 0.4, 0.6, 0.8]) {
      final targetX = (width * fraction).round();
      for (var offset = 0; offset <= width ~/ 12; offset++) {
        var placed = false;
        for (final direction in offset == 0 ? const [1] : const [1, -1]) {
          final x = targetX + offset * direction;
          if (x < 8 || x >= width - 8) {
            continue;
          }
          if (grid[ground][x] == 'K') {
            placed = true;
            break;
          }
          if (grid[ground][x] != ' ' ||
              grid[ground + 1][x] != '#' ||
              grid[ground + 2][x] != '#') {
            continue;
          }
          if ([
            x - 2,
            x - 1,
            x + 1,
            x + 2,
          ].any((near) => 'AEGRBTWVLYJ'.contains(grid[ground][near]))) {
            continue;
          }
          grid[ground][x] = 'K';
          placed = true;
          break;
        }
        if (placed) {
          break;
        }
      }
    }
  }

  /// 保留主题平台的同时，确保地面路线有净空且每个坑都能用基础跳跃跨过。
  static void _repairGuaranteedGroundRoute(List<List<String>> grid) {
    const maxGapTiles = 2;
    const minLandingTiles = 2;
    final ground = grid.length - 3;
    final width = grid.first.length;
    bool hasGapJumpClearance(int gapStart) {
      // 坑后也要检查落地跑道：紧贴坑口的低平台可能挡住跳跃落点，形成隐形墙。
      for (
        var x = gapStart - 2;
        x <= gapStart + maxGapTiles + minLandingTiles;
        x++
      ) {
        if (x < 0 || x >= width) {
          continue;
        }
        for (var y = ground - 3; y < ground; y++) {
          if ('#=?D'.contains(grid[y][x])) {
            return false;
          }
        }
      }
      return true;
    }

    // 低位平台会撞到站立角色的头和身体；移出碰撞范围，保留平台并开放地面通道。
    for (var x = 2; x <= width - 3; x++) {
      final tile = grid[ground - 1][x];
      if (tile != '=' && tile != '?') {
        continue;
      }
      grid[ground - 1][x] = ' ';
      var destination = ground - 2;
      while (destination >= ground - 3 && grid[destination][x] != ' ') {
        destination--;
      }
      if (destination >= ground - 3) {
        grid[destination][x] = tile;
      } else if (tile == '?' && grid[ground - 2][x] == '=') {
        grid[ground - 2][x] = '?';
      }
    }

    // 起点、终点固定在有地面的地面通道内，避免后续主题装饰覆盖。
    grid[ground][2] = 'P';
    grid[ground][width - 3] = 'F';
    grid[ground + 1][2] = '#';
    grid[ground + 2][2] = '#';
    grid[ground + 1][width - 3] = '#';
    grid[ground + 2][width - 3] = '#';

    var gapTiles = 0;
    var landingTiles = minLandingTiles;
    for (var x = 2; x <= width - 3; x++) {
      final isGap = grid[ground + 1][x] == ' ' && grid[ground + 2][x] == ' ';
      if (!isGap) {
        gapTiles = 0;
        landingTiles++;
        continue;
      }

      final canStartGap =
          gapTiles == 0 &&
          landingTiles >= minLandingTiles &&
          hasGapJumpClearance(x);
      final canExtendGap =
          gapTiles > 0 &&
          gapTiles < maxGapTiles &&
          hasGapJumpClearance(x - gapTiles);
      if (canStartGap || canExtendGap) {
        gapTiles++;
        landingTiles = 0;
        continue;
      }

      // 重叠坑之间补成落脚地面，限制坑宽并留足下一跳的起跳区。
      grid[ground + 1][x] = '#';
      grid[ground + 2][x] = '#';
      gapTiles = 0;
      landingTiles = 1;
    }
  }

  static void _placeGroundPickup(
    List<List<String>> grid,
    int targetX,
    int ground,
    String pickup, {
    int maxOffset = 8,
    bool groundOnly = false,
  }) {
    final pickupRows = groundOnly
        ? [ground]
        : [ground, ground - 2, ground - 3, ground - 4, ground - 5];
    for (var offset = 0; offset <= maxOffset; offset++) {
      for (final direction in offset == 0 ? const [1] : const [1, -1]) {
        final x = targetX + offset * direction;
        if (x < 10 || x >= grid.first.length - 8) {
          continue;
        }
        final pickupY = pickupRows
            .where((y) => y > 0 && y + 1 < grid.length)
            .firstWhere(
              (y) =>
                  grid[y][x] == ' ' &&
                  grid[y - 1][x] == ' ' &&
                  '=#?'.contains(grid[y + 1][x]),
              orElse: () => -1,
            );
        if (pickupY < 0) {
          continue;
        }
        final nearEnemy = [
          x - 2,
          x - 1,
          x + 1,
          x + 2,
        ].any((near) => 'AEGRBTLYJ'.contains(grid[pickupY][near]));
        if (nearEnemy) {
          continue;
        }
        grid[pickupY][x] = pickup;
        return;
      }
    }
  }

  static void _placeBossGun(List<List<String>> grid, int bossTile) {
    final ground = grid.length - 3;
    const distances = [11, 10, 12, 9, 13, 8, 14];
    for (final allowCoin in [false, true]) {
      for (final distance in distances) {
        final x = bossTile - distance;
        if (x < 10 || x >= grid.first.length - 8) {
          continue;
        }
        final tile = grid[ground][x];
        if (tile != ' ' && !(allowCoin && tile == 'C') ||
            grid[ground - 1][x] != ' ' ||
            [
              x - 2,
              x - 1,
              x + 1,
              x + 2,
            ].any((near) => 'AEGRBTLYJ'.contains(grid[ground][near]))) {
          continue;
        }
        grid[ground][x] = 'W';
        grid[ground + 1][x] = '#';
        grid[ground + 2][x] = '#';
        return;
      }
    }
  }

  /// 长关卡中段补平台与收集物
  static void _fillLongRun(List<List<String>> grid, int world, int level) {
    final w = grid.first.length;
    final ground = grid.length - 3;
    for (var x = 30; x < w - 30; x += 10 + (level % 5)) {
      if ((x + world + level) % 11 != 0) {
        continue;
      }
      final y = ground - 2 - ((x ~/ 10 + level) % 3);
      if (grid[_clampPlatY(grid, y)][x] != ' ') {
        continue;
      }
      _platform(grid, x, y, 2 + (level % 2));
      _coin(grid, x, y - 1);
      if (level >= 3 && (x + world) % 22 == 0) {
        _coin(grid, x + 1, y - 1);
      }
    }
  }

  /// 按难度适度追加坑与小怪
  static void _applyDifficultyPass(
    List<List<String>> grid,
    int world,
    int level,
  ) {
    final d = _difficulty(world, level);
    final w = grid.first.length;
    final ground = grid.length - 3;

    for (var i = 0; i < d ~/ 3; i++) {
      final x = 20 + i * (9 + world);
      if (x < w - 16) {
        _enemy(grid, x, ground);
      }
    }

    if (d >= 4) {
      for (var x = 24; x < w - 24; x += 14 + (world % 3)) {
        if ((x + level + world) % 15 == 0) {
          _gap(grid, x, 2);
        }
      }
    }

    if (d >= 6) {
      for (var x = 28; x < w - 28; x += 18) {
        if ((x + level) % 19 == 0) {
          _enemy(grid, x + 1, ground);
        }
      }
    }

    if (d >= 8 && level >= 3) {
      for (var x = 36; x < w - 36; x += 20) {
        if ((x + world) % 21 == 0) {
          final y = ground - 3 - (level % 2);
          _platform(grid, x, y, 2);
          if (level >= 5) {
            _enemy(grid, x + 1, ground);
          }
        }
      }
    }
  }

  static void _platform(List<List<String>> g, int x, int y, int len) {
    final py = _clampPlatY(g, y);
    // 不自动补机械台阶；安全地面路线与可跳抵的平台分层设计。
    for (var i = 0; i < len; i++) {
      final px = x + i;
      if (px >= 0 && px < g.first.length && py >= 0 && py < g.length) {
        g[py][px] = '=';
      }
    }
  }

  /// 平台最高控制在地面上 4 格，给高难关较短的跳跃留出余量
  static int _clampPlatY(List<List<String>> g, int y) {
    final highest = (g.length - 6).clamp(4, g.length - 5);
    final lowest = (g.length - 4).clamp(highest, g.length - 3);
    return y.clamp(highest, lowest);
  }

  static void _gap(List<List<String>> g, int x, int len) {
    // 坑宽最多 3 格；更宽的需求改成中间浮台
    final useLen = len.clamp(1, 3);
    for (var i = 0; i < useLen; i++) {
      final px = x + i;
      if (px <= 3 || px >= g.first.length - 4) {
        continue;
      }
      if (px >= 0 && px < g.first.length) {
        g[g.length - 1][px] = ' ';
        g[g.length - 2][px] = ' ';
      }
    }
    if (len > 3) {
      _platform(g, x + 1, g.length - 5, 2);
    }
  }

  static void _coin(List<List<String>> g, int x, int y) {
    final py = y.clamp(1, g.length - 3);
    if (py >= 0 && py < g.length && x >= 0 && x < g.first.length) {
      if (g[py][x] == ' ') {
        g[py][x] = 'C';
      }
    }
  }

  static void _enemy(List<List<String>> g, int x, int y) {
    if (y >= 0 && y < g.length && x >= 0 && x < g.first.length) {
      if (g[y][x] == ' ') {
        g[y][x] = 'E';
      }
    }
  }

  static void _put(List<List<String>> g, int x, int y, String ch) {
    var py = y;
    if (ch == '?' || ch == '=' || ch == 'S' || ch == 'M' || ch == 'H') {
      if (ch == '?' || ch == '=') {
        py = _clampPlatY(g, y);
      } else if (ch == 'S') {
        py = (g.length - 3);
      } else {
        py = y.clamp(2, g.length - 4);
      }
    }
    if (py >= 0 && py < g.length && x >= 0 && x < g.first.length) {
      final force =
          ch == '?' ||
          ch == 'S' ||
          ch == 'B' ||
          ch == 'K' ||
          ch == 'G' ||
          ch == 'R' ||
          ch == 'T' ||
          ch == 'N' ||
          ch == 'M' ||
          ch == 'H';
      if (g[py][x] == ' ' || force) {
        g[py][x] = ch;
      }
    }
  }

  static void _worldBlueberry(List<List<String>> g, int level) {
    final ground = g.length - 3;
    for (var i = 0; i < 10 + level; i++) {
      final x = 6 + i * 3;
      final y = ground - 2 - ((i + level) % 4);
      _platform(g, x, y, 1 + (i % 2));
      if (i % 3 == 0) {
        _coin(g, x, y - 1);
      }
      if (i % 4 == 0) {
        _enemy(g, x + 4, ground);
      }
    }
    for (var x = 8; x < g.first.length - 8; x += 8) {
      _gap(g, x, 2);
    }
  }

  static void _worldCaramelMine(List<List<String>> g, int level) {
    final ground = g.length - 3;
    for (var x = 5; x < g.first.length - 5; x += 4) {
      if ((x ~/ 4 + level).isOdd) {
        _platform(g, x, ground - 2, 3);
        _platform(g, x + 1, ground - 4, 2);
        _coin(g, x + 1, ground - 5);
      } else {
        _gap(g, x, 2);
        _enemy(g, x - 1, ground);
      }
    }
    if (level >= 8) {
      _platform(g, g.first.length ~/ 3, ground - 5, 6);
      for (var i = 0; i < 6; i++) {
        _coin(g, g.first.length ~/ 3 + i, ground - 6);
      }
    }
  }

  static void _worldHoneymoon(List<List<String>> g, int level) {
    final ground = g.length - 3;
    for (var i = 0; i < 12 + level; i++) {
      final x = 5 + i * 3;
      final y = ground - 2 - ((i + level) % 4);
      _platform(g, x, y, 2);
      _coin(g, x, y - 1);
      if (i % 5 == 0) {
        _enemy(g, x + 2, ground);
      }
    }
    for (var x = 12; x < g.first.length - 12; x += 6 + level ~/ 3) {
      _gap(g, x, 2);
    }
  }

  static void _worldCreamMeadow(List<List<String>> g, int level) {
    final ground = g.length - 3;
    switch (level) {
      case 0: // 晨雾小径 — 前奏：轻柔入场，几乎没有威胁
        _platform(g, 6, ground - 1, 4);
        _coin(g, 7, ground - 2);
        _coin(g, 8, ground - 2);
        _put(g, 10, ground - 1, '?');
        _platform(g, 16, ground - 2, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 16 + i, ground - 3);
        }
        _platform(g, 28, ground - 1, 3);
        _coin(g, 29, ground - 2);
        _platform(g, 38, ground - 3, 4);
        _coin(g, 39, ground - 4);
        _coin(g, 40, ground - 4);
        _put(g, 41, ground - 3, '?');
        _platform(g, 50, ground - 2, 3);
        _coin(g, 51, ground - 3);
        _platform(g, 62, ground - 1, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 63 + i, ground - 2);
        }
        _enemy(g, 70, ground);
        _platform(g, 78, ground - 2, 4);
        _coin(g, 79, ground - 3);
        _coin(g, 80, ground - 3);
        _platform(g, 90, ground - 3, 3);
        _put(g, 91, ground - 3, '?');
        _platform(g, 100, ground - 1, 4);
        _coin(g, 101, ground - 2);
        _coin(g, 102, ground - 2);
        _put(g, 110, ground, 'S');
        _platform(g, 118, ground - 2, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 119 + i, ground - 3);
        }
      case 1: // 清水湾 — 主歌A：节奏舒缓，引入小怪
        _platform(g, 6, ground - 1, 3);
        _coin(g, 7, ground - 2);
        _platform(g, 14, ground - 2, 4);
        _coin(g, 15, ground - 3);
        _coin(g, 16, ground - 3);
        _enemy(g, 20, ground);
        _platform(g, 26, ground - 3, 3);
        _put(g, 27, ground - 3, '?');
        _coin(g, 27, ground - 4);
        _platform(g, 36, ground - 1, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 37 + i, ground - 2);
        }
        _enemy(g, 44, ground);
        _platform(g, 50, ground - 2, 4);
        _coin(g, 51, ground - 3);
        _coin(g, 52, ground - 3);
        _put(g, 53, ground - 2, '?');
        _platform(g, 62, ground - 3, 3);
        _coin(g, 63, ground - 4);
        _put(g, 70, ground, 'S');
        _platform(g, 78, ground - 2, 5);
        _coin(g, 79, ground - 3);
        _coin(g, 80, ground - 3);
        _coin(g, 81, ground - 3);
        _enemy(g, 88, ground);
        _platform(g, 94, ground - 1, 4);
        _put(g, 95, ground - 1, '?');
        _platform(g, 104, ground - 3, 3);
        _coin(g, 105, ground - 4);
        _enemy(g, 112, ground);
        _platform(g, 120, ground - 2, 4);
        for (var i = 0; i < 3; i++) {
          _coin(g, 121 + i, ground - 3);
        }
        _platform(g, 134, ground - 1, 5);
        _coin(g, 135, ground - 2);
        _coin(g, 136, ground - 2);
        _put(g, 140, ground - 2, 'H');
      case 2: // 素净坡 — 主歌B：引入坑洞，节奏渐起
        _platform(g, 6, ground - 2, 4);
        _coin(g, 7, ground - 3);
        _coin(g, 8, ground - 3);
        _gap(g, 14, 2);
        _platform(g, 18, ground - 1, 3);
        _coin(g, 19, ground - 2);
        _enemy(g, 24, ground);
        _platform(g, 30, ground - 3, 4);
        _put(g, 31, ground - 3, '?');
        _coin(g, 32, ground - 4);
        _gap(g, 38, 2);
        _platform(g, 42, ground - 2, 3);
        _coin(g, 43, ground - 3);
        _put(g, 48, ground, 'S');
        _platform(g, 54, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 55 + i, ground - 4);
        }
        _enemy(g, 62, ground);
        _gap(g, 68, 2);
        _platform(g, 72, ground - 2, 4);
        _coin(g, 73, ground - 3);
        _coin(g, 74, ground - 3);
        _platform(g, 82, ground - 1, 3);
        _put(g, 83, ground - 1, '?');
        _enemy(g, 90, ground);
        _gap(g, 96, 2);
        _platform(g, 100, ground - 3, 3);
        _coin(g, 101, ground - 4);
        _platform(g, 110, ground - 2, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 111 + i, ground - 3);
        }
        _enemy(g, 120, ground);
        _platform(g, 128, ground - 1, 4);
        _put(g, 130, ground - 2, 'M');
        _platform(g, 140, ground - 3, 3);
        _coin(g, 141, ground - 4);
        _gap(g, 148, 2);
        _platform(g, 154, ground - 2, 4);
        _coin(g, 155, ground - 3);
        _coin(g, 156, ground - 3);
      case 3: // 白纱河堤 — 副歌前奏：情绪铺垫，平台跳跃增多
        _platform(g, 6, ground - 2, 5);
        _coin(g, 7, ground - 3);
        _coin(g, 8, ground - 3);
        _coin(g, 9, ground - 3);
        _put(g, 10, ground - 2, '?');
        _enemy(g, 16, ground);
        _gap(g, 22, 2);
        _platform(g, 26, ground - 3, 3);
        _coin(g, 27, ground - 4);
        _platform(g, 34, ground - 1, 4);
        _put(g, 35, ground - 1, '?');
        _gap(g, 42, 3);
        _platform(g, 47, ground - 2, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 48 + i, ground - 3);
        }
        _enemy(g, 56, ground);
        _platform(g, 62, ground - 3, 4);
        _coin(g, 63, ground - 4);
        _coin(g, 64, ground - 4);
        _put(g, 65, ground - 3, '?');
        _put(g, 72, ground, 'S');
        _platform(g, 78, ground - 4, 3);
        _coin(g, 79, ground - 5);
        _put(g, 80, ground - 4, 'M');
        _gap(g, 86, 2);
        _enemy(g, 92, ground);
        _platform(g, 98, ground - 2, 5);
        _coin(g, 99, ground - 3);
        _coin(g, 100, ground - 3);
        _coin(g, 101, ground - 3);
        _gap(g, 108, 3);
        _platform(g, 114, ground - 3, 4);
        _put(g, 115, ground - 3, '?');
        _coin(g, 116, ground - 4);
        _enemy(g, 124, ground);
        _platform(g, 132, ground - 1, 5);
        _coin(g, 133, ground - 2);
        _coin(g, 134, ground - 2);
        _gap(g, 142, 2);
        _platform(g, 148, ground - 2, 4);
        _put(g, 150, ground - 3, 'H');
        _platform(g, 160, ground - 3, 3);
        _coin(g, 161, ground - 4);
        _enemy(g, 168, ground);
        _platform(g, 174, ground - 2, 4);
        _coin(g, 175, ground - 3);
        _coin(g, 176, ground - 3);
      case 4: // 露珠高台 — 副歌：情绪释放，大开大合
        _platform(g, 6, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 7 + i, ground - 4);
        }
        _put(g, 10, ground - 3, '?');
        _gap(g, 16, 3);
        _platform(g, 21, ground - 2, 4);
        _enemy(g, 25, ground);
        _platform(g, 32, ground - 4, 3);
        _coin(g, 33, ground - 5);
        _coin(g, 34, ground - 5);
        _put(g, 33, ground - 4, 'M');
        _put(g, 40, ground, 'S');
        _gap(g, 46, 2);
        _platform(g, 50, ground - 3, 5);
        _coin(g, 51, ground - 4);
        _coin(g, 52, ground - 4);
        _coin(g, 53, ground - 4);
        _put(g, 54, ground - 3, '?');
        _enemy(g, 60, ground);
        _gap(g, 66, 3);
        _platform(g, 72, ground - 2, 4);
        _put(g, 74, ground - 3, 'H');
        _platform(g, 82, ground - 4, 3);
        _coin(g, 83, ground - 5);
        _coin(g, 84, ground - 5);
        _enemy(g, 90, ground);
        _put(g, 96, ground, 'S');
        _gap(g, 102, 2);
        _platform(g, 108, ground - 3, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 108 + i, ground - 4);
        }
        _enemy(g, 118, ground);
        _gap(g, 124, 3);
        _platform(g, 130, ground - 2, 4);
        _put(g, 132, ground - 2, '?');
        _platform(g, 140, ground - 4, 3);
        _coin(g, 141, ground - 5);
        _put(g, 142, ground - 4, 'M');
        _enemy(g, 150, ground);
        _platform(g, 158, ground - 3, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 159 + i, ground - 4);
        }
        _gap(g, 168, 2);
        _platform(g, 174, ground - 1, 4);
        _coin(g, 175, ground - 2);
        _coin(g, 176, ground - 2);
        _put(g, 184, ground, 'S');
        _platform(g, 190, ground - 3, 4);
        _coin(g, 191, ground - 4);
        _coin(g, 192, ground - 4);
      case 5: // 淡妆峡谷 — 间奏：节奏放缓，探索感
        _platform(g, 6, ground - 2, 4);
        _coin(g, 7, ground - 3);
        _coin(g, 8, ground - 3);
        _platform(g, 14, ground - 4, 3);
        _put(g, 15, ground - 4, '?');
        _coin(g, 15, ground - 5);
        _gap(g, 22, 2);
        _enemy(g, 28, ground);
        _platform(g, 34, ground - 3, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 35 + i, ground - 4);
        }
        _put(g, 38, ground - 3, 'M');
        _put(g, 44, ground, 'S');
        _platform(g, 50, ground - 2, 3);
        _coin(g, 51, ground - 3);
        _gap(g, 58, 3);
        _platform(g, 64, ground - 3, 4);
        _coin(g, 65, ground - 4);
        _coin(g, 66, ground - 4);
        _put(g, 67, ground - 3, '?');
        _enemy(g, 74, ground);
        _platform(g, 80, ground - 1, 5);
        _coin(g, 81, ground - 2);
        _coin(g, 82, ground - 2);
        _gap(g, 90, 2);
        _platform(g, 96, ground - 4, 3);
        _put(g, 97, ground - 5, 'H');
        _enemy(g, 104, ground);
        _put(g, 110, ground, 'S');
        _platform(g, 116, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 117 + i, ground - 4);
        }
        _gap(g, 126, 2);
        _platform(g, 132, ground - 2, 4);
        _coin(g, 133, ground - 3);
        _coin(g, 134, ground - 3);
        _enemy(g, 142, ground);
        _platform(g, 148, ground - 3, 3);
        _put(g, 149, ground - 3, '?');
        _platform(g, 158, ground - 1, 4);
        _coin(g, 159, ground - 2);
        _gap(g, 166, 3);
        _platform(g, 172, ground - 2, 5);
        _coin(g, 173, ground - 3);
        _coin(g, 174, ground - 3);
        _enemy(g, 182, ground);
        _platform(g, 188, ground - 4, 3);
        _put(g, 189, ground - 4, 'M');
        _platform(g, 198, ground - 2, 4);
        _coin(g, 199, ground - 3);
        _coin(g, 200, ground - 3);
        _put(g, 208, ground, 'S');
      case 6: // 微光桥 — 主歌2：温暖回忆，平稳但有层次
        _platform(g, 6, ground - 1, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 7 + i, ground - 2);
        }
        _platform(g, 16, ground - 3, 3);
        _put(g, 17, ground - 3, '?');
        _coin(g, 17, ground - 4);
        _enemy(g, 24, ground);
        _gap(g, 30, 2);
        _platform(g, 34, ground - 2, 5);
        _coin(g, 35, ground - 3);
        _coin(g, 36, ground - 3);
        _coin(g, 37, ground - 3);
        _platform(g, 44, ground - 4, 3);
        _put(g, 45, ground - 4, 'M');
        _enemy(g, 52, ground);
        _put(g, 58, ground, 'S');
        _gap(g, 64, 3);
        _platform(g, 70, ground - 3, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 70 + i, ground - 4);
        }
        _put(g, 74, ground - 3, '?');
        _platform(g, 82, ground - 1, 4);
        _coin(g, 83, ground - 2);
        _enemy(g, 90, ground);
        _gap(g, 96, 2);
        _platform(g, 102, ground - 3, 4);
        _coin(g, 103, ground - 4);
        _coin(g, 104, ground - 4);
        _put(g, 105, ground - 3, '?');
        _put(g, 112, ground, 'S');
        _platform(g, 118, ground - 4, 3);
        _put(g, 119, ground - 5, 'H');
        _enemy(g, 126, ground);
        _gap(g, 132, 3);
        _platform(g, 138, ground - 2, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 139 + i, ground - 3);
        }
        _platform(g, 150, ground - 3, 3);
        _coin(g, 151, ground - 4);
        _enemy(g, 158, ground);
        _platform(g, 164, ground - 1, 4);
        _put(g, 166, ground - 1, '?');
        _gap(g, 174, 2);
        _platform(g, 180, ground - 2, 5);
        _coin(g, 181, ground - 3);
        _coin(g, 182, ground - 3);
        _enemy(g, 192, ground);
        _platform(g, 200, ground - 3, 4);
        _put(g, 202, ground - 4, 'M');
        _platform(g, 214, ground - 1, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 215 + i, ground - 2);
        }
        _put(g, 224, ground, 'S');
      case 7: // 花影田 — 副歌2：再次升华，对比强烈
        _platform(g, 6, ground - 3, 4);
        _coin(g, 7, ground - 4);
        _coin(g, 8, ground - 4);
        _coin(g, 9, ground - 4);
        _put(g, 6, ground - 3, '?');
        _gap(g, 14, 3);
        _platform(g, 20, ground - 2, 5);
        _enemy(g, 24, ground);
        _platform(g, 30, ground - 4, 3);
        _put(g, 31, ground - 4, 'M');
        _coin(g, 31, ground - 5);
        _put(g, 38, ground, 'S');
        _gap(g, 44, 2);
        _platform(g, 48, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 49 + i, ground - 4);
        }
        _put(g, 52, ground - 3, '?');
        _enemy(g, 58, ground);
        _platform(g, 64, ground - 1, 4);
        _coin(g, 65, ground - 2);
        _coin(g, 66, ground - 2);
        _gap(g, 74, 3);
        _platform(g, 80, ground - 4, 3);
        _put(g, 81, ground - 5, 'H');
        _platform(g, 90, ground - 2, 5);
        _coin(g, 91, ground - 3);
        _coin(g, 92, ground - 3);
        _coin(g, 93, ground - 3);
        _enemy(g, 100, ground);
        _put(g, 106, ground, 'S');
        _gap(g, 112, 2);
        _platform(g, 118, ground - 3, 4);
        _coin(g, 119, ground - 4);
        _coin(g, 120, ground - 4);
        _put(g, 121, ground - 3, '?');
        _platform(g, 128, ground - 1, 5);
        _enemy(g, 134, ground);
        _gap(g, 140, 3);
        _platform(g, 146, ground - 4, 3);
        _put(g, 147, ground - 4, 'M');
        _platform(g, 156, ground - 2, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 156 + i, ground - 3);
        }
        _enemy(g, 166, ground);
        _platform(g, 172, ground - 3, 4);
        _put(g, 174, ground - 3, '?');
        _gap(g, 182, 2);
        _put(g, 188, ground, 'S');
        _platform(g, 194, ground - 4, 3);
        _put(g, 195, ground - 5, 'H');
        _platform(g, 204, ground - 2, 5);
        _coin(g, 205, ground - 3);
        _coin(g, 206, ground - 3);
        _enemy(g, 216, ground);
        _platform(g, 224, ground - 1, 4);
        _coin(g, 225, ground - 2);
        _coin(g, 226, ground - 2);
        _platform(g, 238, ground - 3, 3);
        _coin(g, 239, ground - 4);
      case 8: // 浅色滑轨 — 桥段：独特节奏，弹簧路线多
        _platform(g, 6, ground - 2, 4);
        _coin(g, 7, ground - 3);
        _coin(g, 8, ground - 3);
        _put(g, 14, ground, 'S');
        _platform(g, 20, ground - 4, 3);
        _coin(g, 21, ground - 5);
        _coin(g, 22, ground - 5);
        _gap(g, 28, 3);
        _enemy(g, 34, ground);
        _platform(g, 40, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 41 + i, ground - 4);
        }
        _put(g, 44, ground - 3, '?');
        _put(g, 50, ground, 'S');
        _platform(g, 56, ground - 4, 3);
        _put(g, 57, ground - 4, 'M');
        _gap(g, 64, 2);
        _platform(g, 68, ground - 2, 4);
        _coin(g, 69, ground - 3);
        _coin(g, 70, ground - 3);
        _enemy(g, 78, ground);
        _put(g, 84, ground, 'S');
        _platform(g, 90, ground - 3, 5);
        _coin(g, 91, ground - 4);
        _coin(g, 92, ground - 4);
        _coin(g, 93, ground - 4);
        _put(g, 94, ground - 3, '?');
        _gap(g, 102, 3);
        _platform(g, 108, ground - 4, 3);
        _put(g, 109, ground - 5, 'H');
        _enemy(g, 116, ground);
        _put(g, 122, ground, 'S');
        _platform(g, 128, ground - 3, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 128 + i, ground - 4);
        }
        _gap(g, 138, 2);
        _platform(g, 144, ground - 2, 4);
        _coin(g, 145, ground - 3);
        _enemy(g, 154, ground);
        _put(g, 160, ground, 'S');
        _platform(g, 166, ground - 4, 3);
        _put(g, 167, ground - 4, 'M');
        _platform(g, 176, ground - 2, 5);
        _coin(g, 177, ground - 3);
        _coin(g, 178, ground - 3);
        _gap(g, 186, 3);
        _enemy(g, 194, ground);
        _platform(g, 200, ground - 3, 4);
        _put(g, 202, ground - 3, '?');
        _coin(g, 202, ground - 4);
        _put(g, 210, ground, 'S');
        _platform(g, 218, ground - 4, 3);
        _coin(g, 219, ground - 5);
        _coin(g, 220, ground - 5);
        _platform(g, 230, ground - 2, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 231 + i, ground - 3);
        }
        _enemy(g, 242, ground);
        _platform(g, 250, ground - 1, 4);
        _put(g, 252, ground - 2, 'H');
        _platform(g, 262, ground - 3, 3);
        _coin(g, 263, ground - 4);
      case 9: // 晨曦高塔 — 高潮：最强难度，密集挑战
        _platform(g, 6, ground - 3, 4);
        for (var i = 0; i < 3; i++) {
          _coin(g, 7 + i, ground - 4);
        }
        _put(g, 6, ground - 3, '?');
        _gap(g, 14, 3);
        _enemy(g, 20, ground);
        _platform(g, 26, ground - 4, 3);
        _coin(g, 27, ground - 5);
        _coin(g, 28, ground - 5);
        _put(g, 27, ground - 4, 'M');
        _put(g, 34, ground, 'S');
        _gap(g, 40, 2);
        _platform(g, 44, ground - 3, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 44 + i, ground - 4);
        }
        _enemy(g, 54, ground);
        _gap(g, 60, 3);
        _platform(g, 66, ground - 2, 4);
        _put(g, 68, ground - 2, '?');
        _coin(g, 68, ground - 3);
        _enemy(g, 76, ground);
        _put(g, 82, ground, 'S');
        _platform(g, 88, ground - 4, 3);
        _put(g, 89, ground - 5, 'H');
        _gap(g, 96, 3);
        _platform(g, 102, ground - 3, 5);
        _coin(g, 103, ground - 4);
        _coin(g, 104, ground - 4);
        _coin(g, 105, ground - 4);
        _put(g, 106, ground - 3, '?');
        _enemy(g, 114, ground);
        _gap(g, 120, 2);
        _platform(g, 126, ground - 4, 3);
        _put(g, 127, ground - 4, 'M');
        _put(g, 134, ground, 'S');
        _platform(g, 140, ground - 3, 4);
        for (var i = 0; i < 4; i++) {
          _coin(g, 140 + i, ground - 4);
        }
        _enemy(g, 150, ground);
        _gap(g, 156, 3);
        _platform(g, 162, ground - 2, 5);
        _put(g, 164, ground - 2, '?');
        _coin(g, 164, ground - 3);
        _enemy(g, 172, ground);
        _put(g, 178, ground, 'S');
        _gap(g, 184, 2);
        _platform(g, 190, ground - 4, 3);
        _coin(g, 191, ground - 5);
        _coin(g, 192, ground - 5);
        _platform(g, 200, ground - 3, 5);
        _enemy(g, 210, ground);
        for (var i = 0; i < 4; i++) {
          _coin(g, 201 + i, ground - 4);
        }
        _gap(g, 218, 3);
        _platform(g, 224, ground - 2, 4);
        _put(g, 226, ground - 3, 'H');
        _enemy(g, 234, ground);
        _platform(g, 240, ground - 4, 3);
        _put(g, 241, ground - 4, 'M');
        _put(g, 250, ground, 'S');
        _platform(g, 256, ground - 3, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 256 + i, ground - 4);
        }
        _gap(g, 266, 2);
        _enemy(g, 274, ground);
        _platform(g, 280, ground - 2, 4);
        _coin(g, 281, ground - 3);
        _coin(g, 282, ground - 3);
      case 10: // 素颜之心 — Boss战
        _platform(g, 6, ground - 2, 3);
        _coin(g, 7, ground - 3);
        _coin(g, 8, ground - 3);
        _platform(g, 14, ground - 3, 4);
        _put(g, 15, ground - 3, '?');
        _enemy(g, 22, ground);
        _gap(g, 28, 2);
        _platform(g, 34, ground - 2, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 35 + i, ground - 3);
        }
        _enemy(g, 44, ground);
        _platform(g, 50, ground - 4, 3);
        _put(g, 51, ground - 4, 'M');
        _put(g, 58, ground, 'S');
        _gap(g, 64, 3);
        _platform(g, 70, ground - 3, 4);
        _coin(g, 71, ground - 4);
        _coin(g, 72, ground - 4);
        _enemy(g, 80, ground);
        _platform(g, 86, ground - 2, 5);
        _put(g, 88, ground - 2, '?');
        _put(g, 96, ground, 'S');
        _platform(g, 102, ground - 4, 3);
        _put(g, 103, ground - 5, 'H');
    }
  }

  static void _placeKindOnGround(
    List<List<String>> g,
    int ground,
    String kind,
    int prefer,
  ) {
    final width = g.first.length;
    final span = width - 24;
    if (span <= 0) {
      return;
    }
    final start = prefer.clamp(16, width - 9);
    for (var step = 0; step < span; step++) {
      final x = 16 + (start - 16 + step) % span;
      if (g[ground][x] != ' ') {
        continue;
      }
      if (g[ground + 1][x] != '#' || g[ground + 2][x] != '#') {
        continue;
      }
      if (g[ground - 2][x] == 'D') {
        continue;
      }
      var blocked = false;
      final softPlatforms = <(int, int)>[];
      for (var laneX = x - 1; laneX <= x + 1 && !blocked; laneX++) {
        for (var laneY = ground - 3; laneY < ground; laneY++) {
          final tile = g[laneY][laneX];
          if ('#?D'.contains(tile)) {
            blocked = true;
            break;
          }
          if (tile == '=') {
            softPlatforms.add((laneX, laneY));
          }
        }
      }
      if (blocked) {
        continue;
      }
      for (var near = x - 6; near <= x + 6 && !blocked; near++) {
        if (near < 0 || near >= width) {
          continue;
        }
        final away = (near - x).abs();
        final tile = g[ground][near];
        if (near != x && away <= 3 && 'AEGRTLYJ'.contains(tile)) {
          blocked = true;
        } else if (near != x && away <= 6 && 'BS'.contains(tile)) {
          blocked = true;
        } else if (away <= 2 && tile == 'K') {
          blocked = true;
        } else if (g[ground - 2][near] == 'D') {
          blocked = true;
        } else if (away <= 4 &&
            g[ground + 1][near] == ' ' &&
            g[ground + 2][near] == ' ') {
          blocked = true;
        }
      }
      if (blocked) {
        continue;
      }
      for (final (laneX, laneY) in softPlatforms) {
        g[laneY][laneX] = ' ';
      }
      g[ground][x] = kind;
      return;
    }
  }

  /// 每个非 Boss 关都尽量安排糖壳、滚轮和糖泡，增加敌人组合变化。
  /// 头顶的软浮台可以让开，硬砖和隧道不拆；无安全空位时再替换普通巡逻怪。
  static void _placeSpecialRoster(
    List<List<String>> grid,
    int world,
    int level,
  ) {
    if (level == GameConstants.levelsPerWorld - 1) {
      return;
    }
    final ground = grid.length - 3;
    _ensureKind(grid, ground, 'L', 36 + level * 3);
    _ensureKind(grid, ground, 'Y', 64 + world * 5);
    _ensureKind(grid, ground, 'J', 96 + world * 4 + level);
  }

  static void _ensureKind(
    List<List<String>> grid,
    int ground,
    String kind,
    int prefer,
  ) {
    if (grid[ground].join().contains(kind)) {
      return;
    }
    _placeKindOnGround(grid, ground, kind, prefer);
    if (grid[ground].join().contains(kind)) {
      return;
    }
    final width = grid.first.length;
    for (var x = 16; x < width - 8; x++) {
      if (grid[ground][x] != 'E') {
        continue;
      }
      var crowded = false;
      for (var near = x - 3; near <= x + 3 && !crowded; near++) {
        if (near == x || near < 0 || near >= width) {
          continue;
        }
        if ('AEGRTLYJ'.contains(grid[ground][near])) {
          crowded = true;
        }
      }
      if (crowded) {
        continue;
      }
      grid[ground][x] = kind;
      return;
    }
  }

  static void _worldStrawberry(List<List<String>> g, int level) {
    final ground = g.length - 3;
    switch (level) {
      case 0: // 马蹄台阶 — 前奏：古风起势，阶梯递升
        _platform(g, 6, ground - 1, 3);
        _coin(g, 7, ground - 2);
        _platform(g, 14, ground - 2, 4);
        _coin(g, 15, ground - 3);
        _coin(g, 16, ground - 3);
        _platform(g, 24, ground - 3, 3);
        _put(g, 25, ground - 3, '?');
        _coin(g, 25, ground - 4);
        _platform(g, 36, ground - 1, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 37 + i, ground - 2);
        }
        _enemy(g, 46, ground);
        _platform(g, 54, ground - 2, 4);
        _coin(g, 55, ground - 3);
        _coin(g, 56, ground - 3);
        _platform(g, 66, ground - 3, 3);
        _put(g, 67, ground - 3, '?');
        _platform(g, 78, ground - 1, 4);
        _coin(g, 79, ground - 2);
        _coin(g, 80, ground - 2);
        _enemy(g, 88, ground);
        _platform(g, 96, ground - 2, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 97 + i, ground - 3);
        }
        _platform(g, 110, ground - 3, 3);
        _coin(g, 111, ground - 4);
        _platform(g, 122, ground - 1, 4);
        _coin(g, 123, ground - 2);
        _coin(g, 124, ground - 2);
        _put(g, 130, ground, 'S');
        _platform(g, 138, ground - 2, 4);
        _coin(g, 139, ground - 3);
        _coin(g, 140, ground - 3);
        _platform(g, 150, ground - 3, 3);
        _coin(g, 151, ground - 4);
      case 1: // 白鬃洞穴 — 主歌A：探索洞穴意象
        _platform(g, 6, ground - 2, 5);
        _coin(g, 7, ground - 3);
        _coin(g, 8, ground - 3);
        _put(g, 10, ground - 2, '?');
        _enemy(g, 18, ground);
        _platform(g, 24, ground - 3, 4);
        _coin(g, 25, ground - 4);
        _coin(g, 26, ground - 4);
        _gap(g, 34, 2);
        _platform(g, 38, ground - 1, 3);
        _coin(g, 39, ground - 2);
        _platform(g, 48, ground - 4, 3);
        _put(g, 49, ground - 4, 'M');
        _enemy(g, 56, ground);
        _platform(g, 62, ground - 2, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 63 + i, ground - 3);
        }
        _gap(g, 72, 2);
        _platform(g, 78, ground - 3, 4);
        _put(g, 79, ground - 3, '?');
        _coin(g, 80, ground - 4);
        _put(g, 88, ground, 'S');
        _enemy(g, 96, ground);
        _platform(g, 102, ground - 2, 4);
        _coin(g, 103, ground - 3);
        _coin(g, 104, ground - 3);
        _platform(g, 114, ground - 4, 3);
        _put(g, 115, ground - 5, 'H');
        _gap(g, 124, 2);
        _platform(g, 130, ground - 1, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 131 + i, ground - 2);
        }
        _enemy(g, 140, ground);
        _platform(g, 148, ground - 3, 3);
        _coin(g, 149, ground - 4);
      case 2: // 缰绳弹跳 — 副歌前奏：弹簧路线，白马奔驰感
        _platform(g, 6, ground - 1, 4);
        _coin(g, 7, ground - 2);
        _coin(g, 8, ground - 2);
        _put(g, 14, ground, 'S');
        _platform(g, 20, ground - 3, 4);
        _coin(g, 21, ground - 4);
        _coin(g, 22, ground - 4);
        _put(g, 23, ground - 3, '?');
        _gap(g, 30, 2);
        _enemy(g, 36, ground);
        _platform(g, 42, ground - 2, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 43 + i, ground - 3);
        }
        _put(g, 50, ground, 'S');
        _platform(g, 56, ground - 4, 3);
        _put(g, 57, ground - 4, 'M');
        _enemy(g, 64, ground);
        _gap(g, 70, 3);
        _platform(g, 76, ground - 2, 4);
        _coin(g, 77, ground - 3);
        _coin(g, 78, ground - 3);
        _put(g, 84, ground, 'S');
        _platform(g, 90, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 91 + i, ground - 4);
        }
        _put(g, 94, ground - 3, '?');
        _enemy(g, 102, ground);
        _gap(g, 108, 2);
        _platform(g, 114, ground - 4, 3);
        _put(g, 115, ground - 5, 'H');
        _put(g, 122, ground, 'S');
        _platform(g, 128, ground - 2, 4);
        _coin(g, 129, ground - 3);
        _coin(g, 130, ground - 3);
        _enemy(g, 138, ground);
        _platform(g, 146, ground - 3, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 147 + i, ground - 4);
        }
        _gap(g, 156, 2);
        _platform(g, 162, ground - 1, 4);
        _coin(g, 163, ground - 2);
      case 3: // 马鞍断桥 — 副歌A：断桥意象，大跳跃
        _platform(g, 6, ground - 2, 3);
        _coin(g, 7, ground - 3);
        _gap(g, 14, 3);
        _platform(g, 20, ground - 3, 4);
        _coin(g, 21, ground - 4);
        _coin(g, 22, ground - 4);
        _put(g, 23, ground - 3, '?');
        _enemy(g, 30, ground);
        _gap(g, 38, 3);
        _platform(g, 44, ground - 2, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 45 + i, ground - 3);
        }
        _put(g, 52, ground, 'S');
        _platform(g, 58, ground - 4, 3);
        _put(g, 59, ground - 4, 'M');
        _gap(g, 66, 2);
        _enemy(g, 72, ground);
        _platform(g, 78, ground - 3, 5);
        _coin(g, 79, ground - 4);
        _coin(g, 80, ground - 4);
        _coin(g, 81, ground - 4);
        _gap(g, 88, 3);
        _platform(g, 94, ground - 2, 4);
        _put(g, 96, ground - 2, '?');
        _enemy(g, 104, ground);
        _put(g, 110, ground, 'S');
        _gap(g, 118, 2);
        _platform(g, 124, ground - 4, 3);
        _put(g, 125, ground - 5, 'H');
        _platform(g, 134, ground - 1, 5);
        _coin(g, 135, ground - 2);
        _coin(g, 136, ground - 2);
        _gap(g, 144, 3);
        _enemy(g, 152, ground);
        _platform(g, 158, ground - 3, 4);
        for (var i = 0; i < 4; i++) {
          _coin(g, 158 + i, ground - 4);
        }
        _gap(g, 168, 2);
        _platform(g, 174, ground - 2, 3);
        _coin(g, 175, ground - 3);
        _put(g, 182, ground, 'S');
      case 4: // 云驹河流 — 间奏：流水般的平台，舒缓
        _platform(g, 6, ground - 2, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 7 + i, ground - 3);
        }
        _platform(g, 16, ground - 1, 3);
        _coin(g, 17, ground - 2);
        _platform(g, 26, ground - 3, 4);
        _put(g, 27, ground - 3, '?');
        _coin(g, 28, ground - 4);
        _enemy(g, 36, ground);
        _gap(g, 42, 2);
        _platform(g, 48, ground - 2, 5);
        _coin(g, 49, ground - 3);
        _coin(g, 50, ground - 3);
        _put(g, 56, ground, 'S');
        _platform(g, 62, ground - 4, 3);
        _put(g, 63, ground - 4, 'M');
        _platform(g, 72, ground - 1, 4);
        _coin(g, 73, ground - 2);
        _coin(g, 74, ground - 2);
        _enemy(g, 82, ground);
        _gap(g, 88, 3);
        _platform(g, 94, ground - 3, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 94 + i, ground - 4);
        }
        _platform(g, 106, ground - 2, 3);
        _put(g, 107, ground - 2, '?');
        _enemy(g, 116, ground);
        _put(g, 122, ground, 'S');
        _platform(g, 128, ground - 4, 3);
        _put(g, 129, ground - 5, 'H');
        _gap(g, 138, 2);
        _platform(g, 144, ground - 2, 4);
        _coin(g, 145, ground - 3);
        _coin(g, 146, ground - 3);
        _platform(g, 158, ground - 3, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 159 + i, ground - 4);
        }
        _enemy(g, 168, ground);
        _platform(g, 176, ground - 1, 4);
        _coin(g, 177, ground - 2);
        _gap(g, 186, 2);
        _platform(g, 192, ground - 2, 5);
        _coin(g, 193, ground - 3);
        _coin(g, 194, ground - 3);
        _put(g, 200, ground, 'S');
      case 5: // 长鞭螺旋 — 主歌B：螺旋上升，层次丰富
        _platform(g, 6, ground - 1, 4);
        _coin(g, 7, ground - 2);
        _coin(g, 8, ground - 2);
        _platform(g, 14, ground - 3, 3);
        _put(g, 15, ground - 3, '?');
        _gap(g, 22, 2);
        _enemy(g, 28, ground);
        _platform(g, 34, ground - 4, 4);
        _coin(g, 35, ground - 5);
        _coin(g, 36, ground - 5);
        _put(g, 37, ground - 4, 'M');
        _put(g, 44, ground, 'S');
        _platform(g, 50, ground - 2, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 51 + i, ground - 3);
        }
        _gap(g, 60, 3);
        _platform(g, 66, ground - 3, 4);
        _coin(g, 67, ground - 4);
        _coin(g, 68, ground - 4);
        _enemy(g, 76, ground);
        _platform(g, 82, ground - 1, 5);
        _put(g, 84, ground - 1, '?');
        _put(g, 92, ground, 'S');
        _platform(g, 98, ground - 4, 3);
        _put(g, 99, ground - 5, 'H');
        _gap(g, 106, 2);
        _platform(g, 112, ground - 2, 4);
        _coin(g, 113, ground - 3);
        _coin(g, 114, ground - 3);
        _enemy(g, 122, ground);
        _platform(g, 128, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 129 + i, ground - 4);
        }
        _gap(g, 138, 3);
        _put(g, 146, ground, 'S');
        _platform(g, 152, ground - 4, 3);
        _put(g, 153, ground - 4, 'M');
        _platform(g, 162, ground - 2, 4);
        _coin(g, 163, ground - 3);
        _coin(g, 164, ground - 3);
        _enemy(g, 172, ground);
        _gap(g, 178, 2);
        _platform(g, 184, ground - 3, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 184 + i, ground - 4);
        }
        _platform(g, 196, ground - 1, 3);
        _coin(g, 197, ground - 2);
        _enemy(g, 206, ground);
        _platform(g, 214, ground - 2, 4);
        _put(g, 216, ground - 2, '?');
      case 6: // 银蹄高台 — 副歌B：高台纵跳，银蹄意象
        _platform(g, 6, ground - 3, 4);
        _coin(g, 7, ground - 4);
        _coin(g, 8, ground - 4);
        _coin(g, 9, ground - 4);
        _put(g, 6, ground - 3, '?');
        _gap(g, 16, 3);
        _platform(g, 22, ground - 2, 5);
        _enemy(g, 26, ground);
        _put(g, 32, ground, 'S');
        _platform(g, 38, ground - 4, 3);
        _put(g, 39, ground - 4, 'M');
        _gap(g, 46, 2);
        _platform(g, 52, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 53 + i, ground - 4);
        }
        _put(g, 56, ground - 3, '?');
        _enemy(g, 64, ground);
        _platform(g, 70, ground - 1, 4);
        _coin(g, 71, ground - 2);
        _coin(g, 72, ground - 2);
        _gap(g, 80, 3);
        _put(g, 88, ground, 'S');
        _platform(g, 94, ground - 4, 3);
        _put(g, 95, ground - 5, 'H');
        _platform(g, 104, ground - 2, 5);
        _coin(g, 105, ground - 3);
        _coin(g, 106, ground - 3);
        _enemy(g, 114, ground);
        _gap(g, 120, 2);
        _platform(g, 126, ground - 3, 4);
        _coin(g, 127, ground - 4);
        _coin(g, 128, ground - 4);
        _put(g, 134, ground, 'S');
        _platform(g, 140, ground - 4, 3);
        _put(g, 141, ground - 4, 'M');
        _gap(g, 148, 3);
        _platform(g, 154, ground - 2, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 155 + i, ground - 3);
        }
        _enemy(g, 164, ground);
        _platform(g, 170, ground - 3, 4);
        _put(g, 172, ground - 3, '?');
        _gap(g, 180, 2);
        _platform(g, 186, ground - 1, 5);
        _coin(g, 187, ground - 2);
        _coin(g, 188, ground - 2);
        _enemy(g, 196, ground);
        _put(g, 204, ground, 'S');
        _platform(g, 210, ground - 4, 3);
        _coin(g, 211, ground - 5);
        _coin(g, 212, ground - 5);
        _platform(g, 222, ground - 2, 4);
        _coin(g, 223, ground - 3);
        _gap(g, 232, 2);
      case 7: // 追风环 — 桥段：风的意象，高速通过
        _platform(g, 6, ground - 2, 5);
        _coin(g, 7, ground - 3);
        _coin(g, 8, ground - 3);
        _coin(g, 9, ground - 3);
        _put(g, 10, ground - 2, '?');
        _enemy(g, 18, ground);
        _gap(g, 24, 2);
        _platform(g, 30, ground - 3, 4);
        _coin(g, 31, ground - 4);
        _coin(g, 32, ground - 4);
        _put(g, 40, ground, 'S');
        _platform(g, 46, ground - 4, 3);
        _put(g, 47, ground - 4, 'M');
        _gap(g, 54, 3);
        _enemy(g, 62, ground);
        _platform(g, 68, ground - 2, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 68 + i, ground - 3);
        }
        _platform(g, 80, ground - 3, 3);
        _put(g, 81, ground - 3, '?');
        _gap(g, 88, 2);
        _put(g, 96, ground, 'S');
        _enemy(g, 104, ground);
        _platform(g, 110, ground - 4, 3);
        _put(g, 111, ground - 5, 'H');
        _platform(g, 120, ground - 2, 4);
        _coin(g, 121, ground - 3);
        _coin(g, 122, ground - 3);
        _gap(g, 130, 3);
        _platform(g, 136, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 137 + i, ground - 4);
        }
        _enemy(g, 146, ground);
        _put(g, 154, ground, 'S');
        _gap(g, 160, 2);
        _platform(g, 166, ground - 4, 3);
        _put(g, 167, ground - 4, 'M');
        _platform(g, 176, ground - 1, 4);
        _coin(g, 177, ground - 2);
        _enemy(g, 186, ground);
        _platform(g, 192, ground - 3, 5);
        _coin(g, 193, ground - 4);
        _coin(g, 194, ground - 4);
        _gap(g, 204, 3);
        _platform(g, 210, ground - 2, 4);
        _put(g, 212, ground - 2, '?');
        _enemy(g, 222, ground);
        _platform(g, 228, ground - 3, 3);
        _coin(g, 229, ground - 4);
        _put(g, 238, ground, 'S');
        _platform(g, 244, ground - 4, 3);
        _coin(g, 245, ground - 5);
      case 8: // 草原谷 — 副歌C：开阔草原，最后的奔驰
        _platform(g, 6, ground - 1, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 6 + i, ground - 2);
        }
        _gap(g, 16, 2);
        _enemy(g, 22, ground);
        _platform(g, 28, ground - 3, 4);
        _coin(g, 29, ground - 4);
        _coin(g, 30, ground - 4);
        _put(g, 31, ground - 3, '?');
        _put(g, 38, ground, 'S');
        _platform(g, 44, ground - 4, 3);
        _put(g, 45, ground - 4, 'M');
        _gap(g, 52, 3);
        _platform(g, 58, ground - 2, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 59 + i, ground - 3);
        }
        _enemy(g, 68, ground);
        _gap(g, 74, 2);
        _platform(g, 80, ground - 3, 4);
        _coin(g, 81, ground - 4);
        _coin(g, 82, ground - 4);
        _put(g, 90, ground, 'S');
        _platform(g, 96, ground - 4, 3);
        _put(g, 97, ground - 5, 'H');
        _enemy(g, 106, ground);
        _gap(g, 112, 3);
        _platform(g, 118, ground - 2, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 119 + i, ground - 3);
        }
        _put(g, 122, ground - 2, '?');
        _platform(g, 130, ground - 3, 3);
        _coin(g, 131, ground - 4);
        _enemy(g, 140, ground);
        _put(g, 146, ground, 'S');
        _gap(g, 152, 2);
        _platform(g, 158, ground - 4, 3);
        _put(g, 159, ground - 4, 'M');
        _platform(g, 168, ground - 1, 5);
        _coin(g, 169, ground - 2);
        _coin(g, 170, ground - 2);
        _enemy(g, 178, ground);
        _gap(g, 186, 3);
        _platform(g, 192, ground - 3, 4);
        for (var i = 0; i < 4; i++) {
          _coin(g, 192 + i, ground - 4);
        }
        _platform(g, 204, ground - 2, 5);
        _put(g, 206, ground - 2, '?');
        _enemy(g, 214, ground);
        _platform(g, 222, ground - 4, 3);
        _put(g, 223, ground - 5, 'H');
        _put(g, 232, ground, 'S');
        _platform(g, 238, ground - 3, 4);
        _coin(g, 239, ground - 4);
        _coin(g, 240, ground - 4);
        _gap(g, 248, 2);
        _platform(g, 254, ground - 2, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 255 + i, ground - 3);
        }
      case 9: // 踏雪之巅 — 高潮：最难，踏雪意象
        _platform(g, 6, ground - 3, 4);
        for (var i = 0; i < 3; i++) {
          _coin(g, 7 + i, ground - 4);
        }
        _put(g, 6, ground - 3, '?');
        _gap(g, 14, 3);
        _enemy(g, 22, ground);
        _platform(g, 28, ground - 4, 3);
        _put(g, 29, ground - 4, 'M');
        _coin(g, 29, ground - 5);
        _put(g, 36, ground, 'S');
        _gap(g, 42, 2);
        _platform(g, 48, ground - 3, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 48 + i, ground - 4);
        }
        _enemy(g, 58, ground);
        _gap(g, 64, 3);
        _platform(g, 70, ground - 2, 4);
        _put(g, 72, ground - 2, '?');
        _enemy(g, 80, ground);
        _put(g, 86, ground, 'S');
        _platform(g, 92, ground - 4, 3);
        _put(g, 93, ground - 5, 'H');
        _gap(g, 100, 3);
        _platform(g, 106, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 107 + i, ground - 4);
        }
        _put(g, 110, ground - 3, '?');
        _enemy(g, 118, ground);
        _gap(g, 124, 2);
        _platform(g, 130, ground - 4, 3);
        _put(g, 131, ground - 4, 'M');
        _put(g, 138, ground, 'S');
        _gap(g, 144, 3);
        _platform(g, 150, ground - 3, 4);
        _coin(g, 151, ground - 4);
        _coin(g, 152, ground - 4);
        _enemy(g, 160, ground);
        _platform(g, 166, ground - 2, 5);
        _put(g, 168, ground - 2, '?');
        _gap(g, 176, 2);
        _put(g, 184, ground, 'S');
        _platform(g, 190, ground - 4, 3);
        _coin(g, 191, ground - 5);
        _coin(g, 192, ground - 5);
        _enemy(g, 200, ground);
        _gap(g, 206, 3);
        _platform(g, 212, ground - 3, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 212 + i, ground - 4);
        }
        _platform(g, 224, ground - 2, 4);
        _enemy(g, 232, ground);
        _gap(g, 238, 2);
        _put(g, 244, ground, 'S');
        _platform(g, 250, ground - 4, 3);
        _put(g, 251, ground - 5, 'H');
        _platform(g, 262, ground - 3, 4);
        _coin(g, 263, ground - 4);
        _coin(g, 264, ground - 4);
        _enemy(g, 274, ground);
        _platform(g, 280, ground - 2, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 281 + i, ground - 3);
        }
      case 10: // 白马城堡 — Boss战
        _platform(g, 6, ground - 2, 4);
        _coin(g, 7, ground - 3);
        _coin(g, 8, ground - 3);
        _put(g, 9, ground - 2, '?');
        _enemy(g, 18, ground);
        _gap(g, 24, 2);
        _platform(g, 30, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 31 + i, ground - 4);
        }
        _enemy(g, 40, ground);
        _put(g, 48, ground, 'S');
        _platform(g, 54, ground - 4, 3);
        _put(g, 55, ground - 4, 'M');
        _gap(g, 62, 3);
        _platform(g, 68, ground - 2, 4);
        _coin(g, 69, ground - 3);
        _coin(g, 70, ground - 3);
        _enemy(g, 78, ground);
        _platform(g, 86, ground - 3, 5);
        _put(g, 88, ground - 3, '?');
        _put(g, 96, ground, 'S');
        _platform(g, 102, ground - 4, 3);
        _put(g, 103, ground - 5, 'H');
    }
  }

  static void _worldMint(List<List<String>> g, int level) {
    final ground = g.length - 3;
    switch (level) {
      case 0: // 回声入口 — 前奏：迷雾缭绕，神秘入场
        _platform(g, 6, ground - 2, 4);
        _coin(g, 7, ground - 3);
        _coin(g, 8, ground - 3);
        _platform(g, 16, ground - 3, 3);
        _put(g, 17, ground - 3, '?');
        _platform(g, 28, ground - 1, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 29 + i, ground - 2);
        }
        _enemy(g, 38, ground);
        _platform(g, 46, ground - 2, 4);
        _coin(g, 47, ground - 3);
        _coin(g, 48, ground - 3);
        _platform(g, 58, ground - 3, 3);
        _coin(g, 59, ground - 4);
        _put(g, 66, ground, 'S');
        _platform(g, 74, ground - 2, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 75 + i, ground - 3);
        }
        _enemy(g, 84, ground);
        _platform(g, 92, ground - 1, 4);
        _coin(g, 93, ground - 2);
        _platform(g, 104, ground - 3, 3);
        _put(g, 105, ground - 3, '?');
        _platform(g, 116, ground - 2, 4);
        _coin(g, 117, ground - 3);
        _coin(g, 118, ground - 3);
        _platform(g, 130, ground - 1, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 131 + i, ground - 2);
        }
        _put(g, 140, ground, 'S');
        _platform(g, 148, ground - 3, 3);
        _coin(g, 149, ground - 4);
        _platform(g, 160, ground - 2, 4);
        _coin(g, 161, ground - 3);
      case 1: // 问号喷泉 — 主歌A：问号意象，谜箱多
        _platform(g, 6, ground - 1, 3);
        _put(g, 7, ground - 1, '?');
        _coin(g, 7, ground - 2);
        _platform(g, 16, ground - 3, 4);
        _put(g, 17, ground - 3, '?');
        _coin(g, 18, ground - 4);
        _enemy(g, 26, ground);
        _platform(g, 34, ground - 2, 5);
        _coin(g, 35, ground - 3);
        _coin(g, 36, ground - 3);
        _put(g, 37, ground - 2, '?');
        _gap(g, 44, 2);
        _platform(g, 50, ground - 3, 3);
        _put(g, 51, ground - 3, '?');
        _coin(g, 51, ground - 4);
        _put(g, 58, ground, 'S');
        _enemy(g, 66, ground);
        _platform(g, 72, ground - 2, 4);
        _coin(g, 73, ground - 3);
        _coin(g, 74, ground - 3);
        _put(g, 75, ground - 2, '?');
        _platform(g, 84, ground - 4, 3);
        _put(g, 85, ground - 4, 'M');
        _gap(g, 94, 2);
        _platform(g, 100, ground - 1, 5);
        _put(g, 102, ground - 1, '?');
        for (var i = 0; i < 3; i++) {
          _coin(g, 101 + i, ground - 2);
        }
        _enemy(g, 112, ground);
        _platform(g, 118, ground - 3, 4);
        _put(g, 119, ground - 3, '?');
        _coin(g, 120, ground - 4);
        _platform(g, 130, ground - 2, 3);
        _coin(g, 131, ground - 3);
        _put(g, 138, ground, 'S');
        _platform(g, 146, ground - 3, 4);
        _put(g, 148, ground - 4, 'H');
        _platform(g, 158, ground - 1, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 159 + i, ground - 2);
        }
        _enemy(g, 168, ground);
      case 2: // 迷雾滑道 — 副歌前奏：弹簧连跳
        _platform(g, 6, ground - 2, 3);
        _coin(g, 7, ground - 3);
        _put(g, 14, ground, 'S');
        _platform(g, 20, ground - 4, 4);
        _coin(g, 21, ground - 5);
        _coin(g, 22, ground - 5);
        _gap(g, 30, 2);
        _enemy(g, 36, ground);
        _platform(g, 42, ground - 3, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 43 + i, ground - 4);
        }
        _put(g, 46, ground - 3, '?');
        _put(g, 54, ground, 'S');
        _platform(g, 60, ground - 4, 3);
        _put(g, 61, ground - 4, 'M');
        _gap(g, 68, 3);
        _platform(g, 74, ground - 2, 4);
        _coin(g, 75, ground - 3);
        _coin(g, 76, ground - 3);
        _enemy(g, 84, ground);
        _put(g, 90, ground, 'S');
        _platform(g, 96, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 97 + i, ground - 4);
        }
        _gap(g, 106, 2);
        _platform(g, 112, ground - 4, 3);
        _put(g, 113, ground - 5, 'H');
        _put(g, 120, ground, 'S');
        _enemy(g, 128, ground);
        _platform(g, 134, ground - 2, 4);
        _coin(g, 135, ground - 3);
        _coin(g, 136, ground - 3);
        _gap(g, 144, 3);
        _platform(g, 150, ground - 3, 5);
        _put(g, 152, ground - 3, '?');
        _enemy(g, 160, ground);
        _platform(g, 166, ground - 1, 4);
        _coin(g, 167, ground - 2);
      case 3: // 影子气泡 — 副歌A：泡泡飘浮感，高低交错
        _platform(g, 6, ground - 3, 3);
        _coin(g, 7, ground - 4);
        _coin(g, 8, ground - 4);
        _platform(g, 14, ground - 1, 4);
        _coin(g, 15, ground - 2);
        _gap(g, 24, 2);
        _platform(g, 30, ground - 4, 3);
        _put(g, 31, ground - 4, '?');
        _coin(g, 31, ground - 5);
        _enemy(g, 38, ground);
        _platform(g, 44, ground - 2, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 45 + i, ground - 3);
        }
        _put(g, 52, ground, 'S');
        _platform(g, 58, ground - 4, 3);
        _put(g, 59, ground - 4, 'M');
        _gap(g, 66, 3);
        _platform(g, 72, ground - 1, 4);
        _coin(g, 73, ground - 2);
        _coin(g, 74, ground - 2);
        _enemy(g, 82, ground);
        _platform(g, 88, ground - 3, 5);
        _coin(g, 89, ground - 4);
        _coin(g, 90, ground - 4);
        _put(g, 91, ground - 3, '?');
        _gap(g, 98, 2);
        _platform(g, 104, ground - 4, 3);
        _put(g, 105, ground - 5, 'H');
        _put(g, 112, ground, 'S');
        _platform(g, 118, ground - 2, 4);
        _coin(g, 119, ground - 3);
        _coin(g, 120, ground - 3);
        _enemy(g, 128, ground);
        _gap(g, 134, 3);
        _platform(g, 140, ground - 3, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 140 + i, ground - 4);
        }
        _platform(g, 152, ground - 1, 3);
        _coin(g, 153, ground - 2);
        _enemy(g, 160, ground);
        _platform(g, 168, ground - 4, 3);
        _put(g, 169, ground - 4, 'M');
        _put(g, 176, ground, 'S');
        _platform(g, 182, ground - 2, 4);
        _coin(g, 183, ground - 3);
        _coin(g, 184, ground - 3);
      case 4: // 路灯跳台 — 间奏：路灯下独行，平稳探索
        _platform(g, 6, ground - 2, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 7 + i, ground - 3);
        }
        _put(g, 10, ground - 2, '?');
        _enemy(g, 18, ground);
        _platform(g, 26, ground - 3, 3);
        _coin(g, 27, ground - 4);
        _gap(g, 34, 2);
        _platform(g, 40, ground - 1, 4);
        _coin(g, 41, ground - 2);
        _coin(g, 42, ground - 2);
        _put(g, 48, ground, 'S');
        _platform(g, 54, ground - 4, 3);
        _put(g, 55, ground - 4, 'M');
        _enemy(g, 64, ground);
        _platform(g, 70, ground - 2, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 71 + i, ground - 3);
        }
        _gap(g, 80, 3);
        _platform(g, 86, ground - 3, 4);
        _put(g, 88, ground - 3, '?');
        _coin(g, 88, ground - 4);
        _enemy(g, 96, ground);
        _platform(g, 102, ground - 1, 5);
        _coin(g, 103, ground - 2);
        _coin(g, 104, ground - 2);
        _put(g, 112, ground, 'S');
        _platform(g, 118, ground - 4, 3);
        _put(g, 119, ground - 5, 'H');
        _gap(g, 128, 2);
        _platform(g, 134, ground - 2, 4);
        _coin(g, 135, ground - 3);
        _coin(g, 136, ground - 3);
        _enemy(g, 144, ground);
        _platform(g, 150, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 151 + i, ground - 4);
        }
        _put(g, 160, ground, 'S');
        _platform(g, 166, ground - 2, 3);
        _coin(g, 167, ground - 3);
        _gap(g, 176, 2);
        _platform(g, 182, ground - 3, 4);
        _put(g, 184, ground - 3, '?');
        _enemy(g, 192, ground);
        _platform(g, 200, ground - 1, 5);
        _coin(g, 201, ground - 2);
        _coin(g, 202, ground - 2);
      case 5: // 回眸峡谷 — 主歌B：回望意象，中等难度
        _platform(g, 6, ground - 1, 4);
        _coin(g, 7, ground - 2);
        _coin(g, 8, ground - 2);
        _platform(g, 16, ground - 3, 3);
        _put(g, 17, ground - 3, '?');
        _coin(g, 17, ground - 4);
        _enemy(g, 26, ground);
        _gap(g, 32, 3);
        _platform(g, 38, ground - 2, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 39 + i, ground - 3);
        }
        _put(g, 46, ground, 'S');
        _platform(g, 52, ground - 4, 3);
        _put(g, 53, ground - 4, 'M');
        _gap(g, 60, 2);
        _platform(g, 66, ground - 3, 4);
        _coin(g, 67, ground - 4);
        _coin(g, 68, ground - 4);
        _enemy(g, 76, ground);
        _platform(g, 82, ground - 1, 5);
        _put(g, 84, ground - 1, '?');
        _gap(g, 92, 3);
        _platform(g, 98, ground - 4, 3);
        _put(g, 99, ground - 5, 'H');
        _put(g, 106, ground, 'S');
        _platform(g, 112, ground - 2, 4);
        _coin(g, 113, ground - 3);
        _coin(g, 114, ground - 3);
        _enemy(g, 122, ground);
        _gap(g, 128, 2);
        _platform(g, 134, ground - 3, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 134 + i, ground - 4);
        }
        _platform(g, 146, ground - 1, 3);
        _coin(g, 147, ground - 2);
        _enemy(g, 156, ground);
        _put(g, 162, ground, 'S');
        _platform(g, 168, ground - 4, 3);
        _put(g, 169, ground - 4, 'M');
        _gap(g, 176, 3);
        _platform(g, 182, ground - 2, 4);
        _coin(g, 183, ground - 3);
        _coin(g, 184, ground - 3);
        _enemy(g, 194, ground);
        _platform(g, 200, ground - 3, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 201 + i, ground - 4);
        }
        _put(g, 210, ground, 'S');
        _platform(g, 218, ground - 2, 3);
        _coin(g, 219, ground - 3);
      case 6: // 空白隧道 — 副歌B：空旷中爆发
        _platform(g, 6, ground - 2, 5);
        _coin(g, 7, ground - 3);
        _coin(g, 8, ground - 3);
        _coin(g, 9, ground - 3);
        _gap(g, 16, 3);
        _enemy(g, 24, ground);
        _platform(g, 30, ground - 4, 3);
        _put(g, 31, ground - 4, '?');
        _coin(g, 31, ground - 5);
        _put(g, 38, ground, 'S');
        _platform(g, 44, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 45 + i, ground - 4);
        }
        _gap(g, 54, 2);
        _platform(g, 60, ground - 2, 4);
        _enemy(g, 68, ground);
        _put(g, 74, ground, 'S');
        _platform(g, 80, ground - 4, 3);
        _put(g, 81, ground - 4, 'M');
        _gap(g, 88, 3);
        _platform(g, 94, ground - 3, 5);
        _coin(g, 95, ground - 4);
        _coin(g, 96, ground - 4);
        _coin(g, 97, ground - 4);
        _put(g, 98, ground - 3, '?');
        _enemy(g, 106, ground);
        _platform(g, 112, ground - 1, 4);
        _coin(g, 113, ground - 2);
        _gap(g, 122, 2);
        _platform(g, 128, ground - 4, 3);
        _put(g, 129, ground - 5, 'H');
        _put(g, 136, ground, 'S');
        _platform(g, 142, ground - 2, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 143 + i, ground - 3);
        }
        _enemy(g, 152, ground);
        _gap(g, 158, 3);
        _platform(g, 164, ground - 3, 4);
        _coin(g, 165, ground - 4);
        _coin(g, 166, ground - 4);
        _put(g, 174, ground, 'S');
        _platform(g, 180, ground - 4, 3);
        _put(g, 181, ground - 4, 'M');
        _enemy(g, 190, ground);
        _platform(g, 196, ground - 2, 5);
        _put(g, 198, ground - 2, '?');
        _gap(g, 206, 2);
        _platform(g, 212, ground - 3, 4);
        _coin(g, 213, ground - 4);
        _coin(g, 214, ground - 4);
        _enemy(g, 224, ground);
        _platform(g, 232, ground - 1, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 232 + i, ground - 2);
        }
      case 7: // 疑问风暴 — 桥段：谜箱连串，高强度
        _platform(g, 6, ground - 3, 4);
        _put(g, 7, ground - 3, '?');
        _put(g, 9, ground - 3, '?');
        _coin(g, 8, ground - 4);
        _gap(g, 16, 2);
        _enemy(g, 22, ground);
        _platform(g, 28, ground - 2, 5);
        _put(g, 30, ground - 2, '?');
        _coin(g, 29, ground - 3);
        _coin(g, 31, ground - 3);
        _put(g, 38, ground, 'S');
        _platform(g, 44, ground - 4, 3);
        _put(g, 45, ground - 4, 'M');
        _gap(g, 52, 3);
        _platform(g, 58, ground - 3, 5);
        _put(g, 60, ground - 3, '?');
        for (var i = 0; i < 3; i++) {
          _coin(g, 59 + i, ground - 4);
        }
        _enemy(g, 68, ground);
        _platform(g, 74, ground - 1, 4);
        _put(g, 76, ground - 1, '?');
        _gap(g, 84, 2);
        _put(g, 90, ground, 'S');
        _platform(g, 96, ground - 4, 3);
        _put(g, 97, ground - 5, 'H');
        _enemy(g, 106, ground);
        _platform(g, 112, ground - 3, 5);
        _put(g, 114, ground - 3, '?');
        _coin(g, 113, ground - 4);
        _coin(g, 115, ground - 4);
        _gap(g, 122, 3);
        _platform(g, 128, ground - 2, 4);
        _coin(g, 129, ground - 3);
        _coin(g, 130, ground - 3);
        _put(g, 138, ground, 'S');
        _enemy(g, 146, ground);
        _platform(g, 152, ground - 4, 3);
        _put(g, 153, ground - 4, 'M');
        _gap(g, 160, 2);
        _platform(g, 166, ground - 3, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 166 + i, ground - 4);
        }
        _put(g, 170, ground - 3, '?');
        _enemy(g, 178, ground);
        _platform(g, 184, ground - 1, 4);
        _put(g, 186, ground - 1, '?');
        _gap(g, 194, 3);
        _platform(g, 200, ground - 2, 5);
        _coin(g, 201, ground - 3);
        _coin(g, 202, ground - 3);
        _put(g, 210, ground, 'S');
        _platform(g, 216, ground - 4, 3);
        _put(g, 217, ground - 5, 'H');
        _enemy(g, 226, ground);
        _platform(g, 234, ground - 3, 4);
        _put(g, 236, ground - 3, '?');
        _coin(g, 236, ground - 4);
        _platform(g, 248, ground - 2, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 249 + i, ground - 3);
        }
      case 8: // 倒影平台 — 副歌C：对称布局
        _platform(g, 6, ground - 2, 4);
        _coin(g, 7, ground - 3);
        _coin(g, 8, ground - 3);
        _platform(g, 16, ground - 3, 3);
        _coin(g, 17, ground - 4);
        _gap(g, 24, 3);
        _enemy(g, 32, ground);
        _platform(g, 38, ground - 2, 5);
        _put(g, 40, ground - 2, '?');
        for (var i = 0; i < 4; i++) {
          _coin(g, 39 + i, ground - 3);
        }
        _put(g, 48, ground, 'S');
        _platform(g, 54, ground - 4, 3);
        _put(g, 55, ground - 4, 'M');
        _gap(g, 62, 2);
        _platform(g, 68, ground - 3, 4);
        _coin(g, 69, ground - 4);
        _coin(g, 70, ground - 4);
        _enemy(g, 78, ground);
        _platform(g, 84, ground - 1, 5);
        _coin(g, 85, ground - 2);
        _coin(g, 86, ground - 2);
        _gap(g, 94, 3);
        _put(g, 102, ground, 'S');
        _platform(g, 108, ground - 4, 3);
        _put(g, 109, ground - 5, 'H');
        _enemy(g, 118, ground);
        _platform(g, 124, ground - 2, 4);
        _put(g, 126, ground - 2, '?');
        _gap(g, 134, 2);
        _platform(g, 140, ground - 3, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 140 + i, ground - 4);
        }
        _enemy(g, 150, ground);
        _put(g, 158, ground, 'S');
        _platform(g, 164, ground - 4, 3);
        _put(g, 165, ground - 4, 'M');
        _gap(g, 172, 3);
        _platform(g, 178, ground - 2, 4);
        _coin(g, 179, ground - 3);
        _coin(g, 180, ground - 3);
        _enemy(g, 188, ground);
        _platform(g, 196, ground - 3, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 197 + i, ground - 4);
        }
        _put(g, 200, ground - 3, '?');
        _gap(g, 208, 2);
        _platform(g, 214, ground - 1, 4);
        _coin(g, 215, ground - 2);
        _enemy(g, 224, ground);
        _put(g, 232, ground, 'S');
        _platform(g, 238, ground - 3, 4);
        _coin(g, 239, ground - 4);
        _coin(g, 240, ground - 4);
        _platform(g, 252, ground - 2, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 253 + i, ground - 3);
        }
        _enemy(g, 264, ground);
      case 9: // 无名高塔 — 高潮：最强挑战
        _platform(g, 6, ground - 3, 4);
        for (var i = 0; i < 3; i++) {
          _coin(g, 7 + i, ground - 4);
        }
        _put(g, 6, ground - 3, '?');
        _gap(g, 14, 3);
        _enemy(g, 22, ground);
        _put(g, 28, ground, 'S');
        _platform(g, 34, ground - 4, 3);
        _put(g, 35, ground - 4, 'M');
        _coin(g, 35, ground - 5);
        _gap(g, 42, 2);
        _platform(g, 48, ground - 3, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 48 + i, ground - 4);
        }
        _enemy(g, 58, ground);
        _gap(g, 64, 3);
        _platform(g, 70, ground - 2, 4);
        _put(g, 72, ground - 2, '?');
        _put(g, 80, ground, 'S');
        _enemy(g, 88, ground);
        _platform(g, 94, ground - 4, 3);
        _put(g, 95, ground - 5, 'H');
        _gap(g, 102, 3);
        _platform(g, 108, ground - 3, 5);
        _coin(g, 109, ground - 4);
        _coin(g, 110, ground - 4);
        _coin(g, 111, ground - 4);
        _put(g, 112, ground - 3, '?');
        _enemy(g, 120, ground);
        _gap(g, 126, 2);
        _put(g, 134, ground, 'S');
        _platform(g, 140, ground - 4, 3);
        _put(g, 141, ground - 4, 'M');
        _enemy(g, 150, ground);
        _gap(g, 156, 3);
        _platform(g, 162, ground - 3, 4);
        for (var i = 0; i < 4; i++) {
          _coin(g, 162 + i, ground - 4);
        }
        _platform(g, 174, ground - 2, 5);
        _put(g, 176, ground - 2, '?');
        _enemy(g, 184, ground);
        _put(g, 190, ground, 'S');
        _gap(g, 196, 2);
        _platform(g, 202, ground - 4, 3);
        _coin(g, 203, ground - 5);
        _coin(g, 204, ground - 5);
        _enemy(g, 214, ground);
        _platform(g, 220, ground - 3, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 220 + i, ground - 4);
        }
        _gap(g, 230, 3);
        _platform(g, 236, ground - 2, 4);
        _put(g, 238, ground - 3, 'H');
        _enemy(g, 246, ground);
        _put(g, 254, ground, 'S');
        _platform(g, 260, ground - 4, 3);
        _put(g, 261, ground - 4, 'M');
        _gap(g, 268, 2);
        _platform(g, 274, ground - 3, 5);
        _coin(g, 275, ground - 4);
        _coin(g, 276, ground - 4);
        _enemy(g, 286, ground);
      case 10: // 答案之心 — Boss战
        _platform(g, 6, ground - 2, 4);
        _coin(g, 7, ground - 3);
        _coin(g, 8, ground - 3);
        _put(g, 9, ground - 2, '?');
        _enemy(g, 18, ground);
        _platform(g, 26, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 27 + i, ground - 4);
        }
        _gap(g, 36, 2);
        _enemy(g, 44, ground);
        _put(g, 50, ground, 'S');
        _platform(g, 56, ground - 4, 3);
        _put(g, 57, ground - 4, 'M');
        _platform(g, 66, ground - 2, 4);
        _coin(g, 67, ground - 3);
        _coin(g, 68, ground - 3);
        _gap(g, 76, 3);
        _enemy(g, 84, ground);
        _platform(g, 90, ground - 3, 5);
        _put(g, 92, ground - 3, '?');
        _put(g, 100, ground, 'S');
        _platform(g, 106, ground - 4, 3);
        _put(g, 107, ground - 5, 'H');
    }
  }

  static void _worldTaroStar(List<List<String>> g, int level) {
    final ground = g.length - 3;
    switch (level) {
      case 0: // 静夜星门 — 前奏：寂静入夜，星光点缀
        _platform(g, 6, ground - 1, 4);
        _coin(g, 7, ground - 2);
        _coin(g, 8, ground - 2);
        _platform(g, 18, ground - 2, 3);
        _put(g, 19, ground - 2, '?');
        _coin(g, 19, ground - 3);
        _platform(g, 30, ground - 3, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 31 + i, ground - 4);
        }
        _enemy(g, 42, ground);
        _platform(g, 50, ground - 1, 4);
        _coin(g, 51, ground - 2);
        _coin(g, 52, ground - 2);
        _platform(g, 64, ground - 2, 3);
        _coin(g, 65, ground - 3);
        _put(g, 74, ground, 'S');
        _platform(g, 82, ground - 3, 4);
        _coin(g, 83, ground - 4);
        _coin(g, 84, ground - 4);
        _put(g, 85, ground - 3, '?');
        _enemy(g, 96, ground);
        _platform(g, 104, ground - 2, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 105 + i, ground - 3);
        }
        _platform(g, 118, ground - 1, 3);
        _coin(g, 119, ground - 2);
        _platform(g, 130, ground - 3, 4);
        _coin(g, 131, ground - 4);
        _put(g, 140, ground, 'S');
        _platform(g, 148, ground - 2, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 149 + i, ground - 3);
        }
        _platform(g, 164, ground - 1, 4);
        _coin(g, 165, ground - 2);
        _coin(g, 166, ground - 2);
        _enemy(g, 176, ground);
        _platform(g, 184, ground - 3, 3);
        _coin(g, 185, ground - 4);
      case 1: // 轻声台阶 — 主歌A：轻声细语般
        _platform(g, 6, ground - 2, 3);
        _coin(g, 7, ground - 3);
        _platform(g, 16, ground - 3, 4);
        _put(g, 17, ground - 3, '?');
        _coin(g, 18, ground - 4);
        _enemy(g, 28, ground);
        _gap(g, 34, 2);
        _platform(g, 40, ground - 1, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 41 + i, ground - 2);
        }
        _platform(g, 52, ground - 2, 3);
        _coin(g, 53, ground - 3);
        _put(g, 60, ground, 'S');
        _platform(g, 68, ground - 3, 4);
        _coin(g, 69, ground - 4);
        _coin(g, 70, ground - 4);
        _enemy(g, 80, ground);
        _gap(g, 86, 2);
        _platform(g, 92, ground - 2, 5);
        _put(g, 94, ground - 2, '?');
        for (var i = 0; i < 4; i++) {
          _coin(g, 93 + i, ground - 3);
        }
        _platform(g, 106, ground - 4, 3);
        _put(g, 107, ground - 4, 'M');
        _enemy(g, 116, ground);
        _platform(g, 124, ground - 1, 4);
        _coin(g, 125, ground - 2);
        _coin(g, 126, ground - 2);
        _gap(g, 134, 2);
        _platform(g, 140, ground - 3, 3);
        _coin(g, 141, ground - 4);
        _put(g, 148, ground, 'S');
        _platform(g, 156, ground - 2, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 157 + i, ground - 3);
        }
        _enemy(g, 166, ground);
        _platform(g, 174, ground - 3, 4);
        _put(g, 176, ground - 4, 'H');
        _platform(g, 188, ground - 1, 5);
        _coin(g, 189, ground - 2);
        _coin(g, 190, ground - 2);
      case 2: // 屏息浮岛 — 副歌前奏：浮岛感，弹簧路线
        _platform(g, 6, ground - 2, 4);
        _coin(g, 7, ground - 3);
        _coin(g, 8, ground - 3);
        _put(g, 14, ground, 'S');
        _platform(g, 20, ground - 4, 3);
        _coin(g, 21, ground - 5);
        _coin(g, 22, ground - 5);
        _gap(g, 30, 2);
        _enemy(g, 36, ground);
        _platform(g, 42, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 43 + i, ground - 4);
        }
        _put(g, 46, ground - 3, '?');
        _put(g, 54, ground, 'S');
        _platform(g, 60, ground - 4, 3);
        _put(g, 61, ground - 4, 'M');
        _gap(g, 68, 3);
        _platform(g, 74, ground - 2, 4);
        _coin(g, 75, ground - 3);
        _coin(g, 76, ground - 3);
        _enemy(g, 84, ground);
        _put(g, 90, ground, 'S');
        _platform(g, 96, ground - 3, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 97 + i, ground - 4);
        }
        _gap(g, 106, 2);
        _platform(g, 112, ground - 4, 3);
        _put(g, 113, ground - 5, 'H');
        _put(g, 120, ground, 'S');
        _enemy(g, 128, ground);
        _platform(g, 134, ground - 2, 4);
        _coin(g, 135, ground - 3);
        _coin(g, 136, ground - 3);
        _gap(g, 144, 3);
        _platform(g, 150, ground - 3, 5);
        _put(g, 152, ground - 3, '?');
        _coin(g, 153, ground - 4);
        _enemy(g, 162, ground);
        _put(g, 168, ground, 'S');
        _platform(g, 174, ground - 4, 3);
        _put(g, 175, ground - 4, 'M');
        _platform(g, 186, ground - 1, 4);
        _coin(g, 187, ground - 2);
        _coin(g, 188, ground - 2);
        _gap(g, 196, 2);
        _platform(g, 202, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 203 + i, ground - 4);
        }
      case 3: // 月影断桥 — 副歌A：月夜断桥，跳跃密集
        _platform(g, 6, ground - 3, 3);
        _coin(g, 7, ground - 4);
        _coin(g, 8, ground - 4);
        _gap(g, 14, 3);
        _platform(g, 20, ground - 2, 4);
        _coin(g, 21, ground - 3);
        _put(g, 22, ground - 2, '?');
        _enemy(g, 30, ground);
        _gap(g, 36, 2);
        _platform(g, 42, ground - 4, 3);
        _put(g, 43, ground - 4, 'M');
        _put(g, 50, ground, 'S');
        _platform(g, 56, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 57 + i, ground - 4);
        }
        _gap(g, 66, 3);
        _enemy(g, 74, ground);
        _platform(g, 80, ground - 2, 4);
        _coin(g, 81, ground - 3);
        _coin(g, 82, ground - 3);
        _gap(g, 90, 2);
        _platform(g, 96, ground - 3, 3);
        _put(g, 97, ground - 3, '?');
        _put(g, 104, ground, 'S');
        _platform(g, 110, ground - 4, 3);
        _put(g, 111, ground - 5, 'H');
        _enemy(g, 120, ground);
        _gap(g, 126, 3);
        _platform(g, 132, ground - 2, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 132 + i, ground - 3);
        }
        _gap(g, 142, 2);
        _platform(g, 148, ground - 3, 4);
        _put(g, 150, ground - 3, '?');
        _enemy(g, 158, ground);
        _put(g, 164, ground, 'S');
        _gap(g, 170, 3);
        _platform(g, 176, ground - 4, 3);
        _put(g, 177, ground - 4, 'M');
        _platform(g, 188, ground - 2, 4);
        _coin(g, 189, ground - 3);
        _coin(g, 190, ground - 3);
        _enemy(g, 200, ground);
        _gap(g, 206, 2);
        _platform(g, 212, ground - 3, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 213 + i, ground - 4);
        }
      case 4: // 萤火平台 — 间奏：萤火虫点缀，舒缓
        _platform(g, 6, ground - 1, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 7 + i, ground - 2);
        }
        _platform(g, 18, ground - 3, 3);
        _put(g, 19, ground - 3, '?');
        _enemy(g, 28, ground);
        _gap(g, 34, 2);
        _platform(g, 40, ground - 2, 4);
        _coin(g, 41, ground - 3);
        _coin(g, 42, ground - 3);
        _put(g, 50, ground, 'S');
        _platform(g, 56, ground - 4, 3);
        _put(g, 57, ground - 4, 'M');
        _platform(g, 66, ground - 1, 5);
        _coin(g, 67, ground - 2);
        _coin(g, 68, ground - 2);
        _enemy(g, 78, ground);
        _gap(g, 84, 3);
        _platform(g, 90, ground - 3, 4);
        _coin(g, 91, ground - 4);
        _coin(g, 92, ground - 4);
        _put(g, 93, ground - 3, '?');
        _put(g, 102, ground, 'S');
        _platform(g, 108, ground - 4, 3);
        _put(g, 109, ground - 5, 'H');
        _enemy(g, 118, ground);
        _platform(g, 124, ground - 2, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 125 + i, ground - 3);
        }
        _gap(g, 134, 2);
        _platform(g, 140, ground - 3, 3);
        _coin(g, 141, ground - 4);
        _enemy(g, 150, ground);
        _put(g, 158, ground, 'S');
        _platform(g, 164, ground - 2, 4);
        _coin(g, 165, ground - 3);
        _coin(g, 166, ground - 3);
        _platform(g, 178, ground - 4, 3);
        _put(g, 179, ground - 4, 'M');
        _gap(g, 188, 3);
        _platform(g, 194, ground - 1, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 195 + i, ground - 2);
        }
        _enemy(g, 206, ground);
        _platform(g, 214, ground - 3, 4);
        _coin(g, 215, ground - 4);
        _coin(g, 216, ground - 4);
      case 5: // 无声回廊 — 主歌B：安静走廊
        _platform(g, 6, ground - 2, 4);
        _coin(g, 7, ground - 3);
        _coin(g, 8, ground - 3);
        _put(g, 9, ground - 2, '?');
        _enemy(g, 18, ground);
        _platform(g, 26, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 27 + i, ground - 4);
        }
        _gap(g, 36, 2);
        _platform(g, 42, ground - 1, 3);
        _coin(g, 43, ground - 2);
        _put(g, 50, ground, 'S');
        _platform(g, 56, ground - 4, 3);
        _put(g, 57, ground - 4, 'M');
        _enemy(g, 66, ground);
        _gap(g, 72, 3);
        _platform(g, 78, ground - 2, 4);
        _coin(g, 79, ground - 3);
        _coin(g, 80, ground - 3);
        _platform(g, 90, ground - 3, 5);
        _put(g, 92, ground - 3, '?');
        for (var i = 0; i < 3; i++) {
          _coin(g, 91 + i, ground - 4);
        }
        _put(g, 100, ground, 'S');
        _platform(g, 106, ground - 4, 3);
        _put(g, 107, ground - 5, 'H');
        _enemy(g, 116, ground);
        _gap(g, 122, 2);
        _platform(g, 128, ground - 2, 5);
        _coin(g, 129, ground - 3);
        _coin(g, 130, ground - 3);
        _platform(g, 142, ground - 3, 3);
        _put(g, 143, ground - 3, '?');
        _enemy(g, 152, ground);
        _put(g, 158, ground, 'S');
        _gap(g, 166, 3);
        _platform(g, 172, ground - 4, 3);
        _put(g, 173, ground - 4, 'M');
        _platform(g, 184, ground - 1, 4);
        _coin(g, 185, ground - 2);
        _coin(g, 186, ground - 2);
        _enemy(g, 196, ground);
        _platform(g, 204, ground - 2, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 205 + i, ground - 3);
        }
        _gap(g, 216, 2);
        _platform(g, 222, ground - 3, 4);
        _coin(g, 223, ground - 4);
      case 6: // 流星滑道 — 副歌B：流星意象，快节奏
        _platform(g, 6, ground - 3, 4);
        for (var i = 0; i < 3; i++) {
          _coin(g, 7 + i, ground - 4);
        }
        _put(g, 6, ground - 3, '?');
        _gap(g, 16, 3);
        _enemy(g, 24, ground);
        _put(g, 30, ground, 'S');
        _platform(g, 36, ground - 4, 3);
        _put(g, 37, ground - 4, 'M');
        _gap(g, 44, 2);
        _platform(g, 50, ground - 2, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 51 + i, ground - 3);
        }
        _enemy(g, 60, ground);
        _put(g, 66, ground, 'S');
        _platform(g, 72, ground - 3, 4);
        _coin(g, 73, ground - 4);
        _coin(g, 74, ground - 4);
        _put(g, 75, ground - 3, '?');
        _gap(g, 82, 3);
        _platform(g, 88, ground - 4, 3);
        _put(g, 89, ground - 5, 'H');
        _enemy(g, 98, ground);
        _put(g, 104, ground, 'S');
        _platform(g, 110, ground - 2, 5);
        _coin(g, 111, ground - 3);
        _coin(g, 112, ground - 3);
        _coin(g, 113, ground - 3);
        _gap(g, 120, 2);
        _platform(g, 126, ground - 3, 4);
        _put(g, 128, ground - 3, '?');
        _enemy(g, 136, ground);
        _put(g, 142, ground, 'S');
        _platform(g, 148, ground - 4, 3);
        _put(g, 149, ground - 4, 'M');
        _gap(g, 156, 3);
        _platform(g, 162, ground - 2, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 162 + i, ground - 3);
        }
        _enemy(g, 172, ground);
        _platform(g, 178, ground - 3, 3);
        _coin(g, 179, ground - 4);
        _gap(g, 186, 2);
        _put(g, 194, ground, 'S');
        _platform(g, 200, ground - 4, 3);
        _coin(g, 201, ground - 5);
        _coin(g, 202, ground - 5);
        _enemy(g, 212, ground);
        _platform(g, 218, ground - 1, 4);
        _put(g, 220, ground - 1, '?');
        _platform(g, 232, ground - 2, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 233 + i, ground - 3);
        }
      case 7: // 安眠高台 — 桥段：安眠意象，高台俯瞰
        _platform(g, 6, ground - 2, 5);
        _coin(g, 7, ground - 3);
        _coin(g, 8, ground - 3);
        _coin(g, 9, ground - 3);
        _put(g, 10, ground - 2, '?');
        _gap(g, 18, 2);
        _enemy(g, 26, ground);
        _platform(g, 32, ground - 4, 3);
        _put(g, 33, ground - 4, 'M');
        _put(g, 40, ground, 'S');
        _platform(g, 46, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 47 + i, ground - 4);
        }
        _gap(g, 56, 3);
        _platform(g, 62, ground - 2, 4);
        _enemy(g, 70, ground);
        _platform(g, 76, ground - 3, 3);
        _put(g, 77, ground - 3, '?');
        _coin(g, 77, ground - 4);
        _put(g, 84, ground, 'S');
        _platform(g, 90, ground - 4, 3);
        _put(g, 91, ground - 5, 'H');
        _gap(g, 98, 2);
        _enemy(g, 106, ground);
        _platform(g, 112, ground - 2, 5);
        _coin(g, 113, ground - 3);
        _coin(g, 114, ground - 3);
        _platform(g, 124, ground - 3, 4);
        _put(g, 126, ground - 3, '?');
        _put(g, 134, ground, 'S');
        _gap(g, 140, 3);
        _platform(g, 146, ground - 4, 3);
        _put(g, 147, ground - 4, 'M');
        _enemy(g, 156, ground);
        _platform(g, 162, ground - 1, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 163 + i, ground - 2);
        }
        _gap(g, 174, 2);
        _platform(g, 180, ground - 3, 4);
        _coin(g, 181, ground - 4);
        _coin(g, 182, ground - 4);
        _enemy(g, 192, ground);
        _put(g, 198, ground, 'S');
        _platform(g, 204, ground - 4, 3);
        _coin(g, 205, ground - 5);
        _platform(g, 216, ground - 2, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 217 + i, ground - 3);
        }
        _gap(g, 228, 3);
        _enemy(g, 236, ground);
        _platform(g, 244, ground - 3, 4);
        _put(g, 246, ground - 4, 'H');
        _platform(g, 258, ground - 1, 5);
        _coin(g, 259, ground - 2);
        _coin(g, 260, ground - 2);
      case 8: // 耳语之桥 — 副歌C：耳语般强度
        _platform(g, 6, ground - 3, 4);
        _coin(g, 7, ground - 4);
        _coin(g, 8, ground - 4);
        _put(g, 9, ground - 3, '?');
        _gap(g, 16, 3);
        _enemy(g, 24, ground);
        _put(g, 30, ground, 'S');
        _platform(g, 36, ground - 4, 3);
        _put(g, 37, ground - 4, 'M');
        _platform(g, 46, ground - 2, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 47 + i, ground - 3);
        }
        _gap(g, 56, 2);
        _enemy(g, 64, ground);
        _platform(g, 70, ground - 3, 4);
        _coin(g, 71, ground - 4);
        _coin(g, 72, ground - 4);
        _put(g, 80, ground, 'S');
        _platform(g, 86, ground - 4, 3);
        _put(g, 87, ground - 5, 'H');
        _gap(g, 94, 3);
        _platform(g, 100, ground - 2, 5);
        _put(g, 102, ground - 2, '?');
        _coin(g, 103, ground - 3);
        _enemy(g, 112, ground);
        _put(g, 118, ground, 'S');
        _platform(g, 124, ground - 3, 4);
        for (var i = 0; i < 4; i++) {
          _coin(g, 124 + i, ground - 4);
        }
        _gap(g, 134, 2);
        _platform(g, 140, ground - 4, 3);
        _put(g, 141, ground - 4, 'M');
        _enemy(g, 150, ground);
        _platform(g, 156, ground - 1, 5);
        _coin(g, 157, ground - 2);
        _coin(g, 158, ground - 2);
        _gap(g, 168, 3);
        _put(g, 176, ground, 'S');
        _platform(g, 182, ground - 3, 4);
        _coin(g, 183, ground - 4);
        _coin(g, 184, ground - 4);
        _put(g, 185, ground - 3, '?');
        _enemy(g, 194, ground);
        _platform(g, 200, ground - 2, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 201 + i, ground - 3);
        }
        _gap(g, 212, 2);
        _put(g, 220, ground, 'S');
        _platform(g, 226, ground - 4, 3);
        _put(g, 227, ground - 5, 'H');
        _enemy(g, 236, ground);
        _platform(g, 242, ground - 2, 4);
        _coin(g, 243, ground - 3);
        _coin(g, 244, ground - 3);
        _gap(g, 254, 3);
        _platform(g, 260, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 261 + i, ground - 4);
        }
      case 9: // 星尘之巅 — 高潮
        _platform(g, 6, ground - 3, 4);
        for (var i = 0; i < 3; i++) {
          _coin(g, 7 + i, ground - 4);
        }
        _put(g, 6, ground - 3, '?');
        _gap(g, 14, 3);
        _enemy(g, 22, ground);
        _put(g, 28, ground, 'S');
        _platform(g, 34, ground - 4, 3);
        _put(g, 35, ground - 4, 'M');
        _gap(g, 42, 2);
        _platform(g, 48, ground - 3, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 48 + i, ground - 4);
        }
        _enemy(g, 58, ground);
        _gap(g, 64, 3);
        _platform(g, 70, ground - 2, 4);
        _put(g, 72, ground - 2, '?');
        _put(g, 80, ground, 'S');
        _platform(g, 86, ground - 4, 3);
        _put(g, 87, ground - 5, 'H');
        _enemy(g, 96, ground);
        _gap(g, 102, 2);
        _platform(g, 108, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 109 + i, ground - 4);
        }
        _put(g, 112, ground - 3, '?');
        _enemy(g, 120, ground);
        _put(g, 126, ground, 'S');
        _gap(g, 132, 3);
        _platform(g, 138, ground - 4, 3);
        _put(g, 139, ground - 4, 'M');
        _platform(g, 150, ground - 2, 4);
        _coin(g, 151, ground - 3);
        _coin(g, 152, ground - 3);
        _enemy(g, 160, ground);
        _gap(g, 166, 2);
        _platform(g, 172, ground - 3, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 172 + i, ground - 4);
        }
        _put(g, 182, ground, 'S');
        _enemy(g, 190, ground);
        _platform(g, 196, ground - 4, 3);
        _put(g, 197, ground - 5, 'H');
        _gap(g, 204, 3);
        _platform(g, 210, ground - 2, 4);
        _put(g, 212, ground - 2, '?');
        _enemy(g, 222, ground);
        _put(g, 228, ground, 'S');
        _platform(g, 234, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 235 + i, ground - 4);
        }
        _gap(g, 244, 2);
        _platform(g, 250, ground - 4, 3);
        _put(g, 251, ground - 4, 'M');
        _enemy(g, 260, ground);
        _platform(g, 266, ground - 2, 5);
        _coin(g, 267, ground - 3);
        _coin(g, 268, ground - 3);
        _gap(g, 278, 3);
        _platform(g, 284, ground - 3, 4);
        for (var i = 0; i < 3; i++) {
          _coin(g, 285 + i, ground - 4);
        }
      case 10: // 静夜王座 — Boss战
        _platform(g, 6, ground - 2, 4);
        _coin(g, 7, ground - 3);
        _coin(g, 8, ground - 3);
        _put(g, 9, ground - 2, '?');
        _enemy(g, 18, ground);
        _gap(g, 24, 2);
        _platform(g, 30, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 31 + i, ground - 4);
        }
        _enemy(g, 42, ground);
        _put(g, 48, ground, 'S');
        _platform(g, 54, ground - 4, 3);
        _put(g, 55, ground - 4, 'M');
        _gap(g, 62, 3);
        _platform(g, 68, ground - 2, 4);
        _coin(g, 69, ground - 3);
        _coin(g, 70, ground - 3);
        _enemy(g, 80, ground);
        _platform(g, 86, ground - 3, 5);
        _put(g, 88, ground - 3, '?');
        _put(g, 96, ground, 'S');
        _platform(g, 102, ground - 4, 3);
        _put(g, 103, ground - 5, 'H');
    }
  }

  static void _worldLemonBeach(List<List<String>> g, int level) {
    final ground = g.length - 3;
    switch (level) {
      case 0: // 破晓海岸 — 前奏：黎明海边，温暖起步
        _platform(g, 6, ground - 1, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 7 + i, ground - 2);
        }
        _platform(g, 18, ground - 2, 3);
        _put(g, 19, ground - 2, '?');
        _platform(g, 30, ground - 1, 4);
        _coin(g, 31, ground - 2);
        _coin(g, 32, ground - 2);
        _enemy(g, 42, ground);
        _platform(g, 50, ground - 3, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 51 + i, ground - 4);
        }
        _platform(g, 64, ground - 1, 4);
        _coin(g, 65, ground - 2);
        _coin(g, 66, ground - 2);
        _put(g, 74, ground, 'S');
        _platform(g, 82, ground - 2, 3);
        _coin(g, 83, ground - 3);
        _enemy(g, 92, ground);
        _platform(g, 100, ground - 3, 5);
        _put(g, 102, ground - 3, '?');
        for (var i = 0; i < 4; i++) {
          _coin(g, 101 + i, ground - 4);
        }
        _platform(g, 114, ground - 1, 4);
        _coin(g, 115, ground - 2);
        _platform(g, 128, ground - 2, 3);
        _coin(g, 129, ground - 3);
        _coin(g, 130, ground - 3);
        _enemy(g, 140, ground);
        _platform(g, 148, ground - 3, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 149 + i, ground - 4);
        }
        _put(g, 160, ground, 'S');
        _platform(g, 168, ground - 2, 4);
        _coin(g, 169, ground - 3);
        _coin(g, 170, ground - 3);
        _platform(g, 182, ground - 1, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 183 + i, ground - 2);
        }
        _enemy(g, 196, ground);
        _platform(g, 204, ground - 3, 3);
        _coin(g, 205, ground - 4);
        _platform(g, 218, ground - 2, 4);
        _coin(g, 219, ground - 3);
        _coin(g, 220, ground - 3);
      case 1: // 闹钟弹跳 — 主歌A：闹钟打破宁静
        _platform(g, 6, ground - 2, 4);
        _coin(g, 7, ground - 3);
        _coin(g, 8, ground - 3);
        _put(g, 14, ground, 'S');
        _platform(g, 20, ground - 3, 3);
        _put(g, 21, ground - 3, '?');
        _coin(g, 21, ground - 4);
        _enemy(g, 30, ground);
        _gap(g, 36, 2);
        _platform(g, 42, ground - 2, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 43 + i, ground - 3);
        }
        _put(g, 52, ground, 'S');
        _platform(g, 58, ground - 4, 3);
        _put(g, 59, ground - 4, 'M');
        _enemy(g, 68, ground);
        _platform(g, 74, ground - 1, 4);
        _coin(g, 75, ground - 2);
        _coin(g, 76, ground - 2);
        _gap(g, 84, 2);
        _put(g, 92, ground, 'S');
        _platform(g, 98, ground - 3, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 99 + i, ground - 4);
        }
        _put(g, 102, ground - 3, '?');
        _enemy(g, 112, ground);
        _platform(g, 118, ground - 2, 4);
        _coin(g, 119, ground - 3);
        _gap(g, 128, 3);
        _platform(g, 134, ground - 4, 3);
        _put(g, 135, ground - 5, 'H');
        _put(g, 142, ground, 'S');
        _platform(g, 148, ground - 2, 5);
        _coin(g, 149, ground - 3);
        _coin(g, 150, ground - 3);
        _enemy(g, 160, ground);
        _platform(g, 168, ground - 3, 3);
        _coin(g, 169, ground - 4);
        _gap(g, 178, 2);
        _put(g, 184, ground, 'S');
        _platform(g, 190, ground - 4, 3);
        _put(g, 191, ground - 4, 'M');
        _platform(g, 202, ground - 1, 4);
        _coin(g, 203, ground - 2);
        _coin(g, 204, ground - 2);
        _enemy(g, 216, ground);
        _platform(g, 224, ground - 2, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 225 + i, ground - 3);
        }
      case 2: // 晨潮平台 — 副歌前奏：潮水涌来
        _platform(g, 6, ground - 1, 4);
        _coin(g, 7, ground - 2);
        _coin(g, 8, ground - 2);
        _gap(g, 14, 2);
        _platform(g, 20, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 21 + i, ground - 4);
        }
        _put(g, 24, ground - 3, '?');
        _enemy(g, 32, ground);
        _put(g, 38, ground, 'S');
        _platform(g, 44, ground - 4, 3);
        _put(g, 45, ground - 4, 'M');
        _gap(g, 52, 3);
        _platform(g, 58, ground - 2, 4);
        _coin(g, 59, ground - 3);
        _coin(g, 60, ground - 3);
        _enemy(g, 68, ground);
        _platform(g, 74, ground - 3, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 75 + i, ground - 4);
        }
        _gap(g, 84, 2);
        _put(g, 92, ground, 'S');
        _platform(g, 98, ground - 4, 3);
        _put(g, 99, ground - 5, 'H');
        _enemy(g, 108, ground);
        _platform(g, 114, ground - 1, 4);
        _put(g, 116, ground - 1, '?');
        _gap(g, 124, 3);
        _platform(g, 130, ground - 2, 5);
        _coin(g, 131, ground - 3);
        _coin(g, 132, ground - 3);
        _put(g, 140, ground, 'S');
        _platform(g, 146, ground - 3, 4);
        _coin(g, 147, ground - 4);
        _coin(g, 148, ground - 4);
        _enemy(g, 156, ground);
        _gap(g, 164, 2);
        _platform(g, 170, ground - 4, 3);
        _put(g, 171, ground - 4, 'M');
        _platform(g, 182, ground - 2, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 183 + i, ground - 3);
        }
        _enemy(g, 194, ground);
        _platform(g, 202, ground - 1, 4);
        _coin(g, 203, ground - 2);
        _gap(g, 212, 3);
        _put(g, 220, ground, 'S');
        _platform(g, 226, ground - 3, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 227 + i, ground - 4);
        }
      case 3: // 日出跳台 — 副歌A：日出能量爆发
        _platform(g, 6, ground - 3, 4);
        for (var i = 0; i < 3; i++) {
          _coin(g, 7 + i, ground - 4);
        }
        _put(g, 6, ground - 3, '?');
        _gap(g, 16, 3);
        _enemy(g, 24, ground);
        _platform(g, 30, ground - 2, 5);
        _coin(g, 31, ground - 3);
        _coin(g, 32, ground - 3);
        _put(g, 40, ground, 'S');
        _platform(g, 46, ground - 4, 3);
        _put(g, 47, ground - 4, 'M');
        _gap(g, 54, 2);
        _platform(g, 60, ground - 3, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 60 + i, ground - 4);
        }
        _enemy(g, 72, ground);
        _gap(g, 78, 3);
        _platform(g, 84, ground - 2, 4);
        _put(g, 86, ground - 2, '?');
        _put(g, 94, ground, 'S');
        _platform(g, 100, ground - 4, 3);
        _put(g, 101, ground - 5, 'H');
        _enemy(g, 110, ground);
        _gap(g, 116, 2);
        _platform(g, 122, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 123 + i, ground - 4);
        }
        _platform(g, 134, ground - 1, 4);
        _coin(g, 135, ground - 2);
        _gap(g, 144, 3);
        _enemy(g, 152, ground);
        _put(g, 158, ground, 'S');
        _platform(g, 164, ground - 4, 3);
        _put(g, 165, ground - 4, 'M');
        _platform(g, 176, ground - 2, 5);
        _coin(g, 177, ground - 3);
        _coin(g, 178, ground - 3);
        _gap(g, 188, 2);
        _enemy(g, 196, ground);
        _platform(g, 202, ground - 3, 4);
        _put(g, 204, ground - 3, '?');
        _put(g, 212, ground, 'S');
        _platform(g, 218, ground - 4, 3);
        _coin(g, 219, ground - 5);
        _coin(g, 220, ground - 5);
        _gap(g, 228, 3);
        _platform(g, 234, ground - 2, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 235 + i, ground - 3);
        }
        _enemy(g, 246, ground);
      case 4: // 第一缕光 — 间奏：第一缕阳光，暖色调
        _platform(g, 6, ground - 2, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 7 + i, ground - 3);
        }
        _put(g, 10, ground - 2, '?');
        _platform(g, 18, ground - 1, 3);
        _coin(g, 19, ground - 2);
        _enemy(g, 28, ground);
        _platform(g, 36, ground - 3, 4);
        _coin(g, 37, ground - 4);
        _coin(g, 38, ground - 4);
        _put(g, 46, ground, 'S');
        _platform(g, 52, ground - 4, 3);
        _put(g, 53, ground - 4, 'M');
        _gap(g, 60, 2);
        _platform(g, 66, ground - 2, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 67 + i, ground - 3);
        }
        _enemy(g, 78, ground);
        _platform(g, 84, ground - 3, 3);
        _put(g, 85, ground - 3, '?');
        _gap(g, 94, 3);
        _platform(g, 100, ground - 4, 3);
        _put(g, 101, ground - 5, 'H');
        _put(g, 108, ground, 'S');
        _platform(g, 114, ground - 2, 4);
        _coin(g, 115, ground - 3);
        _coin(g, 116, ground - 3);
        _enemy(g, 126, ground);
        _platform(g, 132, ground - 1, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 133 + i, ground - 2);
        }
        _gap(g, 142, 2);
        _platform(g, 148, ground - 3, 3);
        _coin(g, 149, ground - 4);
        _put(g, 156, ground, 'S');
        _platform(g, 162, ground - 4, 3);
        _put(g, 163, ground - 4, 'M');
        _enemy(g, 174, ground);
        _platform(g, 180, ground - 2, 5);
        _coin(g, 181, ground - 3);
        _coin(g, 182, ground - 3);
        _gap(g, 192, 3);
        _platform(g, 198, ground - 3, 4);
        for (var i = 0; i < 3; i++) {
          _coin(g, 199 + i, ground - 4);
        }
        _enemy(g, 210, ground);
        _platform(g, 218, ground - 1, 5);
        _coin(g, 219, ground - 2);
        _coin(g, 220, ground - 2);
        _put(g, 230, ground, 'S');
        _platform(g, 238, ground - 2, 4);
        _coin(g, 239, ground - 3);
        _platform(g, 252, ground - 3, 3);
        _coin(g, 253, ground - 4);
      case 5: // 早班高堤 — 主歌B：通勤节奏
        _platform(g, 6, ground - 1, 4);
        _coin(g, 7, ground - 2);
        _coin(g, 8, ground - 2);
        _platform(g, 16, ground - 3, 3);
        _put(g, 17, ground - 3, '?');
        _enemy(g, 28, ground);
        _gap(g, 34, 3);
        _platform(g, 40, ground - 2, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 41 + i, ground - 3);
        }
        _put(g, 50, ground, 'S');
        _platform(g, 56, ground - 4, 3);
        _put(g, 57, ground - 4, 'M');
        _gap(g, 64, 2);
        _enemy(g, 72, ground);
        _platform(g, 78, ground - 3, 4);
        _coin(g, 79, ground - 4);
        _coin(g, 80, ground - 4);
        _put(g, 81, ground - 3, '?');
        _put(g, 90, ground, 'S');
        _platform(g, 96, ground - 4, 3);
        _put(g, 97, ground - 5, 'H');
        _gap(g, 104, 3);
        _platform(g, 110, ground - 2, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 111 + i, ground - 3);
        }
        _enemy(g, 120, ground);
        _platform(g, 128, ground - 1, 4);
        _coin(g, 129, ground - 2);
        _gap(g, 138, 2);
        _put(g, 146, ground, 'S');
        _platform(g, 152, ground - 3, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 152 + i, ground - 4);
        }
        _enemy(g, 162, ground);
        _platform(g, 170, ground - 4, 3);
        _put(g, 171, ground - 4, 'M');
        _gap(g, 178, 3);
        _platform(g, 184, ground - 2, 4);
        _coin(g, 185, ground - 3);
        _coin(g, 186, ground - 3);
        _enemy(g, 196, ground);
        _put(g, 204, ground, 'S');
        _platform(g, 210, ground - 3, 5);
        _put(g, 212, ground - 3, '?');
        for (var i = 0; i < 4; i++) {
          _coin(g, 211 + i, ground - 4);
        }
        _gap(g, 222, 2);
        _platform(g, 228, ground - 1, 4);
        _coin(g, 229, ground - 2);
        _enemy(g, 240, ground);
        _platform(g, 248, ground - 2, 5);
        _coin(g, 249, ground - 3);
        _coin(g, 250, ground - 3);
      case 6: // 海风滑道 — 副歌B：海风吹拂
        _platform(g, 6, ground - 3, 4);
        _coin(g, 7, ground - 4);
        _coin(g, 8, ground - 4);
        _coin(g, 9, ground - 4);
        _gap(g, 16, 3);
        _enemy(g, 24, ground);
        _put(g, 30, ground, 'S');
        _platform(g, 36, ground - 4, 3);
        _put(g, 37, ground - 4, 'M');
        _platform(g, 48, ground - 2, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 49 + i, ground - 3);
        }
        _put(g, 52, ground - 2, '?');
        _gap(g, 58, 2);
        _enemy(g, 66, ground);
        _platform(g, 72, ground - 3, 4);
        _coin(g, 73, ground - 4);
        _coin(g, 74, ground - 4);
        _put(g, 82, ground, 'S');
        _platform(g, 88, ground - 4, 3);
        _put(g, 89, ground - 5, 'H');
        _gap(g, 96, 3);
        _platform(g, 102, ground - 2, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 102 + i, ground - 3);
        }
        _enemy(g, 114, ground);
        _put(g, 120, ground, 'S');
        _gap(g, 126, 2);
        _platform(g, 132, ground - 3, 4);
        _put(g, 134, ground - 3, '?');
        _coin(g, 134, ground - 4);
        _enemy(g, 144, ground);
        _platform(g, 150, ground - 4, 3);
        _put(g, 151, ground - 4, 'M');
        _gap(g, 158, 3);
        _platform(g, 164, ground - 1, 5);
        _coin(g, 165, ground - 2);
        _coin(g, 166, ground - 2);
        _put(g, 174, ground, 'S');
        _enemy(g, 182, ground);
        _platform(g, 188, ground - 3, 4);
        for (var i = 0; i < 4; i++) {
          _coin(g, 188 + i, ground - 4);
        }
        _gap(g, 198, 2);
        _platform(g, 204, ground - 2, 5);
        _coin(g, 205, ground - 3);
        _coin(g, 206, ground - 3);
        _enemy(g, 216, ground);
        _put(g, 224, ground, 'S');
        _platform(g, 230, ground - 4, 3);
        _put(g, 231, ground - 5, 'H');
        _platform(g, 242, ground - 2, 4);
        _coin(g, 243, ground - 3);
        _coin(g, 244, ground - 3);
        _gap(g, 254, 3);
        _platform(g, 260, ground - 3, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 261 + i, ground - 4);
        }
      case 7: // 灯塔之桥 — 桥段：灯塔指引
        _platform(g, 6, ground - 2, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 7 + i, ground - 3);
        }
        _put(g, 10, ground - 2, '?');
        _enemy(g, 18, ground);
        _gap(g, 24, 2);
        _platform(g, 30, ground - 4, 3);
        _put(g, 31, ground - 4, 'M');
        _put(g, 38, ground, 'S');
        _platform(g, 44, ground - 3, 5);
        _coin(g, 45, ground - 4);
        _coin(g, 46, ground - 4);
        _coin(g, 47, ground - 4);
        _gap(g, 54, 3);
        _enemy(g, 62, ground);
        _platform(g, 68, ground - 2, 4);
        _put(g, 70, ground - 2, '?');
        _platform(g, 80, ground - 4, 3);
        _put(g, 81, ground - 5, 'H');
        _put(g, 88, ground, 'S');
        _gap(g, 94, 2);
        _platform(g, 100, ground - 3, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 100 + i, ground - 4);
        }
        _enemy(g, 112, ground);
        _platform(g, 118, ground - 1, 4);
        _coin(g, 119, ground - 2);
        _gap(g, 128, 3);
        _put(g, 136, ground, 'S');
        _platform(g, 142, ground - 4, 3);
        _put(g, 143, ground - 4, 'M');
        _enemy(g, 152, ground);
        _platform(g, 158, ground - 2, 5);
        _coin(g, 159, ground - 3);
        _coin(g, 160, ground - 3);
        _gap(g, 170, 2);
        _platform(g, 176, ground - 3, 4);
        _put(g, 178, ground - 3, '?');
        _coin(g, 178, ground - 4);
        _enemy(g, 188, ground);
        _put(g, 194, ground, 'S');
        _platform(g, 200, ground - 4, 3);
        _coin(g, 201, ground - 5);
        _coin(g, 202, ground - 5);
        _gap(g, 210, 3);
        _platform(g, 216, ground - 2, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 217 + i, ground - 3);
        }
        _enemy(g, 228, ground);
        _platform(g, 234, ground - 3, 3);
        _coin(g, 235, ground - 4);
        _put(g, 244, ground, 'S');
        _platform(g, 250, ground - 4, 3);
        _put(g, 251, ground - 5, 'H');
        _platform(g, 262, ground - 1, 4);
        _coin(g, 263, ground - 2);
        _coin(g, 264, ground - 2);
        _gap(g, 274, 2);
        _platform(g, 280, ground - 2, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 281 + i, ground - 3);
        }
      case 8: // 金色沙堡 — 副歌C：沙堡意象
        _platform(g, 6, ground - 1, 4);
        _coin(g, 7, ground - 2);
        _coin(g, 8, ground - 2);
        _gap(g, 16, 3);
        _enemy(g, 24, ground);
        _platform(g, 30, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 31 + i, ground - 4);
        }
        _put(g, 34, ground - 3, '?');
        _put(g, 42, ground, 'S');
        _platform(g, 48, ground - 4, 3);
        _put(g, 49, ground - 4, 'M');
        _gap(g, 56, 2);
        _platform(g, 62, ground - 2, 4);
        _enemy(g, 70, ground);
        _platform(g, 76, ground - 3, 5);
        _coin(g, 77, ground - 4);
        _coin(g, 78, ground - 4);
        _put(g, 86, ground, 'S');
        _gap(g, 92, 3);
        _platform(g, 98, ground - 4, 3);
        _put(g, 99, ground - 5, 'H');
        _enemy(g, 108, ground);
        _platform(g, 114, ground - 2, 5);
        _put(g, 116, ground - 2, '?');
        for (var i = 0; i < 3; i++) {
          _coin(g, 115 + i, ground - 3);
        }
        _gap(g, 124, 2);
        _put(g, 132, ground, 'S');
        _platform(g, 138, ground - 3, 4);
        _coin(g, 139, ground - 4);
        _coin(g, 140, ground - 4);
        _enemy(g, 148, ground);
        _platform(g, 156, ground - 4, 3);
        _put(g, 157, ground - 4, 'M');
        _gap(g, 164, 3);
        _platform(g, 170, ground - 1, 5);
        _coin(g, 171, ground - 2);
        _coin(g, 172, ground - 2);
        _enemy(g, 182, ground);
        _put(g, 188, ground, 'S');
        _platform(g, 194, ground - 3, 4);
        for (var i = 0; i < 4; i++) {
          _coin(g, 194 + i, ground - 4);
        }
        _gap(g, 204, 2);
        _platform(g, 210, ground - 2, 5);
        _put(g, 212, ground - 2, '?');
        _enemy(g, 222, ground);
        _platform(g, 228, ground - 4, 3);
        _put(g, 229, ground - 5, 'H');
        _put(g, 238, ground, 'S');
        _platform(g, 244, ground - 3, 5);
        _coin(g, 245, ground - 4);
        _coin(g, 246, ground - 4);
        _gap(g, 256, 3);
        _enemy(g, 264, ground);
        _platform(g, 270, ground - 2, 4);
        _coin(g, 271, ground - 3);
        _coin(g, 272, ground - 3);
        _platform(g, 284, ground - 1, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 285 + i, ground - 2);
        }
      case 9: // 黎明之巅 — 高潮
        _platform(g, 6, ground - 3, 4);
        for (var i = 0; i < 3; i++) {
          _coin(g, 7 + i, ground - 4);
        }
        _put(g, 6, ground - 3, '?');
        _gap(g, 14, 3);
        _enemy(g, 22, ground);
        _put(g, 28, ground, 'S');
        _platform(g, 34, ground - 4, 3);
        _put(g, 35, ground - 4, 'M');
        _gap(g, 42, 2);
        _platform(g, 48, ground - 3, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 48 + i, ground - 4);
        }
        _enemy(g, 58, ground);
        _gap(g, 64, 3);
        _put(g, 72, ground, 'S');
        _platform(g, 78, ground - 4, 3);
        _put(g, 79, ground - 5, 'H');
        _platform(g, 88, ground - 2, 4);
        _put(g, 90, ground - 2, '?');
        _enemy(g, 98, ground);
        _gap(g, 104, 2);
        _platform(g, 110, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 111 + i, ground - 4);
        }
        _put(g, 120, ground, 'S');
        _platform(g, 126, ground - 4, 3);
        _put(g, 127, ground - 4, 'M');
        _enemy(g, 136, ground);
        _gap(g, 142, 3);
        _platform(g, 148, ground - 2, 4);
        _coin(g, 149, ground - 3);
        _coin(g, 150, ground - 3);
        _put(g, 158, ground, 'S');
        _gap(g, 164, 2);
        _enemy(g, 172, ground);
        _platform(g, 178, ground - 3, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 178 + i, ground - 4);
        }
        _put(g, 182, ground - 3, '?');
        _gap(g, 190, 3);
        _platform(g, 196, ground - 4, 3);
        _put(g, 197, ground - 5, 'H');
        _put(g, 204, ground, 'S');
        _enemy(g, 212, ground);
        _platform(g, 218, ground - 2, 4);
        _coin(g, 219, ground - 3);
        _coin(g, 220, ground - 3);
        _gap(g, 230, 2);
        _platform(g, 236, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 237 + i, ground - 4);
        }
        _enemy(g, 248, ground);
        _put(g, 254, ground, 'S');
        _platform(g, 260, ground - 4, 3);
        _put(g, 261, ground - 4, 'M');
        _gap(g, 268, 3);
        _platform(g, 274, ground - 2, 5);
        _coin(g, 275, ground - 3);
        _coin(g, 276, ground - 3);
        _enemy(g, 288, ground);
        _platform(g, 294, ground - 3, 4);
        for (var i = 0; i < 3; i++) {
          _coin(g, 295 + i, ground - 4);
        }
      case 10: // 二十分灯塔 — Boss战
        _platform(g, 6, ground - 2, 4);
        _coin(g, 7, ground - 3);
        _coin(g, 8, ground - 3);
        _put(g, 9, ground - 2, '?');
        _enemy(g, 18, ground);
        _gap(g, 24, 2);
        _platform(g, 30, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 31 + i, ground - 4);
        }
        _enemy(g, 42, ground);
        _put(g, 48, ground, 'S');
        _platform(g, 54, ground - 4, 3);
        _put(g, 55, ground - 4, 'M');
        _gap(g, 62, 3);
        _platform(g, 68, ground - 2, 4);
        _coin(g, 69, ground - 3);
        _coin(g, 70, ground - 3);
        _enemy(g, 80, ground);
        _platform(g, 86, ground - 3, 5);
        _put(g, 88, ground - 3, '?');
        _put(g, 96, ground, 'S');
        _platform(g, 102, ground - 4, 3);
        _put(g, 103, ground - 5, 'H');
    }
  }

  static void _worldRoseCastle(List<List<String>> g, int level) {
    final ground = g.length - 3;
    switch (level) {
      case 0: // 迷途门廊 — 前奏：迷失入口，哥特门廊
        _platform(g, 6, ground - 1, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 7 + i, ground - 2);
        }
        _platform(g, 18, ground - 2, 3);
        _put(g, 19, ground - 2, '?');
        _enemy(g, 28, ground);
        _platform(g, 36, ground - 3, 4);
        _coin(g, 37, ground - 4);
        _coin(g, 38, ground - 4);
        _gap(g, 46, 2);
        _platform(g, 52, ground - 1, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 53 + i, ground - 2);
        }
        _put(g, 62, ground, 'S');
        _platform(g, 68, ground - 3, 3);
        _put(g, 69, ground - 3, 'M');
        _enemy(g, 78, ground);
        _platform(g, 86, ground - 2, 4);
        _coin(g, 87, ground - 3);
        _coin(g, 88, ground - 3);
        _platform(g, 98, ground - 1, 5);
        _put(g, 100, ground - 1, '?');
        _gap(g, 108, 2);
        _platform(g, 114, ground - 3, 3);
        _coin(g, 115, ground - 4);
        _enemy(g, 124, ground);
        _platform(g, 132, ground - 2, 4);
        for (var i = 0; i < 3; i++) {
          _coin(g, 133 + i, ground - 3);
        }
        _put(g, 142, ground, 'S');
        _platform(g, 148, ground - 4, 3);
        _put(g, 149, ground - 5, 'H');
        _platform(g, 160, ground - 1, 5);
        _coin(g, 161, ground - 2);
        _coin(g, 162, ground - 2);
        _enemy(g, 174, ground);
        _platform(g, 182, ground - 3, 4);
        for (var i = 0; i < 4; i++) {
          _coin(g, 182 + i, ground - 4);
        }
        _platform(g, 196, ground - 2, 3);
        _coin(g, 197, ground - 3);
        _gap(g, 206, 2);
        _platform(g, 212, ground - 1, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 213 + i, ground - 2);
        }
        _platform(g, 224, ground - 3, 3);
        _put(g, 225, ground - 3, '?');
      case 1: // 回旋台阶 — 主歌A：螺旋上升
        _platform(g, 6, ground - 2, 4);
        _coin(g, 7, ground - 3);
        _coin(g, 8, ground - 3);
        _put(g, 14, ground, 'S');
        _platform(g, 20, ground - 3, 3);
        _put(g, 21, ground - 3, '?');
        _enemy(g, 30, ground);
        _gap(g, 36, 2);
        _platform(g, 42, ground - 4, 4);
        for (var i = 0; i < 3; i++) {
          _coin(g, 43 + i, ground - 5);
        }
        _platform(g, 54, ground - 2, 5);
        _coin(g, 55, ground - 3);
        _coin(g, 56, ground - 3);
        _put(g, 64, ground, 'S');
        _platform(g, 70, ground - 4, 3);
        _put(g, 71, ground - 4, 'M');
        _enemy(g, 80, ground);
        _gap(g, 86, 3);
        _platform(g, 92, ground - 3, 4);
        for (var i = 0; i < 4; i++) {
          _coin(g, 92 + i, ground - 4);
        }
        _put(g, 95, ground - 3, '?');
        _platform(g, 104, ground - 1, 5);
        _coin(g, 105, ground - 2);
        _put(g, 114, ground, 'S');
        _platform(g, 120, ground - 4, 3);
        _put(g, 121, ground - 5, 'H');
        _enemy(g, 130, ground);
        _platform(g, 138, ground - 2, 4);
        _coin(g, 139, ground - 3);
        _coin(g, 140, ground - 3);
        _gap(g, 150, 2);
        _platform(g, 156, ground - 3, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 156 + i, ground - 4);
        }
        _enemy(g, 168, ground);
        _put(g, 174, ground, 'S');
        _platform(g, 180, ground - 4, 3);
        _put(g, 181, ground - 4, 'M');
        _gap(g, 188, 3);
        _platform(g, 194, ground - 2, 4);
        _coin(g, 195, ground - 3);
        _coin(g, 196, ground - 3);
        _enemy(g, 206, ground);
        _platform(g, 214, ground - 3, 3);
        _put(g, 215, ground - 3, '?');
        _platform(g, 226, ground - 1, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 227 + i, ground - 2);
        }
        _gap(g, 238, 2);
        _platform(g, 244, ground - 2, 3);
        _coin(g, 245, ground - 3);
      case 2: // 断线平台 — 主歌B：断裂失落
        _platform(g, 6, ground - 1, 3);
        _coin(g, 7, ground - 2);
        _coin(g, 8, ground - 2);
        _gap(g, 14, 3);
        _platform(g, 20, ground - 3, 4);
        for (var i = 0; i < 3; i++) {
          _coin(g, 21 + i, ground - 4);
        }
        _put(g, 23, ground - 3, '?');
        _enemy(g, 32, ground);
        _put(g, 38, ground, 'S');
        _platform(g, 44, ground - 4, 3);
        _put(g, 45, ground - 4, 'M');
        _gap(g, 52, 2);
        _platform(g, 58, ground - 2, 5);
        _coin(g, 59, ground - 3);
        _coin(g, 60, ground - 3);
        _enemy(g, 70, ground);
        _gap(g, 76, 3);
        _platform(g, 82, ground - 3, 4);
        for (var i = 0; i < 4; i++) {
          _coin(g, 82 + i, ground - 4);
        }
        _put(g, 92, ground, 'S');
        _platform(g, 98, ground - 4, 3);
        _put(g, 99, ground - 5, 'H');
        _gap(g, 106, 2);
        _enemy(g, 114, ground);
        _platform(g, 120, ground - 2, 5);
        _put(g, 122, ground - 2, '?');
        _coin(g, 121, ground - 3);
        _coin(g, 122, ground - 3);
        _gap(g, 132, 3);
        _put(g, 140, ground, 'S');
        _platform(g, 146, ground - 3, 4);
        for (var i = 0; i < 3; i++) {
          _coin(g, 147 + i, ground - 4);
        }
        _enemy(g, 156, ground);
        _platform(g, 164, ground - 4, 3);
        _put(g, 165, ground - 4, 'M');
        _gap(g, 172, 2);
        _platform(g, 178, ground - 1, 5);
        _coin(g, 179, ground - 2);
        _coin(g, 180, ground - 2);
        _enemy(g, 190, ground);
        _put(g, 196, ground, 'S');
        _platform(g, 202, ground - 3, 4);
        for (var i = 0; i < 4; i++) {
          _coin(g, 202 + i, ground - 4);
        }
        _gap(g, 212, 3);
        _platform(g, 218, ground - 2, 5);
        _put(g, 220, ground - 2, '?');
        _enemy(g, 230, ground);
        _platform(g, 238, ground - 4, 3);
        _put(g, 239, ground - 5, 'H');
        _platform(g, 250, ground - 1, 4);
        _coin(g, 251, ground - 2);
        _coin(g, 252, ground - 2);
        _gap(g, 262, 2);
      case 3: // 荆棘回廊 — 副歌前奏：荆棘逼近
        _platform(g, 6, ground - 2, 4);
        for (var i = 0; i < 3; i++) {
          _coin(g, 7 + i, ground - 3);
        }
        _put(g, 9, ground - 2, '?');
        _gap(g, 16, 2);
        _enemy(g, 24, ground);
        _platform(g, 30, ground - 3, 5);
        _coin(g, 31, ground - 4);
        _coin(g, 32, ground - 4);
        _put(g, 40, ground, 'S');
        _platform(g, 46, ground - 4, 3);
        _put(g, 47, ground - 4, 'M');
        _enemy(g, 56, ground);
        _gap(g, 62, 3);
        _platform(g, 68, ground - 2, 4);
        for (var i = 0; i < 4; i++) {
          _coin(g, 68 + i, ground - 3);
        }
        _platform(g, 80, ground - 3, 3);
        _put(g, 81, ground - 3, '?');
        _put(g, 88, ground, 'S');
        _gap(g, 94, 2);
        _enemy(g, 102, ground);
        _platform(g, 108, ground - 4, 4);
        for (var i = 0; i < 3; i++) {
          _coin(g, 109 + i, ground - 5);
        }
        _put(g, 111, ground - 4, 'H');
        _gap(g, 118, 3);
        _platform(g, 124, ground - 2, 5);
        _coin(g, 125, ground - 3);
        _coin(g, 126, ground - 3);
        _enemy(g, 136, ground);
        _put(g, 142, ground, 'S');
        _platform(g, 148, ground - 3, 4);
        _put(g, 150, ground - 3, 'M');
        _gap(g, 158, 2);
        _platform(g, 164, ground - 4, 3);
        _coin(g, 165, ground - 5);
        _coin(g, 166, ground - 5);
        _enemy(g, 176, ground);
        _platform(g, 182, ground - 1, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 183 + i, ground - 2);
        }
        _gap(g, 192, 3);
        _put(g, 200, ground, 'S');
        _platform(g, 206, ground - 3, 4);
        _put(g, 208, ground - 3, '?');
        _enemy(g, 218, ground);
        _platform(g, 224, ground - 4, 3);
        _put(g, 225, ground - 4, 'M');
        _gap(g, 232, 2);
        _platform(g, 238, ground - 2, 5);
        _coin(g, 239, ground - 3);
        _coin(g, 240, ground - 3);
        _enemy(g, 252, ground);
        _platform(g, 260, ground - 3, 3);
        _put(g, 261, ground - 3, '?');
        _platform(g, 272, ground - 1, 4);
        for (var i = 0; i < 3; i++) {
          _coin(g, 273 + i, ground - 2);
        }
        _put(g, 280, ground, 'S');
      case 4: // 雾中塔楼 — 副歌A：迷雾塔楼
        _platform(g, 6, ground - 3, 4);
        for (var i = 0; i < 3; i++) {
          _coin(g, 7 + i, ground - 4);
        }
        _gap(g, 14, 3);
        _enemy(g, 22, ground);
        _put(g, 28, ground, 'S');
        _platform(g, 34, ground - 4, 3);
        _put(g, 35, ground - 4, 'M');
        _platform(g, 46, ground - 2, 5);
        _put(g, 48, ground - 2, '?');
        _coin(g, 47, ground - 3);
        _coin(g, 48, ground - 3);
        _gap(g, 56, 2);
        _enemy(g, 64, ground);
        _platform(g, 70, ground - 3, 4);
        for (var i = 0; i < 4; i++) {
          _coin(g, 70 + i, ground - 4);
        }
        _put(g, 80, ground, 'S');
        _platform(g, 86, ground - 4, 3);
        _put(g, 87, ground - 5, 'H');
        _gap(g, 94, 3);
        _platform(g, 100, ground - 2, 5);
        _coin(g, 101, ground - 3);
        _coin(g, 102, ground - 3);
        _enemy(g, 112, ground);
        _platform(g, 118, ground - 3, 3);
        _put(g, 119, ground - 3, '?');
        _put(g, 126, ground, 'S');
        _gap(g, 132, 2);
        _platform(g, 138, ground - 4, 4);
        for (var i = 0; i < 3; i++) {
          _coin(g, 139 + i, ground - 5);
        }
        _enemy(g, 148, ground);
        _platform(g, 156, ground - 1, 5);
        _coin(g, 157, ground - 2);
        _coin(g, 158, ground - 2);
        _gap(g, 166, 3);
        _put(g, 174, ground, 'S');
        _platform(g, 180, ground - 4, 3);
        _put(g, 181, ground - 4, 'M');
        _enemy(g, 192, ground);
        _platform(g, 198, ground - 2, 4);
        _put(g, 200, ground - 2, '?');
        _gap(g, 208, 2);
        _platform(g, 214, ground - 3, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 214 + i, ground - 4);
        }
        _enemy(g, 226, ground);
        _put(g, 232, ground, 'S');
        _platform(g, 238, ground - 4, 3);
        _put(g, 239, ground - 5, 'H');
        _gap(g, 246, 3);
        _platform(g, 252, ground - 2, 4);
        _coin(g, 253, ground - 3);
        _coin(g, 254, ground - 3);
        _enemy(g, 264, ground);
        _platform(g, 272, ground - 3, 3);
        _put(g, 273, ground - 3, 'M');
        _platform(g, 284, ground - 1, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 285 + i, ground - 2);
        }
        _gap(g, 296, 2);
      case 5: // 花瓣断桥 — 间奏：花瓣飘落
        _platform(g, 6, ground - 2, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 7 + i, ground - 3);
        }
        _put(g, 10, ground - 2, '?');
        _enemy(g, 18, ground);
        _gap(g, 24, 2);
        _platform(g, 30, ground - 3, 3);
        _coin(g, 31, ground - 4);
        _put(g, 38, ground, 'S');
        _platform(g, 44, ground - 4, 4);
        _put(g, 46, ground - 4, 'M');
        _gap(g, 54, 3);
        _platform(g, 60, ground - 1, 5);
        _coin(g, 61, ground - 2);
        _coin(g, 62, ground - 2);
        _enemy(g, 72, ground);
        _platform(g, 78, ground - 3, 3);
        _put(g, 79, ground - 3, '?');
        _put(g, 86, ground, 'S');
        _platform(g, 92, ground - 4, 3);
        _put(g, 93, ground - 5, 'H');
        _gap(g, 100, 2);
        _platform(g, 106, ground - 2, 4);
        for (var i = 0; i < 3; i++) {
          _coin(g, 107 + i, ground - 3);
        }
        _enemy(g, 118, ground);
        _gap(g, 124, 3);
        _platform(g, 130, ground - 3, 5);
        _coin(g, 131, ground - 4);
        _coin(g, 132, ground - 4);
        _put(g, 140, ground, 'S');
        _platform(g, 146, ground - 4, 3);
        _put(g, 147, ground - 4, 'M');
        _enemy(g, 156, ground);
        _gap(g, 162, 2);
        _platform(g, 168, ground - 2, 4);
        _put(g, 170, ground - 2, '?');
        _coin(g, 169, ground - 3);
        _coin(g, 170, ground - 3);
        _platform(g, 180, ground - 1, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 181 + i, ground - 2);
        }
        _enemy(g, 192, ground);
        _gap(g, 198, 3);
        _put(g, 206, ground, 'S');
        _platform(g, 212, ground - 3, 4);
        for (var i = 0; i < 3; i++) {
          _coin(g, 213 + i, ground - 4);
        }
        _enemy(g, 224, ground);
        _platform(g, 230, ground - 4, 3);
        _put(g, 231, ground - 5, 'H');
        _gap(g, 238, 2);
        _platform(g, 244, ground - 2, 5);
        _coin(g, 245, ground - 3);
        _coin(g, 246, ground - 3);
        _enemy(g, 258, ground);
        _platform(g, 264, ground - 3, 3);
        _put(g, 265, ground - 3, '?');
        _platform(g, 276, ground - 1, 4);
        _coin(g, 277, ground - 2);
        _coin(g, 278, ground - 2);
        _put(g, 288, ground, 'S');
        _platform(g, 294, ground - 4, 3);
        _put(g, 295, ground - 4, 'M');
        _gap(g, 304, 3);
        _platform(g, 310, ground - 2, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 311 + i, ground - 3);
        }
      case 6: // 失落大厅 — 主歌2：空旷大厅
        _platform(g, 6, ground - 1, 4);
        _coin(g, 7, ground - 2);
        _coin(g, 8, ground - 2);
        _gap(g, 16, 3);
        _enemy(g, 24, ground);
        _platform(g, 30, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 31 + i, ground - 4);
        }
        _put(g, 34, ground - 3, '?');
        _put(g, 42, ground, 'S');
        _platform(g, 48, ground - 4, 3);
        _put(g, 49, ground - 4, 'M');
        _gap(g, 56, 2);
        _platform(g, 62, ground - 2, 4);
        _coin(g, 63, ground - 3);
        _coin(g, 64, ground - 3);
        _enemy(g, 74, ground);
        _gap(g, 80, 3);
        _platform(g, 86, ground - 3, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 86 + i, ground - 4);
        }
        _put(g, 96, ground, 'S');
        _platform(g, 102, ground - 4, 3);
        _put(g, 103, ground - 5, 'H');
        _enemy(g, 112, ground);
        _gap(g, 118, 2);
        _platform(g, 124, ground - 2, 4);
        _put(g, 126, ground - 2, '?');
        _coin(g, 125, ground - 3);
        _put(g, 134, ground, 'S');
        _platform(g, 140, ground - 3, 5);
        _coin(g, 141, ground - 4);
        _coin(g, 142, ground - 4);
        _gap(g, 152, 3);
        _enemy(g, 160, ground);
        _platform(g, 166, ground - 4, 3);
        _put(g, 167, ground - 4, 'M');
        _platform(g, 178, ground - 1, 4);
        _coin(g, 179, ground - 2);
        _gap(g, 188, 2);
        _platform(g, 194, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 195 + i, ground - 4);
        }
        _enemy(g, 206, ground);
        _put(g, 212, ground, 'S');
        _platform(g, 218, ground - 4, 3);
        _put(g, 219, ground - 5, 'H');
        _gap(g, 226, 3);
        _platform(g, 232, ground - 2, 4);
        _put(g, 234, ground - 2, '?');
        _coin(g, 233, ground - 3);
        _coin(g, 234, ground - 3);
        _enemy(g, 244, ground);
        _platform(g, 252, ground - 3, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 253 + i, ground - 4);
        }
        _gap(g, 264, 2);
        _put(g, 272, ground, 'S');
        _platform(g, 278, ground - 4, 3);
        _put(g, 279, ground - 4, 'M');
        _enemy(g, 290, ground);
        _platform(g, 296, ground - 1, 5);
        _coin(g, 297, ground - 2);
        _coin(g, 298, ground - 2);
        _gap(g, 308, 3);
        _platform(g, 314, ground - 2, 4);
        for (var i = 0; i < 3; i++) {
          _coin(g, 315 + i, ground - 3);
        }
        _platform(g, 328, ground - 3, 3);
        _put(g, 329, ground - 3, '?');
      case 7: // 迷宫高台 — 副歌B：迷宫攀登
        _platform(g, 6, ground - 3, 4);
        for (var i = 0; i < 3; i++) {
          _coin(g, 7 + i, ground - 4);
        }
        _put(g, 6, ground - 3, '?');
        _gap(g, 14, 2);
        _enemy(g, 22, ground);
        _put(g, 28, ground, 'S');
        _platform(g, 34, ground - 4, 3);
        _put(g, 35, ground - 4, 'M');
        _platform(g, 46, ground - 2, 5);
        _coin(g, 47, ground - 3);
        _coin(g, 48, ground - 3);
        _gap(g, 56, 3);
        _enemy(g, 64, ground);
        _platform(g, 70, ground - 3, 4);
        for (var i = 0; i < 4; i++) {
          _coin(g, 70 + i, ground - 4);
        }
        _put(g, 73, ground - 3, '?');
        _put(g, 80, ground, 'S');
        _platform(g, 86, ground - 4, 3);
        _put(g, 87, ground - 5, 'H');
        _gap(g, 94, 2);
        _platform(g, 100, ground - 2, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 100 + i, ground - 3);
        }
        _enemy(g, 112, ground);
        _gap(g, 118, 3);
        _put(g, 126, ground, 'S');
        _platform(g, 132, ground - 4, 3);
        _put(g, 133, ground - 4, 'M');
        _platform(g, 144, ground - 1, 4);
        _coin(g, 145, ground - 2);
        _enemy(g, 154, ground);
        _gap(g, 160, 2);
        _platform(g, 166, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 167 + i, ground - 4);
        }
        _put(g, 170, ground - 3, '?');
        _put(g, 178, ground, 'S');
        _gap(g, 184, 3);
        _platform(g, 190, ground - 4, 3);
        _put(g, 191, ground - 5, 'H');
        _enemy(g, 200, ground);
        _platform(g, 208, ground - 2, 4);
        _coin(g, 209, ground - 3);
        _coin(g, 210, ground - 3);
        _gap(g, 220, 2);
        _platform(g, 226, ground - 3, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 227 + i, ground - 4);
        }
        _enemy(g, 238, ground);
        _put(g, 244, ground, 'S');
        _platform(g, 250, ground - 4, 3);
        _put(g, 251, ground - 4, 'M');
        _gap(g, 258, 3);
        _platform(g, 264, ground - 2, 4);
        _put(g, 266, ground - 2, '?');
        _coin(g, 265, ground - 3);
        _coin(g, 266, ground - 3);
        _enemy(g, 276, ground);
        _platform(g, 284, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 285 + i, ground - 4);
        }
        _gap(g, 296, 2);
        _put(g, 304, ground, 'S');
        _platform(g, 310, ground - 4, 3);
        _coin(g, 311, ground - 5);
        _coin(g, 312, ground - 5);
        _platform(g, 324, ground - 1, 4);
        _coin(g, 325, ground - 2);
        _enemy(g, 336, ground);
        _platform(g, 344, ground - 2, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 345 + i, ground - 3);
        }
      case 8: // 指路之桥 — 桥段：指引归途
        _platform(g, 6, ground - 2, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 7 + i, ground - 3);
        }
        _put(g, 10, ground - 2, '?');
        _enemy(g, 18, ground);
        _gap(g, 24, 3);
        _platform(g, 30, ground - 4, 3);
        _put(g, 31, ground - 4, 'M');
        _put(g, 38, ground, 'S');
        _platform(g, 44, ground - 3, 5);
        _coin(g, 45, ground - 4);
        _coin(g, 46, ground - 4);
        _coin(g, 47, ground - 4);
        _gap(g, 54, 2);
        _enemy(g, 62, ground);
        _platform(g, 68, ground - 2, 4);
        _put(g, 70, ground - 2, '?');
        _put(g, 78, ground, 'S');
        _platform(g, 84, ground - 4, 3);
        _put(g, 85, ground - 5, 'H');
        _gap(g, 92, 3);
        _platform(g, 98, ground - 3, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 98 + i, ground - 4);
        }
        _enemy(g, 110, ground);
        _gap(g, 116, 2);
        _platform(g, 122, ground - 1, 4);
        _coin(g, 123, ground - 2);
        _put(g, 132, ground, 'S');
        _platform(g, 138, ground - 4, 3);
        _put(g, 139, ground - 4, 'M');
        _enemy(g, 148, ground);
        _gap(g, 154, 3);
        _platform(g, 160, ground - 2, 5);
        _coin(g, 161, ground - 3);
        _coin(g, 162, ground - 3);
        _put(g, 170, ground, 'S');
        _platform(g, 176, ground - 3, 4);
        _put(g, 178, ground - 3, '?');
        for (var i = 0; i < 3; i++) {
          _coin(g, 177 + i, ground - 4);
        }
        _enemy(g, 188, ground);
        _gap(g, 194, 2);
        _platform(g, 200, ground - 4, 3);
        _put(g, 201, ground - 5, 'H');
        _put(g, 208, ground, 'S');
        _platform(g, 214, ground - 2, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 215 + i, ground - 3);
        }
        _gap(g, 226, 3);
        _enemy(g, 234, ground);
        _platform(g, 240, ground - 3, 4);
        _coin(g, 241, ground - 4);
        _coin(g, 242, ground - 4);
        _put(g, 252, ground, 'S');
        _platform(g, 258, ground - 4, 3);
        _put(g, 259, ground - 4, 'M');
        _gap(g, 266, 2);
        _platform(g, 272, ground - 2, 5);
        _put(g, 274, ground - 2, '?');
        _coin(g, 273, ground - 3);
        _coin(g, 274, ground - 3);
        _enemy(g, 284, ground);
        _platform(g, 292, ground - 3, 3);
        _coin(g, 293, ground - 4);
        _gap(g, 302, 3);
        _put(g, 310, ground, 'S');
        _platform(g, 316, ground - 4, 3);
        _coin(g, 317, ground - 5);
        _coin(g, 318, ground - 5);
        _platform(g, 330, ground - 1, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 331 + i, ground - 2);
        }
        _enemy(g, 344, ground);
        _platform(g, 352, ground - 2, 4);
        _coin(g, 353, ground - 3);
        _gap(g, 362, 2);
        _platform(g, 368, ground - 3, 3);
        _put(g, 369, ground - 3, '?');
      case 9: // 归途尖塔 — 高潮：最终攀登
        _platform(g, 6, ground - 3, 4);
        for (var i = 0; i < 3; i++) {
          _coin(g, 7 + i, ground - 4);
        }
        _put(g, 6, ground - 3, '?');
        _gap(g, 14, 3);
        _enemy(g, 22, ground);
        _put(g, 28, ground, 'S');
        _platform(g, 34, ground - 4, 3);
        _put(g, 35, ground - 4, 'M');
        _gap(g, 42, 2);
        _platform(g, 48, ground - 3, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 48 + i, ground - 4);
        }
        _enemy(g, 60, ground);
        _gap(g, 66, 3);
        _put(g, 74, ground, 'S');
        _platform(g, 80, ground - 4, 3);
        _put(g, 81, ground - 5, 'H');
        _platform(g, 92, ground - 2, 4);
        _put(g, 94, ground - 2, '?');
        _coin(g, 93, ground - 3);
        _coin(g, 94, ground - 3);
        _enemy(g, 104, ground);
        _gap(g, 110, 2);
        _platform(g, 116, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 117 + i, ground - 4);
        }
        _put(g, 126, ground, 'S');
        _platform(g, 132, ground - 4, 3);
        _put(g, 133, ground - 4, 'M');
        _enemy(g, 142, ground);
        _gap(g, 148, 3);
        _platform(g, 154, ground - 2, 4);
        _coin(g, 155, ground - 3);
        _coin(g, 156, ground - 3);
        _put(g, 164, ground, 'S');
        _gap(g, 170, 2);
        _enemy(g, 178, ground);
        _platform(g, 184, ground - 3, 5);
        for (var i = 0; i < 5; i++) {
          _coin(g, 184 + i, ground - 4);
        }
        _put(g, 188, ground - 3, '?');
        _gap(g, 196, 3);
        _platform(g, 202, ground - 4, 3);
        _put(g, 203, ground - 5, 'H');
        _put(g, 210, ground, 'S');
        _enemy(g, 218, ground);
        _platform(g, 224, ground - 2, 4);
        _coin(g, 225, ground - 3);
        _coin(g, 226, ground - 3);
        _gap(g, 236, 2);
        _platform(g, 242, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 243 + i, ground - 4);
        }
        _enemy(g, 254, ground);
        _put(g, 260, ground, 'S');
        _platform(g, 266, ground - 4, 3);
        _put(g, 267, ground - 4, 'M');
        _gap(g, 274, 3);
        _platform(g, 280, ground - 2, 5);
        _coin(g, 281, ground - 3);
        _coin(g, 282, ground - 3);
        _enemy(g, 294, ground);
        _platform(g, 300, ground - 3, 4);
        for (var i = 0; i < 3; i++) {
          _coin(g, 301 + i, ground - 4);
        }
        _put(g, 303, ground - 3, '?');
        _gap(g, 312, 2);
        _put(g, 320, ground, 'S');
        _platform(g, 326, ground - 4, 3);
        _put(g, 327, ground - 5, 'H');
        _platform(g, 338, ground - 1, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 339 + i, ground - 2);
        }
        _enemy(g, 352, ground);
        _gap(g, 358, 3);
        _platform(g, 364, ground - 3, 4);
        _coin(g, 365, ground - 4);
        _coin(g, 366, ground - 4);
        _platform(g, 378, ground - 2, 5);
        for (var i = 0; i < 3; i++) {
          _coin(g, 379 + i, ground - 3);
        }
        _enemy(g, 390, ground);
      case 10: // 找回之心 — Boss战：最终Boss
        _platform(g, 6, ground - 2, 4);
        _coin(g, 7, ground - 3);
        _coin(g, 8, ground - 3);
        _put(g, 9, ground - 2, '?');
        _enemy(g, 18, ground);
        _gap(g, 24, 3);
        _platform(g, 30, ground - 3, 5);
        for (var i = 0; i < 4; i++) {
          _coin(g, 31 + i, ground - 4);
        }
        _put(g, 40, ground, 'S');
        _platform(g, 46, ground - 4, 3);
        _put(g, 47, ground - 4, 'M');
        _enemy(g, 56, ground);
        _gap(g, 62, 2);
        _platform(g, 68, ground - 2, 4);
        _coin(g, 69, ground - 3);
        _coin(g, 70, ground - 3);
        _put(g, 78, ground, 'S');
        _platform(g, 84, ground - 3, 5);
        _put(g, 86, ground - 3, '?');
        _platform(g, 96, ground - 4, 3);
        _put(g, 97, ground - 5, 'H');
    }
  }

  static void _bossSpice(List<List<String>> g, int world) {
    final mid = g.first.length ~/ 2;
    final ground = g.length - 3;
    _platform(g, mid - 4, ground - 5, 3);
    _platform(g, mid + 1, ground - 5, 3);
    _platform(g, mid - 8, ground - 3, 3);
    _platform(g, mid + 5, ground - 3, 3);
    for (var i = 0; i < 8; i++) {
      _coin(g, mid - 3 + i, ground - 6);
    }
    _put(g, mid + 1, ground - 5, '?');
    _put(g, mid + 2, ground - 6, 'M');
    _put(g, mid - 2, ground - 6, 'H');
    _enemy(g, mid - 2, ground);
    _put(g, mid + 6, ground, 'G');
    _put(g, mid - 6, ground, 'R');
    _put(g, mid, ground, 'B');
    _gap(g, mid - 6, 3);
    _gap(g, mid + 4, 3);
    _put(g, mid - 10, ground, 'S');
    _put(g, mid - 14, ground, 'K');
  }

  /// 标志性关卡手调关键段让每世界更有记忆点
  static void _signatureSpice(List<List<String>> g, int world, int level) {
    final w = g.first.length;
    final ground = g.length - 3;
    final anchor = (w * (0.28 + (level % 3) * 0.12)).floor().clamp(12, w - 20);
    // 错落浮岛与弧形糖轨：避开连续同向升高的机械台阶。
    _platform(g, anchor, ground - 3, 5);
    _platform(g, anchor + 8, ground - 5, 3);
    _platform(g, anchor + 15, ground - 2, 4);
    _platform(g, anchor + 22, ground - 4, 3);
    _coin(g, anchor + 4, ground - 4);
    _coin(g, anchor + 5, ground - 5);
    _coin(g, anchor + 6, ground - 5);
    _coin(g, anchor + 7, ground - 4);
    _coin(g, anchor + 9, ground - 6);
    _coin(g, anchor + 10, ground - 6);
    _put(g, anchor + 2, ground - 3, '?');
    _put(g, anchor + 9, ground - 5, 'M');
    _put(g, anchor + 16, ground - 3, 'S');
    _put(g, anchor + 3, ground - 2, 'K');
    if (level >= 4) {
      _put(g, anchor + 9, ground, 'R');
      _put(g, anchor + 14, ground, 'G');
    } else {
      _enemy(g, anchor + 8, ground);
    }
    if (world % 2 == 0) {
      _gap(g, anchor + 20, 2);
      _platform(g, anchor + 23, ground - 2, 3);
      _put(g, anchor + 24, ground - 2, 'H');
    } else {
      _platform(g, anchor + 20, ground - 4, 3);
      _coin(g, anchor + 20, ground - 5);
      _coin(g, anchor + 21, ground - 5);
      _put(g, anchor + 21, ground - 4, '?');
    }
  }
}
