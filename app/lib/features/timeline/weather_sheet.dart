import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/place/homes.dart';
import '../../core/state/app_providers.dart';
import '../../core/theme/typography.dart';
import 'weather_projection.dart';

Future<void> showWeatherSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF07090D),
      shape: const RoundedRectangleBorder(),
      builder: (_) => const _WeatherSheet(),
    );

class _WeatherSheet extends ConsumerStatefulWidget {
  const _WeatherSheet();
  @override
  ConsumerState<_WeatherSheet> createState() => _WeatherSheetState();
}

class _WeatherSheetState extends ConsumerState<_WeatherSheet> {
  bool _busy = false;
  String? _note;
  Future<void> _refresh() async {
    if (_busy) return;
    final profile = ref.read(storeProvider).profile;
    if (profile.weatherSource == 'off') return;
    setState(() {
      _busy = true;
      _note = null;
    });
    try {
      final service = ref.read(weatherServiceProvider);
      service.setSourceId(profile.weatherSource);
      final observation = await service.refresh(
        latitude: profile.latitudeDeg,
        longitude: profile.longitudeDeg,
      );
      if (mounted) {
        setState(
          () => _note = observation == null
              ? 'Weather unavailable. Last good observation retained until stale.'
              : 'Updated from Settings home.',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _note = 'Weather unavailable.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(storeRevisionProvider);
    final store = ref.watch(storeProvider);
    final profile = store.profile;
    final observation = ref.watch(weatherViewProvider);
    final points = observation?.hourly24h ?? const [];
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('WEATHER · 24 HOURS', style: Type.label),
                const SizedBox(height: 8),
                Text(
                  'HOME · ${matchingHome(profile).label}\nTimes use the device clock. Home coordinates are sent only to the selected weather service.',
                  style: Type.micro,
                ),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    TextButton(
                      onPressed: () async {
                        final next = profile.weatherSource == 'off'
                            ? 'open-meteo'
                            : 'off';
                        ref.read(weatherServiceProvider).setSourceId(next);
                        await store.putProfile(
                          profile.copyWith(weatherSource: next),
                        );
                        if (next != 'off' && mounted) await _refresh();
                      },
                      child: Text(
                        profile.weatherSource == 'off'
                            ? 'SOURCE · OFF'
                            : 'SOURCE · OPEN-METEO',
                        style: Type.label,
                      ),
                    ),
                    TextButton(
                      onPressed: _busy || profile.weatherSource == 'off'
                          ? null
                          : _refresh,
                      child: Text(
                        _busy ? 'FETCHING' : 'REFRESH',
                        style: Type.label,
                      ),
                    ),
                  ],
                ),
                if (_note != null) Text(_note!, style: Type.caption),
                Text('°C · PRECIPITATION CHANCE · MM/H', style: Type.micro),
                const SizedBox(height: 8),
                if (points.isEmpty)
                  Text('—  No fresh projection.', style: Type.body),
                for (final point in points)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Text(
                          '${point.time.toLocal().day.toString().padLeft(2, '0')} ${point.time.toLocal().hour.toString().padLeft(2, '0')}:00',
                          style: Type.micro,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${point.tempC.toStringAsFixed(1)}°',
                            style: Type.micro,
                          ),
                        ),
                        Text(
                          '${point.precipitationChance == null ? '—' : '${(point.precipitationChance!.clamp(0.0, 1.0) * 100).round()}%'}  ${point.precipitationMm?.toStringAsFixed(1) ?? '—'}  ${precipitationKind(point.weatherCode)?.name.toUpperCase() ?? '—'}',
                          style: Type.micro,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Timeline: rain strokes, snow spokes, hail squares. Size and opacity follow intensity × probability. Missing inputs draw no mark.\nOpen-Meteo · open-meteo.com',
                  style: Type.micro,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
