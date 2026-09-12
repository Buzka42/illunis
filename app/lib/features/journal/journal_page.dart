import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/records.dart';
import '../../core/fitness/format.dart';
import '../../core/i18n/dates.dart';
import '../../core/i18n/strings.dart';
import '../../core/journal/dictation.dart';
import '../../core/journal/stamp.dart';
import '../../core/sky/celestial_scene.dart';
import '../../core/state/app_providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/units/mass.dart';
import '../shell/surface_title.dart';

/// The input surface. The writing line is the capture; the list is the record.
class JournalPage extends ConsumerWidget {
  const JournalPage({super.key, required this.scene});

  final ValueListenable<ResolvedScene?> scene;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(journalEntriesProvider);
    final selected = ref.watch(journalDayProvider);
    final figures = ref.watch(journalFiguresProvider);
    final today = sameDay(selected, DateTime.now());
    final date = formatLongDate(selected);
    final n = entries.length;
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
              _NavWord(
                label: S.prev,
                onTap: () => ref.read(journalDayProvider.notifier).prev(),
              ),
              const SizedBox(width: 14),
              _NavWord(
                label: S.next,
                active: !today,
                onTap: today
                    ? null
                    : () => ref.read(journalDayProvider.notifier).next(),
              ),
            ],
          ),
          Container(height: 1, color: Inks.hairline),
          Text(
            '$date${figures.incompleteBed == null ? '' : ' · BED ${_EntryExtract.clock(figures.incompleteBed!.startHours)}'}',
            style: Type.micro,
            maxLines: 1,
          ),
          Expanded(
            child: entries.isEmpty
                ? Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      today ? S.journalEmpty : S.journalEmptyDay,
                      style: Type.caption,
                    ),
                  )
                : _EntryPages(
                    key: ValueKey(selected),
                    entries: entries.reversed.toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EntryPages extends StatefulWidget {
  const _EntryPages({super.key, required this.entries});
  final List<JournalEntry> entries;
  @override
  State<_EntryPages> createState() => _EntryPagesState();
}

class _EntryPagesState extends State<_EntryPages> {
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
              child: _EntryTile(entry: entry, compact: true),
            ),
          if (pages > 1)
            Row(
              children: [
                _NavWord(
                  label: 'NEWER',
                  active: page > 0,
                  onTap: page > 0
                      ? () => setState(() => _page = page - 1)
                      : null,
                ),
                const Spacer(),
                Text('${page + 1}/$pages', style: Type.micro),
                const Spacer(),
                _NavWord(
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

/// Unconfirmed estimates dock on the writing line, not in the page column.
class JournalPending extends ConsumerWidget {
  const JournalPending({super.key, this.maxHeight = maxPendingHeight});
  final double maxHeight;

  /// One estimate row: caption plus DROP / CONFIRM.
  static const double rowBand = 40;

  static const double confirmAllBand = 28;

  /// Maximum height the pending dock may occupy so it never squashes the ground pager.
  static const double maxPendingHeight = 148;

  static double heightFor(int pending) {
    if (pending <= 0) return 0;
    final unbounded = pending * rowBand + (pending > 1 ? confirmAllBand : 0);
    return unbounded > maxPendingHeight ? maxPendingHeight : unbounded;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final figures = ref.watch(journalFiguresProvider);
    final pending = figures.unconfirmed.length + figures.unconfirmedActs.length;
    if (pending == 0) return const SizedBox.shrink();
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final f in figures.unconfirmed) _UnconfirmedFood(food: f),
        for (final a in figures.unconfirmedActs) _UnconfirmedAct(act: a),
        if (pending > 1)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              final days = <String>{
                for (final f in figures.unconfirmed) f.day,
                for (final a in figures.unconfirmedActs) a.day,
              };
              final repo = ref.read(journalRepositoryProvider);
              for (final day in days) {
                await repo.confirmAll(day);
              }
            },
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

class _Word extends StatelessWidget {
  const _Word(this.label, {required this.onTap, this.faint = false});
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

class _NavWord extends StatelessWidget {
  const _NavWord({required this.label, this.onTap, this.active = true});
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

class _EntryTile extends ConsumerWidget {
  const _EntryTile({required this.entry, this.compact = false});
  final bool compact;
  final JournalEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = entry.at.hour.toString().padLeft(2, '0');
    final m = entry.at.minute.toString().padLeft(2, '0');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => ref
          .read(journalDraftProvider.notifier)
          .offer(
            JournalDraft(
              draftFromStamp(at: entry.at, text: entry.text),
              keepLocal: entry.excludedFromAi,
              replacesEntryId: entry.id,
            ),
          ),
      onLongPress: () => ref.read(journalRepositoryProvider).revert(entry.id),
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
                  _Word(
                    S.keepLocal,
                    faint: true,
                    onTap: () => ref
                        .read(journalRepositoryProvider)
                        .setKeepLocal(entry.id, false),
                  ),
                _Word(
                  S.revert,
                  faint: true,
                  onTap: () async {
                    final hit = await ref
                        .read(journalRepositoryProvider)
                        .revert(entry.id);
                    if (hit == null) return;
                    ref
                        .read(journalDraftProvider.notifier)
                        .offer(
                          JournalDraft(
                            draftFromStamp(at: hit.at, text: hit.text),
                            keepLocal: hit.excludedFromAi,
                          ),
                        );
                  },
                ),
              ],
            ),
            if (!compact) _EntryExtract(id: entry.id),
          ],
        ),
      ),
    );
  }
}

class _EntryExtract extends ConsumerWidget {
  const _EntryExtract({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(storeRevisionProvider);
    final store = ref.watch(storeProvider);
    final units = store.profile.units;
    final lines = <String>[];
    for (final s in store.sets) {
      if (s.journalEntryId != id) continue;
      final mass = s.weightKg == 0
          ? 'BW'
          : '${formatMass(s.weightKg, units)} ${massUnit(units)}';
      final rpe = s.rpe == null ? '' : '  @${s.rpe}';
      final rm = s.epley1rm == null
          ? ''
          : '  ·  1RM ${formatMass(s.epley1rm!, units)}';
      lines.add('${s.exerciseName}  $mass × ${s.reps} × ${s.sets}$rpe$rm');
    }
    for (final f in store.nutrition) {
      if (f.journalEntryId != id || !f.confirmed) continue;
      lines.add('${f.label}  ${f.kcal.round()} kcal');
    }
    for (final a in store.activities) {
      if (a.journalEntryId != id || !a.confirmed) continue;
      final bits = <String>[a.label];
      if (a.effort != null) bits.add(a.effort!);
      if (a.distanceKm != null) bits.add('${formatKm(a.distanceKm!)} km');
      if (a.paceSecPerKm != null) bits.add('${formatPace(a.paceSecPerKm!)}/km');
      if (a.minutes != null) bits.add('${a.minutes!.round()} min');
      bits.add('${a.kcal.round()} kcal');
      lines.add(bits.join('  '));
    }
    for (final s in store.sleeps) {
      if (s.journalEntryId != id) continue;
      if (!s.isComplete) {
        lines.add('Bed  ${clock(s.startHours)}');
        continue;
      }
      final felt = s.quality == null
          ? ''
          : (s.quality! < 0.5 ? '  poorly' : '  well');
      lines.add('Sleep  ${_dur(s.durationHours)}$felt');
    }
    for (final w in store.weights) {
      if (w.journalEntryId != id) continue;
      lines.add(
        '${formatMass(w.kg, units, fractionDigits: 1)} ${massUnit(units)}',
      );
    }
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

  static String _dur(double h) {
    final m = (h.abs() * 60).round();
    return '${m ~/ 60}h ${(m % 60).toString().padLeft(2, '0')}m';
  }

  static String clock(double hours) {
    var h = hours;
    while (h < 0) {
      h += 24;
    }
    final m = ((h % 24) * 60).round();
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }
}

class _UnconfirmedFood extends ConsumerWidget {
  const _UnconfirmedFood({required this.food});
  final NutritionEntry food;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(journalFiguresProvider).day;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_pendingDay(food.day, selected)}${food.label}  ·  ${food.kcal.round()} kcal (${S.est.toLowerCase()})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Type.caption,
            ),
          ),
          _Word(
            S.drop,
            faint: true,
            onTap: () => ref.read(journalRepositoryProvider).dropFood(food.id),
          ),
          _Word(
            S.confirm,
            onTap: () =>
                ref.read(journalRepositoryProvider).confirmFood(food.id),
          ),
        ],
      ),
    );
  }
}

class _UnconfirmedAct extends ConsumerWidget {
  const _UnconfirmedAct({required this.act});
  final ActivityEntry act;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(journalFiguresProvider).day;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_pendingDay(act.day, selected)}${act.label}  ·  ${act.kcal.round()} kcal (${S.est.toLowerCase()})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Type.caption,
            ),
          ),
          _Word(
            S.drop,
            faint: true,
            onTap: () =>
                ref.read(journalRepositoryProvider).dropActivity(act.id),
          ),
          _Word(
            S.confirm,
            onTap: () =>
                ref.read(journalRepositoryProvider).confirmActivity(act.id),
          ),
        ],
      ),
    );
  }
}

String _pendingDay(String day, String selected) {
  if (day == selected) return '';
  final yesterday = dayKey(DateTime.now().subtract(const Duration(days: 1)));
  if (day == yesterday) return 'YESTERDAY  ·  ';
  return '${day.substring(5)}  ·  ';
}

class JournalWritingLine extends ConsumerStatefulWidget {
  const JournalWritingLine({super.key});

  /// Space the pager leaves above the surface switch for this line.
  static const double band = 46;

  @override
  ConsumerState<JournalWritingLine> createState() => _JournalWritingLineState();
}

class _JournalWritingLineState extends ConsumerState<JournalWritingLine> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _dictation = JournalDictation();
  var _keepLocal = false;
  var _listening = false;
  String? _replacesEntryId;
  String _spokenBase = '';
  String? _submitError;

  @override
  void dispose() {
    _dictation.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;
    final now = DateTime.now();
    final selected = ref.read(journalDayProvider);
    final dayCtl = ref.read(journalDayProvider.notifier);
    final stamped = stampJournalLine(text);
    final at = (stamped.daysBack != 0 || !dayCtl.catchUp)
        ? now
        : DateTime(
            selected.year,
            selected.month,
            selected.day,
            now.hour,
            now.minute,
            now.second,
          );
    try {
      if (_replacesEntryId != null) {
        final replaceId = _replacesEntryId!;
        _replacesEntryId = null;
        await ref.read(journalRepositoryProvider).revert(replaceId);
      }
      final entry = await ref
          .read(journalRepositoryProvider)
          .log(text, excludedFromAi: _keepLocal, at: at);
      if (!mounted) return;
      _controller.clear();
      setState(() => _submitError = null);
      if (_keepLocal) setState(() => _keepLocal = false);
      ref.read(journalDayProvider.notifier).go(entry.at);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitError = e.toString());
    }
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _dictation.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    _spokenBase = _controller.text.trimRight();
    final ok = await _dictation.start(
      onWords: (words, _) {
        if (!mounted) return;
        final spacer = _spokenBase.isEmpty || words.isEmpty ? '' : ' ';
        final text = '$_spokenBase$spacer$words';
        _controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      },
      onDone: () {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!mounted) return;
    if (!ok) {
      _focus.requestFocus();
      return;
    }
    setState(() => _listening = true);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(storeRevisionProvider);
    final persistError = ref.watch(storeProvider).lastPersistenceError;
    final saveError = _submitError ?? persistError;
    ref.listen<JournalDraft?>(journalDraftProvider, (prev, next) {
      if (next == null) return;
      setState(() {
        _controller.value = TextEditingValue(
          text: next.text,
          selection: TextSelection.collapsed(offset: next.text.length),
        );
        _keepLocal = next.keepLocal;
        _replacesEntryId = next.replacesEntryId;
      });
      _focus.requestFocus();
      ref.read(journalDraftProvider.notifier).clear();
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_replacesEntryId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                Text('EDITING', style: Type.micro.copyWith(color: Inks.muted)),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      _replacesEntryId = null;
                      _controller.clear();
                    });
                  },
                  child: Text(
                    S.drop,
                    style: Type.micro.copyWith(color: Inks.faint),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                style: Type.body.copyWith(color: Inks.strong),
                cursorColor: Inks.strong,
                textInputAction: TextInputAction.done,
                onSubmitted: _submit,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: S.journalHint,
                  hintStyle: Type.body.copyWith(color: Inks.muted),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: _keepLocal ? 'Keep local enabled' : 'Keep local disabled',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _keepLocal = !_keepLocal),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  child: Text(
                    _keepLocal ? '[ LOCAL ]' : S.keepLocal,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: Type.label.copyWith(
                      color: _keepLocal ? Inks.warm : Inks.faint,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Semantics(
              button: true,
              label: _listening ? 'Stop dictation' : 'Start dictation',
              child: GestureDetector(
                key: const ValueKey('journal-mic'),
                behavior: HitTestBehavior.opaque,
                onTap: _toggleMic,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 0, 8),
                  child: CustomPaint(
                    size: const Size(14, 18),
                    painter: _MicMark(_listening ? Inks.warm : Inks.body),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: Space.hairline,
          color: Inks.full.withValues(alpha: 0.4),
        ),
        if (saveError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'NOT SAVED — $saveError',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Type.micro.copyWith(color: Inks.negative),
            ),
          ),
      ],
    );
  }
}

class _MicMark extends CustomPainter {
  const _MicMark(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final w = size.width, h = size.height;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.3, 0, w * 0.4, h * 0.55),
        Radius.circular(w * 0.2),
      ),
      p,
    );
    final path = Path()
      ..moveTo(w * 0.08, h * 0.42)
      ..arcToPoint(
        Offset(w * 0.92, h * 0.42),
        radius: Radius.circular(w * 0.45),
        clockwise: false,
      );
    canvas.drawPath(path, p);
    canvas.drawLine(Offset(w / 2, h * 0.78), Offset(w / 2, h), p);
  }

  @override
  bool shouldRepaint(_MicMark old) => old.color != color;
}
