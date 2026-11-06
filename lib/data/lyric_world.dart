import 'package:macaron_girlfriend_run/data/song_profile.dart';

enum LyricLandmark { street, gate, mirror, heartbeat, clock, streetlight }

class LyricChapter {
  const LyricChapter(this.name, this.landmark);
  final String name;
  final LyricLandmark landmark;
}

class LyricWorld {
  LyricWorld._();

  static const chapters = <List<LyricChapter>>[
    [
      LyricChapter('往日街角', LyricLandmark.street),
      LyricChapter('风中的约定', LyricLandmark.street),
      LyricChapter('回首那一天', LyricLandmark.mirror),
    ],
    [
      LyricChapter('踏上归途', LyricLandmark.gate),
      LyricChapter('风沙三关', LyricLandmark.gate),
      LyricChapter('找回相见', LyricLandmark.gate),
    ],
    [
      LyricChapter('你的眼中', LyricLandmark.mirror),
      LyricChapter('两人的距离', LyricLandmark.mirror),
      LyricChapter('未说的答案', LyricLandmark.heartbeat),
    ],
    [
      LyricChapter('悄悄心动', LyricLandmark.heartbeat),
      LyricChapter('靠近的心跳', LyricLandmark.heartbeat),
      LyricChapter('温柔相拥', LyricLandmark.heartbeat),
    ],
    [
      LyricChapter('清晨钟点', LyricLandmark.clock),
      LyricChapter('一起走过的街', LyricLandmark.street),
      LyricChapter('留在回忆里', LyricLandmark.clock),
    ],
    [
      LyricChapter('夜色里的路', LyricLandmark.streetlight),
      LyricChapter('游走与迷失', LyricLandmark.streetlight),
      LyricChapter('远去的灯光', LyricLandmark.streetlight),
    ],
  ];

  static LyricChapter chapterFor(int world, int level) {
    final chapter = (level.clamp(0, 10) * 3 ~/ 11).clamp(0, 2);
    return chapters[SongProfile.songIndexOf(world)][chapter];
  }

  static const preferredSceneKinds = <List<int>>[
    [6, 3, 0], // rooms, streets and steps
    [3, 4, 5], // bridges, gates and valleys
    [6, 2, 5], // rooms, towers and distance
    [7, 6, 3], // gardens, rooms and bridges
    [2, 3, 6], // clocks, streets and rooms
    [5, 2, 3], // valleys, towers and night roads
  ];

  static double sceneBias(int world, int level, int kind) {
    final kinds = preferredSceneKinds[SongProfile.songIndexOf(world)];
    final phase = (level.clamp(0, 10) * 3 ~/ 11).clamp(0, 2);
    return kind == kinds[phase] ? 0.22 : 0;
  }

  static int preferredScene(int world, int level) {
    final phase = (level.clamp(0, 10) * 3 ~/ 11).clamp(0, 2);
    return preferredSceneKinds[SongProfile.songIndexOf(world)][phase];
  }
}
