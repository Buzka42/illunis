import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The 3D layer is dumb on purpose. It may know geometry, paint and
/// `dart:ui`; it may not know Riverpod, the clock, a database or a
/// kilocalorie. If this fails, the seam the backend plugs into has moved.
void main() {
  test('core/sky imports nothing above its station', () {
    final dir = Directory('lib/core/sky');
    expect(dir.existsSync(), isTrue);
    final imports = RegExp(r'''(?:import|export)\s+['"]([^'"]+)['"]''');
    final health = RegExp(r'\b(kcal|calorie|workout|DateTime\.now)\b');
    for (final f
        in dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final src = f.readAsStringSync();
      for (final match in imports.allMatches(src)) {
        final uri = match.group(1)!;
        final own =
            !uri.contains(':') &&
            !uri.contains('..') &&
            File('${dir.path}/$uri').existsSync();
        expect(
          uri == 'dart:math' ||
              uri == 'dart:ui' ||
              uri.startsWith('package:flutter/') ||
              own ||
              uri == '../theme/tokens.dart',
          isTrue,
          reason: '${f.path} imports across the seam: $uri',
        );
      }
      expect(
        health.hasMatch(src),
        isFalse,
        reason: '${f.path} knows something it should not',
      );
    }
  });
}
