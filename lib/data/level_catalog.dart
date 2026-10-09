import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/level_names.dart';

/// 99 关全量目录（每关独立构图规则，按世界主题手调）
class LevelCatalog {
  LevelCatalog._();

  static LevelData load(int worldIndex, int levelIndex) {
    final w = worldIndex.clamp(0, GameConstants.worldCount - 1);
    final l = levelIndex.clamp(0, GameConstants.levelsPerWorld - 1);
    final rows = _buildRows(w, l);
    return LevelData(
      worldIndex: w,
      levelIndex: l,
      title: LevelNames.fullTitle(w, l),
      rows: rows,
      difficulty: _difficulty(w, l),
    );
  }

  static int _difficulty(int w, int l) {
    var d = 1 + w + (l ~/ 3);
    if (l == 10) {
      d += 2 + (w ~/ 3);
    }
    return d;
  }

  static List<String> _buildRows(int world, int level) {
    final width = 130 + world * 18 + level * 18;
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
    _addDuckTunnel(grid, world, level);
    _placeSceneCheckpoints(grid);
    _repairEnemyPatrolRoutes(grid);

    return grid.map((r) => r.join()).toList();
  }

  /// 敌人的巡逻范围固定延伸两格，不能让整段范围悬在坑上或压住隧道缓冲区。
  static void _repairEnemyPatrolRoutes(List<List<String>> grid) {
    final ground = grid.length - 3;
    final width = grid.first.length;
    final bossTile = grid[ground].indexOf('B');

    bool hasSafeAnchor(int x) {
      if (x < 4 ||
          x >= width - 4 ||
          bossTile >= 0 && (x - bossTile).abs() <= 6 ||
          (grid[ground + 1][x] != '#' && grid[ground + 2][x] != '#')) {
        return false;
      }
      if ('#=?D'.contains(grid[ground - 1][x])) {
        return false;
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
        if (grid[ground - 1][patrolX] == 'D') {
          return false;
        }
      }
      return true;
    }

    for (var x = 2; x < width - 2; x++) {
      final enemy = grid[ground][x];
      if (!'AEGRT'.contains(enemy) ||
          (hasSafeAnchor(x) &&
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
            if (candidate < 4 ||
                candidate >= width - 4 ||
                grid[ground][candidate] != ' ' ||
                !hasSafeAnchor(candidate) ||
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
      if (destination < 0 && enemy == 'A') {
        continue;
      }
      final landing = destination < 0 ? x : destination;
      clearApproach(landing);
      grid[ground][landing] = enemy;
    }
  }

  /// 四段轮换组合不同玩法，保持长关节奏变化且不强迫玩家走危险路线。
  static void _addSceneChallenges(
    List<List<String>> grid,
    int world,
    int level,
  ) {
    final width = grid.first.length;
    final ground = grid.length - 3;
    final sectionWidth = (width - 8) ~/ 4;
    final difficulty = _difficulty(world, level);
    final rotation = (world * 3 + level) % 5;

    for (var section = 0; section < 4; section++) {
      final start = 4 + section * sectionWidth;
      final x = start + sectionWidth * 2 ~/ 3;
      switch ((rotation + section) % 5) {
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
          _placeSceneEnemy(grid, x + 5, ground, difficulty, world, level);
          _coin(grid, x + 2, ground - 2);
          _coin(grid, x + 3, ground - 2);
          break;
        case 2:
          // 横向枪战：先给发射器，再布置有间距的敌人，留下跳跃/冲刺选择。
          _placeGroundPickup(grid, x, ground, 'W');
          _placeSceneEnemy(grid, x + 5, ground, difficulty, world, level);
          if (difficulty >= 4) {
            _placeSceneEnemy(grid, x + 9, ground, difficulty, world, level);
          }
          break;
        case 3:
          // 载具冲刺：车在障碍前出现，冲撞收益明显；不把车放在坑边。
          _placeGroundPickup(grid, x, ground, 'V');
          _placeSceneEnemy(grid, x + 5, ground, difficulty, world, level);
          if (difficulty >= 5) {
            _placeSceneEnemy(grid, x + 9, ground, difficulty, world, level);
          }
          _coin(grid, x + 6, ground - 2);
          _coin(grid, x + 7, ground - 2);
          break;
        case 4:
          // 技能对抗：预警型怪物搭配高台糖轨，冲刺与跳跃都能应对。
          _placeSceneEnemy(grid, x, ground, difficulty, world, level);
          _platform(grid, x + 4, ground - 3, 3);
          _coin(grid, x + 4, ground - 4);
          if (difficulty >= 5) {
            _placeSceneEnemy(grid, x + 7, ground, difficulty, world, level);
          }
          break;
      }
    }
  }

  /// 每关加入低顶隧道：下蹲取糖或跳上顶棚绕行，地面保持连续。
  static void _addDuckTunnel(
    List<List<String>> grid,
    int world,
    int level,
  ) {
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
        final runwayOverlapsBossPatrol =
            bossTile >= 0 &&
            candidate - 3 <= bossTile + 4 &&
            candidate + length + 2 >= bossTile - 3;
        if (runwayOverlapsBossPatrol) {
          continue;
        }
        var clear = true;
        final movingEnemies = <(int, String)>[];
        for (var x = candidate; x < candidate + length; x++) {
          final tile = grid[ground][x];
          if (grid[ground - 1][x] != ' ' || 'PFBVS?'.contains(tile)) {
            clear = false;
            break;
          }
          if ('AEGRT'.contains(tile)) {
            movingEnemies.add((x, tile));
          }
        }
        if (clear) {
          for (var x = candidate - 2; x < candidate + length + 2; x++) {
            if ((x < candidate || x >= candidate + length) &&
                'AEGRBT'.contains(grid[ground][x])) {
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
      grid[ground - 1][start + i] = 'D';
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
        ![guardX - 2, guardX - 1, guardX + 1, guardX + 2].any(
          (x) => 'AEGRBT'.contains(grid[ground][x]),
        )) {
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
        if (x < 6 || x >= width - 6 ||
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
  ) {
    final width = grid.first.length;
    final sceneType = (world + level) % 5;
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
        ].any((near) => 'AEGRBTWV'.contains(grid[ground][near]))) {
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
          ].any((near) => 'AEGRBTWV'.contains(grid[ground][near]))) {
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
      for (var x = gapStart - 2; x <= gapStart + maxGapTiles + 1; x++) {
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
    String pickup,
  ) {
    for (var offset = 0; offset <= 8; offset++) {
      for (final direction in offset == 0 ? const [1] : const [1, -1]) {
        final x = targetX + offset * direction;
        if (x < 10 || x >= grid.first.length - 8) {
          continue;
        }
        final pickupY = [ground, ground - 2, ground - 3, ground - 4, ground - 5]
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
        ].any((near) => 'AEGRBT'.contains(grid[pickupY][near]));
        if (nearEnemy) {
          continue;
        }
        grid[pickupY][x] = pickup;
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

  static void _worldCreamMeadow(List<List<String>> g, int level) {
    final ground = g.length - 3;
    _platform(g, 6, ground - 1, 4);
    _coin(g, 7, ground - 2);
    _coin(g, 8, ground - 2);
    _put(g, 9, ground - 1, '?');
    _platform(g, 12, ground - 3, 3);
    _coin(g, 13, ground - 4);
    _enemy(g, 10, ground);
    _put(g, 15, ground, 'S');
    if (level >= 2) {
      _gap(g, 17, 2);
    }

    final step = 6 + level;
    for (var x = 16; x < g.first.length - 10; x += step) {
      final platY = ground - 2 - (level % 3);
      _platform(g, x, platY, 3 + (level % 2));
      _coin(g, x + 1, platY - 1);
      if (x % (step * 2) == 0) {
        _put(g, x + 1, platY, '?');
      }
      if (level >= 2 && x % (step * 2) == 0) {
        _enemy(g, x + 2, ground);
      }
      if (level >= 3) {
        _gap(g, x + 3, 2 + (level ~/ 5).clamp(0, 1));
      }
      if (level >= 4 && x % 18 == 0) {
        _put(g, x, platY - 1, 'M');
      }
    }
    if (level >= 4) {
      _put(g, 24, ground - 2, 'H');
    }
    if (level >= 5) {
      _platform(g, 20, ground - 4, 4);
      _platform(g, 28, ground - 5, 3);
      _coin(g, 29, ground - 6);
      _put(g, 30, ground - 5, '?');
    }
  }

  static void _worldStrawberry(List<List<String>> g, int level) {
    final ground = g.length - 3;
    for (var i = 0; i < 6 + level; i++) {
      final x = 7 + i * (5 + level ~/ 3);
      final y = ground - 1 - (i % 4);
      _platform(g, x, y, 2 + (i % 3));
      _coin(g, x, y - 1);
      if (i.isOdd) {
        _enemy(g, x + 1, ground);
      }
      if (level >= 4) {
        _gap(g, x + 2, 2);
      }
    }
    _platform(g, g.first.length ~/ 2, ground - 5, 5);
    for (var c = 0; c < 5; c++) {
      _coin(g, g.first.length ~/ 2 + c, ground - 6);
    }
  }

  static void _worldMint(List<List<String>> g, int level) {
    final ground = g.length - 3;
    for (var x = 6; x < g.first.length - 8; x += 5) {
      final y = ground - 2 - ((x ~/ 5 + level) % 3);
      _platform(g, x, y, 2);
      _coin(g, x, y - 1);
    }
    for (var x = 12; x < g.first.length - 12; x += 9) {
      _gap(g, x, 2 + (level ~/ 6).clamp(0, 1));
      _enemy(g, x - 2, ground);
    }
  }

  static void _worldTaroStar(List<List<String>> g, int level) {
    final ground = g.length - 3;
    for (var i = 0; i < 8 + level; i++) {
      final x = 5 + i * 4;
      final y = ground - 2 - ((i + level) % 4);
      _platform(g, x, y, 2);
      if (i % 2 == 0) {
        _coin(g, x, y - 1);
      } else {
        _enemy(g, x, ground);
      }
    }
    for (var x = 10; x < g.first.length - 10; x += 7) {
      _gap(g, x, 2);
    }
  }

  static void _worldLemonBeach(List<List<String>> g, int level) {
    final ground = g.length - 3;
    for (var x = 8; x < g.first.length - 8; x += 6) {
      _platform(g, x, ground - 1, 4);
      _coin(g, x + 1, ground - 2);
      _coin(g, x + 2, ground - 2);
      if (level >= 2) {
        _enemy(g, x + 3, ground);
      }
      if (level >= 6) {
        _gap(g, x + 4, 2);
        _platform(g, x + 5, ground - 4, 2);
      }
    }
  }

  static void _worldRoseCastle(List<List<String>> g, int level) {
    final ground = g.length - 3;
    var x = 6;
    const islandHeights = [3, 1, 4, 2, 3, 1, 4, 2];
    for (var i = 0; i < 5 + level ~/ 2; i++) {
      final y = ground - islandHeights[(i + level) % islandHeights.length];
      _platform(g, x, y, 2 + (i % 2));
      _coin(g, x + 1, y - 1);
      x += 5 + (i % 2);
    }
    for (var gx = 15; gx < g.first.length - 15; gx += 10) {
      _gap(g, gx, 2);
      _enemy(g, gx - 1, ground);
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

  static void _bossSpice(List<List<String>> g, int world) {
    final mid = g.first.length ~/ 2;
    final ground = g.length - 3;
    _platform(g, mid - 4, ground - 5, 8);
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
