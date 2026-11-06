import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:macaron_girlfriend_run/data/audio_service.dart';
import 'package:macaron_girlfriend_run/data/song_music_controller.dart';
import 'package:macaron_girlfriend_run/data/song_profile.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSongPlayer implements SongPlayer {
  final events = <String>[];
  Duration current = Duration.zero;
  bool failPlay = false;
  Completer<void>? gate;

  @override
  Future<void> play(int song, Duration position) async {
    events.add('play:$song:${position.inSeconds}');
    if (failPlay) throw StateError('autoplay blocked');
    current = position;
    if (gate != null) await gate!.future;
  }

  @override
  Future<void> pause() async {
    events.add('pause');
  }

  @override
  Future<void> resume() async {
    events.add('resume');
  }

  @override
  Future<void> stop() async {
    events.add('stop');
  }

  @override
  Future<Duration?> position() async => current;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeSongPlayer player;
  late Map<int, Duration> saved;
  late SongMusicController music;
  var enabled = true;
  setUp(() {
    player = FakeSongPlayer();
    saved = {};
    enabled = true;
    music = SongMusicController(
      player: player,
      readPosition: (s) => saved[s],
      writePosition: (s, p) async {
        saved[s] = p;
      },
      enabled: () => enabled,
    );
  });

  test('歌词读取当前播放位置，暂停时不显示并在恢复后继续', () async {
    final owner = Object();
    await music.start(0, owner);
    player.current = const Duration(seconds: 12);
    music.onPosition(player.current);
    expect(music.currentPosition, const Duration(seconds: 12));
    await music.pause();
    expect(music.currentPosition, isNull);
    await music.resume();
    expect(music.currentPosition, const Duration(seconds: 12));
    await music.start(1, owner);
    expect(music.currentPosition, const Duration(seconds: 33));
  });

  test('song positions survive reinitialising the real save service', () async {
    SharedPreferences.setMockInitialValues({});
    await SaveService.instance.init();
    await SaveService.instance.setSongPosition(1, const Duration(seconds: 97));
    await SaveService.instance.init();
    expect(SaveService.instance.songPosition(1), const Duration(seconds: 97));
    expect(SaveService.instance.songPosition(0), isNull);
  });

  test('all worlds including bosses and depth map to their song', () {
    for (var w = 0; w < 9; w++) {
      expect(SongProfile.songIndexOf(w), SongProfile.worldSongs[w]);
    }
  });

  test('every world song is included in the bundled assets', () async {
    for (final song in AudioService.songs) {
      final data = await rootBundle.load('assets/${song.asset}');
      expect(data.lengthInBytes, greaterThan(1024), reason: song.title);
    }
  });

  test('next level retains song and stale page cannot stop it', () async {
    final a = Object(), b = Object();
    await music.start(0, a);
    player.current = const Duration(seconds: 46);
    await music.start(0, b);
    await music.leave(a);
    expect(player.events.where((e) => e.startsWith('play:')), ['play:0:0']);
    expect(player.events.where((e) => e == 'pause'), isEmpty);
    await music.leave(b);
    expect(saved[0], const Duration(seconds: 46));
    await music.start(0, Object());
    expect(player.events.last, 'resume');
  });

  test(
    'relaunch, change of song, and repeated song restore saved position',
    () async {
      final a = Object();
      await music.start(0, a);
      player.current = const Duration(seconds: 62);
      await music.start(1, Object());
      expect(saved[0], const Duration(seconds: 62));
      expect(player.events, contains('play:1:33'));
      final second = SongMusicController(
        player: FakeSongPlayer(),
        readPosition: (s) => saved[s],
        writePosition: (s, p) async {
          saved[s] = p;
        },
        enabled: () => true,
      );
      await second.start(0, Object());
      expect((second.player as FakeSongPlayer).events, contains('play:0:62'));
    },
  );

  test(
    'intro offset applies only initially and at each completed loop',
    () async {
      await music.start(1, Object());
      expect(player.events.last, 'play:1:33');
      player.current = const Duration(seconds: 105);
      music.onPosition(player.current);
      await Future<void>.delayed(Duration.zero);
      expect(saved[1], const Duration(seconds: 105));
      await music.onComplete();
      expect(player.events.last, 'play:1:33');
      expect(saved[1], const Duration(seconds: 33));
      saved[1] = const Duration(seconds: 55);
      final restored = SongMusicController(
        player: FakeSongPlayer(),
        readPosition: (s) => saved[s],
        writePosition: (s, p) async {
          saved[s] = p;
        },
        enabled: () => true,
      );
      await restored.start(1, Object());
      expect((restored.player as FakeSongPlayer).events.last, 'play:1:55');
    },
  );

  test(
    'blocked browser autoplay retries the same song after a gesture',
    () async {
      player.failPlay = true;
      await music.start(1, Object());
      expect(music.needsRetry, isTrue);
      player.failPlay = false;
      await music.resume();
      expect(player.events.where((e) => e.startsWith('play:')), [
        'play:1:33',
        'play:1:33',
      ]);
      expect(music.needsRetry, isFalse);
    },
  );

  test('muting and unmuting retain the active song and its position', () async {
    await music.start(0, Object());
    player.current = const Duration(seconds: 81);
    enabled = false;
    await music.pause();
    enabled = true;
    await music.resume();
    expect(saved[0], const Duration(seconds: 81));
    expect(player.events.last, 'resume');
  });

  test(
    'a deliberate pause is not treated as a blocked autoplay retry',
    () async {
      await music.start(0, Object());
      await music.pause();
      expect(music.needsRetry, isFalse);
      await music.onComplete();
      expect(player.events.last, 'pause');
      await music.resume();
      expect(player.events.last, 'resume');
    },
  );

  test('a pause requested while a track is loading is respected', () async {
    player.gate = Completer<void>();
    final start = music.start(0, Object());
    await Future<void>.delayed(Duration.zero);
    final pause = music.pause();
    player.gate!.complete();
    await Future.wait([start, pause]);
    expect(player.events.last, 'pause');
    expect(music.needsRetry, isFalse);
  });

  test('leave while a new owner starts cannot pause the new song', () async {
    final a = Object(), b = Object();
    await music.start(0, a);
    player.gate = Completer<void>();
    final switchSong = music.start(1, b);
    await Future<void>.delayed(Duration.zero);
    final staleLeave = music.leave(a);
    player.gate!.complete();
    await Future.wait([switchSong, staleLeave]);
    expect(player.events.last, 'play:1:33');
    expect(music.currentSong, 1);
  });
}
