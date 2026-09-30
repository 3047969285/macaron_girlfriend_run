import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';

void main() {
  test('enemy combo bonus grows and stays capped', () {
    expect(GameConstants.enemyComboBonusFor(-1), 0);
    expect(GameConstants.enemyComboBonusFor(0), 0);
    expect(GameConstants.enemyComboBonusFor(1), 0);
    expect(GameConstants.enemyComboBonusFor(2), 25);
    expect(GameConstants.enemyComboBonusFor(5), 100);
    expect(GameConstants.enemyComboBonusFor(99), 100);
  });
}
