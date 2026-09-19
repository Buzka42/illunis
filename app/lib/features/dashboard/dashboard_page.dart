import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/records.dart';
import '../../core/i18n/dates.dart';
import '../../core/i18n/strings.dart';
import '../../core/sky/celestial_math.dart';
import '../../core/sky/celestial_scene.dart';
import '../../core/sky/sky_state.dart';
import '../../core/state/app_providers.dart';
import '../../core/state/sky_state_source.dart';
import '../../core/state/sleep_record.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../shell/surface_title.dart';
import '../timeline/weather_projection.dart';
import '../timeline/weather_sheet.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key, required this.scene, required this.state});
  final ValueListenable<ResolvedScene?> scene;
  final SkyState state;
  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(journalDayProvider);
    final day = dayKey(selected);
    final today = sameDay(selected, DateTime.now());
    final stats = ref.watch(lifeStatsProvider(day));
    final figures = ref.watch(journalFiguresProvider);
    final preset = ref.watch(skyOverridesProvider.select((o) => o.preset));
    final mock = today && preset != SkyPreset.live;
    final strain = mock ? widget.state.strain : figures.summary?.strain;
    final sleep = mock
        ? ref.watch(sleepRecordProvider)?.asleepHours
        : stats.sleep.value;
    final cells = <Widget>[
      _Stat(
        'BURN',
        number(stats.caloriesBurned.value),
        'KCAL',
        stats.caloriesBurned.source.name,
      ),
      _Stat(
        S.intake,
        number(stats.calorieIntake.value),
        'KCAL',
        stats.calorieIntake.source.name,
      ),
      _Stat('STEPS', number(stats.steps.value), '', stats.steps.source.name),
      _Stat(
        S.sleep,
        sleep == null ? S.emptyDash : '${sleep.toStringAsFixed(1)}h',
        '',
        mock ? 'MOCK' : stats.sleep.source.name,
      ),
      _Stat(
        'REST HR',
        number(stats.restingHr.value),
        'BPM',
        stats.restingHr.source.name,
      ),
      _Stat(
        'ACTIVE',
        number(stats.activeMinutes.value),
        'MIN',
        stats.activeMinutes.source.name,
      ),
      _Stat(
        'RESTED',
        stats.restedness.value == null
            ? S.emptyDash
            : '${(stats.restedness.value! * 100).round()}',
        '/100',
        stats.restedness.source.name,
      ),
      _Stat(
        S.strain,
        strain?.toStringAsFixed(2) ?? S.emptyDash,
        'LOAD',
        mock ? 'MOCK' : 'RULE',
      ),
    ];
    final hasData =
        figures.entryCount > 0 ||
        [
          stats.caloriesBurned.value,
          stats.calorieIntake.value,
          stats.steps.value,
          sleep,
          stats.restingHr.value,
          stats.activeMinutes.value,
          stats.restedness.value,
        ].any((v) => v != null);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.margin, 0, Space.margin, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const SurfaceTitle(S.dashboard),
                  const Spacer(),
                  Text(
                    mock
                        ? (preset == SkyPreset.noData ? S.noData : S.mockData)
                        : (hasData ? S.local : S.noData),
                    style: Type.micro,
                  ),
                  const SizedBox(width: 12),
                  _Action(
                    S.prev,
                    () => ref.read(journalDayProvider.notifier).prev(),
                  ),
                  const SizedBox(width: 12),
                  _Action(
                    S.next,
                    today
                        ? null
                        : () => ref.read(journalDayProvider.notifier).next(),
                  ),
                ],
              ),
              if (!today) Text(formatShortDate(selected), style: Type.micro),
              const _WeatherLine(),
              const SizedBox(height: 4),
              for (var row = 0; row < 2; row++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var col = 0; col < 4; col++)
                        Expanded(child: cells[row * 4 + col]),
                    ],
                  ),
                ),
              Container(height: 1, color: Inks.hairline),
              ValueListenableBuilder<ResolvedScene?>(
                valueListenable: widget.scene,
                builder: (context, scene, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      _FigureLine(
                        'SUN',
                        '↑ ${time(scene?.sunrise)}   ↓ ${time(scene?.sunset)}',
                        scene?.dayLength == null
                            ? S.emptyDash
                            : formatDuration(scene!.dayLength!),
                      ),
                      _FigureLine(
                        'MOON',
                        '↑ ${time(scene?.moonrise)}   ↓ ${time(scene?.moonset)}',
                        scene == null
                            ? S.emptyDash
                            : '${(scene.moonIllumination * 100).round()}%',
                      ),
                    ],
                  ),
                ),
              ),
              Container(height: 1, color: Inks.hairline),
            ],
          );
          final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
          // Accessibility text and short windows retain all figures. Blade at
          // default text size uses a fixed, non-scrolling composition.
          if (constraints.maxHeight < (today ? 224 : 236) * scale ||
              constraints.maxWidth < 300) {
            return SingleChildScrollView(child: content);
          }
          return content;
        },
      ),
    );
  }

  static String number(num? n) => n?.round().toString() ?? S.emptyDash;
  static String time(double? t) => t == null ? '—:—' : formatHours(t);
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.unit, this.source);
  final String label, value, unit, source;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label $value $unit, $source',
    excludeSemantics: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Type.label),
        Text(value, style: Type.figureSmall, maxLines: 1),
        Text(
          '${switch (source.toLowerCase()) {
            'journal' => 'JNL',
            'wearable' => 'HC',
            _ => source.toUpperCase(),
          }}${unit.isEmpty ? '' : ' $unit'}',
          style: Type.micro.copyWith(color: Inks.muted),
        ),
      ],
    ),
  );
}

class _FigureLine extends StatelessWidget {
  const _FigureLine(this.label, this.value, this.unit);
  final String label, value, unit;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        flex: 2,
        child: Text(
          label,
          style: Type.micro,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      Expanded(flex: 3, child: Text(value, style: Type.micro, maxLines: 1)),
      Text(unit, style: Type.micro.copyWith(color: Inks.muted)),
    ],
  );
}

class _Action extends StatelessWidget {
  const _Action(this.label, this.onTap);
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          label,
          style: Type.label.copyWith(
            color: onTap == null ? Inks.faint : Inks.strong,
          ),
        ),
      ),
    ),
  );
}

class _WeatherLine extends ConsumerWidget {
  const _WeatherLine();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final observation = ref.watch(weatherViewProvider);
    String temp(double? t) => t == null ? S.emptyDash : '${t.round()}°';
    return Semantics(
      button: true,
      label: 'Weather and 24-hour forecast',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showWeatherSheet(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FigureLine(
              'WEATHER',
              '${temp(observation?.currentTempC)} NOW',
              observation == null
                  ? 'UNOBSERVED'
                  : observation.sourceId.toUpperCase(),
            ),
            _FigureLine(
              '24H °C',
              '${temp(observation?.minTempC)} / ${temp(observation?.maxTempC)}',
              'PRECIP ${observation?.precipitationChance == null ? S.emptyDash : '${(observation!.precipitationChance!.clamp(0.0, 1.0) * 100).round()}%'}',
            ),
          ],
        ),
      ),
    );
  }
}
