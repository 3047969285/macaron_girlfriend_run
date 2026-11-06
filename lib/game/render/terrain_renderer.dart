import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macaron_girlfriend_run/data/song_profile.dart';
import 'package:macaron_girlfriend_run/data/audio_service.dart';
import 'package:macaron_girlfriend_run/data/synced_lyrics.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/level_scenes.dart';
import 'package:macaron_girlfriend_run/data/lyric_world.dart';
import 'package:macaron_girlfriend_run/data/song_world_theme.dart';
import 'package:macaron_girlfriend_run/theme/macaron_colors.dart';

int _sceneValue(int seed, int lane, int salt) =>
    (seed * 73 + lane * 151 + salt * 199 + (seed ~/ 3) * 17) % 997;

/// 地形块
class TerrainTile {
  const TerrainTile({
    required this.rect,
    required this.isGround,
    this.isDuckCeiling = false,
  });

  final Rect rect;
  final bool isGround;
  final bool isDuckCeiling;
}

/// 平台跳跃地形与装饰绘制（离屏 Picture 缓存，避免每帧重绘砖块）
class TerrainRenderer extends PositionComponent {
  TerrainRenderer({
    required this.solids,
    required this.palette,
    required this.mapWidth,
    required this.groundY,
    required this.sceneSeed,
    this.worldIndex,
    this.enableSyncedLyrics = false,
    this.lyricChapter,
    this.scenes = const [],
    this.songTheme,
  }) : super(priority: 0);

  final List<TerrainTile> solids;
  final WorldPalette palette;
  final double mapWidth;
  final double groundY;
  final int sceneSeed;
  final int? worldIndex;
  final bool enableSyncedLyrics;
  final LyricChapter? lyricChapter;
  final List<PlacedScene> scenes;
  final SongWorldTheme? songTheme;

  ui.Picture? _picture;
  List<LyricLine> _lyrics = const [];
  List<Rect> _lyricAreas = const [];
  TextPainter? _lyricPainter;
  String? _paintedLyric;
  bool _removed = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _rebuildPicture();
    if (enableSyncedLyrics && worldIndex != null) {
      _lyricAreas = _makeLyricAreas();
      unawaited(_loadLyrics());
    }
  }

  Future<void> _loadLyrics() async {
    final result = await SyncedLyrics.instance.load(
      SongProfile.songIndexOf(worldIndex!),
    );
    if (!_removed) _lyrics = result;
  }

  List<Rect> _makeLyricAreas() {
    final rows = <double, List<Rect>>{};
    for (final tile in solids) {
      if (tile.isDuckCeiling ||
          (tile.isGround && tile.rect.bottom > groundY + .5)) {
        continue;
      }
      (rows[tile.rect.top] ??= []).add(tile.rect);
    }
    final areas = <Rect>[];
    for (final row in rows.values) {
      row.sort((a, b) => a.left.compareTo(b.left));
      var area = row.first;
      for (final next in row.skip(1)) {
        if (next.left <= area.right + .5 &&
            (next.height - area.height).abs() < .5) {
          area = area.expandToInclude(next);
        } else {
          areas.add(area);
          area = next;
        }
      }
      areas.add(area);
    }
    return areas;
  }

  void _drawLiveLyrics(Canvas canvas) {
    final audio = AudioService.instance;
    final time = audio.currentSongPosition;
    final song = worldIndex == null
        ? null
        : SongProfile.songIndexOf(worldIndex!);
    final lyric = time == null || audio.currentSong != song
        ? null
        : SyncedLyrics.lineAt(_lyrics, time);
    if (lyric == null) return;
    if (_paintedLyric != lyric) {
      _lyricPainter?.dispose();
      _paintedLyric = lyric;
      _lyricPainter = TextPainter(
        text: TextSpan(
          text: lyric,
          style: TextStyle(
            fontFamily: MacaronColors.fontFamily,
            fontFamilyFallback: MacaronColors.fontFallback,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF352A32),
            shadows: const [Shadow(color: Colors.white, blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
    }
    final painter = _lyricPainter!;
    final clip = canvas.getLocalClipBounds();
    for (final area in _lyricAreas) {
      if (!area.overlaps(clip) || area.width < 24) continue;
      canvas.save();
      canvas.clipRect(area);
      final segment = math.min(300.0, area.width);
      final scale = math.min(1.0, (segment - 8) / math.max(1, painter.width));
      final first = math.max(0, ((clip.left - area.left) / segment).floor());
      for (
        var x = area.left + first * segment;
        x < area.right && x < clip.right;
        x += segment
      ) {
        final width = math.min(segment, area.right - x);
        canvas.save();
        canvas.translate(
          x + (width - painter.width * scale) / 2,
          area.center.dy - painter.height * scale / 2,
        );
        canvas.scale(scale);
        painter.paint(canvas, Offset.zero);
        canvas.restore();
      }
      canvas.restore();
    }
  }

  @override
  void onRemove() {
    _removed = true;
    _lyricPainter?.dispose();
    _picture?.dispose();
    _picture = null;
    super.onRemove();
  }

  void _rebuildPicture() {
    _picture?.dispose();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _drawTerrain(canvas);
    _drawScenery(canvas);
    _picture = recorder.endRecording();
  }

  @override
  void render(Canvas canvas) {
    final pic = _picture;
    if (pic != null) {
      canvas.drawPicture(pic);
      if (enableSyncedLyrics) _drawLiveLyrics(canvas);
      return;
    }
    _drawTerrain(canvas);
    _drawScenery(canvas);
    if (enableSyncedLyrics) _drawLiveLyrics(canvas);
  }

  void _drawTerrain(Canvas canvas) {
    _drawLyricLandmarks(canvas);
    final platformRows = <double, List<Rect>>{};
    final duckCeilingRows = <double, List<Rect>>{};
    for (final tile in solids) {
      if (tile.isGround) {
        _drawGroundBlock(canvas, tile.rect);
      } else {
        final rows = tile.isDuckCeiling ? duckCeilingRows : platformRows;
        rows.putIfAbsent(tile.rect.top, () => []).add(tile.rect);
      }
    }
    _drawPlatformRows(canvas, platformRows);
    _drawPlatformRows(canvas, duckCeilingRows, duckCeiling: true);
  }

  void _drawLyricLandmarks(Canvas canvas) {
    final chapter = lyricChapter;
    if (chapter == null) return;
    final ink = Paint()
      ..color = palette.groundDark.withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final light = Paint()..color = palette.accent.withValues(alpha: 0.35);
    for (var i = 0; i < scenes.length; i++) {
      final scene = scenes[i];
      final x = (scene.x + scene.width / 2) * GameConstants.tileSize;
      final y = groundY - 95;
      canvas.save();
      canvas.translate(x, y);
      if (scene.lyricRoute != null) {
        _drawWorldSetPiece(canvas);
        _drawChapterStory(canvas, chapter, scene.mirrored);
      }
      // 建筑远景只参与绘制，不改变实体碰撞或可通过路线。
      final distant = Paint()
        ..color = palette.groundDark.withValues(alpha: 0.12);
      final glow = Paint()..color = palette.accent.withValues(alpha: 0.18);
      final variant = _sceneValue(sceneSeed, i, 29);
      for (var j = 0; j < 5; j++) {
        final dx = -160.0 + j * 75 + ((variant + j * 37) % 24);
        final height = 36.0 + ((variant + j * 53) % 62);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(dx, -height, 48, height),
            const Radius.circular(8),
          ),
          distant,
        );
        canvas.drawCircle(Offset(dx + 24, -height + 14), 3, glow);
      }
      switch (chapter.landmark) {
        case LyricLandmark.street:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(-65, -150, 130, 145),
              const Radius.circular(8),
            ),
            light,
          );
          canvas.drawRect(const Rect.fromLTWH(-58, -142, 116, 137), ink);
          for (final dx in [-36.0, 12.0]) {
            canvas.drawRect(Rect.fromLTWH(dx, -120, 27, 35), ink);
            canvas.drawLine(Offset(dx, -102), Offset(dx + 27, -102), ink);
          }
          canvas.drawRect(const Rect.fromLTWH(-16, -62, 32, 57), ink);
        case LyricLandmark.gate:
          final centers = scene.lyricRoute == null
              ? [0.0]
              : [-120.0, 0.0, 120.0];
          for (final center in centers) {
            final path = Path()
              ..moveTo(center - 45, 0)
              ..lineTo(center - 45, -120)
              ..quadraticBezierTo(center, -175, center + 45, -120)
              ..lineTo(center + 45, 0);
            canvas.drawPath(path, ink..strokeWidth = 10);
            canvas.drawLine(
              Offset(center - 55, -118),
              Offset(center + 55, -118),
              ink,
            );
            canvas.drawCircle(Offset(center, -145), 10, light);
          }
          ink.strokeWidth = 6;
        case LyricLandmark.mirror:
          canvas.drawOval(const Rect.fromLTWH(-50, -160, 100, 130), light);
          canvas.drawOval(const Rect.fromLTWH(-50, -160, 100, 130), ink);
          canvas.drawLine(const Offset(-28, -120), const Offset(-5, -144), ink);
          canvas.drawLine(const Offset(-20, -105), const Offset(5, -130), ink);
          canvas.drawLine(const Offset(0, -30), const Offset(0, 0), ink);
        case LyricLandmark.heartbeat:
          final heart = Path()
            ..moveTo(0, -50)
            ..cubicTo(-120, -115, -44, -185, 0, -138)
            ..cubicTo(44, -185, 120, -115, 0, -50)
            ..close();
          canvas.drawPath(heart, light);
          canvas.drawPath(heart, ink);
          final pulse = Path()
            ..moveTo(-48, -102)
            ..lineTo(-20, -102)
            ..lineTo(-10, -120)
            ..lineTo(0, -82)
            ..lineTo(10, -105)
            ..lineTo(48, -105);
          canvas.drawPath(pulse, ink);
        case LyricLandmark.clock:
          canvas.drawCircle(const Offset(0, -105), 55, light);
          canvas.drawCircle(const Offset(0, -105), 55, ink);
          canvas.drawLine(const Offset(0, -105), const Offset(0, -140), ink);
          canvas.drawLine(const Offset(0, -105), const Offset(29, -86), ink);
          canvas.drawLine(const Offset(0, -50), const Offset(0, 0), ink);
        case LyricLandmark.streetlight:
          canvas.drawLine(const Offset(0, 0), const Offset(0, -152), ink);
          canvas.drawLine(const Offset(0, -152), const Offset(42, -152), ink);
          canvas.drawCircle(const Offset(42, -142), 15, light);
          canvas.drawLine(const Offset(25, -142), const Offset(59, -142), ink);
      }
      if (scene.lyricRoute case final name?) {
        _songText(canvas, name, const Offset(0, -198), 18, palette.groundDark);
        _songText(
          canvas,
          chapter.name,
          const Offset(0, -221),
          12,
          palette.groundDark.withValues(alpha: 0.75),
        );
      }
      canvas.restore();
    }
  }

  void _drawChapterStory(Canvas canvas, LyricChapter chapter, bool mirrored) {
    final song = LyricWorld.chapters.indexWhere(
      (chapters) => chapters.any((item) => item.name == chapter.name),
    );
    if (song < 0) return;
    final phase = LyricWorld.chapters[song].indexWhere(
      (item) => item.name == chapter.name,
    );
    final line = Paint()
      ..color = palette.groundDark.withValues(alpha: 0.58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = palette.accent.withValues(alpha: 0.55);
    canvas.save();
    if (mirrored) canvas.scale(-1, 1);
    canvas.translate(-115, -30);
    switch (song) {
      case 0:
        // 旧街的信箱、雨伞与相片，对应相遇、雨中和回望。
        if (phase == 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(-15, -46, 30, 36),
              const Radius.circular(5),
            ),
            fill,
          );
          canvas.drawLine(const Offset(-10, -36), const Offset(10, -36), line);
          canvas.drawLine(const Offset(0, -10), const Offset(0, 0), line);
        } else if (phase == 1) {
          canvas.drawPath(
            Path()
              ..moveTo(-30, -26)
              ..quadraticBezierTo(0, -65, 30, -26),
            line,
          );
          canvas.drawLine(const Offset(0, -45), const Offset(0, -7), line);
          canvas.drawArc(
            const Rect.fromLTWH(0, -13, 12, 12),
            0,
            math.pi,
            false,
            line,
          );
          for (final x in [-40.0, -25.0, 24.0, 40.0]) {
            canvas.drawLine(Offset(x, -60), Offset(x - 4, -50), line);
          }
        } else {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(-25, -65, 50, 55),
              const Radius.circular(4),
            ),
            line,
          );
          canvas.drawCircle(const Offset(-8, -46), 6, fill);
          canvas.drawPath(
            Path()
              ..moveTo(-20, -20)
              ..lineTo(-5, -35)
              ..lineTo(4, -27)
              ..lineTo(13, -38)
              ..lineTo(21, -20),
            line,
          );
        }
      case 1:
        // 驿旗、三关与归处的灯。
        if (phase == 0) {
          canvas.drawLine(const Offset(-12, 0), const Offset(-12, -70), line);
          canvas.drawPath(
            Path()
              ..moveTo(-12, -68)
              ..lineTo(26, -59)
              ..lineTo(-12, -48)
              ..close(),
            fill,
          );
        } else if (phase == 1) {
          for (final x in [-36.0, 0.0, 36.0]) {
            canvas.drawPath(
              Path()
                ..moveTo(x - 12, 0)
                ..lineTo(x - 12, -40)
                ..quadraticBezierTo(x, -56, x + 12, -40)
                ..lineTo(x + 12, 0),
              line,
            );
          }
        } else {
          canvas.drawLine(const Offset(0, 0), const Offset(0, -58), line);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(-13, -70, 26, 24),
              const Radius.circular(5),
            ),
            fill,
          );
          canvas.drawCircle(const Offset(0, -58), 5, line);
        }
      case 2:
        // 两面镜子从相对、拉远到交叠。
        final distance = [12.0, 28.0, 5.0][phase];
        for (final x in [-distance, distance]) {
          canvas.drawOval(
            Rect.fromCenter(center: Offset(x, -42), width: 28, height: 46),
            line,
          );
          canvas.drawLine(Offset(x - 6, -40), Offset(x + 4, -51), line);
          canvas.drawLine(Offset(x, -19), Offset(x, 0), line);
        }
      case 3:
        // 花蕾、并肩的花与相连的花冠。
        for (var i = 0; i <= phase; i++) {
          final x = (i - phase / 2) * 25;
          canvas.drawLine(Offset(x, 0), Offset(x, -36), line);
          for (var petal = 0; petal < 5; petal++) {
            final a = petal * math.pi * 2 / 5;
            canvas.drawCircle(
              Offset(x + math.cos(a) * 8, -40 + math.sin(a) * 8),
              5,
              fill,
            );
          }
          canvas.drawCircle(Offset(x, -40), 3, line);
        }
      case 4:
        // 清晨闹钟、街巷窗户与留在长椅上的回忆。
        if (phase == 0) {
          canvas.drawCircle(const Offset(0, -39), 23, line);
          canvas.drawLine(const Offset(0, -39), const Offset(-10, -48), line);
          canvas.drawLine(const Offset(0, -39), const Offset(14, -32), line);
          canvas.drawCircle(const Offset(-17, -60), 7, fill);
          canvas.drawCircle(const Offset(17, -60), 7, fill);
        } else if (phase == 1) {
          for (final x in [-20.0, 12.0]) {
            canvas.drawRect(Rect.fromLTWH(x, -64, 24, 38), line);
            canvas.drawLine(Offset(x + 12, -64), Offset(x + 12, -26), line);
            canvas.drawLine(Offset(x, -45), Offset(x + 24, -45), line);
          }
        } else {
          canvas.drawLine(const Offset(-35, -25), const Offset(35, -25), line);
          canvas.drawLine(const Offset(-30, -39), const Offset(30, -39), line);
          canvas.drawLine(const Offset(-25, -39), const Offset(-25, 0), line);
          canvas.drawLine(const Offset(25, -39), const Offset(25, 0), line);
          canvas.drawCircle(const Offset(0, -49), 8, fill);
        }
      case 5:
        // 夜路的方向牌、岔路和远方灯火。
        if (phase < 2) {
          canvas.drawLine(const Offset(0, 0), const Offset(0, -70), line);
          for (var i = 0; i <= phase; i++) {
            final y = -62.0 + i * 22;
            final sign = Path()
              ..moveTo(-27, y)
              ..lineTo(18, y)
              ..lineTo(29, y + 7)
              ..lineTo(18, y + 14)
              ..lineTo(-27, y + 14)
              ..close();
            canvas.save();
            if (i == 1) canvas.scale(-1, 1);
            canvas.drawPath(sign, fill);
            canvas.drawPath(sign, line);
            canvas.restore();
          }
        } else {
          for (final x in [-28.0, 0.0, 28.0]) {
            canvas.drawLine(
              Offset(x, 0),
              Offset(x, -45 - (x == 0 ? 14 : 0)),
              line,
            );
            canvas.drawCircle(Offset(x, -49 - (x == 0 ? 14 : 0)), 8, fill);
          }
        }
    }
    canvas.restore();
  }

  void _drawWorldSetPiece(Canvas canvas) {
    final silhouette = Paint()
      ..color = palette.groundDark.withValues(alpha: 0.18);
    final accent = Paint()..color = palette.accent.withValues(alpha: 0.32);
    final line = Paint()
      ..color = palette.groundDark.withValues(alpha: 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    switch (palette.name) {
      case '奶油草地':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-150, -175, 300, 175),
            const Radius.circular(8),
          ),
          silhouette,
        );
        for (final x in [-105.0, -35.0, 35.0, 105.0]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x - 20, -145, 40, 52),
              const Radius.circular(18),
            ),
            accent,
          );
          canvas.drawLine(Offset(x, -142), Offset(x, -96), line);
        }
      case '草莓甜点':
        for (final x in [-120.0, 0.0, 120.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(x - 38, 0)
              ..lineTo(x - 38, -135)
              ..quadraticBezierTo(x, -185, x + 38, -135)
              ..lineTo(x + 38, 0),
            line,
          );
          canvas.drawPath(
            Path()
              ..moveTo(x - 40, -142)
              ..lineTo(x, -168)
              ..lineTo(x + 40, -142)
              ..close(),
            accent,
          );
        }
      case '薄荷汽水':
        for (final x in [-90.0, 90.0]) {
          canvas.drawOval(
            Rect.fromCenter(center: Offset(x, -110), width: 105, height: 150),
            silhouette,
          );
          canvas.drawOval(
            Rect.fromCenter(center: Offset(x, -110), width: 105, height: 150),
            line,
          );
          canvas.drawLine(Offset(x - 20, -100), Offset(x + 15, -140), line);
        }
      case '香芋星空':
        for (final x in [-125.0, 0.0, 125.0]) {
          canvas.drawLine(Offset(x, 0), Offset(x, -160), line);
          canvas.drawCircle(Offset(x, -160), 26, accent);
          canvas.drawLine(Offset(x - 12, -160), Offset(x + 12, -160), line);
          canvas.drawLine(Offset(x, -172), Offset(x, -148), line);
        }
      case '柠檬沙滩':
        for (var i = 0; i < 5; i++) {
          final x = -145.0 + i * 62;
          final h = 90.0 + (i % 3) * 35;
          canvas.drawRect(Rect.fromLTWH(x, -h, 50, h), silhouette);
          for (var row = 0; row < 3; row++) {
            canvas.drawRect(
              Rect.fromLTWH(x + 10, -h + 18 + row * 20, 8, 10),
              accent,
            );
            canvas.drawRect(
              Rect.fromLTWH(x + 30, -h + 18 + row * 20, 8, 10),
              accent,
            );
          }
        }
      case '玫瑰城堡':
        canvas.drawRect(const Rect.fromLTWH(-110, -130, 220, 130), silhouette);
        for (final x in [-100.0, 100.0]) {
          canvas.drawRect(Rect.fromLTWH(x - 26, -175, 52, 175), silhouette);
          canvas.drawPath(
            Path()
              ..moveTo(x - 34, -175)
              ..lineTo(x, -220)
              ..lineTo(x + 34, -175)
              ..close(),
            accent,
          );
        }
      case '蓝莓峡谷':
        canvas.drawPath(
          Path()
            ..moveTo(-170, 0)
            ..lineTo(-100, -180)
            ..lineTo(-20, -45)
            ..lineTo(55, -210)
            ..lineTo(170, 0)
            ..close(),
          silhouette,
        );
        canvas.drawPath(
          Path()
            ..moveTo(-115, -145)
            ..lineTo(-100, -180)
            ..lineTo(-75, -138)
            ..moveTo(35, -160)
            ..lineTo(55, -210)
            ..lineTo(85, -155),
          line,
        );
      case '焦糖矿山':
        for (final x in [-95.0, 95.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(x - 65, 0)
              ..lineTo(x - 65, -150)
              ..lineTo(x + 65, -150)
              ..lineTo(x + 65, 0),
            line,
          );
          canvas.drawLine(Offset(x - 65, -150), Offset(x + 65, 0), line);
          canvas.drawLine(Offset(x + 65, -150), Offset(x - 65, 0), line);
        }
      case '蜜月彩虹':
        for (var i = 0; i < 4; i++) {
          canvas.drawArc(
            Rect.fromCenter(
              center: const Offset(0, 0),
              width: 300 - i * 25,
              height: 300 - i * 25,
            ),
            math.pi,
            math.pi,
            false,
            Paint()
              ..color = [
                palette.accent,
                MacaronColors.rose,
                MacaronColors.lemon,
                MacaronColors.sky,
              ][i].withValues(alpha: 0.28)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 10,
          );
        }
    }
  }

  void _drawPlatformRows(
    Canvas canvas,
    Map<double, List<Rect>> rows, {
    bool duckCeiling = false,
  }) {
    // 把同一高度相连的瓦片画成整片软边浮台，去掉逐块描边的砖阶感。
    for (final row in rows.values) {
      row.sort((a, b) => a.left.compareTo(b.left));
      var left = row.first.left;
      var right = row.first.right;
      var top = row.first.top;
      var bottom = row.first.bottom;
      for (final rect in row.skip(1)) {
        if (rect.left <= right + 0.5) {
          right = right > rect.right ? right : rect.right;
          bottom = bottom > rect.bottom ? bottom : rect.bottom;
          continue;
        }
        _drawPlatformCluster(
          canvas,
          Rect.fromLTRB(left, top, right, bottom),
          duckCeiling: duckCeiling,
        );
        left = rect.left;
        right = rect.right;
        top = rect.top;
        bottom = rect.bottom;
      }
      _drawPlatformCluster(
        canvas,
        Rect.fromLTRB(left, top, right, bottom),
        duckCeiling: duckCeiling,
      );
    }
  }

  void _drawGroundBlock(Canvas canvas, Rect r) {
    final isSurface = r.bottom <= groundY + 0.5;
    final body = Paint()
      ..color = isSurface
          ? Color.lerp(palette.ground, palette.groundDark, 0.3)!
          : Color.lerp(palette.groundDark, palette.skyBottom, 0.16)!;
    canvas.drawRect(r, body);
    final crumbs = Paint()..color = palette.accent.withValues(alpha: 0.22);
    final tileX = (r.left / r.width).round();
    for (var i = 0; i < 2; i++) {
      final x = r.left + 8 + _sceneValue(sceneSeed, tileX, i + 7) % 32;
      final y = r.top + 16 + _sceneValue(sceneSeed, tileX, i + 11) % 24;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 3.5, height: 2.5),
        crumbs,
      );
    }
    if (!isSurface) return;

    if (songTheme != null) {
      _drawSongSurface(canvas, r, songTheme!);
      return;
    }
    if (_drawThemedSurface(canvas, r)) {
      return;
    }

    final grass = Paint()..color = palette.ground;
    canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 8), grass);
    final softEdge = Paint()
      ..color = Color.lerp(palette.ground, Colors.white, 0.18)!;
    for (var x = r.left + 8; x < r.right; x += 16) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, r.top + 5), width: 12, height: 8),
        softEdge,
      );
    }
    canvas.drawLine(
      Offset(r.left, r.top),
      Offset(r.right, r.top),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.38)
        ..strokeWidth = 1.2,
    );
  }

  void _drawPlatformCluster(Canvas canvas, Rect r, {bool duckCeiling = false}) {
    final radius = Radius.circular(
      duckCeiling
          ? 8
          : switch (palette.name) {
              '草莓甜点' || '蜜月彩虹' => 12,
              '薄荷汽水' => 9,
              '玫瑰城堡' || '蓝莓峡谷' || '焦糖矿山' => 4,
              _ => 6,
            },
    );
    final rrect = RRect.fromRectAndRadius(r, radius);
    canvas.drawRRect(
      RRect.fromRectAndRadius(r.shift(const Offset(0, 4)), radius),
      Paint()..color = palette.groundDark.withValues(alpha: 0.34),
    );
    final material = switch (palette.name) {
      '奶油草地' => const Color(0xFFC79C79),
      '草莓甜点' => const Color(0xFFEAA5BA),
      '薄荷汽水' => const Color(0xFF87CFC7),
      '香芋星空' => const Color(0xFF7760AC),
      '柠檬沙滩' => const Color(0xFFCBA672),
      '玫瑰城堡' => const Color(0xFFCC9CAE),
      '蓝莓峡谷' => const Color(0xFF738CB1),
      '焦糖矿山' => const Color(0xFFAE784F),
      '蜜月彩虹' => const Color(0xFFD8E9F6),
      _ => palette.accent,
    };
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(material, Colors.white, 0.3)!,
            material,
            Color.lerp(material, palette.groundDark, 0.32)!,
          ],
        ).createShader(r),
    );
    if (!duckCeiling) {
      canvas.save();
      canvas.clipRRect(rrect);
      _drawPlatformMaterial(canvas, r);
      canvas.restore();
    }
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.52)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.drawLine(
      Offset(r.left + radius.x, r.top + 3),
      Offset(r.right - radius.x, r.top + 3),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.48)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    if (duckCeiling) {
      final marker = Paint()
        ..color = palette.accent.withValues(alpha: 0.76)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      for (var x = r.left + 14; x < r.right - 6; x += 24) {
        canvas.drawLine(
          Offset(x, r.bottom - 3),
          Offset(x + 8, r.bottom - 3),
          marker,
        );
      }
    }
  }

  void _drawPlatformMaterial(Canvas canvas, Rect r) {
    if (songTheme != null) {
      _drawSongPlatform(canvas, r, songTheme!);
      return;
    }
    final seam = Paint()
      ..color = palette.groundDark.withValues(alpha: 0.42)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final cream = Paint()..color = const Color(0xFFFFF3DB);
    final center = r.center;
    switch (palette.name) {
      case '奶油草地':
        for (var x = r.left - r.height; x < r.right; x += 18) {
          canvas.drawLine(
            Offset(x, r.bottom),
            Offset(x + r.height, r.top),
            seam,
          );
          canvas.drawLine(
            Offset(x, r.top),
            Offset(x + r.height, r.bottom),
            seam,
          );
        }
        _drawMeadowTurf(canvas, r);
      case '草莓甜点':
        canvas.drawRect(Rect.fromLTWH(r.left, r.top + 20, r.width, 7), cream);
        canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 9), cream);
        for (var x = r.left + 8; x < r.right; x += 22) {
          canvas.drawCircle(Offset(x, r.top + 8), 5, cream);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(x + 5, r.bottom - 10),
              width: 2.5,
              height: 4,
            ),
            Paint()..color = const Color(0xFFFFE6A7),
          );
        }
      case '薄荷汽水':
        for (var i = 0; i < (r.width / 23).ceil(); i++) {
          final x = r.left + 12 + i * 23;
          final y = r.top + 20 + (i % 2) * 12;
          canvas.drawCircle(
            Offset(x, y),
            4 + i % 3,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.75)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }
        canvas.drawLine(
          Offset(r.left + 8, r.bottom - 6),
          Offset(r.left + 19, r.top + 13),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.55)
            ..strokeWidth = 3,
        );
        _drawCap(canvas, r, const Color(0xFFDFFFF5), Colors.white);
      case '香芋星空':
        for (var x = r.left; x < r.right; x += 40) {
          canvas.drawPath(
            Path()
              ..moveTo(x, r.bottom)
              ..lineTo(x + 20, r.top)
              ..lineTo(x + 40, r.bottom)
              ..close(),
            Paint()..color = const Color(0xFFC7A9EA).withValues(alpha: 0.3),
          );
        }
        for (var x = r.left + 23; x < r.right; x += 48) {
          final star = Path()
            ..moveTo(x, center.dy - 7)
            ..lineTo(x + 2, center.dy - 2)
            ..lineTo(x + 7, center.dy)
            ..lineTo(x + 2, center.dy + 2)
            ..lineTo(x, center.dy + 7)
            ..lineTo(x - 2, center.dy + 2)
            ..lineTo(x - 7, center.dy)
            ..lineTo(x - 2, center.dy - 2)
            ..close();
          canvas.drawPath(star, Paint()..color = const Color(0xFFFFE8AA));
        }
      case '柠檬沙滩':
        for (var x = r.left + 24; x < r.right; x += 24) {
          canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), seam);
        }
        for (final y in [r.top + 12, r.bottom - 10]) {
          canvas.drawLine(Offset(r.left + 7, y), Offset(r.right - 7, y), seam);
        }
        for (var x = r.left + 12; x < r.right; x += 24) {
          canvas.drawCircle(
            Offset(x, r.top + 6),
            1.8,
            Paint()..color = const Color(0xFF856746),
          );
        }
      case '玫瑰城堡':
        canvas.drawLine(
          Offset(r.left, center.dy),
          Offset(r.right, center.dy),
          seam,
        );
        for (var x = r.left + 24; x < r.right; x += 48) {
          canvas.drawLine(Offset(x, r.top), Offset(x, center.dy), seam);
          canvas.drawLine(
            Offset(x + 24, center.dy),
            Offset(x + 24, r.bottom),
            seam,
          );
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: 17, height: 24),
            const Radius.circular(8),
          ),
          cream,
        );
        canvas.drawCircle(center, 4, Paint()..color = palette.accent);
      case '蓝莓峡谷':
        for (var i = 0; i < 3; i++) {
          final y = r.top + 13 + i * 12;
          canvas.drawPath(
            Path()
              ..moveTo(r.left, y)
              ..lineTo(r.left + r.width * 0.35, y - 5)
              ..lineTo(r.left + r.width * 0.7, y + 2)
              ..lineTo(r.right, y - 3),
            seam,
          );
        }
        canvas.drawPath(
          Path()
            ..moveTo(center.dx + 8, r.top + 4)
            ..lineTo(center.dx, center.dy)
            ..lineTo(center.dx + 5, r.bottom),
          seam,
        );
      case '焦糖矿山':
        canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 7), cream);
        for (var x = r.left + 7; x < r.right; x += 36) {
          canvas.drawLine(
            Offset(x, r.top + 10),
            Offset(x + 26, r.bottom - 5),
            seam,
          );
          canvas.drawLine(
            Offset(x + 26, r.top + 10),
            Offset(x, r.bottom - 5),
            seam,
          );
        }
        final gem = Path()
          ..moveTo(center.dx, r.top + 11)
          ..lineTo(center.dx + 7, center.dy)
          ..lineTo(center.dx, r.bottom - 7)
          ..lineTo(center.dx - 7, center.dy)
          ..close();
        canvas.drawPath(gem, Paint()..color = const Color(0xFFFFD98A));
      case '蜜月彩虹':
        _drawRainbowCap(canvas, Rect.fromLTWH(r.left, r.top + 18, r.width, 10));
        for (var x = r.left + 9; x < r.right; x += 19) {
          canvas.drawCircle(
            Offset(x, r.top + 7),
            9,
            Paint()..color = Colors.white,
          );
        }
      default:
        _drawCap(canvas, r, palette.ground, palette.accent);
    }
  }

  void _drawSongSurface(Canvas canvas, Rect r, SongWorldTheme theme) {
    canvas.drawRect(
      Rect.fromLTWH(r.left, r.top, r.width, 7),
      Paint()..color = theme.light,
    );
    final ink = Paint()
      ..color = theme.dark.withValues(alpha: .6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (var x = r.left + 8; x < r.right; x += 16) {
      switch (theme) {
        case SongWorldTheme.firstLove:
          canvas.drawArc(
            Rect.fromCenter(center: Offset(x, r.top + 6), width: 11, height: 7),
            0,
            math.pi,
            false,
            ink,
          );
        case SongWorldTheme.whiteHorse:
          canvas.drawLine(
            Offset(x - 5, r.top + 12),
            Offset(x + 5, r.top + 12),
            ink,
          );
        case SongWorldTheme.reflection:
          canvas.drawPath(
            Path()
              ..moveTo(x, r.top + 8)
              ..lineTo(x + 4, r.top + 13)
              ..lineTo(x, r.top + 18)
              ..lineTo(x - 4, r.top + 13)
              ..close(),
            ink,
          );
        case SongWorldTheme.quietLove:
          canvas.drawCircle(Offset(x, r.top + 11), 3, ink);
        case SongWorldTheme.dawn:
          canvas.drawLine(Offset(x, r.top + 7), Offset(x, r.top + 15), ink);
        case SongWorldTheme.lost:
          canvas.drawCircle(
            Offset(x, r.top + 12),
            2,
            Paint()..color = theme.light,
          );
      }
    }
  }

  void _drawSongPlatform(Canvas canvas, Rect r, SongWorldTheme theme) {
    final ink = Paint()
      ..color = theme.dark.withValues(alpha: .55)
      ..strokeWidth = 1.7
      ..style = PaintingStyle.stroke;
    canvas.drawRect(
      Rect.fromLTWH(r.left, r.top, r.width, 7),
      Paint()..color = theme.light.withValues(alpha: .85),
    );
    for (var x = r.left + 12; x < r.right - 4; x += 28) {
      switch (theme) {
        case SongWorldTheme.firstLove:
          break;
        case SongWorldTheme.whiteHorse:
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(x, r.center.dy),
              width: 25,
              height: 16,
            ),
            ink,
          );
          canvas.drawLine(
            Offset(x, r.center.dy - 8),
            Offset(x, r.center.dy + 8),
            ink,
          );
        case SongWorldTheme.reflection:
          canvas.drawLine(
            Offset(x - 10, r.bottom - 7),
            Offset(x + 8, r.top + 8),
            ink,
          );
        case SongWorldTheme.quietLove:
          canvas.drawCircle(Offset(x, r.center.dy), 5, ink);
          for (final dx in [-7.0, 7.0]) {
            canvas.drawCircle(Offset(x + dx, r.center.dy), 3, ink);
          }
        case SongWorldTheme.dawn:
          canvas.drawCircle(Offset(x, r.center.dy), 8, ink);
          canvas.drawLine(
            Offset(x, r.center.dy),
            Offset(x, r.center.dy - 6),
            ink,
          );
          canvas.drawLine(
            Offset(x, r.center.dy),
            Offset(x + 5, r.center.dy + 3),
            ink,
          );
        case SongWorldTheme.lost:
          canvas.drawPath(
            Path()
              ..moveTo(x - 8, r.center.dy - 5)
              ..lineTo(x, r.center.dy)
              ..lineTo(x - 8, r.center.dy + 5),
            ink,
          );
          canvas.drawLine(
            Offset(x, r.center.dy),
            Offset(x + 8, r.center.dy),
            ink,
          );
      }
    }
  }

  void _drawMeadowTurf(Canvas canvas, Rect r) {
    canvas.drawRect(
      Rect.fromLTWH(r.left, r.top, r.width, 10),
      Paint()..color = const Color(0xFFB6F0C8),
    );
    final blade = Paint()
      ..color = const Color(0xFF3E9A62)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final tileX = (r.left / r.width).round();
    for (var i = 0; i < 4; i++) {
      final x = r.left + 6 + (i * 11 + _sceneValue(sceneSeed, tileX, i) % 8);
      final h = 7.0 + _sceneValue(sceneSeed, tileX, i + 3) % 6;
      canvas.drawLine(
        Offset(x, r.top + 8),
        Offset(x - 2, r.top + 8 - h),
        blade,
      );
      if (i == 1 && _sceneValue(sceneSeed, tileX, 9) % 3 == 0) {
        canvas.drawCircle(
          Offset(x, r.top - 2),
          3.2,
          Paint()..color = const Color(0xFFFF8FB5),
        );
        canvas.drawCircle(
          Offset(x, r.top - 2),
          1.3,
          Paint()..color = const Color(0xFFFFF1B8),
        );
      }
    }
  }

  /// 九个世界各有自己的地表。名字对不上时退回下面的通用草皮。
  bool _drawThemedSurface(Canvas canvas, Rect r) {
    switch (palette.name) {
      case '奶油草地':
        _drawMeadowTurf(canvas, r);
      case '草莓甜点':
        _drawCap(canvas, r, const Color(0xFFFFF4F8), const Color(0xFFE23D5C));
      case '薄荷汽水':
        _drawCap(canvas, r, const Color(0xFFF4FFFC), Colors.white);
        _drawFoam(canvas, r);
      case '香芋星空':
        _drawCap(canvas, r, const Color(0xFF6E5A96), const Color(0xFFFFF6C8));
      case '柠檬沙滩':
        _drawCap(canvas, r, const Color(0xFFFFF3C4), const Color(0xFFE6C35C));
      case '玫瑰城堡':
        _drawCap(canvas, r, const Color(0xFFFFD0E0), const Color(0xFFFF8FB5));
      case '蓝莓峡谷':
        _drawCap(canvas, r, const Color(0xFF5A7BC4), const Color(0xFFD6E4FF));
      case '焦糖矿山':
        _drawCap(canvas, r, const Color(0xFFC48A52), const Color(0xFFFFE6A7));
        canvas.drawRect(
          Rect.fromLTWH(r.left, r.top + 6, r.width, 3),
          Paint()..color = palette.groundDark.withValues(alpha: 0.55),
        );
      case '蜜月彩虹':
        _drawRainbowCap(canvas, r);
      default:
        return false;
    }
    return true;
  }

  void _drawCap(Canvas canvas, Rect r, Color cap, Color speck) {
    canvas.drawRect(
      Rect.fromLTWH(r.left, r.top, r.width, 10),
      Paint()..color = cap,
    );
    final tileX = (r.left / r.width).round();
    final paint = Paint()..color = speck;
    for (var i = 0; i < 3; i++) {
      final x = r.left + 8 + _sceneValue(sceneSeed, tileX, i + 2) % 32;
      canvas.drawCircle(Offset(x.toDouble(), r.top + 5), 1.7, paint);
    }
  }

  void _drawFoam(Canvas canvas, Rect r) {
    final foam = Paint()..color = Colors.white.withValues(alpha: 0.85);
    final tileX = (r.left / r.width).round();
    for (var i = 0; i < 2; i++) {
      final x = r.left + 10 + _sceneValue(sceneSeed, tileX, i + 5) % 28;
      canvas.drawCircle(Offset(x.toDouble(), r.top - 2), 3.2, foam);
    }
  }

  void _drawRainbowCap(Canvas canvas, Rect r) {
    const bands = <Color>[
      MacaronColors.rose,
      MacaronColors.lemon,
      MacaronColors.mint,
      MacaronColors.sky,
    ];
    for (var i = 0; i < bands.length; i++) {
      canvas.drawRect(
        Rect.fromLTWH(r.left, r.top + i * 2.5, r.width, 2.5),
        Paint()..color = bands[i],
      );
    }
  }

  void _drawScenery(Canvas canvas) {
    if (songTheme case final theme?) {
      switch (theme) {
        case SongWorldTheme.firstLove:
          _alongGround(canvas, 240, _drawFlowerGarden);
        case SongWorldTheme.whiteHorse:
          _alongGround(canvas, 330, _drawHorseshoeLamp);
        case SongWorldTheme.reflection:
          _alongGround(canvas, 360, _drawCloudQuestion);
        case SongWorldTheme.quietLove:
          _alongGround(canvas, 240, _drawTaroLantern);
        case SongWorldTheme.dawn:
          _alongGround(canvas, 400, _drawDawnClock);
        case SongWorldTheme.lost:
          _alongGround(canvas, 360, _drawForkSign);
      }
      if (groundY > 700) _drawSkySong(canvas);
      return;
    }
    switch (palette.name) {
      case '奶油草地':
        _drawMeadowSet(canvas);
      case '草莓甜点':
        _alongGround(canvas, 176, _drawStrawberry);
      case '薄荷汽水':
        _alongGround(canvas, 188, _drawSodaCup);
      case '香芋星空':
        _alongGround(canvas, 210, _drawTaroLantern);
      case '柠檬沙滩':
        _alongGround(canvas, 200, _drawBeachUmbrella);
      case '玫瑰城堡':
        _alongGround(canvas, 280, _drawCastleBeat);
      case '蓝莓峡谷':
        _alongGround(canvas, 168, _drawBlueberryCluster);
      case '焦糖矿山':
        _alongGround(canvas, 196, _drawCaramelCrystal);
      case '蜜月彩虹':
        _alongGround(canvas, 260, _drawRainbowArch);
      default:
        _drawSharedScenery(canvas);
    }
    _drawSongSet(canvas);
  }

  /// 每个世界配的歌的意象，作为远景装饰叠在原有布景上（不参与碰撞）。
  /// 素颜 → 晨雾；身骑白马 → 路灯与马蹄铁；谁 → 云里的问号；
  /// 静悄悄 → 月牙与“zZ”；5点20AM → 指着 5:20 的闹钟；Lost → 岔路指示牌。
  void _drawSongSet(Canvas canvas) {
    final (double spacing, void Function(Canvas, double) draw)? set =
        switch (palette.name) {
          '奶油草地' || '蜜月彩虹' => (420.0, _drawMorningMist),
          '草莓甜点' || '焦糖矿山' => (330.0, _drawHorseshoeLamp),
          '薄荷汽水' => (400.0, _drawCloudQuestion),
          '香芋星空' => (430.0, _drawCrescentSleep),
          '柠檬沙滩' => (520.0, _drawDawnClock),
          '玫瑰城堡' || '蓝莓峡谷' => (460.0, _drawForkSign),
          _ => null,
        };
    if (set == null) {
      return;
    }
    for (var x = 210.0; x < mapWidth - 100; x += set.$1) {
      final jitter = (_sceneValue(sceneSeed, x.round(), 9) % 61) - 30.0;
      set.$2(canvas, x + jitter);
    }
    if (groundY > 700) {
      _drawSkySong(canvas);
    }
  }

  /// 有天空层的关卡：高处再挂一些这首歌的意象（飘在云层里，不参与碰撞）。
  void _drawSkySong(Canvas canvas) {
    // 下面的装饰函数都以 groundY 为基准，把它们整体抬到天空层中部。
    canvas.save();
    canvas.translate(0, -(groundY - 430));
    for (var x = 340.0; x < mapWidth - 100; x += 520) {
      final jitter = (_sceneValue(sceneSeed, x.round(), 11) % 101) - 50.0;
      final px = x + jitter;
      switch (palette.name) {
        case '草莓甜点' || '焦糖矿山':
          // 空中的马蹄铁
          canvas.drawArc(
            Rect.fromCenter(
              center: Offset(px, groundY - 120),
              width: 70,
              height: 70,
            ),
            math.pi * 0.15,
            math.pi * 1.7,
            false,
            Paint()
              ..color = const Color(0xFFB8B0C8).withValues(alpha: 0.85)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 9
              ..strokeCap = StrokeCap.round,
          );
        case '薄荷汽水':
          _drawCloudQuestion(canvas, px);
        case '香芋星空' || '玫瑰城堡' || '蓝莓峡谷':
          _drawCrescentSleep(canvas, px);
          canvas.drawCircle(
            Offset(px + 110, groundY - 210),
            3.5,
            Paint()..color = Colors.white.withValues(alpha: 0.8),
          );
          canvas.drawCircle(
            Offset(px - 90, groundY - 130),
            2.5,
            Paint()..color = Colors.white.withValues(alpha: 0.7),
          );
        case '柠檬沙滩':
          // 初升的太阳：半圆加射线
          final c = Offset(px, groundY - 120);
          canvas.drawCircle(
            c,
            34,
            Paint()..color = const Color(0xFFFFE08A).withValues(alpha: 0.8),
          );
          for (var i = 0; i < 9; i++) {
            final a = math.pi * (1 + i / 8);
            canvas.drawLine(
              c + Offset(math.cos(a), math.sin(a)) * 44,
              c + Offset(math.cos(a), math.sin(a)) * 62,
              Paint()
                ..color = const Color(0xFFFFD36B).withValues(alpha: 0.8)
                ..strokeWidth = 5
                ..strokeCap = StrokeCap.round,
            );
          }
        default:
          _drawMorningMist(canvas, px);
      }
    }
    canvas.restore();
  }

  void _songText(
    Canvas canvas,
    String text,
    Offset center,
    double size,
    Color c,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: MacaronColors.fontFamily,
          fontFamilyFallback: MacaronColors.fontFallback,
          fontSize: size,
          fontWeight: FontWeight.w900,
          color: c,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawMorningMist(Canvas canvas, double x) {
    final mist = Paint()..color = Colors.white.withValues(alpha: 0.38);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, groundY - 96), width: 260, height: 36),
      mist,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x + 70, groundY - 74),
        width: 200,
        height: 28,
      ),
      mist,
    );
    canvas.drawCircle(
      Offset(x - 60, groundY - 150),
      16,
      Paint()..color = const Color(0xFFFFF3B0).withValues(alpha: 0.55),
    );
  }

  void _drawHorseshoeLamp(Canvas canvas, double x) {
    final pole = Paint()
      ..color = const Color(0xFF8A7A8F)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x, groundY), Offset(x, groundY - 110), pole);
    canvas.drawCircle(
      Offset(x, groundY - 118),
      16,
      Paint()..color = const Color(0xFFFFE9A8).withValues(alpha: 0.6),
    );
    canvas.drawCircle(
      Offset(x, groundY - 118),
      7,
      Paint()..color = const Color(0xFFFFD86B),
    );
    // 马蹄铁：开口朝下的粗弧。
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(x + 34, groundY - 56),
        width: 30,
        height: 30,
      ),
      math.pi * 0.15,
      math.pi * 1.7,
      false,
      Paint()
        ..color = const Color(0xFFB8B0C8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawCloudQuestion(Canvas canvas, double x) {
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.7);
    final c = Offset(x, groundY - 150);
    canvas.drawCircle(c, 30, cloud);
    canvas.drawCircle(c + const Offset(-30, 8), 22, cloud);
    canvas.drawCircle(c + const Offset(30, 8), 22, cloud);
    _songText(canvas, '?', c + const Offset(0, 2), 34, palette.groundDark);
  }

  void _drawCrescentSleep(Canvas canvas, double x) {
    final c = Offset(x, groundY - 170);
    canvas.drawCircle(c, 20, Paint()..color = const Color(0xFFFFF3C4));
    canvas.drawCircle(
      c + const Offset(9, -4),
      18,
      Paint()..color = palette.skyTop,
    );
    _songText(
      canvas,
      'zZ',
      c + const Offset(34, -18),
      15,
      const Color(0xCCE8DDFF),
    );
    _songText(
      canvas,
      'z',
      c + const Offset(52, -34),
      11,
      const Color(0x99E8DDFF),
    );
  }

  void _drawDawnClock(Canvas canvas, double x) {
    final c = Offset(x, groundY - 88);
    canvas.drawLine(
      Offset(x - 14, groundY),
      c + const Offset(-10, 24),
      Paint()
        ..color = const Color(0xFFB07A5A)
        ..strokeWidth = 4,
    );
    canvas.drawLine(
      Offset(x + 14, groundY),
      c + const Offset(10, 24),
      Paint()
        ..color = const Color(0xFFB07A5A)
        ..strokeWidth = 4,
    );
    canvas.drawCircle(c, 26, Paint()..color = const Color(0xFFFFF8E8));
    canvas.drawCircle(
      c,
      26,
      Paint()
        ..color = palette.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    final hand = Paint()
      ..color = const Color(0xFF6B4F4F)
      ..strokeCap = StrokeCap.round;
    // 5:20：时针指向 5 点偏一点（约 160°），分针指向 4（120°）。
    final hour = (5 + 20 / 60) * math.pi / 6 - math.pi / 2;
    final minute = 20 * math.pi / 30 - math.pi / 2;
    canvas.drawLine(
      c,
      c + Offset(math.cos(hour), math.sin(hour)) * 13,
      hand..strokeWidth = 4,
    );
    canvas.drawLine(
      c,
      c + Offset(math.cos(minute), math.sin(minute)) * 20,
      hand..strokeWidth = 2.5,
    );
  }

  void _drawForkSign(Canvas canvas, double x) {
    final post = Paint()
      ..color = const Color(0xFF9A7B8F)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x, groundY), Offset(x, groundY - 120), post);
    final boards = [(-1.0, -104.0), (1.0, -84.0), (-1.0, -64.0)];
    for (final (dir, dy) in boards) {
      final y = groundY + dy;
      final path = Path()
        ..moveTo(x, y - 9)
        ..lineTo(x + dir * 38, y - 9)
        ..lineTo(x + dir * 50, y)
        ..lineTo(x + dir * 38, y + 9)
        ..lineTo(x, y + 9)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = palette.accent.withValues(alpha: 0.9),
      );
    }
  }

  void _alongGround(
    Canvas canvas,
    double spacing,
    void Function(Canvas canvas, double x) draw,
  ) {
    for (var x = 90.0; x < mapWidth - 40; x += spacing) {
      final jitter = (_sceneValue(sceneSeed, x.round(), 4) % 21) - 10.0;
      draw(canvas, x + jitter);
    }
  }

  void _drawSharedScenery(Canvas canvas) {
    final sectionWidth = mapWidth / 4;
    final bush = Paint()..color = palette.groundDark;
    final pipeColor = Color.lerp(palette.ground, palette.accent, 0.45)!;
    for (var section = 0; section < 4; section++) {
      final center =
          sectionWidth * (section + 0.5) +
          (_sceneValue(sceneSeed, section, 1) % 81 - 40) * 1.4;
      switch (_sceneValue(sceneSeed, section, 2) % 6) {
        case 0:
          _drawBush(canvas, Offset(center - 170, groundY - 4), bush);
          _drawMacaronPipe(canvas, Offset(center - 22, groundY), pipeColor);
          _drawBush(canvas, Offset(center + 150, groundY - 4), bush);
          break;
        case 1:
          _drawCupcake(canvas, Offset(center, groundY - 2));
          _drawCupcake(canvas, Offset(center + 210, groundY - 2));
          break;
        case 2:
          _drawLollipop(canvas, Offset(center - 120, groundY - 4));
          _drawLollipop(canvas, Offset(center + 120, groundY - 4));
          break;
        case 3:
          _drawCandyCastle(canvas, center);
          break;
        case 4:
          _drawFlowerGarden(canvas, center);
          break;
        case 5:
          _drawRibbonGate(canvas, center);
          break;
      }
    }
  }

  void _drawMeadowSet(Canvas canvas) {
    final hill = Paint()..color = const Color(0xFFD8F8E4);
    for (var i = 0; i < 6; i++) {
      final x = mapWidth * (i + 0.5) / 6;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, groundY - 18),
          width: 220,
          height: 70,
        ),
        hill,
      );
    }
    final spacing = 168.0;
    for (var x = 80.0; x < mapWidth - 40; x += spacing) {
      final jitter = (_sceneValue(sceneSeed, x.round(), 4) % 21) - 10;
      _drawFlowerGarden(canvas, x + jitter);
    }
  }

  void _drawFlowerGarden(Canvas canvas, double centerX) {
    final stem = Paint()
      ..color = const Color(0xFF579A6C)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final colors = [
      MacaronColors.rose,
      MacaronColors.lemon,
      MacaronColors.lilac,
    ];
    for (var i = 0; i < 5; i++) {
      final x = centerX - 92 + i * 46.0;
      final height = 32.0 + (i % 3) * 11;
      final flower = Offset(x, groundY - height);
      canvas.drawLine(Offset(x, groundY - 4), flower, stem);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x - 6, groundY - height * 0.45),
          width: 13,
          height: 6,
        ),
        Paint()..color = MacaronColors.mint,
      );
      for (var petal = 0; petal < 5; petal++) {
        final angle = petal * 1.256;
        canvas.drawCircle(
          flower + Offset(math.cos(angle) * 7, math.sin(angle) * 7),
          5,
          Paint()..color = colors[i % colors.length],
        );
      }
      canvas.drawCircle(flower, 3.3, Paint()..color = const Color(0xFFFFF1B8));
    }
  }

  void _drawRibbonGate(Canvas canvas, double centerX) {
    final path = Path()
      ..moveTo(centerX - 64, groundY)
      ..quadraticBezierTo(centerX - 64, groundY - 112, centerX, groundY - 112)
      ..quadraticBezierTo(centerX + 64, groundY - 112, centerX + 64, groundY);
    canvas.drawPath(
      path,
      Paint()
        ..color = palette.accent.withValues(alpha: 0.88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    for (final side in [-1.0, 1.0]) {
      final x = centerX + side * 64;
      canvas.drawCircle(
        Offset(x, groundY - 8),
        10,
        Paint()..color = palette.ground,
      );
    }
  }

  void _drawCandyCastle(Canvas canvas, double centerX) {
    final icing = Paint()..color = palette.accent.withValues(alpha: 0.88);
    final trim = Paint()..color = palette.ground.withValues(alpha: 0.95);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX - 46, groundY - 58, 92, 58),
        const Radius.circular(8),
      ),
      icing,
    );
    for (final side in [-1.0, 1.0]) {
      final towerX = centerX + side * 42 - 15;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(towerX, groundY - 84, 30, 84),
          const Radius.circular(7),
        ),
        icing,
      );
      canvas.drawPath(
        Path()
          ..moveTo(towerX - 3, groundY - 82)
          ..lineTo(towerX + 15, groundY - 106)
          ..lineTo(towerX + 33, groundY - 82)
          ..close(),
        trim,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(towerX + 9, groundY - 58, 12, 19),
          const Radius.circular(6),
        ),
        trim,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX - 11, groundY - 30, 22, 30),
        const Radius.circular(11),
      ),
      trim,
    );
  }

  void _drawCupcake(Canvas canvas, Offset base) {
    final wrapper = Paint()..color = palette.accent;
    canvas.drawPath(
      Path()
        ..moveTo(base.dx - 22, base.dy - 26)
        ..lineTo(base.dx + 22, base.dy - 26)
        ..lineTo(base.dx + 16, base.dy - 3)
        ..lineTo(base.dx - 16, base.dy - 3)
        ..close(),
      wrapper,
    );
    final icing = Paint()..color = palette.ground.withValues(alpha: 0.95);
    canvas.drawCircle(Offset(base.dx - 10, base.dy - 31), 14, icing);
    canvas.drawCircle(Offset(base.dx + 8, base.dy - 34), 17, icing);
    canvas.drawCircle(Offset(base.dx + 21, base.dy - 26), 11, icing);
    canvas.drawCircle(
      Offset(base.dx + 3, base.dy - 40),
      4,
      Paint()..color = MacaronColors.rose,
    );
  }

  void _drawLollipop(Canvas canvas, Offset base) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(base.dx - 2, base.dy - 42, 4, 42),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );
    final candy = Offset(base.dx, base.dy - 52);
    canvas.drawCircle(candy, 18, Paint()..color = palette.accent);
    canvas.drawCircle(
      candy,
      11,
      Paint()
        ..color = palette.ground
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawCircle(
      candy + const Offset(-5, -6),
      3,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  void _drawBush(Canvas canvas, Offset base, Paint paint) {
    canvas.drawCircle(Offset(base.dx - 10, base.dy - 8), 12, paint);
    canvas.drawCircle(Offset(base.dx + 8, base.dy - 10), 14, paint);
    canvas.drawCircle(Offset(base.dx + 22, base.dy - 6), 10, paint);
  }

  void _drawMacaronPipe(Canvas canvas, Offset base, Color color) {
    const w = 44.0;
    const h = 64.0;
    final body = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(base.dx, base.dy - h, w, h),
        const Radius.circular(8),
      ),
      body,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(base.dx - 4, base.dy - h - 8, w + 8, 14),
        const Radius.circular(6),
      ),
      body,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(base.dx + w / 2, base.dy - h + 12),
        width: 18,
        height: 10,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  void _drawStrawberry(Canvas canvas, double x) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, groundY - 22), width: 28, height: 34),
      Paint()..color = const Color(0xFFE23D5C),
    );
    canvas.drawPath(
      Path()
        ..moveTo(x, groundY - 42)
        ..lineTo(x - 12, groundY - 30)
        ..lineTo(x + 12, groundY - 30)
        ..close(),
      Paint()..color = const Color(0xFF3E9A62),
    );
    final seed = Paint()..color = const Color(0xFFFFE6A7);
    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(x - 6 + (i % 3) * 6, groundY - 28 + (i ~/ 3) * 8),
        1.4,
        seed,
      );
    }
  }

  void _drawSodaCup(Canvas canvas, double x) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 16, groundY - 52, 32, 52),
        const Radius.circular(8),
      ),
      Paint()..color = palette.ground.withValues(alpha: 0.95),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, groundY - 52), width: 36, height: 12),
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
    canvas.drawLine(
      Offset(x + 6, groundY - 48),
      Offset(x + 14, groundY - 78),
      Paint()
        ..color = palette.accent
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    final bubble = Paint()..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(Offset(x - 4, groundY - 36), 3, bubble);
    canvas.drawCircle(Offset(x + 5, groundY - 24), 2.2, bubble);
  }

  void _drawTaroLantern(Canvas canvas, double x) {
    canvas.drawLine(
      Offset(x, groundY - 4),
      Offset(x, groundY - 70),
      Paint()
        ..color = palette.groundDark
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, groundY - 86), width: 22, height: 28),
      Paint()..color = const Color(0xFFFFF1B8),
    );
    final star = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final sx = x + 40;
    final sy = groundY - 124;
    canvas.drawLine(Offset(sx - 6, sy), Offset(sx + 6, sy), star);
    canvas.drawLine(Offset(sx, sy - 6), Offset(sx, sy + 6), star);
  }

  void _drawBeachUmbrella(Canvas canvas, double x) {
    canvas.drawLine(
      Offset(x, groundY),
      Offset(x, groundY - 64),
      Paint()
        ..color = palette.groundDark
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      Path()
        ..moveTo(x - 36, groundY - 52)
        ..quadraticBezierTo(x, groundY - 90, x + 36, groundY - 52)
        ..close(),
      Paint()..color = palette.accent,
    );
  }

  void _drawCastleBeat(Canvas canvas, double x) {
    _drawRibbonGate(canvas, x);
    _drawFlowerGarden(canvas, x + 96);
  }

  void _drawBlueberryCluster(Canvas canvas, double x) {
    final berry = Paint()..color = const Color(0xFF3D4E9A);
    final shine = Paint()..color = Colors.white.withValues(alpha: 0.45);
    for (final o in [
      Offset(x - 10, groundY - 12),
      Offset(x + 8, groundY - 14),
      Offset(x, groundY - 26),
    ]) {
      canvas.drawCircle(o, 10, berry);
      canvas.drawCircle(o + const Offset(-3, -3), 2, shine);
    }
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, groundY - 38), width: 14, height: 6),
      Paint()..color = const Color(0xFF6FCB9A),
    );
  }

  void _drawCaramelCrystal(Canvas canvas, double x) {
    canvas.drawPath(
      Path()
        ..moveTo(x, groundY - 58)
        ..lineTo(x + 14, groundY - 18)
        ..lineTo(x, groundY - 8)
        ..lineTo(x - 14, groundY - 18)
        ..close(),
      Paint()..color = const Color(0xFFFFE6A7),
    );
    canvas.drawLine(
      Offset(x - 4, groundY - 42),
      Offset(x + 2, groundY - 22),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawRainbowArch(Canvas canvas, double x) {
    const colors = <Color>[
      MacaronColors.rose,
      MacaronColors.lemon,
      MacaronColors.mint,
      MacaronColors.sky,
      MacaronColors.lilac,
    ];
    for (var i = 0; i < colors.length; i++) {
      final inset = i * 7.0;
      canvas.drawPath(
        Path()
          ..moveTo(x - 70 + inset, groundY)
          ..quadraticBezierTo(x, groundY - 96 + inset, x + 70 - inset, groundY),
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    }
  }
}

/// 远景云与山（缓存 Picture）
class WorldBackdrop extends PositionComponent {
  WorldBackdrop({
    required this.palette,
    required this.mapWidth,
    required this.sceneSeed,
    this.worldIndex,
    this.skyShift = 0,
  }) : super(priority: -10);

  final WorldPalette palette;
  final double mapWidth;
  final int sceneSeed;
  final int? worldIndex;
  final double skyShift;
  ui.Picture? _picture;
  ui.Image? _songBackground;
  bool _removed = false;
  static final Map<int, Future<ui.Image?>> _backgrounds = {};
  static const _backgroundNames = [
    'firstLove',
    'whiteHorse',
    'reflection',
    'quietLove',
    'dawn',
    'lost',
  ];

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _rebuild();
    if (worldIndex case final world?) {
      unawaited(_loadBackground(world));
    }
  }

  Future<void> _loadBackground(int world) async {
    final song = SongProfile.songIndexOf(world);
    final image = await _backgrounds.putIfAbsent(song, () async {
      try {
        final bytes = await rootBundle.load(
          'assets/worlds/${_backgroundNames[song]}.png',
        );
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(),
        );
        try {
          return (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      } catch (_) {
        return null;
      }
    });
    if (!_removed && image != null) {
      _songBackground = image.clone();
      _rebuild();
    }
  }

  @override
  void onRemove() {
    _removed = true;
    _songBackground?.dispose();
    _picture?.dispose();
    _picture = null;
    super.onRemove();
  }

  void _rebuild() {
    _picture?.dispose();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final image = _songBackground;
    if (image == null) {
      _drawSceneTints(canvas);
      _drawHills(canvas);
      _drawClouds(canvas);
    } else {
      final height = 640.0 + math.max(0.0, skyShift);
      final width = height * image.width / image.height;
      final src = Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
      final paint = Paint()..filterQuality = FilterQuality.medium;
      for (var x = 0.0; x < mapWidth; x += width) {
        canvas.drawImageRect(
          image,
          src,
          Rect.fromLTWH(x, -math.max(0.0, skyShift), width, height),
          paint,
        );
      }
    }
    _picture = recorder.endRecording();
  }

  @override
  void render(Canvas canvas) {
    final pic = _picture;
    if (pic != null) {
      canvas.drawPicture(pic);
      return;
    }
    _drawSceneTints(canvas);
    _drawHills(canvas);
    _drawClouds(canvas);
  }

  void _drawSceneTints(Canvas canvas) {
    final tints = [
      palette.skyTop,
      palette.accent,
      palette.parallaxMid,
      MacaronColors.lemon,
    ];
    final sectionWidth = mapWidth / 4;
    for (var section = 0; section < 4; section++) {
      final tint = tints[_sceneValue(sceneSeed, section, 4) % tints.length];
      final alpha = 0.045 + (_sceneValue(sceneSeed, section, 5) % 36) / 1000;
      canvas.drawRect(
        Rect.fromLTWH(section * sectionWidth, 0, sectionWidth, 640),
        Paint()..color = tint.withValues(alpha: alpha),
      );
    }
  }

  void _drawHills(Canvas canvas) {
    final hill = Paint()..color = palette.ground.withValues(alpha: 0.45);
    var x = -180.0 + _sceneValue(sceneSeed, 0, 6) % 240;
    for (var index = 0; x < mapWidth + 400; index++) {
      final peak = 235.0 + _sceneValue(sceneSeed, index, 7) % 86;
      canvas.drawPath(
        Path()
          ..moveTo(x, 380)
          ..quadraticBezierTo(x + 90, peak, x + 180, 380)
          ..quadraticBezierTo(x + 260, 460, x + 360, 380)
          ..lineTo(x + 360, 560)
          ..lineTo(x, 560)
          ..close(),
        hill,
      );
      x += 280 + _sceneValue(sceneSeed, index, 8) % 101;
    }
  }

  void _drawClouds(Canvas canvas) {
    final cloud = Paint()
      ..color = palette.name == '香芋星空'
          ? const Color(0xFFD4C4F5).withValues(alpha: 0.55)
          : Colors.white.withValues(alpha: 0.85);
    var x = -120.0 + _sceneValue(sceneSeed, 0, 9) % 240;
    for (var index = 0; x < mapWidth + 200; index++) {
      final y = 48.0 + _sceneValue(sceneSeed, index, 10) % 74;
      _cloud(canvas, Offset(x, y), cloud);
      if (_sceneValue(sceneSeed, index, 11) % 3 != 0) {
        _cloud(canvas, Offset(x + 80, y + 24), cloud);
      }
      x += 200 + _sceneValue(sceneSeed, index, 12) % 91;
    }
  }

  void _cloud(Canvas canvas, Offset c, Paint paint) {
    canvas.drawCircle(c, 18, paint);
    canvas.drawCircle(Offset(c.dx + 20, c.dy + 4), 22, paint);
    canvas.drawCircle(Offset(c.dx + 44, c.dy), 16, paint);
  }
}
