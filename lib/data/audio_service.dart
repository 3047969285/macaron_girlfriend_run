import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/data/synth_wav.dart';

/// 背景音乐与音效（运行时合成 WAV + audioplayers）
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  static const int _fxPoolSize = 6;

  final AudioPlayer _bgm = AudioPlayer();
  final List<AudioPlayer> _fxPool = [];
  int _fxCursor = 0;
  bool _ready = false;
  bool _bgmPlaying = false;
  int _bgmWorld = -1;

  late final Uint8List _wavClick;
  late final Uint8List _wavJump;
  late final Uint8List _wavCoin;
  late final Uint8List _wavStomp;
  late final Uint8List _wavHurt;
  late final Uint8List _wavWin;
  late final Uint8List _wavPower;
  final Map<int, Uint8List> _bgmByWorld = {};

  bool get soundOn => SaveService.instance.soundEnabled;
  bool get musicOn => SaveService.instance.musicEnabled;
  bool get hapticOn => SaveService.instance.hapticEnabled;

  /// 初始化合成音频缓存与音效池
  Future<void> init() async {
    if (_ready) {
      return;
    }
    _wavClick = SynthWav.click();
    _wavJump = SynthWav.jump();
    _wavCoin = SynthWav.coin();
    _wavStomp = SynthWav.stomp();
    _wavHurt = SynthWav.hurt();
    _wavWin = SynthWav.win();
    _wavPower = SynthWav.powerUp();
    for (var i = 0; i < _fxPoolSize; i++) {
      _fxPool.add(AudioPlayer());
    }
    await _bgm.setReleaseMode(ReleaseMode.loop);
    await applyVolumes();
    _ready = true;
  }

  /// 按存档音量刷新播放器
  Future<void> applyVolumes() async {
    await _bgm.setVolume(SaveService.instance.musicVolume);
    for (final p in _fxPool) {
      await p.setVolume(SaveService.instance.soundVolume);
    }
  }

  Uint8List _bgmBytes(int worldIndex) {
    final w = worldIndex.clamp(0, 8);
    return _bgmByWorld.putIfAbsent(w, () => SynthWav.bgmLoopForWorld(w));
  }

  /// 关卡内开始循环 BGM（按世界主题）
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
    await _bgm.play(BytesSource(_bgmBytes(worldIndex)));
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

  Future<void> _playFx(Uint8List bytes) async {
    if (!_ready) {
      await init();
    }
    if (!soundOn || _fxPool.isEmpty) {
      return;
    }
    final player = _fxPool[_fxCursor % _fxPool.length];
    _fxCursor++;
    try {
      await player.stop();
      await player.setVolume(SaveService.instance.soundVolume);
      await player.play(BytesSource(bytes));
    } catch (_) {}
  }

  Future<void> click() async {
    await _playFx(_wavClick);
  }

  Future<void> jump() async {
    await _playFx(_wavJump);
    if (hapticOn) {
      await HapticFeedback.selectionClick();
    }
  }

  Future<void> coin() async {
    await _playFx(_wavCoin);
    if (hapticOn) {
      await HapticFeedback.lightImpact();
    }
  }

  /// 踩怪击杀音效
  Future<void> stomp() async {
    await _playFx(_wavStomp);
    if (hapticOn) {
      await HapticFeedback.heavyImpact();
    }
  }

  Future<void> hurt() async {
    await _playFx(_wavHurt);
    if (hapticOn) {
      await HapticFeedback.heavyImpact();
    }
  }

  Future<void> win() async {
    await _playFx(_wavWin);
    if (hapticOn) {
      await HapticFeedback.mediumImpact();
    }
  }

  Future<void> powerUp() async {
    await _playFx(_wavPower);
    if (hapticOn) {
      await HapticFeedback.mediumImpact();
    }
  }
}
