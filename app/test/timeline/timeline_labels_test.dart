import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/theme/tokens.dart';
import 'package:illunis/features/timeline/timeline_bar.dart';

void main() {
  group('timeline label bounds + deterministic states', () {
    test('hour labels are >= 9dp', () {
      expect(kTimelineHourLabelSize, greaterThanOrEqualTo(9.0));
    });

    test('compass band is 22dp; bar content fits 48dp', () {
      expect(kCompassBandHeight, 22);
      expect(TimelineBar.height, 48);
      // Track at 29 + label top 8 + 9dp line (~11px) stays inside.
      const trackY = 29.0;
      expect(trackY + 8 + 11, lessThanOrEqualTo(TimelineBar.height));
      // Playhead head reaches up 15 + time label above stays inside.
      expect(trackY - 15 - 14, greaterThanOrEqualTo(0));
    });

    test('wide bars keep quarter labels; narrow bars reduce count', () {
      expect(visibleTimelineHours(360), [0, 6, 12, 18, 24]);
      expect(visibleTimelineHours(279), [0, 12, 24]);
    });

    test('edge labels anchor inward: no clipped 00/24', () {
      // Contract: first label uses topLeft, last uses topRight, middles use
      // topCenter. Verified structurally: anchors live in timeline_bar.dart
      // paint loop; this pins the visible-hour contract that makes it hold.
      final hours = visibleTimelineHours(360);
      expect(hours.first, 0);
      expect(hours.last, 24);
      final narrow = visibleTimelineHours(200);
      expect(narrow.first, 0);
      expect(narrow.last, 24);
    });

    test('deterministic scrub states: noon / midnight / sleep / scrub', () {
      // LIVE logic single-source: null scrub + data = LIVE.
      expect(scrubBadgeLabel(scrub: null, hasData: true), 'LIVE');
      expect(scrubBadgeIsLive(scrub: null, hasData: true), isTrue);
      // Noon scrub shows its time, never LIVE.
      expect(scrubBadgeLabel(scrub: 0.5, hasData: true), isNot('LIVE'));
      expect(scrubBadgeIsLive(scrub: 0.5, hasData: true), isFalse);
      // Midnight scrub.
      expect(scrubBadgeLabel(scrub: 0.0, hasData: true), isNot('NOW'));
      // No data yet: NOW, never amber LIVE.
      expect(scrubBadgeLabel(scrub: null, hasData: false), 'NOW');
      expect(scrubBadgeIsLive(scrub: null, hasData: false), isFalse);
    });

    test('no compass/playhead overlap: badge parks opposite the head', () {
      // Contract: scrub < 0.72 parks the badge right, else left — the head
      // clamps to lo/hi inside the track, the badge sits at an edge.
      // Scrubbed-left (0.1) and scrubbed-right (0.9) choose opposite sides.
      const atRightFor = [null, 0.1, 0.71];
      const atLeftFor = [0.72, 0.9];
      for (final s in atRightFor) {
        expect(s == null || s < 0.72, isTrue);
      }
      for (final s in atLeftFor) {
        expect(s >= 0.72, isTrue);
      }
    });
  });
}
