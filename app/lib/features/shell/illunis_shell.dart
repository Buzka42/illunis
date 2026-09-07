import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/sky/celestial_scene.dart';
import '../../core/sky/sky_view.dart';
import '../../core/state/app_providers.dart';
import '../../core/state/sky_state_source.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../dashboard/dashboard_page.dart';
import '../debug/capture.dart';
import '../debug/sky_debug_sheet.dart';
import '../journal/journal_page.dart';
import '../settings/settings_sheet.dart';
import '../timeline/timeline_bar.dart';
import 'shell_header.dart';

/// One sky, two surfaces sliding over it.
///
/// ```
///    ← Journal ═══════════════ Dashboard →
/// ```
/// The pager's offset turns the camera a few degrees, so crossing between
/// surfaces reads as turning your head under the same sky.
class IllunisShell extends ConsumerStatefulWidget {
  const IllunisShell({super.key});

  @override
  ConsumerState<IllunisShell> createState() => _IllunisShellState();
}

class _IllunisShellState extends ConsumerState<IllunisShell> {
  final _controller = PageController(initialPage: 1);
  final _scene = ValueNotifier<ResolvedScene?>(null);
  final _boundary = GlobalKey();
  double _page = 1;

  static const _yawPerPage = 0.14; // radians

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final p = _controller.hasClients && _controller.position.haveDimensions
          ? _controller.page ?? _page
          : _page;
      if (p != _page) setState(() => _page = p);
    });
    if (kDebugMode && kCaptureDir.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        runCaptureSequence(_boundary, ProviderScope.containerOf(context));
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scene.dispose();
    super.dispose();
  }

  void _go(int index) {
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(skyStateProvider);
    final mq = MediaQuery.of(context);
    final horizonY = mq.size.height * kHorizonFraction;

    final ime = mq.viewInsets.bottom;
    final onJournal = (1 - _page).clamp(0.0, 1.0);
    final captureBottom = math.max(mq.padding.bottom + 52, ime);
    final figures = ref.watch(journalFiguresProvider);
    final pending = figures.unconfirmed.length + figures.unconfirmedActs.length;
    final journalDock =
        JournalWritingLine.band +
        (ime > 8 ? 0.0 : JournalPending.heightFor(pending));

    return Scaffold(
      backgroundColor: const Color(0xFF07090D),
      resizeToAvoidBottomInset: false,
      body: RepaintBoundary(
        key: _boundary,
        child: Stack(
          fit: StackFit.expand,
          children: [
            SkyView(
              state: state,
              yawOffsetRad: (_page - 0.5) * _yawPerPage,
              onScene: (s) => _scene.value = s,
            ),
            // The day as a track, under the compass scale.
            Positioned(
              left: 0,
              right: 0,
              top: horizonY + kCompassBandHeight,
              child: TimelineBar(scene: _scene),
            ),
            // Surfaces live on the ground. The sky above stays legible.
            Positioned(
              left: 0,
              right: 0,
              top: horizonY + kCompassBandHeight + TimelineBar.height,
              bottom:
                  mq.padding.bottom +
                  52 +
                  (ime > 8 ? 0 : journalDock * onJournal),
              child: PageView(
                controller: _controller,
                physics: const ClampingScrollPhysics(),
                children: [
                  JournalPage(scene: _scene),
                  DashboardPage(scene: _scene, state: state),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: mq.padding.top,
              child: ShellHeader(
                scene: _scene,
                onWordmarkLongPress: kDebugMode
                    ? () => showSkyDebugSheet(context)
                    : null,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: captureBottom,
              child: IgnorePointer(
                ignoring: onJournal < 0.5 && ime < 8,
                child: Opacity(
                  opacity: ime > 8 ? 1 : onJournal,
                  child: ColoredBox(
                    color: const Color(
                      0xFF07090D,
                    ).withValues(alpha: ime > 8 ? 0.92 : 0),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        Space.margin,
                        ime > 8 ? 10 : 0,
                        Space.margin,
                        ime > 8 ? 8 : 0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (ime < 8) const JournalPending(),
                          const JournalWritingLine(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: mq.padding.bottom + 10,
              child: IgnorePointer(
                ignoring: ime > 8,
                child: Opacity(
                  opacity: ime > 8 ? 0 : 1,
                  child: _SurfaceSwitch(page: _page, onSelect: _go),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two words and a hairline. Not tabs, not pills.
class _SurfaceSwitch extends StatelessWidget {
  const _SurfaceSwitch({required this.page, required this.onSelect});

  final double page;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.margin),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: () => showSettingsSheet(context),
        child: Row(
          children: [
            _word('JOURNAL', 0),
            const SizedBox(width: 26),
            _word('DASHBOARD', 1),
            const Spacer(),
            Text(S.version, style: Type.micro.copyWith(color: Inks.faint)),
          ],
        ),
      ),
    );
  }

  Widget _word(String s, int index) {
    final t = (1 - (page - index).abs()).clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelect(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s,
              style: Type.label.copyWith(
                color: Color.lerp(Inks.faint, Inks.strong, t),
              ),
            ),
            const SizedBox(height: 5),
            Container(
              height: Space.hairline,
              width: 18 + 22 * t,
              color: Inks.full.withValues(alpha: 0.15 + 0.7 * t),
            ),
          ],
        ),
      ),
    );
  }
}
