import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/platform/host.dart';
import '../../core/sky/celestial_math.dart';
import '../../core/sky/celestial_scene.dart';
import '../../core/sky/sky_view.dart';
import '../../core/state/app_providers.dart';
import '../../core/state/sky_state_source.dart';
import '../../core/state/sleep_record.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../debug/capture.dart';
import '../debug/sky_debug_sheet.dart';
import '../timeline/timeline_bar.dart';
import 'shell_header.dart';

/// The nightstand: one sky, the day's track, a large clock on the ground.
/// No pager. A slow drift against OLED burn-in. Close returns to the lock
/// screen (DreamService) or pops the in-app preview.
class DreamShell extends ConsumerStatefulWidget {
  const DreamShell({super.key});

  @override
  ConsumerState<DreamShell> createState() => _DreamShellState();
}

class _DreamShellState extends ConsumerState<DreamShell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _scene = ValueNotifier<ResolvedScene?>(null);
  final _boundary = GlobalKey();
  late final AnimationController _drift;

  static const _driftPx = 3.0;
  bool _reducedMotion = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 180),
    )..repeat();
    if (kDebugMode && kCaptureDir.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        runCaptureSequence(_boundary, ProviderScope.containerOf(context));
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    _syncDrift();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    _syncDrift();
  }

  void _syncDrift() {
    if (_foreground && !_reducedMotion) {
      if (!_drift.isAnimating) _drift.repeat();
    } else {
      _drift.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _drift.dispose();
    _scene.dispose();
    super.dispose();
  }

  void _close() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    Host.finishDream();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(skyStateProvider);
    final dots = ref.watch(skyPathDotsProvider);
    final mq = MediaQuery.of(context);
    final horizonY = mq.size.height * kHorizonFraction;

    return Scaffold(
      backgroundColor: const Color(0xFF07090D),
      body: AnimatedBuilder(
        animation: _drift,
        builder: (context, child) {
          final t = _drift.value * 2 * math.pi;
          return Transform.translate(
            offset: _reducedMotion
                ? Offset.zero
                : Offset(
                    _driftPx * math.sin(t),
                    _driftPx * 0.7 * math.sin(2 * t + 1.1),
                  ),
            child: child,
          );
        },
        child: RepaintBoundary(
          key: _boundary,
          child: Stack(
            fit: StackFit.expand,
            children: [
              SkyView(
                state: state.copyWith(dots: dots),
                onScene: (s) => _scene.value = s,
              ),
              Positioned(
                left: 0,
                right: 0,
                top: horizonY + kCompassBandHeight,
                child: TimelineBar(scene: _scene),
              ),
              Positioned.fill(
                top: horizonY + kCompassBandHeight + TimelineBar.height,
                child: _NightstandGround(scene: _scene),
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
                bottom: mq.padding.bottom + 10,
                child: _DreamFooter(onClose: _close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NightstandGround extends ConsumerWidget {
  const _NightstandGround({required this.scene});

  final ValueListenable<ResolvedScene?> scene;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sleep = ref.watch(sleepRecordProvider);
    final preset = ref.watch(skyOverridesProvider.select((s) => s.preset));
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.margin, 10, Space.margin, 52),
      child: ValueListenableBuilder<ResolvedScene?>(
        valueListenable: scene,
        builder: (context, s, _) {
          if (s == null) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_clock(s.state.timeOfDay), style: Type.figureLarge),
              const SizedBox(height: 8),
              Text(
                s.describeTwilight().toUpperCase(),
                style: Type.label.copyWith(color: Inks.muted),
              ),
              if (sleep != null) ...[
                const SizedBox(height: 22),
                Container(height: Space.hairline, color: Inks.hairline),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    SizedBox(
                      width: 84,
                      child: Text('SLEEP', style: Type.label),
                    ),
                    Text(
                      formatDuration(sleep.asleepHours / 24),
                      style: Type.figure,
                    ),
                    if (preset != SkyPreset.live) ...[
                      const SizedBox(width: 12),
                      Flexible(child: Text(S.mockData, style: Type.micro)),
                    ],
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  static String _clock(double t) {
    final secs = ((t - t.floorToDouble()) * 86400).floor();
    final h = secs ~/ 3600, m = (secs % 3600) ~/ 60, s = secs % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _DreamFooter extends StatelessWidget {
  const _DreamFooter({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.margin),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CLOSE', style: Type.label.copyWith(color: Inks.strong)),
                  const SizedBox(height: 5),
                  Container(
                    height: Space.hairline,
                    width: 18,
                    color: Inks.full.withValues(alpha: 0.85),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 26),
          Text('NIGHTSTAND', style: Type.label.copyWith(color: Inks.faint)),
          const Spacer(),
          Text(S.version, style: Type.micro.copyWith(color: Inks.faint)),
        ],
      ),
    );
  }
}
