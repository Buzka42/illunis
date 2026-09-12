import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/records.dart';
import '../../core/state/app_providers.dart';
import '../../core/state/civil_day.dart';
import '../../core/theme/typography.dart';

class SkyLetter {
  const SkyLetter(this.id, this.text, this.provenance);
  final String id, text, provenance;
}

final skyLettersProvider = Provider<List<SkyLetter>>((ref) {
  final figures = ref.watch(todayFiguresProvider);
  final summary = figures.summary;
  return [
    if (summary?.digest != null && summary!.digest!.trim().isNotEmpty)
      SkyLetter(
        'daily-digest',
        summary.digest!,
        summary.digestSource == 'ai' ? 'DAILY · AI' : 'DAILY · RULE',
      ),
    for (final finding in figures.findings)
      if (finding.correlation.n >= 21)
        SkyLetter(
          'pattern:${finding.id}',
          finding.sentence,
          'LEARNED · LOCAL · ${finding.correlation.n} PAIRED DAYS',
        ),
  ];
});

/// Arming is ephemeral; confirmed dismissals survive process restart.
class LetterDismissal extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(civilDayProvider);
    return null;
  }

  Future<void> tap(String id) async {
    if (state != id) {
      state = id;
      return;
    }
    state = null;
    final store = ref.read(storeProvider);
    final day = dayKey(ref.read(civilDayProvider));
    final profile = store.profile;
    final ids = <String>{
      if (profile.insightDismissalDay == day) ...profile.dismissedInsightIds,
      id,
    };
    await store.putProfile(
      profile.copyWith(
        insightDismissalDay: day,
        dismissedInsightIds: ids.toList(),
      ),
    );
  }

  void disarm() => state = null;
}

final letterDismissalProvider = NotifierProvider<LetterDismissal, String?>(
  LetterDismissal.new,
);

final visibleSkyLettersProvider = Provider<List<SkyLetter>>((ref) {
  ref.watch(storeRevisionProvider);
  final profile = ref.watch(storeProvider).profile;
  final day = dayKey(ref.watch(civilDayProvider));
  return ref
      .watch(skyLettersProvider)
      .where(
        (letter) =>
            profile.insightDismissalDay != day ||
            !profile.dismissedInsightIds.contains(letter.id),
      )
      .toList();
});

class SkyLetters extends ConsumerStatefulWidget {
  const SkyLetters({super.key, required this.ink});
  final Color ink;
  @override
  ConsumerState<SkyLetters> createState() => _SkyLettersState();
}

class _SkyLettersState extends ConsumerState<SkyLetters> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    final letters = ref.watch(visibleSkyLettersProvider);
    if (letters.isEmpty) return const SizedBox.shrink();
    final letter = letters[_index % letters.length];
    final armed = ref.watch(letterDismissalProvider) == letter.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          hint: armed ? 'Tap again to dismiss' : 'Tap twice to dismiss',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                ref.read(letterDismissalProvider.notifier).tap(letter.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    letter.provenance,
                    style: Type.label.copyWith(color: widget.ink),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    letter.text,
                    style: Type.body.copyWith(color: widget.ink),
                  ),
                  if (armed)
                    Text(
                      'tap again to dismiss',
                      style: Type.micro.copyWith(color: widget.ink),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (letters.length > 1)
          Semantics(
            button: true,
            label: 'Next insight',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                ref.read(letterDismissalProvider.notifier).disarm();
                setState(() => _index++);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'NEXT · ${_index % letters.length + 1}/${letters.length}',
                  style: Type.micro.copyWith(color: widget.ink),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
