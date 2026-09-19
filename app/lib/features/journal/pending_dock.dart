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

  static const double confirmAllBand =
      JournalLayoutInputs.pendingConfirmAllBand;

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
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        key: const PageStorageKey('journal-pending'),
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 6),
              child: Text('ESTIMATES · $pending', style: Type.label),
            ),
            for (final f in figures.unconfirmed)
              PendingFoodRow(key: ValueKey(f.id), food: f, actions: actions),
            for (final a in figures.unconfirmedActs)
              PendingActivityRow(key: ValueKey(a.id), act: a, actions: actions),
            if (pending > 1)
              Align(
                alignment: Alignment.centerRight,
                child: JournalWord(
                  S.confirmAll,
                  onTap: () => actions.confirmAll(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PendingFoodRow extends ConsumerWidget {
  const PendingFoodRow({super.key, required this.food, required this.actions});

  final NutritionEntry food;
  final JournalActions actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(journalFiguresProvider).day;
    return _PendingDecision(
      label: '${pendingDayPrefix(food.day, selected)}${food.label}',
      evidence: '${food.kcal.round()} kcal (${S.est.toLowerCase()})',
      drop: () => actions.dropFood(food.id),
      confirm: () => actions.confirmFood(food.id),
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
    return _PendingDecision(
      label: '${pendingDayPrefix(act.day, selected)}${act.label}',
      evidence: '${act.kcal.round()} kcal (${S.est.toLowerCase()})',
      drop: () => actions.dropActivity(act.id),
      confirm: () => actions.confirmActivity(act.id),
    );
  }
}

class _PendingDecision extends StatelessWidget {
  const _PendingDecision({
    required this.label,
    required this.evidence,
    required this.drop,
    required this.confirm,
  });
  final String label, evidence;
  final VoidCallback drop, confirm;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: [
              TextSpan(
                text: '  ·  $evidence',
                style: Type.micro.copyWith(color: Inks.body, height: 1.4),
              ),
            ],
          ),
          style: Type.caption.copyWith(color: Inks.body, height: 1.4),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            JournalWord(S.drop, faint: true, onTap: drop),
            JournalWord(S.confirm, onTap: confirm),
          ],
        ),
      ],
    ),
  );
}
