import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/sky/celestial_math.dart';
import '../../core/sky/celestial_scene.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// Wordmark left; the instrument line right: clock, date, observer.
class ShellHeader extends StatelessWidget {
  const ShellHeader({super.key, required this.scene, this.onWordmarkLongPress});

  final ValueListenable<ResolvedScene?> scene;
  final VoidCallback? onWordmarkLongPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.margin, 14, Space.margin, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: onWordmarkLongPress,
            child: Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 8, right: 12),
              child: Text('ILLUNIS', style: Type.wordmark),
            ),
          ),
          const Spacer(),
          ValueListenableBuilder<ResolvedScene?>(
            valueListenable: scene,
            builder: (context, s, _) {
              if (s == null) return const SizedBox.shrink();
              final st = s.state;
              final lat = st.latitudeDeg;
              final latText =
                  '${lat.abs().toStringAsFixed(2)}°${lat >= 0 ? 'N' : 'S'}';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_clock(st.timeOfDay), style: Type.clock),
                  const SizedBox(height: 3),
                  Text(
                    'DAY ${st.dayOfYear.floor().toString().padLeft(3, '0')}  ·  $latText',
                    style: Type.micro.copyWith(color: Inks.muted),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static String _clock(double t) {
    final secs = ((t - t.floorToDouble()) * 86400).floor();
    final h = secs ~/ 3600, m = (secs % 3600) ~/ 60, s = secs % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

// Re-exported for callers that only need the formatter.
String formatDayFraction(double? f) => f == null ? '—' : formatHours(f);
