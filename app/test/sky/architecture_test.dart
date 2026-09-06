import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The 3D layer is dumb on purpose. It may know geometry, paint and
/// `dart:ui`; it may not know Riverpod, the clock, a database or a
/// kilocalorie. If this fails, the seam the backend plugs into has moved.
void main() {
  test('core/sky imports nothing above its station', () {
    final dir = Directory('lib/core/sky');
    expect(dir.existsSync(), isTrue);
    final forbidden = RegExp(
      r"import\s+'(package:flutter_riverpod|package:riverpod|\.\./state|\.\./\.\./features|\.\./theme|package:illunis/core/state|package:illunis/features|dart:io)",
    );
    final health = RegExp(r'\b(kcal|calorie|workout|DateTime\.now)\b');
    for (final f in dir.listSync().whereType<File>()) {
      final src = f.readAsStringSync();
      expect(
        forbidden.hasMatch(src),
        isFalse,
        reason: '${f.path} imports across the seam',
      );
      expect(
        health.hasMatch(src),
        isFalse,
        reason: '${f.path} knows something it should not',
      );
    }
  });
}
