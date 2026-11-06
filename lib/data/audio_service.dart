import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/data/song_profile.dart';
import 'package:macaron_girlfriend_run/data/song_music_controller.dart';
import 'package:macaron_girlfriend_run/data/synth_wav.dart';

/// 背景音乐与音效（运行时合成 WAV + audioplayers）
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  static const int _fxPoolSize = 12;

  /// 用户提供的歌曲，每个世界配一首（世界 0–8 → 下标）。
  static const List<({String title, String asset})> songs = [
    (title: '素颜', asset: 'audio/bgm_suyan.mp3'),
    (title: '身骑白马', asset: 'audio/bgm_shenqibaima.mp3'),
    (title: '谁', asset: 'audio/bgm_shui.mp3'),
    (title: '静悄悄', asset: 'audio/bgm_jingqiaoqiao.mp3'),
    (title: '5点20AM', asset: 'audio/bgm_5am20.mp3'),
    (title: 'Lost', asset: 'audio/bgm_lost.mp3'),
  ];

  /// 某个世界普通关配的歌名。
  static String songTitleFor(int worldIndex) =>
      songs[SongProfile.worldSongs[worldIndex.clamp(0, 8).toInt()]].title;

  final AudioPlayer _bgm = AudioPlayer();
  final Object _defaultOwner = Object();
  late final SongMusicController _music = SongMusicController(
    player: _AudioSongPlayer(_bgm, init),
    readPosition: SaveService.instance.songPosition,
    writePosition: SaveService.instance.setSongPosition,
    enabled: () => musicOn,
  );
  final List<AudioPlayer> _fxPool = [];
  AudioPool? _coinPool;
  AudioPool? _powerPool;
  int _fxCursor = 0;
  bool _ready = false;
  bool _soundsReady = false;
  Future<void>? _initTask;
  double? _appliedBgmVolume;
  double? _appliedFxVolume;

  late final Uint8List _wavClick;
  late final Uint8List _wavJump;
  late final Uint8List _wavCoin;
  late final Uint8List _wavStomp;
  late final Uint8List _wavHurt;
  late final Uint8List _wavWin;
  late final Uint8List _wavPower;
  late final Uint8List _wavSkillDash;
  late final Uint8List _wavShoot;
  late final Uint8List _wavVehicle;
  late final Uint8List _wavEnemySkill;

  bool get soundOn => SaveService.instance.soundEnabled;
  bool get musicOn => SaveService.instance.musicEnabled;
  bool get hapticOn => SaveService.instance.hapticEnabled;

  /// 初始化合成音频缓存与音效池
  Future<void> init() async {
    if (_ready) {
      return;
    }
    final activeTask = _initTask;
    if (activeTask != null) {
      await activeTask;
      return;
    }
    final task = _initialize();
    _initTask = task;
    try {
      await task;
    } catch (_) {
      _initTask = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    // 默认的安卓音频焦点是独占（gain）：每个跳跃、技能音效都会把背景音乐顶掉。
    // 改成与其他声音混播，音效和音乐互不打断（iOS 同理使用 mixWithOthers）。
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(
          focus: AudioContextConfigFocus.mixWithOthers,
        ).build(),
      );
    } catch (_) {
      // 网页端等不支持的平台忽略。
    }
    if (!_soundsReady) {
      _wavClick = SynthWav.click();
      _wavJump = SynthWav.jump();
      _wavCoin = SynthWav.coin();
      _wavStomp = SynthWav.stomp();
      _wavHurt = SynthWav.hurt();
      _wavWin = SynthWav.win();
      _wavPower = SynthWav.powerUp();
      _wavSkillDash = SynthWav.skillDash();
      _wavShoot = SynthWav.shoot();
      _wavVehicle = SynthWav.vehicle();
      _wavEnemySkill = SynthWav.enemySkill();
      _soundsReady = true;
    }
    if (_fxPool.isEmpty) {
      for (var i = 0; i < _fxPoolSize; i++) {
        _fxPool.add(AudioPlayer());
      }
    }
    try {
      _coinPool ??= await AudioPool.create(
        source: BytesSource(_wavCoin),
        minPlayers: 2,
        maxPlayers: 4,
      );
      _powerPool ??= await AudioPool.create(
        source: BytesSource(_wavPower),
        minPlayers: 2,
        maxPlayers: 4,
      );
    } catch (_) {
      // 预加载不可用时继续使用普通播放器。
    }
    await _bgm.setReleaseMode(ReleaseMode.stop);
    _bgm.onPositionChanged.listen(_music.onPosition);
    _bgm.onPlayerComplete.listen((_) => unawaited(_music.onComplete()));
    await applyVolumes();
    _ready = true;
  }

  /// 按存档音量刷新播放器
  Future<void> applyVolumes() async {
    final bgmVolume = SaveService.instance.musicVolume;
    if (_appliedBgmVolume != bgmVolume) {
      await _bgm.setVolume(bgmVolume);
      _appliedBgmVolume = bgmVolume;
    }
    final fxVolume = SaveService.instance.soundVolume;
    if (_appliedFxVolume != fxVolume) {
      for (final p in _fxPool) {
        await p.setVolume(fxVolume);
      }
      _appliedFxVolume = fxVolume;
    }
  }

  Future<void> startBgm({
    int worldIndex = 0,
    int levelIndex = 0,
    bool boss = false,
    Object? owner,
  }) {
    _unlockPending = true;
    return _music.start(worldIndex, owner ?? _defaultOwner);
  }

  Future<void> stopBgm({Object? owner}) => _music.leave(owner);

  /// 驾驶「理想」时的进行曲：压住普通 BGM，开车结束后再接回来。
  final AudioPlayer _march = AudioPlayer();
  bool _marchPlaying = false;
  String? _theme;
  final Map<String, Uint8List> _themeBytes = {};
  Uint8List? _mambaBytes;

  bool get marchPlaying => _marchPlaying;
  int? get currentSong => _marchPlaying ? null : _music.currentSong;
  Duration? get currentSongPosition =>
      _marchPlaying ? null : _music.currentPosition;

  /// 当前道具主题（'march' 驾驶进行曲 / 'gum' 口香糖），没有则为 null。
  String? get theme => _marchPlaying ? _theme : null;

  Future<void> startTheme(String kind) async {
    if (_marchPlaying && _theme == kind) {
      return;
    }
    _marchPlaying = true;
    _theme = kind;
    await init();
    if (!musicOn) {
      return;
    }
    try {
      await _march.setReleaseMode(ReleaseMode.loop);
      await _march.setVolume(SaveService.instance.musicVolume);
      try {
        // 用户提供的梗音频；加载失败时退回原创合成旋律。
        await _march.play(AssetSource(kind == 'gum' ? _gumAsset : _marchAsset));
      } catch (_) {
        await _march.play(
          BytesSource(
            _themeBytes.putIfAbsent(
              kind,
              () => kind == 'gum' ? SynthWav.gumLoop() : SynthWav.marchLoop(),
            ),
          ),
        );
      }
    } catch (_) {}
  }

  static const String _marchAsset = 'audio/meme_li_march.mp4';
  static const String _gumAsset = 'audio/meme_orchid.mp4';
  static const String _ramAsset = 'audio/meme_gum.mp4';
  static const String _mambaAsset = 'audio/meme_mamba_out.mp4';
  final AudioPlayer _sting = AudioPlayer();

  Future<void> stopTheme([String? kind]) async {
    if (!_marchPlaying || (kind != null && kind != _theme)) {
      return;
    }
    _marchPlaying = false;
    _theme = null;
    try {
      await _march.stop();
    } catch (_) {}
  }

  /// 飞机结束的收尾音。
  Future<void> mambaOut() async {
    if (!soundOn) {
      return;
    }
    try {
      final volume = SaveService.instance.soundVolume;
      await _sting.setVolume(volume);
      await _sting.setSource(AssetSource(_mambaAsset));
      await _sting.seek(_mambaStart);
      await _sting.resume();
      // 只播一小段，结尾淡出两步再停，免得突然截断。
      Timer(_mambaLength - const Duration(milliseconds: 600), () {
        _sting.setVolume(volume * 0.5).catchError((Object _) {});
      });
      Timer(_mambaLength - const Duration(milliseconds: 250), () {
        _sting.setVolume(volume * 0.2).catchError((Object _) {});
      });
      Timer(_mambaLength, () {
        _sting.stop().catchError((Object _) {});
      });
    } catch (_) {
      await _playFx(() => _mambaBytes ??= SynthWav.mambaOut());
    }
  }

  /// 原片 15 秒音量几乎不变；按「高频冲击最强」挑出结尾那一段（约 11–14.5 秒，
  /// 12.5 秒处有明显的瞬态）。要换段改这两个常量。
  static const Duration _mambaStart = Duration(milliseconds: 11000);
  static const Duration _mambaLength = Duration(milliseconds: 3500);

  final AudioPlayer _killPlayer = AudioPlayer();
  DateTime _killStingAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// 打死一个怪物就播放《同龄人原本没想降维打击》。
  /// 片段约 8 秒，播放中再杀怪不重头开始，免得被切碎。
  Future<void> killSting() async {
    if (!soundOn) {
      return;
    }
    final now = DateTime.now();
    if (now.difference(_killStingAt) < _killClipLength + _killGap) {
      return;
    }
    _killStingAt = now;
    try {
      await _killPlayer.setVolume(SaveService.instance.soundVolume);
      await _killPlayer.setSource(AssetSource(_ramAsset));
      await _killPlayer.seek(_killClipStart);
      await _killPlayer.resume();
      Timer(_killClipLength, () {
        _killPlayer.stop().catchError((Object _) {});
      });
    } catch (_) {}
  }

  /// 只播原片里能量最高的一段（整段约 8 秒，2.75 秒起到 5.5 秒的那句最响）。
  static const Duration _killClipStart = Duration(milliseconds: 2750);
  static const Duration _killClipLength = Duration(milliseconds: 2750);
  static const Duration _killGap = Duration(milliseconds: 600);

  Future<void> pauseBgm() => _music.pause();

  Future<void> resumeBgm() => _music.resume();

  /// 每首曲子开始后，等待第一次手势去解锁网页端的自动播放限制。
  bool _unlockPending = true;

  /// 网页端首次手势解锁音频会话。
  ///
  /// 触控按钮每次按下都会调用它；如果每次都 `resume()` 背景音乐，会多一次平台调用，
  /// 网页上还可能让音频元素重新开始，点跳跃、冲刺时就会“卡一下”。所以每首曲子
  /// 只在第一次手势时解锁一次，之后的按键直接返回。[force] 用于从后台回来时重新解锁。
  Future<void> unlockAudio({bool force = false}) async {
    if (!force && !_unlockPending) {
      return;
    }
    _unlockPending = false;
    await init();
    try {
      if (musicOn && _music.needsRetry) {
        await _music.resume();
        _unlockPending = _music.needsRetry;
      } else if (soundOn) {
        final p = _fxPool[_fxCursor % _fxPool.length];
        _fxCursor++;
        await p.stop();
        await p.setVolume(0.01);
        await p.play(BytesSource(_wavClick));
        await p.setVolume(SaveService.instance.soundVolume);
      }
    } catch (_) {}
  }

  Future<void> _playFx(
    Uint8List Function() loadBytes, {
    AudioPool? Function()? pool,
  }) async {
    if (!soundOn) {
      return;
    }
    if (!_ready) {
      await init();
    }
    final readyPool = pool?.call();
    if (readyPool != null) {
      try {
        await readyPool.start(volume: SaveService.instance.soundVolume);
        return;
      } catch (_) {}
    }
    if (_fxPool.isEmpty) {
      return;
    }
    final player = _fxPool[_fxCursor % _fxPool.length];
    _fxCursor++;
    try {
      await player.stop();
      await player.play(BytesSource(loadBytes()));
    } catch (_) {}
  }

  Future<void> click() async {
    await _playFx(() => _wavClick);
  }

  Future<void> jump() async {
    await _playFx(() => _wavJump);
    if (hapticOn) {
      await HapticFeedback.selectionClick();
    }
  }

  Future<void> coin() async {
    await _playFx(() => _wavCoin, pool: () => _coinPool);
    if (hapticOn) {
      await HapticFeedback.lightImpact();
    }
  }

  /// 踩怪击杀音效
  Future<void> stomp() async {
    await _playFx(() => _wavStomp);
    if (hapticOn) {
      await HapticFeedback.heavyImpact();
    }
  }

  Future<void> hurt() async {
    await _playFx(() => _wavHurt);
    if (hapticOn) {
      await HapticFeedback.heavyImpact();
    }
  }

  Future<void> win() async {
    await _playFx(() => _wavWin);
    if (hapticOn) {
      await HapticFeedback.mediumImpact();
    }
  }

  Future<void> powerUp() async {
    await _playFx(() => _wavPower, pool: () => _powerPool);
    if (hapticOn) {
      await HapticFeedback.mediumImpact();
    }
  }

  Future<void> skillDash() async {
    await _playFx(() => _wavSkillDash);
    if (hapticOn) {
      await HapticFeedback.selectionClick();
    }
  }

  Future<void> shoot() async {
    await _playFx(() => _wavShoot);
  }

  Future<void> vehicle() async {
    await _playFx(() => _wavVehicle);
    if (hapticOn) {
      await HapticFeedback.selectionClick();
    }
  }

  /// 怪物技能蓄力提示音
  Future<void> enemySkill() async {
    await _playFx(() => _wavEnemySkill);
  }
}

class _AudioSongPlayer implements SongPlayer {
  _AudioSongPlayer(this.player, this.ready);
  final AudioPlayer player;
  final Future<void> Function() ready;

  @override
  Future<void> play(int song, Duration position) async {
    await ready();
    await player.play(
      AssetSource(AudioService.songs[song].asset),
      position: position,
    );
  }

  @override
  Future<void> pause() => player.pause();
  @override
  Future<void> resume() => player.resume();
  @override
  Future<void> stop() async {
    await ready();
    await player.stop();
  }

  @override
  Future<Duration?> position() => player.getCurrentPosition();
}
