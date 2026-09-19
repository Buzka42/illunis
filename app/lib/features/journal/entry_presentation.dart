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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 0, 10),
          child: Text(
            label,
            style: Type.label.copyWith(color: faint ? Inks.faint : Inks.strong),
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
        child: Text(
          label,
          style: Type.label.copyWith(color: active ? Inks.muted : Inks.faint),
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
      final rowHeight = 52.0 * scale;
      final count = ((c.maxHeight - 22 * scale) / rowHeight).floor().clamp(
        1,
        100,
      );
      final pages = (widget.entries.length / count).ceil();
      final page = _page.clamp(0, pages - 1);
      final rows = widget.entries.skip(page * count).take(count);
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in rows)
            SizedBox(
              height: rowHeight,
              child: JournalEntryTile(entry: entry, compact: true),
            ),
          if (pages > 1)
            Row(
              children: [
                JournalNavWord(
                  label: 'NEWER',
                  active: page > 0,
                  onTap: page > 0
                      ? () => setState(() => _page = page - 1)
                      : null,
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
            ),
        ],
      );
      if (c.maxHeight < rowHeight + (pages > 1 ? 22 * scale : 0)) {
        return SingleChildScrollView(child: content);
      }
      return content;
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => actions.edit(entry),
      onLongPress: () => actions.revert(entry.id),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 44, child: Text('$h:$m', style: Type.micro)),
                Expanded(
                  child: Text(
                    entry.text,
                    style: Type.body,
                    maxLines: compact ? 2 : null,
                    overflow: compact ? TextOverflow.ellipsis : null,
                  ),
                ),
                if (entry.excludedFromAi)
                  JournalWord(
                    S.keepLocal,
                    faint: true,
                    onTap: () => actions.setEntryKeepLocal(entry.id, false),
                  ),
                JournalWord(
                  S.revert,
                  faint: true,
                  onTap: () => actions.revert(entry.id, putInDraft: true),
                ),
              ],
            ),
            if (!compact) JournalEntryExtract(id: entry.id),
          ],
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
      padding: const EdgeInsets.only(left: 44, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(line, style: Type.micro.copyWith(color: Inks.muted)),
            ),
        ],
      ),
    );
  }
}
