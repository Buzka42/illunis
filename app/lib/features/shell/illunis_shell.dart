import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sky/celestial_scene.dart';
import '../../core/sky/sky_view.dart';
import '../../core/state/app_providers.dart';
import '../../core/state/sky_state_source.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../insights/sky_letters.dart';
import '../settings/quick_guide.dart';
import '../dashboard/dashboard_page.dart';
import '../debug/capture.dart';
import '../debug/sky_debug_sheet.dart';
import '../journal/journal_page.dart';
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
  const IllunisShell({super.key, this.showTutorial = false});
  final bool showTutorial;

  @override
  ConsumerState<IllunisShell> createState() => _IllunisShellState();
}

class _IllunisShellState extends ConsumerState<IllunisShell>
    with WidgetsBindingObserver {
  final _controller = PageController(initialPage: 1);
  final _scene = ValueNotifier<ResolvedScene?>(null);
  final _boundary = GlobalKey();
  double _page = 1;

  static const _yawPerPage = 0.14; // radians

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.showTutorial && kCaptureDir.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || ref.read(storeProvider).profile.tutorialVersion >= 2) {
          return;
        }
        await showQuickGuide(context);
        if (!mounted) return;
        final store = ref.read(storeProvider);
        await store.putProfile(store.profile.copyWith(tutorialVersion: 2));
      });
    }
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Hidden/paused pays for nothing: the 1 Hz source timer stops. The sky
    // view already freezes its own frames; this stops the emissions too.
    final suspended = switch (state) {
      AppLifecycleState.resumed || AppLifecycleState.inactive => false,
      _ => true,
    };
    try {
      ref.read(skyStateSourceProvider).setSuspended(suspended);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _scene.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(skyStateProvider);
    final mq = MediaQuery.of(context);
    if (mq.size.width < 100 || mq.size.height < 100) {
      return const SizedBox.shrink();
    }
    final horizonY = mq.size.height * kHorizonFraction;

    final ime = mq.viewInsets.bottom;
    final onJournal = (1 - _page).clamp(0.0, 1.0);
    final captureBottom = math.max(mq.padding.bottom + 6, ime);
    final figures = ref.watch(journalFiguresProvider);
    final pending = figures.unconfirmed.length + figures.unconfirmedActs.length;
    final pendingHeight = math.min(
      JournalPending.heightFor(pending),
      math.max(
        0.0,
        mq.size.height -
            horizonY -
            kCompassBandHeight -
            TimelineBar.height -
            mq.padding.bottom -
            6 -
            JournalWritingLine.band -
            120,
      ),
    );
    final journalDock =
        JournalWritingLine.band + (ime > 8 ? 0.0 : pendingHeight);

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
            Positioned(
              left: Space.margin,
              right: Space.margin,
              top: mq.padding.top + 80,
              child: ValueListenableBuilder<ResolvedScene?>(
                valueListenable: _scene,
                builder: (context, scene, _) =>
                    SkyLetters(ink: Inks.sky(scene?.skyInkBlend ?? 0)),
              ),
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
                  6 +
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
                          if (ime < 8) JournalPending(maxHeight: pendingHeight),
                          const JournalWritingLine(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
