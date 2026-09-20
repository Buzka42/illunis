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

/// Debug-only APK checksum plumbing. The clean recapture APK is built with
/// `--dart-define=ILLUNIS_APK_SHA=<sha256 of the apk>` so each frame ties
/// back to the installed binary. Empty when not provided; best-effort only.
const String kApkSha = String.fromEnvironment('ILLUNIS_APK_SHA');

/// Per-frame metadata for the recapture manifest. Every captured frame ties
/// back to the exact commit + binary and records the full reproduction
/// context: scenario, viewport, DPR, insets, keyboard, text scale, and the
/// clock/source overrides in force for the shot.
Map<String, Object?> describeFrame(
  MediaQueryData mq, {
  required String scenario,
  required String fileName,
  double? timeOfDay,
  String preset = 'live',
  Map<String, Object?> clock = const {},
  Map<String, Object?> sources = const {},
}) {
  final size = mq.size;
  return {
    'file': fileName,
    'commit': kBuildSha,
    'apkSha256': kApkSha,
    'scenario': scenario,
    'width': size.width,
    'height': size.height,
    'dpr': mq.devicePixelRatio,
    'padding': {
      'left': mq.padding.left,
      'top': mq.padding.top,
      'right': mq.padding.right,
      'bottom': mq.padding.bottom,
    },
    'viewInsets': {'bottom': mq.viewInsets.bottom},
    'keyboardOpen': mq.viewInsets.bottom > 8.0,
    'textScale': mq.textScaler.scale(10) / 10,
    'timeOfDay': timeOfDay,
    'preset': preset,
    'clock': clock,
    'sources': sources,
  };
}

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
  // Capture manifest (Kimi BLD-01 scaffold, G1 recapture): run-level commit
  // plus one metadata entry per frame — {commit, apkSha256, scenario, width,
  // height, dpr, padding, viewInsets, keyboardOpen, textScale, timeOfDay,
  // preset, clock, sources}. MediaQuery is read at the shell boundary.
  final manifest = <String, Object>{
    'commit': kBuildSha,
    'apkSha256': kApkSha,
    'times': kCaptureTimes,
    'frames': <Map<String, Object?>>[],
  };
  final overrides = container.read(skyOverridesProvider.notifier);
  await Future<void>.delayed(const Duration(milliseconds: 1500));
  for (final preset in presets) {
    for (final t in kCaptureTimes) {
      // Boundary key context is stable for the run; read per frame so each
      // manifest entry carries that frame's own metrics.
      // ignore: use_build_context_synchronously
      final frameCtx = boundary.currentContext;
      // ignore: use_build_context_synchronously
      final frameMq = frameCtx == null ? null : MediaQuery.of(frameCtx);
      overrides.set(SkyOverrides(timeOfDay: t, preset: preset));
      // Long enough for the camera's head-turn to settle on the new bearing.
      await Future<void>.delayed(const Duration(milliseconds: 3600));
      final ro = frameCtx?.findRenderObject();
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
      (manifest['frames'] as List<Map<String, Object?>>).add(
        frameMq == null
            ? {'file': name, 'commit': kBuildSha, 'apkSha256': kApkSha}
            : describeFrame(
                frameMq,
                scenario: 'sky',
                fileName: name,
                timeOfDay: t,
                preset: preset.name,
              ),
      );
      debugPrint('captured $name');
    }
  }
  await File(
    '${dir.path}${Platform.pathSeparator}manifest.json',
  ).writeAsString(jsonEncode(manifest));
  overrides.reset();
  debugPrint('capture complete');
}
