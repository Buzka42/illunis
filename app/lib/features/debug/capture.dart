import 'dart:io';
import 'dart:ui' as ui;
import 'dart:convert';

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

/// Debug-only build-SHA plumbing (Kimi BLD-01 scaffold). Run with
/// `--dart-define=ILLUNIS_BUILD_SHA=<sha>` so a recapture run can tie every
/// frame back to the exact commit. Empty in normal dev runs; never read in
/// release (this whole sequence is kDebugMode-gated, no release surface).
const String kBuildSha = String.fromEnvironment('ILLUNIS_BUILD_SHA');

const List<double> kCaptureTimes = [
  0.02, // deep night
  0.12, // small hours, planets up
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
  // Capture line: ties the whole run to the build under test.
  debugPrint('capture build ${kBuildSha.isEmpty ? 'dev' : kBuildSha}');
  // Capture manifest scaffold (Kimi BLD-01): the recapture step will record
  // one entry per frame with {commit, size, dpr, insets} — commit is
  // kBuildSha above; size/dpr/insets come from MediaQuery at the shell
  // boundary and are not yet threaded through. Run-level manifest only.
  final manifest = <String, Object>{
    'commit': kBuildSha,
    'times': kCaptureTimes,
    'frames': <String>[],
  };
  final overrides = container.read(skyOverridesProvider.notifier);
  await Future<void>.delayed(const Duration(milliseconds: 1500));
  for (final preset in presets) {
    for (final t in kCaptureTimes) {
      overrides.set(SkyOverrides(timeOfDay: t, preset: preset));
      // Long enough for the camera's head-turn to settle on the new bearing.
      await Future<void>.delayed(const Duration(milliseconds: 3600));
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
      (manifest['frames'] as List<String>).add(name);
      debugPrint('captured $name');
    }
  }
  await File(
    '${dir.path}${Platform.pathSeparator}manifest.json',
  ).writeAsString(jsonEncode(manifest));
  overrides.reset();
  debugPrint('capture complete');
}
