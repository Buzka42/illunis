import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/records.dart';
import '../../core/i18n/strings.dart';
import '../../core/state/app_providers.dart';
import '../../core/theme/typography.dart';
import 'entry_presentation.dart';
import 'journal_actions.dart';
import 'journal_layout.dart';
import 'journal_presentation_model.dart';

/// Unconfirmed estimates dock on the writing line, not in the page column.
class JournalPending extends ConsumerWidget {
  const JournalPending({super.key, this.maxHeight = maxPendingHeight});
  final double maxHeight;

  /// One estimate row: caption plus DROP / CONFIRM.
  static const double rowBand = JournalLayoutInputs.pendingRowBand;

  static const double confirmAllBand = JournalLayoutInputs.pendingConfirmAllBand;

  /// Maximum height the pending dock may occupy so it never squashes the ground pager.
  static const double maxPendingHeight = JournalLayoutInputs.maxPendingHeight;

  static double heightFor(int pending) =>
      JournalLayoutInputs.calculatePendingHeight(pending);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final figures = ref.watch(journalFiguresProvider);
    final pending = figures.unconfirmed.length + figures.unconfirmedActs.length;
    if (pending == 0) return const SizedBox.shrink();
    final actions = ref.read(journalActionsProvider);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final f in figures.unconfirmed)
          PendingFoodRow(food: f, actions: actions),
        for (final a in figures.unconfirmedActs)
          PendingActivityRow(act: a, actions: actions),
        if (pending > 1)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => actions.confirmAll(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                S.confirmAll,
                style: Type.label.copyWith(color: Inks.strong),
              ),
            ),
          ),
      ],
    );
    final unbounded = pending * rowBand + (pending > 1 ? confirmAllBand : 0);
    if (unbounded <= maxHeight) return content;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: content,
      ),
    );
  }
}

class PendingFoodRow extends ConsumerWidget {
  const PendingFoodRow({
    super.key,
    required this.food,
    required this.actions,
  });

  final NutritionEntry food;
  final JournalActions actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(journalFiguresProvider).day;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${pendingDayPrefix(food.day, selected)}${food.label}  ·  ${food.kcal.round()} kcal (${S.est.toLowerCase()})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Type.caption,
            ),
          ),
          JournalWord(
            S.drop,
            faint: true,
            onTap: () => actions.dropFood(food.id),
          ),
          JournalWord(
            S.confirm,
            onTap: () => actions.confirmFood(food.id),
          ),
        ],
      ),
    );
  }
}

class PendingActivityRow extends ConsumerWidget {
  const PendingActivityRow({
    super.key,
    required this.act,
    required this.actions,
  });

  final ActivityEntry act;
  final JournalActions actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(journalFiguresProvider).day;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${pendingDayPrefix(act.day, selected)}${act.label}  ·  ${act.kcal.round()} kcal (${S.est.toLowerCase()})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Type.caption,
            ),
          ),
          JournalWord(
            S.drop,
            faint: true,
            onTap: () => actions.dropActivity(act.id),
          ),
          JournalWord(
            S.confirm,
            onTap: () => actions.confirmActivity(act.id),
          ),
        ],
      ),
    );
  }
}
