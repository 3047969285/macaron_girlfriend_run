import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

/// 运行时合成短 WAV，避免外置音频文件
class SynthWav {
  SynthWav._();

  static const int _sampleRate = 44100;

  /// 合成单声道 16bit PCM WAV
  static Uint8List build(List<double> samples) {
    final pcm = Int16List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      final v = (samples[i] * 32767).round().clamp(-32767, 32767);
      pcm[i] = v;
    }
    final dataSize = pcm.length * 2;
    final header = ByteData(44);
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, 36 + dataSize, Endian.little);
    header.setUint8(8, 0x57);
    header.setUint8(9, 0x41);
    header.setUint8(10, 0x56);
    header.setUint8(11, 0x45);
    header.setUint8(12, 0x66);
    header.setUint8(13, 0x6d);
    header.setUint8(14, 0x74);
    header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, _sampleRate, Endian.little);
    header.setUint32(28, _sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    header.setUint8(36, 0x64);
    header.setUint8(37, 0x61);
    header.setUint8(38, 0x74);
    header.setUint8(39, 0x61);
    header.setUint32(40, dataSize, Endian.little);

    final out = Uint8List(44 + dataSize);
    out.setAll(0, header.buffer.asUint8List());
    out.setAll(44, pcm.buffer.asUint8List());
    return out;
  }

  static double _env(double t, double atk, double dec, double dur) {
    if (t < 0) {
      return 0;
    }
    if (t < atk) {
      return t / atk;
    }
    if (t < dur) {
      return math.max(0, 1 - (t - atk) / dec);
    }
    return 0;
  }

  static List<double> tone(
    double freq,
    double dur, {
    double vol = 0.35,
    double bend = 0,
  }) {
    final n = (_sampleRate * dur).round();
    final out = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final t = i / _sampleRate;
      final f = freq + bend * t;
      final wave = vol * math.sin(2 * math.pi * f * t);
      out[i] = wave * _env(t, 0.005, dur * 0.7, dur);
    }
    return out;
  }

  static List<double> noise(double dur, {double vol = 0.15}) {
    final rnd = math.Random(7);
    final n = (_sampleRate * dur).round();
    final out = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final t = i / _sampleRate;
      out[i] =
          (rnd.nextDouble() * 2 - 1) * vol * _env(t, 0.001, dur * 0.5, dur);
    }
    return out;
  }

  static List<double> mix(List<List<double>> tracks) {
    final len = tracks.fold<int>(0, (a, t) => math.max(a, t.length));
    final out = List<double>.filled(len, 0);
    for (final tr in tracks) {
      for (var i = 0; i < tr.length; i++) {
        out[i] += tr[i];
      }
    }
    return out;
  }

  static List<double> silence(double dur) {
    return List<double>.filled((_sampleRate * dur).round(), 0);
  }

  /// 预置音效 PCM
  static Uint8List click() => build(tone(880, 0.05, vol: 0.25));

  static Uint8List jump() => build(
    mix([
      tone(520, 0.08, vol: 0.28, bend: 420),
      tone(780, 0.1, vol: 0.18, bend: 300),
    ]),
  );

  static Uint8List coin() =>
      build(mix([tone(988, 0.06, vol: 0.3), tone(1318, 0.09, vol: 0.22)]));

  static Uint8List stomp() => build(
    mix([
      tone(180, 0.07, vol: 0.45, bend: -80),
      tone(120, 0.12, vol: 0.35, bend: -40),
      noise(0.08, vol: 0.25),
    ]),
  );

  static Uint8List hurt() => build(
    mix([
      tone(220, 0.15, vol: 0.35, bend: -120),
      tone(160, 0.2, vol: 0.25, bend: -60),
    ]),
  );

  static Uint8List powerUp() => build(
    mix([
      tone(440, 0.08, vol: 0.25, bend: 180),
      tone(660, 0.12, vol: 0.25, bend: 220),
      tone(880, 0.16, vol: 0.2, bend: 260),
    ]),
  );

  static Uint8List skillDash() => build(
    mix([
      noise(0.16, vol: 0.1),
      tone(620, 0.08, vol: 0.22, bend: 520),
      tone(930, 0.12, vol: 0.2, bend: 440),
      tone(1244, 0.16, vol: 0.16, bend: 260),
    ]),
  );

  static Uint8List shoot() => build(
    mix([
      tone(920, 0.035, vol: 0.16, bend: -220),
      tone(520, 0.055, vol: 0.13, bend: -180),
    ]),
  );

  static Uint8List vehicle() => build(
    mix([
      tone(392, 0.07, vol: 0.2, bend: 180),
      tone(587, 0.09, vol: 0.2, bend: 220),
      tone(784, 0.12, vol: 0.16, bend: 260),
    ]),
  );

  static Uint8List enemySkill() => build(
    mix([
      tone(620, 0.09, vol: 0.19, bend: 180),
      tone(880, 0.11, vol: 0.13, bend: -120),
    ]),
  );

  static Uint8List win() {
    final parts = <List<double>>[];
    for (final e in [(523, 0.12), (659, 0.12), (784, 0.18), (1046, 0.25)]) {
      parts.add(tone(e.$1.toDouble(), e.$2, vol: 0.28));
    }
    return build(mix(parts));
  }

  /// 马卡龙风 BGM 循环
  static Uint8List bgmLoop() => bgmLoopForWorld(0);

  static const List<List<int>> _worldMotifs = [
    [0, 2, 4, 7, 4, 2, 0, -1, 4, 7, 9, 7, 4, 2, 0, -1],
    [0, 0, 3, 5, 7, 5, 3, 0, 5, 7, 8, 7, 5, 3, 0, -1],
    [4, 2, 0, 2, 4, 7, 4, 2, 0, -1, 2, 4, 7, 4, 2, 0],
    [0, 3, 7, 3, 8, 7, 3, 0, 7, 8, 10, 8, 7, 3, 0, -1],
    [7, 4, 2, 0, 2, 4, 7, 9, 7, 4, 2, 4, 0, -1, 0, 2],
    [0, 5, 7, 9, 7, 5, 4, 2, 0, 2, 4, 5, 4, 2, 0, -1],
    [4, 4, 7, 9, 11, 9, 7, 4, 2, 4, 7, 4, 2, 0, -1, 0],
    [0, 2, 3, 7, 3, 2, 0, -1, 7, 5, 3, 2, 3, 5, 7, 8],
    [0, 4, 7, 11, 7, 4, 2, 0, 4, 7, 9, 7, 4, 2, 0, -1],
  ];
  static const List<List<int>> _worldRootsA = [
    [60, 67, 69, 65],
    [65, 60, 62, 67],
    [69, 65, 60, 67],
    [57, 60, 65, 62],
    [62, 69, 67, 60],
    [60, 65, 67, 69],
    [64, 69, 62, 67],
    [55, 60, 65, 58],
    [60, 69, 65, 67],
  ];
  static const List<List<int>> _worldRootsB = [
    [62, 65, 67, 69],
    [69, 65, 60, 67],
    [62, 67, 65, 60],
    [55, 62, 57, 60],
    [65, 60, 67, 62],
    [62, 67, 60, 65],
    [57, 64, 67, 62],
    [62, 55, 60, 65],
    [64, 60, 67, 69],
  ];
  static const List<List<int>> _worldScales = [
    [0, 2, 4, 5, 7, 9, 11],
    [0, 2, 3, 5, 7, 8, 10],
    [0, 2, 4, 5, 7, 9, 11],
    [0, 2, 3, 5, 7, 8, 11],
    [0, 2, 4, 5, 7, 9, 10],
    [0, 2, 4, 5, 7, 9, 11],
    [0, 2, 3, 5, 7, 9, 10],
    [0, 2, 3, 5, 7, 8, 10],
    [0, 2, 4, 6, 7, 9, 11],
  ];
  static const List<List<int>> _bossMotifs = [
    [0, -1, 4, 7, 6, -1, 4, 2, 0, -1, 3, 5, 4, -1, 2, -1],
    [0, 3, -1, 5, 7, -1, 5, 2, 0, 2, -1, 5, 3, -1, 2, -1],
    [4, -1, 2, 0, 5, -1, 4, 2, 0, -1, 4, 7, 5, -1, 2, -1],
    [0, -1, 3, 7, 5, -1, 3, 2, 0, 2, -1, 5, 3, -1, 0, -1],
    [7, -1, 4, 2, 6, -1, 4, 0, 2, -1, 5, 7, 4, -1, 2, -1],
    [0, 2, -1, 5, 7, -1, 4, 2, 0, -1, 4, 5, 3, -1, 2, -1],
    [4, -1, 7, 9, 6, -1, 4, 2, 0, 2, -1, 5, 4, -1, 2, -1],
    [0, -1, 3, 5, 7, -1, 3, 2, 0, -1, 5, 7, 4, -1, 2, -1],
    [0, -1, 4, 7, 6, -1, 4, 2, 0, 2, -1, 5, 3, -1, 0, -1],
  ];
  static const List<List<int>> _bossRoots = [
    [57, 62, 55, 60],
    [60, 65, 58, 62],
    [57, 62, 60, 55],
    [53, 57, 62, 58],
    [55, 62, 57, 60],
    [57, 60, 53, 62],
    [52, 57, 60, 55],
    [55, 58, 62, 53],
    [57, 60, 55, 62],
  ];

  static double _midi(int note) =>
      440 * math.pow(2, (note - 69) / 12).toDouble();

  static void _mixAt(List<double> out, int start, List<double> src) {
    final end = math.min(out.length, start + src.length);
    for (var i = start; i < end; i++) {
      out[i] += src[i - start];
    }
  }

  /// 钢琴音色：基音加少量逐渐衰减的泛音，起音柔和，高音衰减更快。
  /// 谐波只有 4 阶，听感圆润，没有尖锐的高频。
  static List<double> _piano(double freq, double dur, {double vol = 0.15}) {
    final n = (_sampleRate * dur).round();
    final out = List<double>.filled(n, 0);
    final tau = (1.5 * math.sqrt(261.6 / freq)).clamp(0.35, 1.8).toDouble();
    const amps = [1.0, 0.38, 0.16, 0.06];
    final harmonics = freq < 220 ? 4 : (freq < 700 ? 3 : 2);
    final release = math.min(0.06, dur * 0.3);
    for (var i = 0; i < n; i++) {
      final t = i / _sampleRate;
      final attack = math.min(1.0, t / 0.006);
      var s = 0.0;
      for (var k = 1; k <= harmonics; k++) {
        final decay = math.exp(-t / (tau / math.pow(k, 0.55)));
        // 轻微失谐让琴弦更有温度。
        final detune = k == 1 ? 1.0015 : 1.0;
        s +=
            amps[k - 1] * decay * math.sin(2 * math.pi * freq * k * t * detune);
      }
      final tail = t > dur - release ? (dur - t) / release : 1.0;
      out[i] = vol * attack * tail * s;
    }
    return out;
  }

  /// 尼龙弦吉他：Karplus-Strong 拨弦，衰减时高频先消失，声音温暖。
  static List<double> _guitar(double freq, double dur, {double vol = 0.1}) {
    final n = (_sampleRate * dur).round();
    final out = List<double>.filled(n, 0);
    final period = math.max(2, (_sampleRate / freq).round());
    final rnd = math.Random(freq.round());
    final buf = List<double>.generate(period, (_) => rnd.nextDouble() * 2 - 1);
    // 先把初始噪声平滑一遍，拨弦更软。
    for (var pass = 0; pass < 2; pass++) {
      for (var i = 0; i < period; i++) {
        buf[i] = 0.5 * (buf[i] + buf[(i + 1) % period]);
      }
    }
    var idx = 0;
    var lp = 0.0;
    final release = math.min(0.08, dur * 0.3);
    for (var i = 0; i < n; i++) {
      final cur = buf[idx];
      final next = buf[(idx + 1) % period];
      buf[idx] = 0.5 * (cur + next) * 0.9965;
      idx = (idx + 1) % period;
      lp += 0.5 * (cur - lp);
      final t = i / _sampleRate;
      final tail = t > dur - release ? (dur - t) / release : 1.0;
      out[i] = vol * 2.2 * lp * tail * math.min(1.0, t / 0.004);
    }
    return out;
  }

  /// 很轻的低频心跳，代替原来的底鼓。
  static List<double> _thump(double dur, {double vol = 0.1}) {
    final n = (_sampleRate * dur).round();
    final out = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final t = i / _sampleRate;
      final f = 78 - 26 * (t / dur).clamp(0.0, 1.0);
      out[i] =
          vol *
          math.sin(2 * math.pi * f * t) *
          math.min(1.0, t / 0.012) *
          math.exp(-t * 9);
    }
    return out;
  }

  /// 极轻的刷弦沙沙声（低通噪声），代替踩镲。
  static List<double> _brush(double dur, {double vol = 0.018}) {
    final rnd = math.Random(5);
    final n = (_sampleRate * dur).round();
    final out = List<double>.filled(n, 0);
    var lp = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / _sampleRate;
      lp += 0.18 * ((rnd.nextDouble() * 2 - 1) - lp);
      out[i] = vol * lp * math.exp(-t * 22) * math.min(1.0, t / 0.01);
    }
    return out;
  }

  /// 驾驶「理想」时放的原创进行曲：4/4、124 BPM、8 小节，C 大调，
  /// 钢琴主旋律 + 低音/和弦“嗵—嚓”的行进节奏。
  static const double marchBpm = 124;
  static const int marchBars = 8;
  static const List<List<double>> _marchMelody = [
    [67, 1],
    [72, 1],
    [76, 1],
    [72, 1],
    [74, 1.5],
    [72, .5],
    [71, 1],
    [67, 1],
    [69, 1],
    [72, 1],
    [77, 1],
    [76, 1],
    [74, 2],
    [67, 1],
    [0, 1],
    [67, 1],
    [72, 1],
    [76, 1],
    [79, 1],
    [77, 1.5],
    [76, .5],
    [74, 1],
    [72, 1],
    [71, 1],
    [74, 1],
    [77, 1],
    [74, 1],
    [72, 3],
    [0, 1],
  ];
  static const List<int> _marchRoots = [48, 43, 41, 43, 48, 41, 43, 48];

  static Uint8List marchLoop() => _pieceLoop(
    melody: _marchMelody,
    roots: _marchRoots,
    bpm: marchBpm,
    beatsPerBar: 4,
  );

  /// 口香糖道具的原创田园圆舞曲：3/4、96 BPM、8 小节，G 大调。
  static const List<List<double>> _gumMelody = [
    [67, 1],
    [71, 1],
    [74, 1],
    [76, 2],
    [74, 1],
    [72, 1],
    [74, 1],
    [72, 1],
    [71, 2],
    [0, 1],
    [69, 1],
    [72, 1],
    [76, 1],
    [74, 2],
    [71, 1],
    [72, 1],
    [71, 1],
    [69, 1],
    [67, 2],
    [0, 1],
  ];
  static const List<int> _gumRoots = [43, 43, 48, 43, 45, 50, 48, 43];

  static Uint8List gumLoop() =>
      _pieceLoop(melody: _gumMelody, roots: _gumRoots, bpm: 96, beatsPerBar: 3);

  static Uint8List _pieceLoop({
    required List<List<double>> melody,
    required List<int> roots,
    required double bpm,
    required int beatsPerBar,
  }) {
    final bars = roots.length;
    final beat = 60 / bpm;
    final total = (_sampleRate * beat * beatsPerBar * bars).round();
    final out = List<double>.filled(total, 0);
    var at = 0.0;
    for (final n in melody) {
      final dur = n[1] * beat;
      if (n[0] > 0) {
        _mixAt(
          out,
          (at * _sampleRate).round(),
          _piano(_midi(n[0].round()), dur * 0.92, vol: 0.16),
        );
      }
      at += dur;
    }
    for (var bar = 0; bar < bars; bar++) {
      final root = roots[bar];
      final minor = root % 12 == 9; // A 小调和弦
      for (var b = 0; b < beatsPerBar; b++) {
        final start = ((bar * beatsPerBar + b) * beat * _sampleRate).round();
        final strong = beatsPerBar == 4 ? b.isEven : b == 0;
        if (strong) {
          _mixAt(out, start, _piano(_midi(root), beat * 0.9, vol: 0.14));
          _mixAt(out, start, _thump(0.25, vol: 0.1));
        } else {
          for (final iv in minor ? const [12, 15, 19] : const [12, 16, 19]) {
            _mixAt(
              out,
              start,
              _guitar(_midi(root + iv), beat * 0.8, vol: 0.06),
            );
          }
        }
        _mixAt(out, start, _brush(0.12, vol: b.isOdd ? 0.03 : 0.015));
      }
    }
    return build(out);
  }

  /// 飞机结束时的短收尾：慢下行的钢琴音加低沉心跳，原创，不是任何现成音源。
  static Uint8List mambaOut() {
    final out = List<double>.filled((_sampleRate * 4.2).round(), 0);
    const List<List<double>> notes = [
      [76, 0.0, 0.7],
      [74, 0.7, 0.7],
      [71, 1.4, 0.9],
      [67, 2.3, 1.8],
    ];
    for (final n in notes) {
      _mixAt(
        out,
        (n[1] * _sampleRate).round(),
        _piano(_midi(n[0].round()), n[2], vol: 0.2),
      );
    }
    _mixAt(out, (2.3 * _sampleRate).round(), _piano(_midi(43), 1.8, vol: 0.2));
    _mixAt(out, (2.3 * _sampleRate).round(), _thump(0.4, vol: 0.16));
    return build(out);
  }

  /// 每个世界 16 小节原创循环，后半更换和弦走向并变奏旋律。
  /// [alt] 为 true 时换一种和弦走向与旋律起点，同一世界的相邻关卡不重复。
  static Uint8List bgmLoopForWorld(int worldIndex, {bool alt = false}) {
    final world = worldIndex.clamp(0, 8).toInt();
    final motif = _worldMotifs[world];
    final shift = alt ? 4 : 0;
    return _composeLoop(
      motif: [
        for (var i = 0; i < motif.length; i++)
          motif[(i + shift) % motif.length],
      ],
      rootsA: alt ? _worldRootsB[world] : _worldRootsA[world],
      rootsB: alt ? _worldRootsA[world] : _worldRootsB[world],
      scale: _worldScales[world],
      bars: 16,
      bpm: 92 + (world % 3) * 6,
    );
  }

  /// 只规划旋律不合成音频，返回每个八分位的 MIDI 音高（null 表示不起音）。
  @visibleForTesting
  static List<int?> melodyPlanForWorld(int worldIndex, {bool alt = false}) {
    final world = worldIndex.clamp(0, 8).toInt();
    final motif = _worldMotifs[world];
    final shift = alt ? 4 : 0;
    final plan = <int?>[];
    _composeLoop(
      motif: [
        for (var i = 0; i < motif.length; i++)
          motif[(i + shift) % motif.length],
      ],
      rootsA: alt ? _worldRootsB[world] : _worldRootsA[world],
      rootsB: alt ? _worldRootsA[world] : _worldRootsB[world],
      scale: _worldScales[world],
      bars: 16,
      bpm: 92 + (world % 3) * 6,
      melodyOut: plan,
      planOnly: true,
    );
    return plan;
  }

  /// Boss 专用四小节主题，保留世界音阶但使用另一段旋律与和弦。
  static Uint8List bossLoopForWorld(int worldIndex) {
    final world = worldIndex.clamp(0, 8).toInt();
    return _composeLoop(
      motif: _bossMotifs[world],
      rootsA: _bossRoots[world],
      rootsB: _bossRoots[world],
      scale: _worldScales[world],
      bars: 4,
      bpm: 76 + (world % 3) * 4,
      boss: true,
    );
  }

  /// 每小节 8 个八分音符位，1 表示在这一位起一个新音，0 表示延音。
  static const List<List<int>> _rhythms = [
    [1, 0, 1, 0, 1, 1, 0, 1],
    [1, 0, 0, 1, 1, 0, 1, 0],
    [1, 0, 1, 1, 0, 1, 0, 0],
    [1, 1, 0, 1, 0, 1, 1, 0],
    [1, 0, 0, 0, 1, 0, 1, 1],
    [1, 0, 1, 0, 0, 1, 0, 0],
  ];

  /// 乐句收尾的小节：长音加一个弱起。
  static const List<List<int>> _cadences = [
    [1, 0, 0, 0, 0, 0, 1, 0],
    [1, 0, 0, 0, 1, 0, 0, 0],
  ];

  /// 吉他分解和弦型：数字是和弦音序号，-1 表示休止。
  static const List<List<int>> _guitarPatterns = [
    [0, 1, 2, 1, 0, 1, 2, 1],
    [0, 2, 1, 2, 0, 2, 1, 2],
    [0, 1, 2, 3, 2, 1, 2, 1],
    [0, -1, 1, 2, -1, 2, 1, -1],
  ];

  static Uint8List _composeLoop({
    required List<int> motif,
    required List<int> rootsA,
    required List<int> rootsB,
    required List<int> scale,
    required int bars,
    required int bpm,
    bool boss = false,
    List<int?>? melodyOut,
    bool planOnly = false,
  }) {
    final eighth = 60 / bpm / 2;
    final steps = bars * 8;
    final out = List<double>.filled(
      planOnly ? 0 : (_sampleRate * eighth * steps).round(),
      0,
    );

    // 曲子里大量音符重复出现：同一音高、时长、音量只合成一次。
    final noteCache = <String, List<double>>{};
    List<double> piano(double freq, double dur, {double vol = 0.15}) =>
        noteCache.putIfAbsent(
          'p$freq|$dur|$vol',
          () => _piano(freq, dur, vol: vol),
        );
    List<double> guitar(double freq, double dur, {double vol = 0.1}) =>
        noteCache.putIfAbsent(
          'g$freq|$dur|$vol',
          () => _guitar(freq, dur, vol: vol),
        );
    final thump = _thump(0.4, vol: boss ? 0.14 : 0.09);
    final brush = _brush(0.14, vol: boss ? 0.026 : 0.016);

    // 旋律和节奏都由世界自己的动机和和弦确定地生成，同一世界每次听都一样。
    final seed =
        (motif.fold<int>(17, (a, b) => a * 31 + b + 2) ^
            rootsA.fold<int>(7, (a, b) => a * 37 + b)) &
        0x7fffffff;
    final phraseBars = math.max(2, math.min(4, bars));
    final phrases = math.max(1, bars ~/ phraseBars);

    // 乐句结构 A A' B A''：A' 只在后半句变化，B 换新的走向且音区更高。
    int phraseSeed(int phrase, int pos) {
      final kind = phrases >= 4 ? const [0, 0, 1, 0][phrase % 4] : phrase % 2;
      final varies =
          phrases >= 4 &&
          ((phrase == 1 && pos >= 2) || (phrase == 3 && pos == 3));
      return seed + kind * 1009 + pos * 13 + (varies ? 7919 : 0);
    }

    // 逐小节生成旋律（每个八分位的音高，null 表示这一位不起音）。
    final melodyMidi = List<int?>.filled(steps, null);
    final melodyLen = List<int>.filled(steps, 0);
    var degree = (motif[0] < 0 ? 0 : motif[0]) % 7 + 7;
    var previousRhythm = -1;
    for (var bar = 0; bar < bars; bar++) {
      final phrase = bar ~/ phraseBars;
      final pos = bar % phraseBars;
      final secondHalf = bars > 4 && bar >= bars ~/ 2;
      final chordRoot = (secondHalf ? rootsB : rootsA)[bar % rootsA.length];
      final rnd = math.Random(phraseSeed(phrase, pos));
      final isCadence = pos == phraseBars - 1;
      var rhythmIndex = rnd.nextInt(_rhythms.length);
      // 相邻小节不用同一种节奏，听起来才有起伏。
      if (rhythmIndex == previousRhythm) {
        rhythmIndex = (rhythmIndex + 1 + rnd.nextInt(2)) % _rhythms.length;
      }
      final template = isCadence
          ? _cadences[(seed + phrase) % _cadences.length]
          : _rhythms[rhythmIndex];
      previousRhythm = isCadence ? -1 : rhythmIndex;
      final bSection = phrases >= 4 && phrase == 2;

      final hits = [
        for (var i = 0; i < 8; i++)
          if (template[i] == 1) i,
      ];
      for (var h = 0; h < hits.length; h++) {
        final slot = hits[h];
        final step = bar * 8 + slot;
        // 强拍（第 1、5 个八分位）落在和弦音上，其余位置级进或小跳。
        final strong = slot == 0 || slot == 4;
        if (strong) {
          final target = motif[(bar * 3 + slot) % motif.length];
          final base =
              (target < 0 ? degree : target) % 7 +
              (bSection ? 7 : (rnd.nextBool() ? 7 : 0));
          const chordTones = [0, 2, 4, 7, 9, 11];
          degree = chordTones.reduce(
            (a, b) => (a - base).abs() <= (b - base).abs() ? a : b,
          );
        } else {
          const moves = [-2, -1, -1, 1, 1, 2, 3, -3, 0];
          degree += moves[rnd.nextInt(moves.length)];
        }
        degree = degree.clamp(2, bSection ? 13 : 11);
        var midi = chordRoot + scale[degree % 7] + 12 * (degree ~/ 7);
        while (midi > 81) {
          midi -= 12;
        }
        while (midi < 55) {
          midi += 12;
        }
        melodyMidi[step] = midi;
        final next = h + 1 < hits.length ? hits[h + 1] : 8;
        melodyLen[step] = next - slot;
      }
    }

    melodyOut?.addAll(melodyMidi);
    if (planOnly) {
      return Uint8List(0);
    }

    for (var step = 0; step < steps; step++) {
      final at = (_sampleRate * eighth * step).round();
      final bar = step ~/ 8;
      final slot = step % 8;
      final phrase = bar ~/ phraseBars;
      final pos = bar % phraseBars;
      final secondHalf = bars > 4 && bar >= bars ~/ 2;
      final chordRoot = (secondHalf ? rootsB : rootsA)[bar % rootsA.length];
      final bSection = phrases >= 4 && phrase == 2;

      // 钢琴旋律：重音落在强拍，弱拍轻一点；音区压在 C6 以下。
      final midi = melodyMidi[step];
      if (midi != null) {
        final accent = slot == 0 ? 1.25 : (slot == 4 ? 1.05 : 0.85);
        final base = boss ? 0.1 : (bSection ? 0.14 : 0.12);
        final len = melodyLen[step].clamp(1, 6);
        _mixAt(
          out,
          at,
          piano(_midi(midi), eighth * (len + 1.2), vol: base * accent),
        );
      }

      // 吉他分解和弦：每小节一种指法，乐句最后一小节用稀疏的那种。
      final pattern = pos == phraseBars - 1
          ? _guitarPatterns[3]
          : _guitarPatterns[(bar + seed) % 3];
      final tones = [
        chordRoot,
        chordRoot + scale[4],
        chordRoot + scale[2] + 12,
        chordRoot + 12,
      ];
      final tone = pattern[slot];
      if (tone >= 0 && (!boss || slot.isEven)) {
        var gm = tones[tone];
        while (gm > 72) {
          gm -= 12;
        }
        while (gm < 50) {
          gm += 12;
        }
        final accent = slot == 0 ? 1.3 : (slot == 4 ? 1.1 : 0.8);
        _mixAt(
          out,
          at,
          guitar(_midi(gm), eighth * 3.2, vol: (boss ? 0.075 : 0.07) * accent),
        );
      }

      // 钢琴左手：每小节开头的低音和和弦；奇数小节在第 7 个八分位切分重击。
      if (slot == 0) {
        _mixAt(out, at, piano(_midi(chordRoot - 12), eighth * 7.5, vol: 0.12));
        for (final add in [0, scale[2], scale[4]]) {
          _mixAt(
            out,
            at,
            piano(_midi(chordRoot + add), eighth * 7, vol: boss ? 0.045 : 0.04),
          );
        }
        _mixAt(out, at, thump);
      } else if (slot == 4) {
        if (bar.isEven) {
          // 低音走到五度，增加律动。
          _mixAt(
            out,
            at,
            piano(_midi(chordRoot + scale[4] - 12), eighth * 3.5, vol: 0.07),
          );
        }
        if (!boss && bar.isOdd) {
          _mixAt(out, at, thump);
        }
      } else if (slot == 6 && bar.isOdd) {
        for (final add in [scale[2], scale[4]]) {
          _mixAt(
            out,
            at,
            piano(_midi(chordRoot + add + 12), eighth * 1.6, vol: 0.035),
          );
        }
      }
      if (bSection && slot == 0) {
        // B 段把低音叠上一个八度，听感更饱满。
        _mixAt(out, at, piano(_midi(chordRoot), eighth * 7, vol: 0.06));
      }
      // 乐句转句的小填充：最后一小节的第 7 位轻敲一下。
      if (pos == phraseBars - 1 && slot == 6) {
        _mixAt(out, at, thump);
      }
      if (slot == 3 || slot == 7 || (slot == 5 && bar % 3 == 1)) {
        _mixAt(out, at, brush);
      }
    }

    // 整体低通（两级一阶），削掉刺耳的高频，再统一音量。
    for (var pass = 0; pass < 2; pass++) {
      var y = 0.0;
      for (var i = 0; i < out.length; i++) {
        y += 0.36 * (out[i] - y);
        out[i] = y;
      }
    }
    var peak = 0.0;
    for (final s in out) {
      final a = s.abs();
      if (a > peak) {
        peak = a;
      }
    }
    final gain = peak > 0 ? 0.72 / peak : 1.0;
    for (var i = 0; i < out.length; i++) {
      out[i] *= gain;
    }
    return build(out);
  }
}
