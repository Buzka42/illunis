import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/sky/celestial_math.dart';
import '../../core/sky/celestial_scene.dart';
import '../../core/sky/sky_state.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// The output surface. Phase 1: the day's figures set as a table on the
/// ground, straight from mock state and the resolved sky. No logic; the
/// composition is what is being judged.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.scene, required this.state});

  final ValueListenable<ResolvedScene?> scene;
  final SkyState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.margin, 18, Space.margin, 52),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Eyebrow(
              left: 'TODAY',
              right: state.hasVitals ? 'MOCK DATA' : 'NO DATA',
            ),
            const SizedBox(height: 6),
            _Row(
              label: 'SLEEP',
              value: _sleep(state.sleepScore),
              unit: state.sleepScore == null
                  ? null
                  : 'SCORE ${(state.sleepScore! * 100).round()}',
            ),
            _Row(
              label: 'RECOVERY',
              value: _pct(state.recovery),
              unit: state.recovery == null ? null : '/ 100',
              tint: _tintFor(state.recovery, lowIsBad: true),
            ),
            _Row(
              label: 'STRAIN',
              value: state.strain == null
                  ? '—'
                  : state.strain!.toStringAsFixed(2),
              unit: state.strain == null ? null : 'LOAD',
              tint: _tintFor(state.strain, lowIsBad: false),
            ),
            _Row(
              label: 'ENERGY',
              value: _energy(state.energyBalance),
              unit: state.energyBalance == null ? null : 'KCAL · 7D',
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<ResolvedScene?>(
              valueListenable: scene,
              builder: (context, s, _) {
                if (s == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Eyebrow(
                      left: 'SKY',
                      right: s.describeTwilight().toUpperCase(),
                    ),
                    const SizedBox(height: 6),
                    _Row(
                      label: 'SUN',
                      value: '↑ ${_t(s.sunrise)}   ↓ ${_t(s.sunset)}',
                      unit: s.dayLength == null
                          ? null
                          : formatDuration(s.dayLength!).toUpperCase(),
                      small: true,
                    ),
                    _Row(
                      label: 'MOON',
                      value: '↑ ${_t(s.moonrise)}   ↓ ${_t(s.moonset)}',
                      unit:
                          '${(s.moonIllumination * 100).round()}% · ${s.describeMoonPhase().toUpperCase()}',
                      small: true,
                      tint: Inks.cool,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _t(double? f) => f == null ? '——:——' : formatHours(f);

  static String _pct(double? v) =>
      v == null ? '—' : (v * 100).round().toString();

  static String _sleep(double? score) {
    if (score == null) return '—';
    // Mock: the score stands in for duration until a real source exists.
    final minutes = (5.0 * 60 + score * 3.6 * 60).round();
    return '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m';
  }

  static String _energy(double? e) {
    if (e == null) return '—';
    final kcal = (e * 640).round();
    return '${kcal >= 0 ? '+' : '−'}${kcal.abs()}';
  }

  static Color? _tintFor(double? v, {required bool lowIsBad}) {
    if (v == null) return null;
    final bad = lowIsBad ? v < 0.4 : v > 0.75;
    return bad ? Inks.negative : null;
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.left, required this.right});
  final String left, right;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(left, style: Type.label),
            const Spacer(),
            Text(right, style: Type.label.copyWith(color: Inks.faint)),
          ],
        ),
        const SizedBox(height: 7),
        Container(height: Space.hairline, color: Inks.hairline),
      ],
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
  });

  final String label;
  final String value;
  final String? unit;
  final Color? tint;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final figure = (small ? Type.figure.copyWith(fontSize: 14.5) : Type.figure)
        .copyWith(color: tint ?? Inks.strong);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(width: 84, child: Text(label, style: Type.label)),
          Text(value, style: figure),
          const Spacer(),
          if (unit != null) Text(unit!, style: Type.micro),
        ],
      ),
    );
  }
}
