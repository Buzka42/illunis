// Review harness only. Never imported by the product entrypoints.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/sky/celestial_math.dart';
import 'package:illunis/core/sky/celestial_scene.dart';
import 'package:illunis/core/sky/sky_state.dart';
import 'package:illunis/core/sky/sky_view.dart';
import 'package:illunis/core/state/app_providers.dart';
import 'package:illunis/core/state/sky_state_source.dart';
import 'package:illunis/features/shell/dream_shell.dart';
import 'package:illunis/main.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  if (kReleaseMode) throw StateError('Review harness is debug/profile only');
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  const out = String.fromEnvironment('ASTRA_CAPTURE_DIR');
  if (out.isEmpty) throw ArgumentError('Pass ASTRA_CAPTURE_DIR');
  // Android 11+ requires Context.getExternalFilesDir to create this root;
  // Dart cannot mkdir Android/data directly under scoped storage.
  if (Platform.isAndroid) await getExternalStorageDirectory();
  final dir = await Directory(out).create(recursive: true);
  final base = SkyState(
    timeOfDay: 0.5,
    dayOfYear: 252,
    epochDays: epochDaysForDate(2026, 9, 9) - 2 / 24,
    latitudeDeg: 52.23,
    solarNoon: solarNoonFor(epochDaysForDate(2026, 9, 9) + 10 / 24, 21.01, 2),
    moonPhase: moonPhaseFor(DateTime.utc(2026, 9, 9, 10)),
  );
  SkyState atAltitude(double degrees) {
    var lo = base.solarNoon, hi = 1.0;
    for (var i = 0; i < 36; i++) {
      final mid = (lo + hi) / 2;
      final alt =
          CelestialScene.resolve(base.copyWith(timeOfDay: mid)).sunAltitudeRad *
          radToDeg;
      if (alt > degrees) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final t = (lo + hi) / 2;
    return base.copyWith(
      timeOfDay: t,
      moonPhase: moonPhaseAt(base.epochDays + t),
    );
  }

  final nightEpoch = epochDaysForDate(2026, 9, 26) - 2 / 24;
  final night = base.copyWith(
    dayOfYear: 269,
    epochDays: nightEpoch,
    timeOfDay: 0.04,
    moonPhase: moonPhaseAt(nightEpoch + 0.04),
    solarNoon: solarNoonFor(nightEpoch + 0.04, 21.01, 2),
  );
  final cases = <(String, SkyState, String)>[
    ('clear_noon', base.copyWith(timeOfDay: base.solarNoon), 'sky'),
    ('golden_set', atAltitude(1), 'sky'),
    ('civil_twilight', atAltitude(-3), 'sky'),
    ('nautical_twilight', atAltitude(-9), 'sky'),
    ('astronomical_twilight', atAltitude(-15), 'sky'),
    ('night_moon', night, 'sky'),
    for (final preset in WeatherPreset.values)
      if (preset != WeatherPreset.source && preset != WeatherPreset.clear)
        (
          'weather_${preset.name}',
          base.copyWith(weather: preset.weather),
          'sky',
        ),
    (
      'overcast_night',
      night.copyWith(weather: WeatherPreset.overcast.weather),
      'sky',
    ),
    ('dashboard', base.copyWith(timeOfDay: base.solarNoon), 'dashboard'),
    ('journal', base.copyWith(timeOfDay: base.solarNoon), 'journal'),
    (
      'dashboard_rain',
      base.copyWith(weather: WeatherPreset.rain.weather),
      'dashboard',
    ),
    ('nightstand', night, 'dream'),
  ];
  final report = <Map<String, Object?>>[];
  final timings = <FrameTiming>[];
  void collect(List<FrameTiming> frames) => timings.addAll(frames);
  SchedulerBinding.instance.addTimingsCallback(collect);
  for (final (name, state, surface) in cases) {
    final boundary = GlobalKey();
    final home = surface == 'sky'
        ? SkyView(state: state)
        : surface == 'dream'
        ? const DreamShell()
        : null;
    runApp(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          storeProvider.overrideWith((ref) {
            final store = AppStore.memory();
            ref.onDispose(store.dispose);
            return store;
          }),
          skyStateSourceProvider.overrideWith((ref) => _FixedSource(state)),
        ],
        child: RepaintBoundary(
          key: boundary,
          child: IllunisApp(home: home ?? const _DefaultShell()),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    if (surface == 'journal') {
      void selectJournal(Element element) {
        final widget = element.widget;
        if (widget is PageView) widget.controller?.jumpToPage(0);
        element.visitChildren(selectJournal);
      }

      (boundary.currentContext! as Element).visitChildren(selectJournal);
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    var warmupMaxMs = 0.0;
    for (var attempt = 0; attempt < 3; attempt++) {
      for (final frame in timings) {
        final ms = frame.rasterDuration.inMicroseconds / 1000;
        if (ms > warmupMaxMs) warmupMaxMs = ms;
      }
      timings.clear();
      await Future<void>.delayed(const Duration(seconds: 4));
      if (timings.length >= 120 &&
          timings.every((f) => f.rasterDuration.inMilliseconds < 100)) {
        break;
      }
    }
    double percentile(Duration Function(FrameTiming) pick, double p) {
      final sorted = timings.map((f) => pick(f).inMicroseconds / 1000).toList()
        ..sort();
      return sorted.isEmpty ? 0 : sorted[((sorted.length - 1) * p).round()];
    }

    final metrics = <String, Object?>{
      'name': name,
      'surface': surface,
      'state': state.toString(),
      'platform': defaultTargetPlatform.name,
      'mode': kProfileMode ? 'profile' : 'debug',
      'frames': timings.length,
      'warmup_raster_max_ms': warmupMaxMs,
      'raster_p50_ms': percentile((f) => f.rasterDuration, 0.5),
      'raster_p95_ms': percentile((f) => f.rasterDuration, 0.95),
      'build_p95_ms': percentile((f) => f.buildDuration, 0.95),
    };
    await SchedulerBinding.instance.endOfFrame;
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final view = View.of(boundary.currentContext!);
    final picture = await render.toImage(pixelRatio: view.devicePixelRatio);
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    metrics['width'] = picture.width;
    metrics['height'] = picture.height;
    picture.dispose();
    await File(
      '${dir.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    report.add(metrics);
    debugPrint('ASTRA_CAPTURE ${jsonEncode(metrics)}');
  }
  SchedulerBinding.instance.removeTimingsCallback(collect);
  await File(
    '${dir.path}/metrics.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
  debugPrint('ASTRA_CAPTURE_COMPLETE ${dir.path}');
}

// Keeps the harness's default home exactly the product's home.
class _DefaultShell extends StatelessWidget {
  const _DefaultShell();
  @override
  Widget build(BuildContext context) => const IllunisApp().home;
}

class _FixedSource implements SkyStateSource {
  const _FixedSource(this.state);
  final SkyState state;
  @override
  Stream<SkyState> get states => Stream.value(state);
  @override
  SkyState peek() => state;
  @override
  Future<void> dispose() async {}
  @override
  void setSuspended(bool suspended) {}
}
