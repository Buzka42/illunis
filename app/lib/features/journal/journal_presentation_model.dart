import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/records.dart';
import '../../core/db/store.dart';
import '../../core/fitness/format.dart';
import '../../core/i18n/dates.dart';
import '../../core/state/app_providers.dart';
import '../../core/state/civil_day.dart';
import '../../core/units/mass.dart';

enum PendingItemType { food, activity }

/// A single unconfirmed estimate item with originating day context.
class JournalPendingItem {
  const JournalPendingItem({
    required this.id,
    required this.journalEntryId,
    required this.originatingDay,
    required this.dayPrefix,
    required this.label,
    required this.kcal,
    required this.type,
  });

  final String id;
  final String journalEntryId;
  final String originatingDay;
  final String dayPrefix;
  final String label;
  final double kcal;
  final PendingItemType type;
}

/// Submission and input state on the journal writing line.
class JournalSubmissionState {
  const JournalSubmissionState({
    this.draftText = '',
    this.cursorPosition = 0,
    this.keepLocal = false,
    this.replacesEntryId,
    this.isEditing = false,
    this.isSubmitting = false,
    this.isListening = false,
    this.isFocused = false,
    this.submitError,
  });

  final String draftText;
  final int cursorPosition;
  final bool keepLocal;
  final String? replacesEntryId;
  final bool isEditing;
  final bool isSubmitting;
  final bool isListening;
  final bool isFocused;
  final String? submitError;

  JournalSubmissionState copyWith({
    String? draftText,
    int? cursorPosition,
    bool? keepLocal,
    String? replacesEntryId,
    bool clearReplacesEntryId = false,
    bool? isEditing,
    bool? isSubmitting,
    bool? isListening,
    bool? isFocused,
    String? submitError,
    bool clearSubmitError = false,
  }) {
    return JournalSubmissionState(
      draftText: draftText ?? this.draftText,
      cursorPosition: cursorPosition ?? this.cursorPosition,
      keepLocal: keepLocal ?? this.keepLocal,
      replacesEntryId: clearReplacesEntryId
          ? null
          : (replacesEntryId ?? this.replacesEntryId),
      isEditing: isEditing ??
          (clearReplacesEntryId
              ? false
              : (replacesEntryId != null || this.replacesEntryId != null)),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isListening: isListening ?? this.isListening,
      isFocused: isFocused ?? this.isFocused,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
    );
  }
}

class JournalSubmissionStateNotifier extends Notifier<JournalSubmissionState> {
  @override
  JournalSubmissionState build() => const JournalSubmissionState();

  void setText(String text, int cursor) {
    state = state.copyWith(draftText: text, cursorPosition: cursor);
  }

  void setKeepLocal(bool keepLocal) {
    state = state.copyWith(keepLocal: keepLocal);
  }

  void setDraft({
    required String text,
    required bool keepLocal,
    String? replacesEntryId,
    bool requestFocus = true,
  }) {
    state = state.copyWith(
      draftText: text,
      cursorPosition: text.length,
      keepLocal: keepLocal,
      replacesEntryId: replacesEntryId,
      clearReplacesEntryId: replacesEntryId == null,
      isEditing: replacesEntryId != null,
      isFocused: requestFocus,
      clearSubmitError: true,
    );
  }

  void clearDraft() {
    state = state.copyWith(
      draftText: '',
      cursorPosition: 0,
      clearReplacesEntryId: true,
      isEditing: false,
      clearSubmitError: true,
    );
  }

  void setFocus(bool focused) {
    state = state.copyWith(isFocused: focused);
  }

  void setListening(bool listening) {
    state = state.copyWith(isListening: listening);
  }

  void setSubmitting(bool submitting) {
    state = state.copyWith(isSubmitting: submitting);
  }

  void onError(String error) {
    state = state.copyWith(submitError: error, isSubmitting: false);
  }

  void onSuccess() {
    state = state.copyWith(
      draftText: '',
      cursorPosition: 0,
      keepLocal: false,
      clearReplacesEntryId: true,
      isEditing: false,
      isSubmitting: false,
      clearSubmitError: true,
    );
  }
}

final journalSubmissionStateProvider =
    NotifierProvider<JournalSubmissionStateNotifier, JournalSubmissionState>(
      JournalSubmissionStateNotifier.new,
    );

/// Unified presentation model for the journal surface.
class JournalPresentationModel {
  const JournalPresentationModel({
    required this.selectedDay,
    required this.isCatchUp,
    required this.isToday,
    required this.dateLabel,
    this.bedTimeClock,
    required this.orderedEntries,
    required this.rawEntries,
    required this.entryCount,
    required this.extractionSummaries,
    required this.pendingItems,
    required this.unconfirmedFood,
    required this.unconfirmedActs,
    required this.submissionState,
  });

  final DateTime selectedDay;
  final bool isCatchUp;
  final bool isToday;
  final String dateLabel;
  final String? bedTimeClock;
  final List<JournalEntry> orderedEntries;
  final List<JournalEntry> rawEntries;
  final int entryCount;
  final Map<String, List<String>> extractionSummaries;
  final List<JournalPendingItem> pendingItems;
  final List<NutritionEntry> unconfirmedFood;
  final List<ActivityEntry> unconfirmedActs;
  final JournalSubmissionState submissionState;

  bool get canGoNext => !isToday;
  bool get isEmpty => orderedEntries.isEmpty;
  int get pendingCount => unconfirmedFood.length + unconfirmedActs.length;
}

String pendingDayPrefix(String day, String selectedDay) {
  if (day == selectedDay) return '';
  final yesterday = dayKey(DateTime.now().subtract(const Duration(days: 1)));
  if (day == yesterday) return 'YESTERDAY  ·  ';
  return '${day.substring(5)}  ·  ';
}

String clockFromHours(double hours) {
  var h = hours;
  while (h < 0) {
    h += 24;
  }
  final m = ((h % 24) * 60).round();
  return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
}

List<String> computeEntryExtractions(AppStore store, String entryId, String units) {
  final lines = <String>[];
  for (final s in store.sets) {
    if (s.journalEntryId != entryId) continue;
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
    if (f.journalEntryId != entryId || !f.confirmed) continue;
    lines.add('${f.label}  ${f.kcal.round()} kcal');
  }
  for (final a in store.activities) {
    if (a.journalEntryId != entryId || !a.confirmed) continue;
    final bits = <String>[a.label];
    if (a.effort != null) bits.add(a.effort!);
    if (a.distanceKm != null) bits.add('${formatKm(a.distanceKm!)} km');
    if (a.paceSecPerKm != null) bits.add('${formatPace(a.paceSecPerKm!)}/km');
    if (a.minutes != null) bits.add('${a.minutes!.round()} min');
    bits.add('${a.kcal.round()} kcal');
    lines.add(bits.join('  '));
  }
  for (final s in store.sleeps) {
    if (s.journalEntryId != entryId) continue;
    if (!s.isComplete) {
      lines.add('Bed  ${clockFromHours(s.startHours)}');
      continue;
    }
    final felt = s.quality == null
        ? ''
        : (s.quality! < 0.5 ? '  poorly' : '  well');
    final m = (s.durationHours.abs() * 60).round();
    final dur = '${m ~/ 60}h ${(m % 60).toString().padLeft(2, '0')}m';
    lines.add('Sleep  $dur$felt');
  }
  for (final w in store.weights) {
    if (w.journalEntryId != entryId) continue;
    lines.add(
      '${formatMass(w.kg, units, fractionDigits: 1)} ${massUnit(units)}',
    );
  }
  return lines;
}

final journalPresentationModelProvider = Provider<JournalPresentationModel>((ref) {
  ref.watch(storeRevisionProvider);
  final store = ref.watch(storeProvider);
  final selected = ref.watch(journalDayProvider);
  final dayNotifier = ref.watch(journalDayProvider.notifier);
  final figures = ref.watch(journalFiguresProvider);
  final rawEntries = ref.watch(journalEntriesProvider);
  final submissionState = ref.watch(journalSubmissionStateProvider);
  final civilDay = ref.watch(civilDayProvider);
  final today = sameDay(selected, civilDay);
  final date = formatLongDate(selected);
  final selectedDayKey = dayKey(selected);
  final units = store.profile.units;

  final extractions = <String, List<String>>{};
  for (final entry in rawEntries) {
    final lines = computeEntryExtractions(store, entry.id, units);
    if (lines.isNotEmpty) {
      extractions[entry.id] = lines;
    }
  }

  final pendingItems = <JournalPendingItem>[
    for (final f in figures.unconfirmed)
      JournalPendingItem(
        id: f.id,
        journalEntryId: f.journalEntryId,
        originatingDay: f.day,
        dayPrefix: pendingDayPrefix(f.day, selectedDayKey),
        label: f.label,
        kcal: f.kcal,
        type: PendingItemType.food,
      ),
    for (final a in figures.unconfirmedActs)
      JournalPendingItem(
        id: a.id,
        journalEntryId: a.journalEntryId,
        originatingDay: a.day,
        dayPrefix: pendingDayPrefix(a.day, selectedDayKey),
        label: a.label,
        kcal: a.kcal,
        type: PendingItemType.activity,
      ),
  ];

  return JournalPresentationModel(
    selectedDay: selected,
    isCatchUp: dayNotifier.catchUp,
    isToday: today,
    dateLabel: date,
    bedTimeClock: figures.incompleteBed == null
        ? null
        : clockFromHours(figures.incompleteBed!.startHours),
    orderedEntries: rawEntries.reversed.toList(),
    rawEntries: rawEntries,
    entryCount: rawEntries.length,
    extractionSummaries: extractions,
    pendingItems: pendingItems,
    unconfirmedFood: figures.unconfirmed,
    unconfirmedActs: figures.unconfirmedActs,
    submissionState: submissionState,
  );
});
