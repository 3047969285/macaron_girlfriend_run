import 'dart:math' as math;
import 'dart:typed_data';

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
      out[i] = (rnd.nextDouble() * 2 - 1) * vol * _env(t, 0.001, dur * 0.5, dur);
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

  static Uint8List coin() => build(
        mix([
          tone(988, 0.06, vol: 0.3),
          tone(1318, 0.09, vol: 0.22),
        ]),
      );

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

  static Uint8List win() {
    final parts = <List<double>>[];
    for (final e in [(523, 0.12), (659, 0.12), (784, 0.18), (1046, 0.25)]) {
      parts.add(tone(e.$1.toDouble(), e.$2, vol: 0.28));
    }
    return build(mix(parts));
  }

  /// 马卡龙风 BGM 循环
  static Uint8List bgmLoop() => bgmLoopForWorld(0);

  /// 按世界移调的 BGM 循环
  static Uint8List bgmLoopForWorld(int worldIndex) {
    const base = [
      (523.0, 0.18),
      (659.0, 0.18),
      (784.0, 0.18),
      (659.0, 0.18),
      (587.0, 0.18),
      (740.0, 0.18),
      (880.0, 0.18),
      (740.0, 0.18),
      (659.0, 0.18),
      (784.0, 0.18),
      (988.0, 0.22),
      (784.0, 0.18),
      (698.0, 0.18),
      (880.0, 0.18),
      (1046.0, 0.24),
      (880.0, 0.18),
    ];
    final shiftSemitone = (worldIndex % 9) * 0.7;
    final ratio = math.pow(2, shiftSemitone / 12).toDouble();
    final tempo = 1.0 - (worldIndex % 3) * 0.04;
    final seq = <List<double>>[];
    for (var r = 0; r < 2; r++) {
      for (final n in base) {
        seq.add(tone(n.$1 * ratio, n.$2 * tempo, vol: 0.15));
        seq.add(silence(0.02 * tempo));
      }
    }
    return build(mix(seq));
  }
}
