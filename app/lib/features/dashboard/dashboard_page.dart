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
import '../../core/wearables/life_stats.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../shell/surface_title.dart';
import '../timeline/weather_projection.dart';
import '../timeline/weather_sheet.dart';
import 'dashboard_comparisons.dart';

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
    final supporting = <Widget>[
      _Stat('STEPS', number(stats.steps.value), '', stats.steps.source.name),
      _Stat(
        'REST HR',
        number(stats.restingHr.value),
        'BPM',
        stats.restingHr.source.name,
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
      padding: const EdgeInsets.symmetric(horizontal: Space.margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const SurfaceTitle(S.dashboard),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
            ],
          ),
          if (!today) Text(formatShortDate(selected), style: Type.micro),
          Expanded(
            child: SingleChildScrollView(
              key: const PageStorageKey('dashboard-reading'),
              padding: const EdgeInsets.only(top: 2, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ComparisonsSection(day: day),
                  const _Rule(),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final scale =
                          MediaQuery.textScalerOf(context).scale(10) / 10;
                      final columns = constraints.maxWidth >= 300 * scale
                          ? 4
                          : 2;
                      return Wrap(
                        key: const ValueKey('dashboard-supporting'),
                        spacing: 8,
                        runSpacing: 12,
                        children: [
                          for (final stat in supporting)
                            SizedBox(
                              width:
                                  (constraints.maxWidth - 8 * (columns - 1)) /
                                  columns,
                              child: stat,
                            ),
                        ],
                      );
                    },
                  ),
                  if (mock)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _FigureLine(
                        'PREVIEW SLEEP',
                        sleep == null
                            ? S.emptyDash
                            : '${sleep.toStringAsFixed(1)}h',
                        'MOCK',
                      ),
                    ),
                  const _Rule(),
                  const _WeatherLine(),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<ResolvedScene?>(
                    valueListenable: widget.scene,
                    builder: (context, scene, _) => Column(
                      children: [
                        _FigureLine(
                          'SUN',
                          '↑ ${time(scene?.sunrise)}   ↓ ${time(scene?.sunset)}',
                          scene?.dayLength == null
                              ? S.emptyDash
                              : formatDuration(scene!.dayLength!),
                        ),
                        const SizedBox(height: 4),
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
                ],
              ),
            ),
          ),
        ],
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
      if (constraints.maxWidth < 300 * scale) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Type.label),
              Wrap(
                spacing: 12,
                children: [
                  Text(value, style: Type.micro),
                  Text(unit, style: Type.micro),
                ],
              ),
            ],
          ),
        );
      }
      return Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: Type.micro)),
          Expanded(flex: 3, child: Text(value, style: Type.micro)),
          Flexible(
            flex: 2,
            child: Text(unit, style: Type.micro, textAlign: TextAlign.right),
          ),
        ],
      );
    },
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

String _source(StatSource? source) => switch (source) {
  StatSource.journal => 'JNL',
  StatSource.wearable => 'HC',
  StatSource.rule => 'RULE',
  StatSource.ai => 'AI',
  null => '—',
};

String _composition(Map<StatSource, int> counts) => counts.isEmpty
    ? '—'
    : counts.entries.map((e) => '${_source(e.key)} ${e.value}').join(' · ');

class _Rule extends StatelessWidget {
  const _Rule();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: SizedBox(height: 0.5, child: ColoredBox(color: Inks.hairline)),
  );
}

/// Three comparisons, one reading order. Supporting instruments continue below
/// the fold instead of shrinking the evidence to fit a particular handset.
class _ComparisonsSection extends ConsumerWidget {
  const _ComparisonsSection({required this.day});
  final String day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(dashboardComparisonsProvider(day));
    final ib = c.intakeBurn;
    final mv = c.movement;
    final sl = c.sleep;
    final movementMax = [
      mv.current.meanActiveMinutes ?? 0,
      mv.previous.meanActiveMinutes ?? 0,
    ].reduce((a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeading('Energy', trailing: 'KCAL'),
        const SizedBox(height: 3, key: ValueKey('dashboard-energy')),
        LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
            final columns = constraints.maxWidth >= 300 * scale ? 2 : 1;
            return Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: (constraints.maxWidth - 20 * (columns - 1)) / columns,
                  child: _EnergyLine(
                    label: S.intake,
                    value: ib.intake,
                    maximum: ib.sharedScaleMax,
                    color: Inks.intake,
                    pending: ib.pendingIntakeCount,
                  ),
                ),
                SizedBox(
                  width: (constraints.maxWidth - 20 * (columns - 1)) / columns,
                  child: _EnergyLine(
                    label: 'BURN',
                    value: ib.burn,
                    maximum: ib.sharedScaleMax,
                    color: Inks.body,
                    estimated: ib.burnEstimated == true,
                    pending: ib.pendingBurnCount,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        const _SectionHeading('Movement', trailing: 'MIN / OBSERVED DAY'),
        const SizedBox(height: 3, key: ValueKey('dashboard-movement')),
        _MovementLine(
          label: 'LAST 7D',
          window: mv.current,
          maximum: movementMax,
          color: Inks.body,
        ),
        const SizedBox(height: 3),
        _MovementLine(
          label: 'PREV 7D',
          window: mv.previous,
          maximum: movementMax,
          color: Inks.faint,
        ),
        const SizedBox(height: 10),
        _SectionHeading(
          S.sleep,
          trailing:
              '${sl.observedCount}/7 NIGHTS · ${_composition(sl.sourceCounts)}',
        ),
        const SizedBox(height: 3, key: ValueKey('dashboard-sleep')),
        LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
            final wide = constraints.maxWidth >= 280 * scale;
            return Wrap(
              key: const ValueKey('dashboard-sleep-marks'),
              spacing: 0,
              runSpacing: 8,
              children: [
                for (final night in sl.nights)
                  SizedBox(
                    width: constraints.maxWidth / (wide ? 7 : 4),
                    child: _SleepMark(night: night),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.title, {required this.trailing});
  final String title, trailing;
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    children: [
      Text(title, style: Type.control),
      Text(trailing, style: Type.micro),
    ],
  );
}

class _EnergyLine extends StatelessWidget {
  const _EnergyLine({
    required this.label,
    required this.value,
    required this.maximum,
    required this.color,
    this.estimated = false,
    this.pending = 0,
  });
  final String label;
  final ComparedValue value;
  final double? maximum;
  final Color color;
  final bool estimated;
  final int pending;

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '$label, ${value.value?.round() ?? 'unobserved'} kilocalories, ${_source(value.source)}'
        '${estimated ? ', estimated' : ''}${pending > 0 ? ', $pending pending excluded' : ''}',
    excludeSemantics: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(label, style: Type.label),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${_source(value.source)} KCAL${estimated ? ' EST' : ''}',
                style: Type.micro,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value.value?.round().toString() ?? S.emptyDash,
          style: Type.figure,
        ),
        const SizedBox(height: 2),
        _MeasureBar(value: value.value, maximum: maximum, color: color),
        if (pending > 0)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text('$pending PENDING · EXCLUDED', style: Type.micro),
          ),
      ],
    ),
  );
}

class _MovementLine extends StatelessWidget {
  const _MovementLine({
    required this.label,
    required this.window,
    required this.maximum,
    required this.color,
  });
  final String label;
  final MovementWindow window;
  final double maximum;
  final Color color;
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '${window.startDay} to ${window.endDay}, '
        '${window.meanActiveMinutes?.toStringAsFixed(1) ?? 'unobserved'} minutes per observed day, '
        '${window.observedCount} of 7 days, ${_composition(window.sourceCounts)}',
    excludeSemantics: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Text(label, style: Type.label),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  window.meanActiveMinutes?.toStringAsFixed(1) ?? S.emptyDash,
                  style: Type.figureSmall,
                ),
                Text(
                  '${window.observedCount}/7 · ${_composition(window.sourceCounts)}',
                  style: Type.micro,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 2),
        _MeasureBar(
          value: window.meanActiveMinutes,
          maximum: maximum,
          color: color,
        ),
      ],
    ),
  );
}

/// Shared zero-origin scale. A zero is a short vertical tick; absence has no
/// mark. The endpoint is square, never a knob or a decorative progress gauge.
class _MeasureBar extends StatelessWidget {
  const _MeasureBar({
    required this.value,
    required this.maximum,
    required this.color,
  });
  final double? value, maximum;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 2,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final fraction = value == null || maximum == null || maximum! <= 0
            ? 0.0
            : (value! / maximum!).clamp(0.0, 1.0);
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: value == null
                ? 0
                : value == 0
                ? 1
                : constraints.maxWidth * fraction,
            height: value == 0 ? 3 : 1,
            child: ColoredBox(color: color),
          ),
        );
      },
    ),
  );
}

class _SleepMark extends StatelessWidget {
  const _SleepMark({required this.night});
  final SleepNight night;
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '${night.day}, ${night.hours?.toStringAsFixed(1) ?? 'unobserved'} hours, ${_source(night.source)}',
    excludeSemantics: true,
    child: Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(night.day.substring(8), style: Type.micro),
          const SizedBox(height: 2),
          Text(
            night.hours == null
                ? S.emptyDash
                : '${night.hours!.toStringAsFixed(1)}h',
            style: Type.micro.copyWith(color: Inks.body),
          ),
        ],
      ),
    ),
  );
}
