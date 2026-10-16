import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/data/synth_wav.dart';

/// 背景音乐与音效（运行时合成 WAV + audioplayers）
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  static const int _fxPoolSize = 6;
  static const List<String> _bgmAssets = [
    'audio/slow_jam.mp3',
    'audio/smooth_lovin.mp3',
    'audio/morning.mp3',
  ];

  final AudioPlayer _bgm = AudioPlayer();
  final List<AudioPlayer> _fxPool = [];
  int _fxCursor = 0;
  bool _ready = false;
  bool _soundsReady = false;
  Future<void>? _initTask;
  bool _bgmPlaying = false;
  int _bgmWorld = -1;
  bool _bgmBoss = false;
  Object? _bgmOwner;
  int _bgmRevision = 0;
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
  final Map<(int, bool), Uint8List> _bgmCache = {};

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
    await _bgm.setReleaseMode(ReleaseMode.loop);
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

  Uint8List _bgmBytes(int worldIndex, {required bool boss}) {
    final world = worldIndex.clamp(0, 8).toInt();
    return _bgmCache.putIfAbsent(
      (world, boss),
      () => boss
          ? SynthWav.bossLoopForWorld(world)
          : SynthWav.bgmLoopForWorld(world),
    );
  }

  /// 普通关按世界轮换授权曲，Boss 关播放世界专属短主题。
  Future<void> startBgm({
    int worldIndex = 0,
    bool boss = false,
    Object? owner,
  }) async {
    final revision = ++_bgmRevision;
    _bgmOwner = owner;
    await init();
    if (!_isBgmRequestCurrent(revision, owner)) {
      return;
    }
    if (!musicOn) {
      await stopBgm(owner: owner);
      return;
    }
    final world = worldIndex.clamp(0, 8).toInt();
    if (_bgmPlaying && _bgmWorld == world && _bgmBoss == boss) {
      await applyVolumes();
      if (!_isBgmRequestCurrent(revision, owner)) {
        return;
      }
      await resumeBgm();
      return;
    }
    await _bgm.stop();
    if (!_isBgmRequestCurrent(revision, owner)) {
      return;
    }
    await applyVolumes();
    if (!_isBgmRequestCurrent(revision, owner)) {
      return;
    }
    final asset = _bgmAssets[(world + (boss ? 1 : 0)) % _bgmAssets.length];
    try {
      if (boss) {
        await _bgm.play(BytesSource(_bgmBytes(world, boss: true)));
      } else {
        await _bgm.play(AssetSource(_bgmAssets[world % _bgmAssets.length]));
      }
    } catch (_) {
      if (!_isBgmRequestCurrent(revision, owner)) {
        return;
      }
      if (boss) {
        await _bgm.play(AssetSource(asset));
      } else {
        await _bgm.play(BytesSource(_bgmBytes(world, boss: false)));
      }
    }
    if (!_isBgmRequestCurrent(revision, owner)) {
      return;
    }
    _bgmWorld = world;
    _bgmBoss = boss;
    _bgmPlaying = true;
  }

  /// 停止 BGM
  bool _isBgmRequestCurrent(int revision, Object? owner) =>
      revision == _bgmRevision && identical(_bgmOwner, owner);

  Future<void> stopBgm({Object? owner}) async {
    if (owner != null && !identical(owner, _bgmOwner)) {
      return;
    }
    _bgmRevision++;
    _bgmOwner = null;
    if (!_bgmPlaying && _bgmWorld < 0) {
      await _bgm.stop();
      _bgmBoss = false;
      return;
    }
    await _bgm.stop();
    _bgmPlaying = false;
    _bgmWorld = -1;
    _bgmBoss = false;
  }

  /// 暂停 BGM
  Future<void> pauseBgm() async {
    if (!_bgmPlaying) {
      return;
    }
    await _bgm.pause();
  }

  /// 恢复 BGM
  Future<void> resumeBgm() async {
    if (!musicOn) {
      return;
    }
    if (!_bgmPlaying && _bgmWorld >= 0) {
      await startBgm(worldIndex: _bgmWorld, boss: _bgmBoss, owner: _bgmOwner);
      return;
    }
    if (!_bgmPlaying) {
      return;
    }
    await applyVolumes();
    await _bgm.resume();
  }

  /// 网页端首次手势解锁音频会话
  Future<void> unlockAudio() async {
    await init();
    try {
      if (musicOn && _bgmPlaying) {
        await _bgm.resume();
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

  Future<void> _playFx(Uint8List Function() loadBytes) async {
    if (!soundOn) {
      return;
    }
    if (!_ready) {
      await init();
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
    await _playFx(() => _wavCoin);
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
    await _playFx(() => _wavPower);
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
