import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/synth_wav.dart';

void main() {
  test(
    'world BGM spans 16 bars and every boss theme is a distinct 4-bar loop',
    () {
      for (var world = 0; world < 9; world++) {
        final bpm = 92 + world % 3 * 6;
        final bossBpm = 76 + world % 3 * 4;
        final regular = _wavData(SynthWav.bgmLoopForWorld(world));
        final boss = _wavData(SynthWav.bossLoopForWorld(world));

        expect(
          regular.lengthInBytes / (44100 * 2),
          closeTo(16 * 4 * 60 / bpm, 0.02),
          reason: 'world $world regular loop',
        );
        expect(
          boss.lengthInBytes / (44100 * 2),
          closeTo(4 * 4 * 60 / bossBpm, 0.02),
          reason: 'world $world boss loop',
        );
        expect(boss.lengthInBytes, lessThan(regular.lengthInBytes));
      }

      final regular = _wavData(SynthWav.bgmLoopForWorld(0));
      final boss = _wavData(SynthWav.bossLoopForWorld(0));
      final halfSamples = regular.lengthInBytes ~/ 4;
      var secondHalfDiffers = false;
      var bossDiffers = false;
      for (var sample = 0; sample < halfSamples; sample++) {
        if (regular.getInt16(sample * 2, Endian.little) !=
            regular.getInt16((sample + halfSamples) * 2, Endian.little)) {
          secondHalfDiffers = true;
        }
      }
      for (
        var byteOffset = 0;
        byteOffset + 1 < math.min(regular.lengthInBytes, boss.lengthInBytes);
        byteOffset += 2
      ) {
        if (regular.getInt16(byteOffset, Endian.little) !=
            boss.getInt16(byteOffset, Endian.little)) {
          bossDiffers = true;
        }
      }
      expect(secondHalfDiffers, isTrue, reason: 'the second 8 bars must vary');
      expect(
        bossDiffers,
        isTrue,
        reason: 'boss music must not reuse the main theme',
      );
    },
  );
}

ByteData _wavData(Uint8List wav) {
  expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
  expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
  final header = ByteData.sublistView(wav);
  final dataSize = header.getUint32(40, Endian.little);
  return ByteData.sublistView(wav, 44, 44 + dataSize);
}
