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
    final width = 80 + world * 12 + level * 10;
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

    // Boss 关最后注入，避免被长关填充覆盖
    if (level == 10) {
      _bossSpice(grid, world);
    }

    return grid.map((r) => r.join()).toList();
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
    // 原定太高时，补一阶过渡平台，避免突然够不着
    if (y < py - 1) {
      final stepY = ((py + (g.length - 3)) / 2).floor();
      final mid = _clampPlatY(g, stepY);
      if (mid > py) {
        for (var i = 0; i < len.clamp(1, 3); i++) {
          final px = x + i - 1;
          if (px >= 0 && px < g.first.length) {
            if (g[mid][px] == ' ') {
              g[mid][px] = '=';
            }
          }
        }
      }
    }
    for (var i = 0; i < len; i++) {
      final px = x + i;
      if (px >= 0 && px < g.first.length && py >= 0 && py < g.length) {
        g[py][px] = '=';
      }
    }
  }

  /// 平台高度钳制：相对地面约 2～5 格，保证普通跳跃可达
  static int _clampPlatY(List<List<String>> g, int y) {
    final highest = (g.length - 8).clamp(4, g.length - 5);
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
      final force = ch == '?' ||
          ch == 'S' ||
          ch == 'B' ||
          ch == 'K' ||
          ch == 'G' ||
          ch == 'R' ||
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
    for (var i = 0; i < 5 + level ~/ 2; i++) {
      final y = ground - i.clamp(0, 5);
      _platform(g, x, y, 3);
      _coin(g, x + 1, y - 1);
      x += 5;
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
    _put(g, mid, ground - 5, 'B');
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
    _platform(g, anchor, ground - 3, 5);
    _platform(g, anchor + 7, ground - 5, 3);
    _platform(g, anchor + 12, ground - 2, 4);
    for (var i = 0; i < 5; i++) {
      _coin(g, anchor + i, ground - 4);
    }
    _put(g, anchor + 2, ground - 3, '?');
    _put(g, anchor + 8, ground - 5, 'M');
    _put(g, anchor + 13, ground - 2, 'S');
    if (level >= 4) {
      _put(g, anchor + 4, ground, 'R');
      _put(g, anchor + 10, ground, 'G');
    } else {
      _enemy(g, anchor + 5, ground);
    }
    if (world % 2 == 0) {
      _gap(g, anchor + 16, 2);
      _put(g, anchor + 19, ground, 'H');
    } else {
      _platform(g, anchor + 17, ground - 4, 2);
      _coin(g, anchor + 17, ground - 5);
      _coin(g, anchor + 18, ground - 5);
    }
  }
}
