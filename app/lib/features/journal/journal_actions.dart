import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/records.dart';
import '../../core/journal/repository.dart';
import '../../core/journal/stamp.dart';
import '../../core/state/app_providers.dart';
import 'journal_presentation_model.dart';

/// Explicit action dispatcher for journal mutations and navigation.
/// Repository remains the mutation authority for database records.
class JournalActions {
  JournalActions(this.ref);
  final Ref ref;

  JournalRepository get repository => ref.read(journalRepositoryProvider);
  JournalDayNotifier get dayNotifier => ref.read(journalDayProvider.notifier);
  JournalSubmissionStateNotifier get submissionNotifier =>
      ref.read(journalSubmissionStateProvider.notifier);

  void prevDay() {
    dayNotifier.prev();
  }

  void nextDay() {
    dayNotifier.next();
  }

  void setKeepLocal(bool value) {
    submissionNotifier.setKeepLocal(value);
  }

  Future<void> setEntryKeepLocal(String entryId, bool excluded) async {
    await repository.setKeepLocal(entryId, excluded);
  }

  void edit(JournalEntry entry) {
    final text = draftFromStamp(at: entry.at, text: entry.text);
    submissionNotifier.setDraft(
      text: text,
      keepLocal: entry.excludedFromAi,
      replacesEntryId: entry.id,
      requestFocus: true,
    );
    // Legacy draft offer for existing test coverage and listeners
    ref.read(journalDraftProvider.notifier).offer(
      JournalDraft(
        text,
        keepLocal: entry.excludedFromAi,
        replacesEntryId: entry.id,
      ),
    );
  }

  void dropEdit() {
    submissionNotifier.clearDraft();
  }

  Future<JournalEntry?> revert(String entryId, {bool putInDraft = false}) async {
    final hit = await repository.revert(entryId);
    if (hit != null && putInDraft) {
      final text = draftFromStamp(at: hit.at, text: hit.text);
      submissionNotifier.setDraft(
        text: text,
        keepLocal: hit.excludedFromAi,
        replacesEntryId: null,
        requestFocus: true,
      );
      ref.read(journalDraftProvider.notifier).offer(
        JournalDraft(
          text,
          keepLocal: hit.excludedFromAi,
        ),
      );
    }
    return hit;
  }

  Future<void> confirmFood(String id) async {
    await repository.confirmFood(id);
  }

  Future<void> dropFood(String id) async {
    await repository.dropFood(id);
  }

  Future<void> confirmActivity(String id) async {
    await repository.confirmActivity(id);
  }

  Future<void> dropActivity(String id) async {
    await repository.dropActivity(id);
  }

  Future<void> confirmAll() async {
    final figures = ref.read(journalFiguresProvider);
    final days = <String>{
      for (final f in figures.unconfirmed) f.day,
      for (final a in figures.unconfirmedActs) a.day,
    };
    for (final day in days) {
      await repository.confirmAll(day);
    }
  }

  Future<JournalEntry?> submit(
    String raw, {
    DateTime? at,
    bool? keepLocalOverride,
  }) async {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final now = DateTime.now();
    final selected = ref.read(journalDayProvider);
    final dayCtl = ref.read(journalDayProvider.notifier);
    final stamped = stampJournalLine(text);
    final entryAt = at ??
        ((stamped.daysBack != 0 || !dayCtl.catchUp)
            ? now
            : DateTime(
                selected.year,
                selected.month,
                selected.day,
                now.hour,
                now.minute,
                now.second,
              ));

    final subState = ref.read(journalSubmissionStateProvider);
    final replaceId = subState.replacesEntryId;
    final keepLocal = keepLocalOverride ?? subState.keepLocal;

    submissionNotifier.setSubmitting(true);
    try {
      if (replaceId != null) {
        await repository.revert(replaceId);
      }
      final entry = await repository.log(
        text,
        excludedFromAi: keepLocal,
        at: entryAt,
      );
      // KEEP LOCAL resets ONLY after success
      submissionNotifier.onSuccess();
      dayNotifier.go(entry.at);
      return entry;
    } catch (e) {
      submissionNotifier.onError(e.toString());
      rethrow;
    }
  }
}

final journalActionsProvider = Provider<JournalActions>((ref) {
  return JournalActions(ref);
});
