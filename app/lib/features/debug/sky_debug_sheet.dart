import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/host.dart';
import '../../core/sky/celestial_math.dart';
import '../../core/sky/sky_state.dart';
import '../../core/state/sky_state_source.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../shell/dream_shell.dart';
import 'frame_budget.dart';

/// Debug builds only: scrub the day, the year, the observer and the moon;
/// switch vitals presets. Long-press the wordmark to open.
Future<void> showSkyDebugSheet(BuildContext context) {
  if (!kDebugMode) return Future<void>.value();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF07090D),
    barrierColor: const Color(0x99000000),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(),
    builder: (_) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      child: const SingleChildScrollView(child: _SkyDebugSheet()),
    ),
  );
}

class _SkyDebugSheet extends ConsumerWidget {
  const _SkyDebugSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = ref.watch(skyOverridesProvider);
    final n = ref.read(skyOverridesProvider.notifier);
    final live = ref.watch(skyStateProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.margin,
        18,
        Space.margin,
        MediaQuery.paddingOf(context).bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('SKY · DEBUG', style: Type.label),
              const Spacer(),
              _TextButton(
                label: o.any || o.preset != SkyPreset.live
                    ? 'FOLLOW CLOCK'
                    : 'FOLLOWING CLOCK',
                active: !(o.any || o.preset != SkyPreset.live),
                onTap: n.reset,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(height: 1, color: Inks.hairline),
          const SizedBox(height: 10),
          _Slider(
            label: 'TIME',
            display: formatHours(live.timeOfDay),
            value: live.timeOfDay,
            min: 0,
            max: 1,
            onChanged: (v) => n.set(o.copyWith(timeOfDay: v)),
          ),
          _Slider(
            label: 'DAY',
            display: live.dayOfYear.floor().toString().padLeft(3, '0'),
            value: live.dayOfYear.clamp(1, 366),
            min: 1,
            max: 366,
            onChanged: (v) => n.set(o.copyWith(dayOfYear: v)),
          ),
          _Slider(
            label: 'LAT',
            display: '${live.latitudeDeg.toStringAsFixed(1)}°',
            value: live.latitudeDeg,
            min: -66,
            max: 66,
            onChanged: (v) => n.set(o.copyWith(latitudeDeg: v)),
          ),
          _Slider(
            label: 'MOON',
            display: '${(live.moonPhase * 100).round()}%',
            value: live.moonPhase,
            min: 0,
            max: 1,
            onChanged: (v) => n.set(o.copyWith(moonPhase: v)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              for (final p in SkyPreset.values)
                _TextButton(
                  label: p.label.toUpperCase(),
                  active: o.preset == p,
                  onTap: () => n.set(o.copyWith(preset: p)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Inks.hairline),
          const SizedBox(height: 12),
          Text('WEATHER · SIMULATED', style: Type.label),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 12,
            children: [
              for (final p in WeatherPreset.values)
                _TextButton(
                  label: p.label.toUpperCase(),
                  active: o.weatherPreset == p,
                  onTap: () =>
                      n.set(o.copyWith(weatherPreset: p, weather: null)),
                ),
            ],
          ),
          if (o.weatherPreset != WeatherPreset.source) ...[
            const SizedBox(height: 8),
            for (final field in [
              'CLOUD',
              'CUMULUS',
              'CIRRUS',
              'RAIN',
              'FOG',
              'SNOW',
            ])
              _Slider(
                label: field,
                display:
                    '${(_weatherAmount(live.weather, field) * 100).round()}%',
                value: _weatherAmount(live.weather, field),
                min: 0,
                max: 1,
                onChanged: (v) {
                  final w = live.weather ?? const SkyWeather.clear();
                  n.set(
                    o.copyWith(
                      weather: switch (field) {
                        'CLOUD' => w.copyWith(cloudCoverage: v),
                        'CUMULUS' => w.copyWith(cumulus: v),
                        'CIRRUS' => w.copyWith(cirrus: v),
                        'RAIN' => w.copyWith(rain: v),
                        'FOG' => w.copyWith(fog: v),
                        _ => w.copyWith(snow: v),
                      },
                    ),
                  );
                },
              ),
          ],
          const SizedBox(height: 14),
          _HostRow(
            onPreview: () {
              final nav = Navigator.of(context);
              nav.pop();
              nav.push(
                PageRouteBuilder<void>(
                  pageBuilder: (_, _, _) => const DreamShell(),
                  transitionsBuilder: (_, a, _, child) =>
                      FadeTransition(opacity: a, child: child),
                  transitionDuration: const Duration(milliseconds: 280),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          _FrameLine(),
        ],
      ),
    );
  }
}

double _weatherAmount(SkyWeather? weather, String field) => switch (field) {
  'CLOUD' => weather?.cloudCoverage ?? 0,
  'CUMULUS' => weather?.cumulus ?? 0.5,
  'CIRRUS' => weather?.cirrus ?? 0,
  'RAIN' => weather?.rain ?? 0,
  'FOG' => weather?.fog ?? 0,
  _ => weather?.snow ?? 0,
};

class _HostRow extends StatelessWidget {
  const _HostRow({required this.onPreview});
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 24,
      runSpacing: 12,
      children: [
        _TextButton(
          label: 'PREVIEW NIGHTSTAND',
          active: false,
          onTap: onPreview,
        ),
        if (Host.isAndroid)
          _TextButton(
            label: 'SET SCREEN SAVER',
            active: false,
            onTap: () {
              Host.openDreamSettings();
            },
          ),
      ],
    );
  }
}

class _FrameLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final b = FrameBudget.instance;
    if (b.n < 8) {
      return Text('FRAME  —', style: Type.micro.copyWith(color: Inks.faint));
    }
    return Text(
      'FRAME  R ${b.p50RasterMs.toStringAsFixed(1)}/${b.p95RasterMs.toStringAsFixed(1)}  '
      'B ${b.p50BuildMs.toStringAsFixed(1)}/${b.p95BuildMs.toStringAsFixed(1)}  MS  N ${b.n}',
      style: Type.micro.copyWith(color: Inks.faint),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.label,
    required this.display,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label, display;
  final double value, min, max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 68, child: Text(label, style: Type.label)),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 1,
              activeTrackColor: Inks.body,
              inactiveTrackColor: Inks.hairline,
              thumbColor: Inks.strong,
              overlayColor: Inks.full.withValues(alpha: 0.08),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              trackShape: const RectangularSliderTrackShape(),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 56,
          child: Text(display, style: Type.clock, textAlign: TextAlign.right),
        ),
      ],
    );
  }
}

class _TextButton extends StatelessWidget {
  const _TextButton({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Type.label.copyWith(
              color: active ? Inks.strong : Inks.muted,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 1,
            width: 16,
            color: active ? Inks.strong : Colors.transparent,
          ),
        ],
      ),
    );
  }
}
