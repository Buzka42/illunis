import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/sky/celestial_scene.dart';
import '../../core/state/app_providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../shell/surface_title.dart';
import 'entry_presentation.dart';
import 'journal_actions.dart';
import 'journal_layout.dart';
import 'journal_presentation_model.dart';
import 'pending_dock.dart';
import 'writing_line.dart';

export 'entry_presentation.dart';
export 'journal_actions.dart';
export 'journal_fixtures.dart';
export 'journal_layout.dart';
export 'journal_presentation_model.dart';
export 'pending_dock.dart';
export 'writing_line.dart';

/// The input surface. The writing line is the capture; the list is the record.
///
/// ONE ground composition: record viewport (flexible) + pending dock
/// (clamped) + writer (measured) share a single budget from the incoming
/// constraints, the measured writer height, the keyboard inset and the text
/// scale. The three hold disjoint rects across keyboard, editing, error,
/// pending and page transitions. Opaque matte: the sky never shows through
/// the writing plane.
///
/// The record region is one scroll (per-day restoration): header, date and
/// entries ride together, so the region flexes to any ground without ever
/// overflowing — on roomy grounds nothing scrolls; under extreme squeeze
/// the header scrolls with the list while dock + writer hold their rects.
class JournalPage extends ConsumerWidget {
  const JournalPage({super.key, required this.scene});

  final ValueListenable<ResolvedScene?> scene;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(journalPresentationModelProvider);
    final actions = ref.read(journalActionsProvider);
    final n = model.entryCount;
    // Single budget, spent top to bottom: record region, dock, writer.
    final mq = MediaQuery.of(context);
    final scale = mq.textScaler.scale(10) / 10;
    final keyboardOpen = mq.viewInsets.bottom > 8.0;
    final editing = model.submissionState.replacesEntryId != null;
    final error =
        model.submissionState.submitError != null ||
        ref.watch(storeProvider).lastPersistenceError != null;
    return ColoredBox(
      color: const Color(0xFF07090D),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.margin, 0, Space.margin, 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final writerH = JournalLayoutInputs.writingHeight(
              scale,
              editing: editing,
              error: error,
            );
            final wantPending = JournalPending.heightFor(model.pendingCount);
            final pendingH = keyboardOpen
                ? 0.0
                : JournalLayoutInputs.pendingClamp(
                    groundHeight: constraints.maxHeight,
                    writingHeight: writerH,
                    want: wantPending,
                  );
            final record = Column(
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
                if (model.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12, right: 44),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model.isToday ? S.journalEmpty : S.journalEmptyDay,
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
                  )
                else
                  JournalEntryList(
                    entries: model.orderedEntries,
                    storageKey: ValueKey(model.selectedDay),
                  ),
              ],
            );
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    key: PageStorageKey('journal-record-${model.selectedDay}'),
                    child: record,
                  ),
                ),
                if (pendingH > 0)
                  JournalPending(
                    key: ValueKey(model.selectedDay),
                    maxHeight: pendingH,
                  ),
                const JournalWritingLine(),
              ],
            );
            if (constraints.maxHeight < writerH + pendingH) {
              // Ground cannot fit even dock + writer: everything scrolls so
              // the writer stays reachable and nothing overflows.
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    record,
                    if (pendingH > 0)
                      JournalPending(
                        key: ValueKey(model.selectedDay),
                        maxHeight: pendingH,
                      ),
                    const JournalWritingLine(),
                  ],
                ),
              );
            }
            return content;
          },
        ),
      ),
    );
  }
}
