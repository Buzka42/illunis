import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/sky/celestial_math.dart';
import 'package:illunis/core/sky/star_catalog.dart';
import 'package:illunis/core/sky/star_field.dart';

void main() {
  test(
    'visual magnitude retains faint differences, including V=5 versus V=6',
    () {
      for (var mag = -1.4; mag < 6; mag += 0.1) {
        expect(starIntensity(mag), greaterThan(starIntensity(mag + 0.1)));
      }
      expect(starIntensity(5), greaterThan(starIntensity(6) * 2));
      expect(starIntensity(-1.44), 1);
    },
  );
  test('extinction depends on air mass and atmospheric turbidity', () {
    expect(starExtinction(0, 2), 0);
    expect(starExtinction(90 * degToRad, 2), closeTo(1, 0.001));
    expect(
      starExtinction(5 * degToRad, 2),
      lessThan(starExtinction(30 * degToRad, 2)),
    );
    expect(
      starExtinction(5 * degToRad, 6),
      lessThan(starExtinction(5 * degToRad, 2)),
    );
  });
  test('bundled catalog preserves all rows and sorted visual magnitude', () {
    expect(kStarPack.length, kStarCount * 4);
    for (var i = 0; i < kStarCount; i++) {
      final star = catalogStarAt(i);
      expect(
        star.raRad.isFinite && star.decRad.isFinite && star.vMag.isFinite,
        isTrue,
      );
      expect(star.vMag, lessThanOrEqualTo(6));
      if (i > 0) {
        expect(star.vMag, greaterThanOrEqualTo(catalogStarAt(i - 1).vMag));
      }
    }
    expect(() => kStarPack[0] = 0, throwsUnsupportedError);
  });
}
