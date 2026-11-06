import 'dart:async';

import 'package:macaron_girlfriend_run/data/song_profile.dart';

abstract interface class SongPlayer {
  Future<void> play(int song, Duration position);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<Duration?> position();
}

class SongMusicController {
  SongMusicController({
    required this.player,
    required this.readPosition,
    required this.writePosition,
    required this.enabled,
  });

  final SongPlayer player;
  final Duration? Function(int song) readPosition;
  final Future<void> Function(int song, Duration position) writePosition;
  final bool Function() enabled;
  Future<void> _pending = Future.value();
  Future<void> _saving = Future.value();
  Object? _owner;
  int? _song;
  bool _loaded = false;
  bool _paused = true;
  bool _desiredPlaying = false;
  bool _acceptPositions = false;
  Duration? _position;
  Duration? _lastSaved;

  static Duration startOffset(int song) =>
      song == 1 ? const Duration(seconds: 33) : Duration.zero;

  int? get currentSong => _song;
  Duration? get currentPosition =>
      _loaded && !_paused && _desiredPlaying ? _position : null;
  bool get needsRetry =>
      _owner != null && _desiredPlaying && (!_loaded || _paused) && enabled();

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> start(int world, Object owner) {
    _owner = owner;
    _desiredPlaying = true;
    final song = SongProfile.songIndexOf(world);
    return _enqueue(() async {
      if (!identical(_owner, owner)) return;
      if (_song != song) {
        await _saveCurrent();
        _acceptPositions = false;
        _song = song;
        _loaded = false;
        _paused = true;
        _lastSaved = null;
        _position = readPosition(song);
        try {
          await player.stop();
        } catch (_) {}
      }
      if (!enabled()) return;
      await _resumeOrStart();
    });
  }

  Future<void> _resumeOrStart() async {
    final song = _song;
    if (song == null || _owner == null || !_desiredPlaying || !enabled()) {
      return;
    }
    if (_loaded) {
      if (_paused) {
        try {
          await player.resume();
          _paused = false;
        } catch (_) {}
      }
      return;
    }
    final offset = startOffset(song);
    final position = _position != null && _position! >= offset
        ? _position!
        : offset;
    try {
      await player.play(song, position);
      _position = position;
      _loaded = true;
      _paused = false;
      _acceptPositions = true;
    } catch (_) {
      _loaded = false;
      _paused = true;
    }
  }

  Future<void> leave(Object? owner) {
    if (owner != null && !identical(_owner, owner)) return Future.value();
    _owner = null;
    _desiredPlaying = false;
    return _enqueue(() async {
      if (_owner != null) return;
      await _pauseAndSave();
    });
  }

  Future<void> pause() {
    _desiredPlaying = false;
    return _enqueue(_pauseAndSave);
  }

  Future<void> _pauseAndSave() async {
    if (!_loaded || _paused) return;
    await player.pause();
    _paused = true;
    await _saveCurrent();
  }

  Future<void> resume() {
    _desiredPlaying = true;
    return _enqueue(_resumeOrStart);
  }

  Future<void> _saveCurrent() async {
    final song = _song;
    if (song == null) return;
    if (_loaded) {
      try {
        _position = await player.position() ?? _position;
      } catch (_) {}
    }
    final position = _position;
    if (position != null) {
      await _persist(song, position);
      _lastSaved = position;
    }
  }

  void onPosition(Duration position) {
    if (!_acceptPositions || !_loaded || _paused || _song == null) return;
    _position = position;
    if (_lastSaved == null ||
        (position - _lastSaved!).abs() >= const Duration(seconds: 3)) {
      final song = _song!;
      _lastSaved = position;
      unawaited(_persist(song, position).catchError((Object _) {}));
    }
  }

  Future<void> onComplete() => _enqueue(() async {
    final song = _song;
    if (song == null ||
        !_loaded ||
        _paused ||
        _owner == null ||
        !_desiredPlaying ||
        !enabled()) {
      return;
    }
    _acceptPositions = false;
    _loaded = false;
    _paused = true;
    _position = startOffset(song);
    await _persist(song, _position!);
    await _resumeOrStart();
  });

  Future<void> _persist(int song, Duration position) {
    final result = _saving.then((_) => writePosition(song, position));
    _saving = result.then((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }
}
