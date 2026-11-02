import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/synth_wav.dart';

void main() {
  test('every world melody has varied rhythm, range and phrasing', () {
    for (var world = 0; world < 9; world++) {
      for (final alt in [false, true]) {
        final plan = SynthWav.melodyPlanForWorld(world, alt: alt);
        expect(plan.length, 16 * 8, reason: 'w$world alt=$alt');

        // 每小节哪些八分位起音，作为这一小节的节奏型。
        final rhythms = <String>[
          for (var bar = 0; bar < 16; bar++)
            [
              for (var slot = 0; slot < 8; slot++)
                plan[bar * 8 + slot] == null ? '0' : '1',
            ].join(),
        ];
        expect(
          rhythms.toSet().length,
          greaterThanOrEqualTo(5),
          reason: 'w$world alt=$alt rhythm patterns: $rhythms',
        );
        // 相邻小节不连续重复同一种节奏（乐句收尾的长音小节除外）。
        var repeats = 0;
        for (var bar = 1; bar < 16; bar++) {
          if (rhythms[bar] == rhythms[bar - 1]) {
            repeats++;
          }
        }
        expect(repeats, lessThanOrEqualTo(2), reason: 'w$world alt=$alt');

        final pitches = plan.whereType<int>().toList();
        expect(pitches.toSet().length, greaterThanOrEqualTo(7));
        expect(
          pitches.reduce((a, b) => a < b ? a : b),
          greaterThanOrEqualTo(55),
        );
        expect(pitches.reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(81));

        // 每一句（4 小节）都不能和下一句完全相同：A A' B A'' 的结构。
        String phrase(int i) => plan.sublist(i * 32, i * 32 + 32).join(',');
        expect(phrase(0) == phrase(1), isFalse, reason: "A' differs w$world");
        expect(phrase(0) == phrase(2), isFalse, reason: 'B differs w$world');
        expect(phrase(2) == phrase(3), isFalse, reason: "A'' differs w$world");
      }
    }
  });

  test(
    'regular and alternate arrangements of a world use different melodies',
    () {
      for (var world = 0; world < 9; world++) {
        expect(
          SynthWav.melodyPlanForWorld(world).join(','),
          isNot(SynthWav.melodyPlanForWorld(world, alt: true).join(',')),
          reason: 'world $world',
        );
      }
    },
  );
}
