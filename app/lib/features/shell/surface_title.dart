import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/theme/typography.dart';
import '../settings/settings_sheet.dart';

/// A surface heading. Long-press opens Settings.
///
/// The titles live inside the swipe pager, whose drag recognizer wins the
/// gesture arena on the slightest finger drift — a stock `onLongPress`
/// dies there on real hardware (pre-V2 the target sat on the bottom bar,
/// outside the pager, so drift never mattered). This fires on a 500 ms
/// hold instead, cancelling only on release or a deliberate move, and never
/// claims the drag: swiping away from the title still pages.
class SurfaceTitle extends StatefulWidget {
  const SurfaceTitle(this.title, {super.key});
  final String title;
  @override
  State<SurfaceTitle> createState() => _SurfaceTitleState();
}

class _SurfaceTitleState extends State<SurfaceTitle> {
  static const _hold = Duration(milliseconds: 500);
  static const _driftSlop = 32.0;

  Timer? _timer;
  Offset? _down;

  void _cancel() {
    _timer?.cancel();
    _timer = null;
    _down = null;
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    hint: 'Long press for Settings',
    child: Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        _cancel();
        _down = e.position;
        _timer = Timer(_hold, () {
          if (!mounted) return;
          _cancel();
          showSettingsSheet(context);
        });
      },
      onPointerMove: (e) {
        final down = _down;
        if (down == null) return;
        if ((e.position - down).distance > _driftSlop) _cancel();
      },
      onPointerUp: (_) => _cancel(),
      onPointerCancel: (_) => _cancel(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(widget.title, style: Type.label),
      ),
    ),
  );
}
