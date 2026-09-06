import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';

/// Rolling frame timings for the debug sheet. Debug builds only; production
/// pays nothing because [start] is never called.
class FrameBudget {
  FrameBudget._();
  static final FrameBudget instance = FrameBudget._();

  final List<FrameTiming> _samples = [];
  var _listening = false;

  void start() {
    if (_listening || !kDebugMode) return;
    _listening = true;
    SchedulerBinding.instance.addTimingsCallback(_on);
  }

  void _on(List<FrameTiming> timings) {
    _samples.addAll(timings);
    final overflow = _samples.length - 180;
    if (overflow > 0) _samples.removeRange(0, overflow);
  }

  int get n => _samples.length;

  double get p50RasterMs => _percentile((t) => t.rasterDuration, 0.50);
  double get p95RasterMs => _percentile((t) => t.rasterDuration, 0.95);
  double get p50BuildMs => _percentile((t) => t.buildDuration, 0.50);
  double get p95BuildMs => _percentile((t) => t.buildDuration, 0.95);

  double _percentile(Duration Function(FrameTiming) pick, double p) {
    if (_samples.isEmpty) return 0;
    final v = _samples.map((t) => pick(t).inMicroseconds / 1000).toList()
      ..sort();
    final i = (p * (v.length - 1)).round().clamp(0, v.length - 1);
    return v[i];
  }
}
