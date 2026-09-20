import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/records.dart';
import '../../core/i18n/strings.dart';
import '../../core/state/app_providers.dart';
import '../../core/theme/typography.dart';
import 'journal_actions.dart';
import 'journal_presentation_model.dart';

/// Interactive word action (e.g. DROP, CONFIRM, REVERT, KEEP LOCAL).
class JournalWord extends StatelessWidget {
  const JournalWord(
    this.label, {
    super.key,
    required this.onTap,
    this.faint = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool faint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            child: Text(
              label,
              style: Type.label.copyWith(
                color: faint ? Inks.muted : Inks.strong,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Navigation word for the pager header (PREV, NEXT).
class JournalNavWord extends StatelessWidget {
  const JournalNavWord({
    super.key,
    required this.label,
    this.onTap,
    this.active = true,
  });

  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: active && onTap != null,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              label,
              style: Type.label.copyWith(
                color: active ? Inks.body : Inks.faint,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One continuous list of a day's journal entries — newest first, full prose,
/// tap to edit, long press to revert. It rides inside the journal record
/// region's scroll (per-day restoration key), so it sizes to its content and
/// never nests a second scroller. Submit continuity holds: editing one entry
/// while another lands keeps the draft on the edited entry (tiles key on id).
class JournalEntryList extends StatelessWidget {
  const JournalEntryList({super.key, required this.entries, this.storageKey});

  final List<JournalEntry> entries;

  /// Per-day restoration token, carried by the enclosing record scroll.
  final ValueKey<Object>? storageKey;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final reduced = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      key: ValueKey(entries.map((e) => e.id).join(':')),
      tween: Tween(begin: reduced ? 1 : 0.65, end: 1),
      duration: Duration(milliseconds: reduced ? 0 : 160),
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in entries)
            JournalEntryTile(key: ValueKey(entry.id), entry: entry),
        ],
      ),
    );
  }
}

/// Single journal entry row displaying time, prose, actions and extracts.
class JournalEntryTile extends ConsumerWidget {
  const JournalEntryTile({
    super.key,
    required this.entry,
    this.compact = false,
  });

  final bool compact;
  final JournalEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = entry.at.hour.toString().padLeft(2, '0');
    final m = entry.at.minute.toString().padLeft(2, '0');
    final actions = ref.read(journalActionsProvider);
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final editing = ref.watch(
      journalSubmissionStateProvider.select(
        (s) => s.replacesEntryId == entry.id,
      ),
    );
    return Semantics(
      button: true,
      selected: editing,
      hint: 'Tap to edit. Long press to revert.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => actions.edit(entry),
        onLongPress: () => actions.revert(entry.id),
        child: Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 44 * scale.clamp(1.0, 1.7),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '$h:$m',
                    style: Type.micro.copyWith(
                      color: editing ? Inks.warm : Inks.muted,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      entry.text,
                      style: Type.body.copyWith(
                        height: 1.5,
                        color: Inks.strong,
                      ),
                    ),
                    JournalEntryExtract(id: entry.id),
                    Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (entry.excludedFromAi)
                          JournalWord(
                            S.keepLocal,
                            faint: true,
                            onTap: () =>
                                actions.setEntryKeepLocal(entry.id, false),
                          ),
                        JournalWord(
                          S.revert,
                          faint: true,
                          onTap: () =>
                              actions.revert(entry.id, putInDraft: true),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Extracted figures (sets, nutrition, activity, sleep, weight) below an entry.
class JournalEntryExtract extends ConsumerWidget {
  const JournalEntryExtract({super.key, required this.id});
  final String id;

  static String clock(double hours) => clockFromHours(hours);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(storeRevisionProvider);
    final store = ref.watch(storeProvider);
    final units = store.profile.units;
    final lines = computeEntryExtractions(store, id, units);
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                line,
                style: Type.micro.copyWith(color: Inks.muted, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }
}
