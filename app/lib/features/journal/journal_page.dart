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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const SurfaceTitle(S.journal),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    children: [
                      Text(
                        n == 1 ? '1 ENTRY' : '$n ENTRIES',
                        style: Type.micro,
                      ),
                      JournalNavWord(label: S.prev, onTap: actions.prevDay),
                      JournalNavWord(
                        label: S.next,
                        active: model.canGoNext,
                        onTap: model.canGoNext ? actions.nextDay : null,
                      ),
                    ],
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${model.dateLabel}${model.bedTimeClock == null ? '' : ' · BED ${model.bedTimeClock}'}',
                  style: Type.micro.copyWith(color: Inks.body),
                ),
              ),
              Expanded(
                child: model.isEmpty
                    ? SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12, right: 44),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                model.isToday
                                    ? S.journalEmpty
                                    : S.journalEmptyDay,
                                style: Type.body.copyWith(
                                  color: Inks.body,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                model.pendingCount > 0
                                    ? 'Your estimates are waiting below.'
                                    : model.isCatchUp
                                    ? 'The next line belongs to this day.'
                                    : 'Begin with a line below.',
                                style: Type.caption.copyWith(height: 1.5),
                              ),
                            ],
                          ),
                        ),
                      )
                    : JournalEntryPages(
                        key: ValueKey(model.selectedDay),
                        entries: model.orderedEntries,
                      ),
              ),
            ],
          );
          final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
          if (constraints.maxHeight < 110 * scale) {
            return SingleChildScrollView(
              child: SizedBox(height: 220 * scale, child: content),
            );
          }
          return content;
        },
      ),
    );
  }
}
