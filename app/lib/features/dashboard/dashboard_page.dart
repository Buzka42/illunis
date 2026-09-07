import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/records.dart';
import '../../core/fitness/format.dart';
import '../../core/i18n/dates.dart';
import '../../core/i18n/strings.dart';
import '../../core/sky/celestial_math.dart';
import '../../core/sky/celestial_scene.dart';
import '../../core/sky/sky_state.dart';
import '../../core/state/app_providers.dart';
import '../../core/state/sleep_record.dart';
import '../../core/state/sky_state_source.dart';
import '../../core/strength/progress.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/units/mass.dart';

/// The output surface. Figures come from the day's rollup; the sky
/// readouts come from the same scene the 3D layer already resolved.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key, required this.scene, required this.state});

  final ValueListenable<ResolvedScene?> scene;
  final SkyState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sleepLive = ref.watch(sleepRecordProvider);
    final figures = ref.watch(journalFiguresProvider);
    final selected = ref.watch(journalDayProvider);
    final today = sameDay(selected, DateTime.now());
    ref.watch(storeRevisionProvider);
    final units = ref.watch(storeProvider).profile.units;
    final preset = ref.watch(skyOverridesProvider.select((o) => o.preset));
    final s = figures.summary;
    final right = preset != SkyPreset.live
        ? S.mockData
        : (_hasLocalRecord(figures, s) || (today && state.hasVitals)
              ? S.local
              : S.noData);

    final sleepHours = today
        ? sleepLive?.asleepHours
        : figures.sleep?.durationHours;
    final sleepScore = today ? state.sleepScore : s?.sleepScore;
    final recovery = today ? state.recovery : s?.recovery;
    final strain = today ? state.strain : s?.strain;
    final energyBal = today ? state.energyBalance : s?.energyBalance;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.margin, 6, Space.margin, 12),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Eyebrow(
              left: today ? S.today : formatShortDate(selected),
              right: right,
              extra: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _NavWord(
                    label: S.prev,
                    onTap: () => ref.read(journalDayProvider.notifier).prev(),
                  ),
                  const SizedBox(width: 14),
                  _NavWord(
                    label: S.next,
                    active: !today,
                    onTap: today
                        ? null
                        : () => ref.read(journalDayProvider.notifier).next(),
                  ),
                ],
              ),
            ),
            if (_weekLine(figures, units) != null) ...[
              const SizedBox(height: 8),
              Text(_weekLine(figures, units)!, style: Type.micro),
            ],
            if (s?.digest != null && s!.digest!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(s.digest!, style: Type.caption),
            ],
            const SizedBox(height: 6),
            _Row(
              label: S.sleep,
              value: sleepHours == null
                  ? S.emptyDash
                  : formatDuration(sleepHours / 24),
              unit: _sleepUnit(sleepScore, figures.sleep?.quality),
            ),
            if (recovery != null)
              _Row(
                label: S.recovery,
                value: _pct(recovery),
                unit: '/ 100',
                tint: _tintFor(recovery, lowIsBad: true),
              ),
            _Row(
              label: S.strain,
              value: strain == null ? S.emptyDash : strain.toStringAsFixed(2),
              unit: strain == null ? null : 'LOAD',
              tint: _tintFor(strain, lowIsBad: false),
            ),
            if (s?.intakeKcal != null)
              _Row(
                label: S.intake,
                value: '${s!.intakeKcal!.round()}',
                unit: _macros(s.proteinG, s.carbsG, s.fatG),
              ),
            if (figures.sessions.isNotEmpty || s?.sets != null) ...[
              _Row(
                label: figures.sessions.length == 1
                    ? figures.sessions.first.label
                    : S.training,
                value: _workValue(s, figures),
                unit: _workUnit(s, figures, units),
              ),
              if (figures.sessions.length != 1)
                for (final session in figures.sessions)
                  _Row(
                    label: session.label,
                    value: session.value,
                    unit: session.unit,
                    small: true,
                  ),
            ],
            if (s?.energyKcal != null || energyBal != null)
              _Row(
                label: S.energy,
                value: _energy(s?.energyKcal, energyBal),
                unit: energyBal == null ? 'KCAL' : 'KCAL · 7D',
              ),
            if (figures.weightKg != null)
              _Row(
                label: S.mass,
                value: formatMass(figures.weightKg!, units, fractionDigits: 1),
                unit: massUnit(units),
              ),
            if (figures.lifts.isNotEmpty) ...[
              for (final lift in figures.lifts.take(6))
                _Row(
                  label: liftLabel(lift.name),
                  value: formatMass(lift.epleyKg, units),
                  unit: lift.deltaKg == null
                      ? '1RM'
                      : '${lift.deltaKg! >= 0 ? '+' : '−'}${formatMass(lift.deltaKg!.abs(), units)} · 1RM',
                  small: true,
                ),
            ],
            const SizedBox(height: 10),
            ValueListenableBuilder<ResolvedScene?>(
              valueListenable: scene,
              builder: (context, sc, _) {
                if (sc == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Eyebrow(
                      left: S.sky,
                      right: sc.describeTwilight().toUpperCase(),
                    ),
                    const SizedBox(height: 6),
                    _Row(
                      label: 'SUN',
                      value: '↑ ${_t(sc.sunrise)}   ↓ ${_t(sc.sunset)}',
                      unit: sc.dayLength == null
                          ? null
                          : formatDuration(sc.dayLength!).toUpperCase(),
                      small: true,
                    ),
                    _Row(
                      label: 'MOON',
                      value: '↑ ${_t(sc.moonrise)}   ↓ ${_t(sc.moonset)}',
                      unit:
                          '${(sc.moonIllumination * 100).round()}% · ${sc.describeMoonPhase().toUpperCase()}',
                      small: true,
                      tint: Inks.cool,
                      unitBelow: true,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            _Eyebrow(
              left: S.patterns,
              right: figures.findings.isEmpty
                  ? (figures.insightWait == null
                        ? '21 DAYS'
                        : '${figures.insightWait!.n} / 21')
                  : '${figures.findings.length}',
            ),
            const SizedBox(height: 6),
            if (figures.findings.isEmpty)
              Text(
                figures.insightWait == null
                    ? S.patternsEmpty
                    : S.insightsWait(
                        figures.insightWait!.label,
                        figures.insightWait!.n,
                      ),
                style: Type.caption,
              )
            else ...[
              if (figures.insightNote != null) ...[
                Text(figures.insightNote!, style: Type.caption),
                const SizedBox(height: 10),
              ],
              for (final f in figures.findings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(f.pairLabel, style: Type.label),
                      const SizedBox(height: 3),
                      Text(f.sentence, style: Type.body),
                      const SizedBox(height: 3),
                      Text(
                        [
                          'r ${f.correlation.r.toStringAsFixed(2)}',
                          'n ${f.correlation.n}',
                          if (f.evidence != null) f.evidence!,
                        ].join('  ·  '),
                        style: Type.micro,
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static String _t(double? f) => f == null ? '——:——' : formatHours(f);

  static String _pct(double? v) =>
      v == null ? S.emptyDash : (v * 100).round().toString();

  static String? _sleepUnit(double? score, double? quality) {
    final bits = <String>[];
    if (score != null) bits.add('SCORE ${(score * 100).round()}');
    if (quality != null) {
      if (quality < 0.5) {
        bits.add('POORLY');
      } else if (quality >= 0.75) {
        bits.add('WELL');
      }
    }
    if (bits.isEmpty) return null;
    return bits.join(' · ');
  }

  static String _energy(double? kcal, double? e) {
    if (kcal != null) {
      final k = kcal.round();
      return '${k >= 0 ? '+' : '−'}${k.abs()}';
    }
    if (e == null) return S.emptyDash;
    final k = (e * 640).round();
    return '${k >= 0 ? '+' : '−'}${k.abs()}';
  }

  static String _macros(double? p, double? c, double? f) {
    if (p == null && c == null && f == null) return 'KCAL';
    return 'P ${p?.round() ?? '—'} · C ${c?.round() ?? '—'} · F ${f?.round() ?? '—'}';
  }

  static String? _weekLine(TodayFigures figures, String units) {
    final bits = <String>[];
    if (figures.weekSleepHours != null) {
      bits.add('SLEEP ${figures.weekSleepHours!.toStringAsFixed(1)}h');
    }
    if (figures.weekIntakeKcal != null) {
      bits.add('INTAKE ${figures.weekIntakeKcal!.round()}');
    }
    if (figures.weekVolumeKg != null) {
      bits.add(
        'VOL ${formatMass(figures.weekVolumeKg!, units)} ${massUnit(units)}',
      );
    }
    if (figures.weekDistanceKm != null) {
      bits.add('DIST ${formatKm(figures.weekDistanceKm!)} KM');
    }
    if (bits.isEmpty) return null;
    return '${S.week}  ${bits.join('  ·  ')}';
  }

  static bool _hasLocalRecord(TodayFigures figures, DaySummary? s) {
    if (figures.entryCount > 0) return true;
    if (figures.unconfirmed.isNotEmpty || figures.unconfirmedActs.isNotEmpty) {
      return true;
    }
    if (s == null) return false;
    return s.sleepScore != null ||
        s.recovery != null ||
        s.strain != null ||
        s.energyBalance != null ||
        s.intakeKcal != null ||
        s.energyKcal != null;
  }

  static String _workValue(DaySummary? s, TodayFigures figures) {
    if (figures.sessions.length == 1) return figures.sessions.first.value;
    if (figures.sessions.isNotEmpty) return '${figures.sessions.length}';
    if (s?.sets != null) return '${s!.sets}';
    return S.emptyDash;
  }

  static String? _workUnit(DaySummary? s, TodayFigures figures, String units) {
    if (figures.sessions.length == 1) {
      return figures.sessions.first.unit;
    }
    if (s?.moveMinutes != null) {
      return '${formatMinutes(s!.moveMinutes!)} MIN';
    }
    if (s?.volumeKg != null) {
      return '${formatMass(s!.volumeKg!, units)} ${massUnit(units)}';
    }
    return figures.sessions.isEmpty ? null : 'SESSION';
  }

  static Color? _tintFor(double? v, {required bool lowIsBad}) {
    if (v == null) return null;
    final bad = lowIsBad ? v < 0.4 : v > 0.75;
    return bad ? Inks.negative : null;
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.left, required this.right, this.extra});
  final String left, right;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(left, style: Type.label),
            const Spacer(),
            ?extra,
            if (extra != null) const SizedBox(width: 16),
            Text(right, style: Type.label.copyWith(color: Inks.faint)),
          ],
        ),
        const SizedBox(height: 7),
        Container(height: Space.hairline, color: Inks.hairline),
      ],
    );
  }
}

class _NavWord extends StatelessWidget {
  const _NavWord({required this.label, this.onTap, this.active = true});
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Text(
        label,
        style: Type.label.copyWith(color: active ? Inks.muted : Inks.faint),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.unit,
    this.tint,
    this.small = false,
    this.unitBelow = false,
  });

  final String label;
  final String value;
  final String? unit;
  final Color? tint;
  final bool small;

  /// Long units (moon phase) sit under the figures so they are not clipped
  /// on a 360 dp phone.
  final bool unitBelow;

  @override
  Widget build(BuildContext context) {
    final figure = (small ? Type.figure.copyWith(fontSize: 14.5) : Type.figure)
        .copyWith(color: tint ?? Inks.strong);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              SizedBox(width: 84, child: Text(label, style: Type.label)),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: figure,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        maxLines: 1,
                      ),
                    ),
                    if (unit != null && !unitBelow) ...[
                      const SizedBox(width: 8),
                      Text(unit!, style: Type.micro),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (unit != null && unitBelow)
            Padding(
              padding: const EdgeInsets.only(left: 84, top: 2),
              child: Text(unit!, style: Type.micro, textAlign: TextAlign.right),
            ),
        ],
      ),
    );
  }
}
