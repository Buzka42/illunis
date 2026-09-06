import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/sky_state_source.dart';

/// Debug builds only. Run with
/// `flutter run --dart-define=ILLUNIS_CAPTURE=<dir>` and the shell writes a
/// PNG of itself at a set of times of day, then returns to the clock.
/// It is how the sky is reviewed as a contact sheet rather than a viewport.
const String kCaptureDir = String.fromEnvironment('ILLUNIS_CAPTURE');

const List<double> kCaptureTimes = [
  0.02, // deep night
  0.23, // astronomical → nautical dawn
  0.262, // just before sunrise
  0.30, // low sun
  0.50, // noon
  0.74, // late afternoon
  0.785, // sunset
  0.82, // civil dusk
  0.90, // night, moon up
];

Future<void> runCaptureSequence(
  GlobalKey boundary,
  ProviderContainer container, {
  List<SkyPreset> presets = const [SkyPreset.live],
}) async {
  if (!kDebugMode || kCaptureDir.isEmpty) return;
  final dir = Directory(kCaptureDir);
  await dir.create(recursive: true);
  final overrides = container.read(skyOverridesProvider.notifier);
  await Future<void>.delayed(const Duration(milliseconds: 1500));
  for (final preset in presets) {
    for (final t in kCaptureTimes) {
      overrides.set(SkyOverrides(timeOfDay: t, preset: preset));
      await Future<void>.delayed(const Duration(milliseconds: 1800));
      final ro = boundary.currentContext?.findRenderObject();
      if (ro is! RenderRepaintBoundary) continue;
      final image = await ro.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) continue;
      final name =
          '${preset.name}_t${(t * 1000).round().toString().padLeft(4, '0')}.png';
      await File(
        '${dir.path}${Platform.pathSeparator}$name',
      ).writeAsBytes(bytes.buffer.asUint8List());
      debugPrint('captured $name');
    }
  }
  overrides.reset();
  debugPrint('capture complete');
}
