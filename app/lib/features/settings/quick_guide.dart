import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/state/app_providers.dart';
import '../../core/theme/typography.dart';
import '../timeline/weather_sheet.dart';

Future<void> showQuickGuide(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0xFF07090D),
  shape: const RoundedRectangleBorder(),
  builder: (_) => const _Guide(),
);

class _Guide extends ConsumerStatefulWidget {
  const _Guide();
  @override
  ConsumerState<_Guide> createState() => _GuideState();
}

class _GuideState extends ConsumerState<_Guide> {
  int _page = 0;
  static const _pages = [
    (
      'MOVE',
      'Swipe left for Dashboard, right for Journal. Long press the surface title for Settings.\n\nLong days scroll as one list. Tap a journal entry to edit its full text; REVERT removes it and its derived records.',
    ),
    (
      'RECORD',
      'Logging works offline. Pending calorie estimates stay outside totals until you confirm them. KEEP LOCAL keeps that entry out of cloud interpretation.\n\nSource labels: JNL means journal, HC means Health Connect, RULE means a local calculation. Change source priority in Settings. An em dash means unobserved.',
    ),
    (
      'INSIGHTS',
      'Learned correlations need at least 21 paired days. Daily summaries are separate and can use available records from day one. Tap a sky insight twice to dismiss it until the next civil day.\n\nCloud interpretation requires its own consent and age gate in Settings. Cloud insight submission and stored history are not enabled yet; neither is covered by interpretation consent.',
    ),
    (
      'WEATHER',
      'Weather uses the Settings home. The strip shows observed temperature, the forecast range and precipitation chance. Missing or stale observations show an em dash.\n\nTap the weather strip for all 24 forecast hours, refresh, or turn Open-Meteo off. Device GPS is not available yet. The sky remains usable without weather data.',
    ),
  ];
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'QUICK GUIDE · ${_page + 1}/${_pages.length}',
              style: Type.label,
            ),
            const SizedBox(height: 16),
            Text(_pages[_page].$1, style: Type.label),
            const SizedBox(height: 8),
            Text(_pages[_page].$2, style: Type.body),
            if (_page == 1) const _SourceChoices(),
            if (_page == 3)
              TextButton(
                onPressed: () => showWeatherSheet(context),
                child: Text('SET WEATHER SOURCE / REFRESH', style: Type.label),
              ),
            if (_page == 0 && kDebugMode) ...[
              const SizedBox(height: 8),
              Text(
                'Debug builds: long press ILLUNIS for the sky debug sheet.',
                style: Type.micro,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('SKIP', style: Type.label),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    if (_page == _pages.length - 1) {
                      Navigator.pop(context);
                    } else {
                      setState(() => _page++);
                    }
                  },
                  child: Text(
                    _page == _pages.length - 1 ? 'DONE' : 'CONTINUE',
                    style: Type.label,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _SourceChoices extends ConsumerWidget {
  const _SourceChoices();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(storeRevisionProvider);
    final store = ref.watch(storeProvider);
    final profile = store.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Tap to choose priority. Journal sleep wins ties; intake stays journal-only and resting HR stays wearable-only.',
          style: Type.micro,
        ),
        TextButton(
          onPressed: () => store.putProfile(
            profile.copyWith(
              caloriesBurnedSource: profile.caloriesBurnedSource == 'journal'
                  ? 'wearable'
                  : 'journal',
            ),
          ),
          child: Text(
            'BURN · ${profile.caloriesBurnedSource.toUpperCase()}',
            style: Type.label,
          ),
        ),
        Text(
          'Prefer journal calculations if wearable calorie estimates are unreliable.',
          style: Type.micro,
        ),
        TextButton(
          onPressed: () => store.putProfile(
            profile.copyWith(
              stepsSource: profile.stepsSource == 'wearable'
                  ? 'journal'
                  : 'wearable',
            ),
          ),
          child: Text(
            'STEPS · ${profile.stepsSource.toUpperCase()}',
            style: Type.label,
          ),
        ),
        TextButton(
          onPressed: () => store.putProfile(
            profile.copyWith(
              activeMinutesSource: profile.activeMinutesSource == 'journal'
                  ? 'wearable'
                  : 'journal',
            ),
          ),
          child: Text(
            'ACTIVE · ${profile.activeMinutesSource.toUpperCase()}',
            style: Type.label,
          ),
        ),
      ],
    );
  }
}
