import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/sky/celestial_scene.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// The input surface. Phase 1: the page, its date, an honest empty state
/// and the writing line — composed, not wired. Capture lands in Phase 2.
class JournalPage extends StatelessWidget {
  const JournalPage({super.key, required this.scene});

  final ValueListenable<ResolvedScene?> scene;

  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date =
        '${_days[now.weekday - 1]} ${now.day} ${_months[now.month - 1]}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.margin, 6, Space.margin, 52),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('JOURNAL', style: Type.label),
              const Spacer(),
              Text('0 ENTRIES', style: Type.label.copyWith(color: Inks.faint)),
            ],
          ),
          const SizedBox(height: 7),
          Container(height: Space.hairline, color: Inks.hairline),
          const SizedBox(height: 18),
          Text(date, style: Type.title),
          const SizedBox(height: 8),
          Text(
            'Nothing logged yet. Say what you did, what you ate, or what you lifted — '
            'the journal works out the rest.',
            style: Type.caption,
          ),
          const Spacer(),
          const _WritingLine(),
        ],
      ),
    );
  }
}

/// A hairline, a prompt, and a microphone drawn in code. Tapping does
/// nothing yet, and says so.
class _WritingLine extends StatelessWidget {
  const _WritingLine();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF15181E),
              content: Text(
                'Capture arrives with the backend.',
                style: Type.body.copyWith(color: Inks.strong),
              ),
            ),
          );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Log an activity, a meal, a workout…',
                  style: Type.body.copyWith(color: Inks.muted),
                ),
              ),
              const SizedBox(width: 12),
              CustomPaint(
                size: const Size(14, 18),
                painter: _MicMark(Inks.body),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: Space.hairline,
            color: Inks.full.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}

class _MicMark extends CustomPainter {
  const _MicMark(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final w = size.width, h = size.height;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.3, 0, w * 0.4, h * 0.55),
        Radius.circular(w * 0.2),
      ),
      p,
    );
    final path = Path()
      ..moveTo(w * 0.08, h * 0.42)
      ..arcToPoint(
        Offset(w * 0.92, h * 0.42),
        radius: Radius.circular(w * 0.45),
        clockwise: false,
      );
    canvas.drawPath(path, p);
    canvas.drawLine(Offset(w / 2, h * 0.78), Offset(w / 2, h), p);
  }

  @override
  bool shouldRepaint(_MicMark old) => old.color != color;
}
