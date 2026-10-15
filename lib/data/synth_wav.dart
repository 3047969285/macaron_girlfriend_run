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

  static double _midi(int note) =>
      440 * math.pow(2, (note - 69) / 12).toDouble();

  static void _mixAt(List<double> out, int start, List<double> src) {
    final end = math.min(out.length, start + src.length);
    for (var i = start; i < end; i++) {
      out[i] += src[i - start];
    }
  }

  /// 双正弦加一点三次谐波，比单音更厚，也不会变成方波的刺耳感。
  static List<double> _softNote(double freq, double dur, {double vol = 0.16}) {
    final n = (_sampleRate * dur).round();
    final out = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final t = i / _sampleRate;
      final env = _env(t, 0.02, dur * 0.85, dur);
      final fundamental = math.sin(2 * math.pi * freq * t);
      final octave = math.sin(2 * math.pi * freq * 2.003 * t);
      final fifth = math.sin(2 * math.pi * freq * 3 * t);
      out[i] = vol * env * (fundamental * 0.72 + octave * 0.22 + fifth * 0.06);
    }
    return out;
  }

  static List<double> _kick(double dur) {
    final n = (_sampleRate * dur).round();
    final out = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final t = i / _sampleRate;
      final f = 150 - 110 * (t / dur).clamp(0.0, 1.0);
      out[i] = 0.34 * math.sin(2 * math.pi * f * t) * math.exp(-t * 18);
    }
    return out;
  }

  static List<double> _hat(double dur) {
    final rnd = math.Random(3);
    final n = (_sampleRate * dur).round();
    final out = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final t = i / _sampleRate;
      out[i] = (rnd.nextDouble() * 2 - 1) * 0.05 * math.exp(-t * 48);
    }
    return out;
  }

  /// 每个世界一段 8 小节原创循环：A、应答、对比段、对比段高八度。
  static Uint8List bgmLoopForWorld(int worldIndex) {
    const motifs = <List<int>>[
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
    const roots = <List<int>>[
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
    const scales = <List<int>>[
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
    final world = worldIndex.clamp(0, 8);
    final bpm = 92 + (world % 3) * 6;
    final eighth = 60 / bpm / 2;
    final bars = roots[world];
    final scale = scales[world];
    final motif = motifs[world];
    final steps = motif.length * 4;
    final total = eighth * steps;
    final out = List<double>.filled((_sampleRate * total).round(), 0);
    final kick = _kick(0.16);
    final hat = _hat(0.05);
    final snare = _hat(0.09);

    for (var step = 0; step < steps; step++) {
      final at = (_sampleRate * eighth * step).round();
      final index = step % motif.length;
      final section = step ~/ motif.length;
      final raw = motif[index];
      final degree = switch (section) {
        0 => raw,
        1 => raw < 0 ? -1 : (raw + 4) % 9,
        2 => raw < 0 ? (index % 4 == 0 ? 2 : -1) : (raw + 5) % 8,
        _ => raw < 0 ? -1 : (raw + 7) % 9,
      };
      if (degree >= 0) {
        final pc = scale[degree.clamp(0, scale.length - 1)];
        final midi =
            bars[0] + pc + (degree >= 7 ? 12 : 0) + (section >= 2 ? 12 : 0);
        _mixAt(
          out,
          at,
          _softNote(_midi(midi), eighth * 0.92, vol: section >= 2 ? 0.11 : 0.15),
        );
        if (step % 2 == 0) {
          final counter = scale[(degree + 2).clamp(0, scale.length - 1)];
          _mixAt(
            out,
            at,
            _softNote(_midi(bars[0] + counter - 12), eighth * 1.5, vol: 0.06),
          );
        }
      }
      if (step % 2 == 0) {
        _mixAt(out, at, hat);
      } else if (section > 0) {
        final root = bars[(step ~/ 8) % bars.length];
        _mixAt(out, at, _softNote(_midi(root + 12), eighth * 0.42, vol: 0.05));
      }
      if (section >= 2 && step % 4 == 2) {
        _mixAt(out, at, snare);
      }
      if (step % 4 == 0) {
        _mixAt(out, at, kick);
        final root = bars[(step ~/ 8 + (section >= 2 ? 2 : 0)) % bars.length];
        _mixAt(out, at, _softNote(_midi(root - 12), eighth * 1.8, vol: 0.2));
      }
      if (step >= steps - 4 && degree >= 0) {
        final fill = scale[index.clamp(0, scale.length - 1)];
        _mixAt(
          out,
          at,
          _softNote(_midi(bars[0] + fill + 12), eighth * 0.35, vol: 0.08),
        );
      }
      if (step % 8 == 0) {
        final root = bars[(step ~/ 8 + (section >= 2 ? 2 : 0)) % bars.length];
        for (final add in [0, 4, 7]) {
          _mixAt(
            out,
            at,
            _softNote(_midi(root + add), eighth * 3.6, vol: 0.04),
          );
        }
      }
    }
    var peak = 0.0;
    for (final s in out) {
      final a = s.abs();
      if (a > peak) {
        peak = a;
      }
    }
    final gain = peak > 0.9 ? 0.9 / peak : 1.0;
    for (var i = 0; i < out.length; i++) {
      out[i] *= gain;
    }
    return build(out);
  }
}
