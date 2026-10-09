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
  final Map<int, Uint8List> _bgmByWorld = {};

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

  Uint8List _bgmBytes(int worldIndex) {
    final w = worldIndex.clamp(0, 8);
    return _bgmByWorld.putIfAbsent(w, () => SynthWav.bgmLoopForWorld(w));
  }

  /// 关卡内开始循环授权慢拍 BGM，按世界轮换。
  Future<void> startBgm({int worldIndex = 0}) async {
    await init();
    if (!musicOn) {
      await stopBgm();
      return;
    }
    if (_bgmPlaying && _bgmWorld == worldIndex) {
      await applyVolumes();
      await resumeBgm();
      return;
    }
    await _bgm.stop();
    await applyVolumes();
    final asset = _bgmAssets[worldIndex % _bgmAssets.length];
    try {
      await _bgm.play(AssetSource(asset));
    } catch (_) {
      // 资源加载异常时仍保留本地合成曲，不能让 BGM 故障影响关卡启动。
      await _bgm.play(BytesSource(_bgmBytes(worldIndex)));
    }
    _bgmWorld = worldIndex;
    _bgmPlaying = true;
  }

  /// 停止 BGM
  Future<void> stopBgm() async {
    if (!_bgmPlaying && _bgmWorld < 0) {
      await _bgm.stop();
      return;
    }
    await _bgm.stop();
    _bgmPlaying = false;
    _bgmWorld = -1;
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
      await startBgm(worldIndex: _bgmWorld);
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
