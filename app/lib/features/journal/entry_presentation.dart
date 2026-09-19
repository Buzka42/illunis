import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/records.dart';
import '../../core/i18n/strings.dart';
import '../../core/state/app_providers.dart';
import '../../core/theme/typography.dart';
import 'journal_actions.dart';
import 'journal_layout.dart';
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

/// Navigation word for pager header and entry pagination (PREV, NEXT, NEWER, OLDER).
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

/// Paginated list of journal entries with NEWER / OLDER pagination.
class JournalEntryPages extends StatefulWidget {
  const JournalEntryPages({super.key, required this.entries});
  final List<JournalEntry> entries;

  @override
  State<JournalEntryPages> createState() => _JournalEntryPagesState();
}

class _JournalEntryPagesState extends State<JournalEntryPages> {
  int _page = 0;

  @override
  void didUpdateWidget(JournalEntryPages oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries.firstOrNull?.id != widget.entries.firstOrNull?.id) {
      _page = 0;
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      if (widget.entries.isEmpty) return const SizedBox.shrink();
      final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
      final count = JournalLayoutInputs(
        groundHeight: c.maxHeight,
        keyboardInset: 0,
        pendingHeight: 0,
        textScale: scale,
      ).entriesPerPage(c.maxHeight);
      final pages = (widget.entries.length / count).ceil();
      final page = _page.clamp(0, pages - 1);
      final rows = widget.entries.skip(page * count).take(count).toList();
      final reduced = MediaQuery.disableAnimationsOf(context);
      final navigation = Row(
        children: [
          JournalNavWord(
            label: 'NEWER',
            active: page > 0,
            onTap: page > 0 ? () => setState(() => _page = page - 1) : null,
          ),
          const Spacer(),
          Text('${page + 1}/$pages', style: Type.micro),
          const Spacer(),
          JournalNavWord(
            label: 'OLDER',
            active: page + 1 < pages,
            onTap: page + 1 < pages
                ? () => setState(() => _page = page + 1)
                : null,
          ),
        ],
      );
      if (c.maxHeight < 44) {
        return SingleChildScrollView(
          child: Column(
            children: [
              for (final entry in rows)
                JournalEntryTile(key: ValueKey(entry.id), entry: entry),
              if (pages > 1) navigation,
            ],
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              key: ValueKey('journal-page-$page-${rows.first.id}'),
              child: TweenAnimationBuilder<double>(
                key: ValueKey(rows.map((e) => e.id).join(':')),
                tween: Tween(begin: reduced ? 1 : 0.65, end: 1),
                duration: Duration(milliseconds: reduced ? 0 : 160),
                builder: (context, opacity, child) =>
                    Opacity(opacity: opacity, child: child),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final entry in rows)
                      JournalEntryTile(key: ValueKey(entry.id), entry: entry),
                  ],
                ),
              ),
            ),
          ),
          if (pages > 1) navigation,
        ],
      );
    },
  );
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
