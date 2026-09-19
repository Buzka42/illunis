import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/features/timeline/timeline_bar.dart';

void main() {
  test('scrub badge: LIVE only on the clock with data', () {
    expect(
      scrubBadgeLabel(scrub: null, hasData: true),
      'LIVE',
    );
    expect(
      scrubBadgeIsLive(scrub: null, hasData: true),
      isTrue,
    );
  });

  test('scrub badge: NOW when live with no data', () {
    expect(
      scrubBadgeLabel(scrub: null, hasData: false),
      'NOW',
    );
    expect(
      scrubBadgeIsLive(scrub: null, hasData: false),
      isFalse,
    );
  });

  test('scrub badge: time when scrubbed, never LIVE', () {
    expect(
      scrubBadgeLabel(scrub: 0.5, hasData: true),
      '12:00',
    );
    expect(
      scrubBadgeIsLive(scrub: 0.5, hasData: true),
      isFalse,
    );
    expect(
      scrubBadgeLabel(scrub: 0.0, hasData: true),
      '00:00',
    );
    expect(
      scrubBadgeIsLive(scrub: 0.0, hasData: false),
      isFalse,
    );
  });
}
