import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/sky/celestial_scene.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../shell/surface_title.dart';
import 'entry_presentation.dart';
import 'journal_actions.dart';
import 'journal_presentation_model.dart';

export 'entry_presentation.dart';
export 'journal_actions.dart';
export 'journal_fixtures.dart';
export 'journal_layout.dart';
export 'journal_presentation_model.dart';
export 'pending_dock.dart';
export 'writing_line.dart';

/// The input surface. The writing line is the capture; the list is the record.
class JournalPage extends ConsumerWidget {
  const JournalPage({super.key, required this.scene});

  final ValueListenable<ResolvedScene?> scene;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(journalPresentationModelProvider);
    final actions = ref.read(journalActionsProvider);
    final n = model.entryCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.margin, 0, Space.margin, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SurfaceTitle(S.journal),
              const Spacer(),
              Text(n == 1 ? '1 ENTRY' : '$n ENTRIES', style: Type.micro),
              const SizedBox(width: 14),
              JournalNavWord(
                label: S.prev,
                onTap: actions.prevDay,
              ),
              const SizedBox(width: 14),
              JournalNavWord(
                label: S.next,
                active: model.canGoNext,
                onTap: model.canGoNext ? actions.nextDay : null,
              ),
            ],
          ),
          Container(height: 1, color: Inks.hairline),
          Text(
            '${model.dateLabel}${model.bedTimeClock == null ? '' : ' · BED ${model.bedTimeClock}'}',
            style: Type.micro,
            maxLines: 1,
          ),
          Expanded(
            child: model.isEmpty
                ? Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      model.isToday ? S.journalEmpty : S.journalEmptyDay,
                      style: Type.caption,
                    ),
                  )
                : JournalEntryPages(
                    key: ValueKey(model.selectedDay),
                    entries: model.orderedEntries,
                  ),
          ),
        ],
      ),
    );
  }
}
