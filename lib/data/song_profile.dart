/// 歌曲的速度、响度曲线和糖果造型。世界 → 歌的映射只在这里，音频播放和地图共用。
class SongProfile {
  const SongProfile({
    required this.title,
    required this.bpm,
    required this.energy,
    required this.motif,
  });

  /// 歌名，与 AudioService.songs 一致。
  final String title;

  /// 速度（每分钟拍数）。
  final double bpm;

  /// 32 点响度曲线，0 = 最轻，1 = 最响，已按歌曲自身归一化。
  final List<double> energy;

  /// 糖果造型：(dx, dk)，dx 从 0 起向右，dk 从 0 起向上（0 = 最底一行）。
  final List<(int, int)> motif;

  /// 世界 0–8 → 歌下标 0–5。
  static const List<int> worldSongs = [0, 1, 2, 3, 4, 5, 5, 1, 0];

  /// 六首歌，顺序同 AudioService.songs。
  static const List<SongProfile> songs = [
    SongProfile(
      title: '素颜',
      bpm: 84.5,
      energy: [
        0.00,
        0.06,
        0.16,
        0.26,
        0.35,
        0.48,
        0.55,
        0.61,
        0.74,
        0.81,
        0.97,
        0.94,
        0.84,
        0.65,
        0.19,
        0.10,
        0.13,
        0.23,
        0.29,
        0.39,
        0.52,
        0.58,
        0.71,
        0.77,
        0.90,
        1.00,
        0.87,
        0.68,
        0.32,
        0.45,
        0.42,
        0.03,
      ],
      motif: [(1, 4), (3, 4), (0, 3), (4, 3), (1, 2), (3, 2), (2, 1)],
    ),
    SongProfile(
      title: '身骑白马',
      bpm: 130.5,
      energy: [
        0.00,
        0.06,
        0.10,
        0.16,
        0.19,
        0.23,
        0.26,
        0.29,
        0.35,
        0.52,
        0.58,
        0.55,
        0.45,
        0.39,
        0.42,
        0.48,
        0.61,
        0.84,
        0.81,
        0.77,
        0.87,
        0.97,
        0.94,
        0.71,
        0.68,
        0.74,
        0.90,
        1.00,
        0.65,
        0.32,
        0.13,
        0.03,
      ],
      motif: [
        (1, 4),
        (2, 4),
        (3, 4),
        (0, 3),
        (4, 3),
        (0, 2),
        (4, 2),
        (0, 1),
        (4, 1),
      ],
    ),
    SongProfile(
      title: '谁',
      bpm: 143.0,
      energy: [
        0.03,
        0.06,
        0.23,
        0.35,
        0.29,
        0.32,
        0.19,
        0.16,
        0.10,
        0.13,
        0.26,
        0.39,
        0.42,
        0.48,
        0.52,
        0.55,
        0.58,
        0.61,
        0.68,
        0.71,
        0.74,
        0.81,
        0.94,
        1.00,
        0.90,
        0.84,
        0.87,
        0.97,
        0.77,
        0.65,
        0.45,
        0.00,
      ],
      motif: [(1, 4), (2, 4), (3, 4), (4, 3), (2, 2), (3, 2), (2, 0)],
    ),
    SongProfile(
      title: '静悄悄',
      bpm: 88.0,
      energy: [
        0.06,
        0.10,
        0.16,
        0.19,
        0.23,
        0.29,
        0.45,
        0.55,
        0.71,
        1.00,
        0.97,
        0.65,
        0.52,
        0.32,
        0.26,
        0.35,
        0.42,
        0.48,
        0.61,
        0.68,
        0.74,
        0.84,
        0.94,
        0.90,
        0.81,
        0.87,
        0.77,
        0.58,
        0.39,
        0.13,
        0.03,
        0.00,
      ],
      motif: [(1, 4), (2, 4), (0, 3), (0, 2), (0, 1), (1, 0), (2, 0)],
    ),
    SongProfile(
      title: '5点20AM',
      bpm: 125.0,
      energy: [
        0.03,
        0.06,
        0.10,
        0.32,
        0.55,
        0.65,
        0.52,
        0.58,
        0.39,
        0.29,
        0.16,
        0.13,
        0.19,
        0.26,
        0.45,
        0.97,
        0.90,
        0.74,
        0.68,
        0.84,
        0.77,
        0.42,
        0.35,
        0.48,
        1.00,
        0.94,
        0.81,
        0.61,
        0.71,
        0.87,
        0.23,
        0.00,
      ],
      motif: [
        (2, 4),
        (1, 3),
        (3, 3),
        (0, 2),
        (2, 2),
        (4, 2),
        (1, 1),
        (3, 1),
        (2, 0),
      ],
    ),
    SongProfile(
      title: 'Lost',
      bpm: 136.0,
      energy: [
        0.03,
        0.06,
        0.13,
        0.29,
        0.58,
        0.87,
        0.77,
        0.68,
        0.65,
        0.61,
        0.74,
        0.90,
        0.94,
        0.71,
        0.55,
        0.52,
        0.45,
        0.35,
        0.16,
        0.10,
        0.19,
        0.32,
        0.23,
        0.39,
        0.42,
        0.48,
        0.81,
        1.00,
        0.97,
        0.84,
        0.26,
        0.00,
      ],
      motif: [
        (2, 4),
        (3, 3),
        (0, 2),
        (1, 2),
        (2, 2),
        (3, 2),
        (4, 2),
        (3, 1),
        (2, 0),
      ],
    ),
  ];

  /// 世界 → 歌下标，世界号夹紧到 0..8。
  static int songIndexOf(int world) =>
      worldSongs[world.clamp(0, worldSongs.length - 1)];

  /// 世界对应的歌。
  static SongProfile of(int world) => songs[songIndexOf(world)];

  /// 一小节（4 拍）的格数：clamp(1840 ÷ 速度, 12, 24)。
  static int barTiles(int world) =>
      (1840 / of(world).bpm).round().clamp(12, 24);

  /// 第 level 关（0..10）窗口的起点，占整首歌的比例；窗口长 0.5。
  static double windowStart(int level) => level / 10 * 0.5;

  /// 第 level 关内横向进度 t（夹紧到 0..1）处的响度，按 32 点曲线线性插值。
  static double levelEnergyAt(int world, int level, double t) {
    final e = of(world).energy;
    final p =
        (windowStart(level) + t.clamp(0.0, 1.0) * 0.5).clamp(0.0, 1.0) *
        (e.length - 1);
    final i = p.floor();
    if (i >= e.length - 1) {
      return e.last;
    }
    return e[i] + (e[i + 1] - e[i]) * (p - i);
  }
}
