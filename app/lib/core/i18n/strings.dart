/// Product copy. English only for v1; the analyzer is the completeness
/// check — every surface string lives here, not in an ARB.
library;

class S {
  const S._();

  static const journal = 'JOURNAL';
  static const dashboard = 'DASHBOARD';
  static const today = 'TODAY';
  static const sky = 'SKY';
  static const sleep = 'SLEEP';
  static const recovery = 'RECOVERY';
  static const strain = 'STRAIN';
  static const energy = 'ENERGY';
  static const training = 'WORK';
  static const intake = 'INTAKE';
  static const patterns = 'INSIGHTS';
  static const noData = 'NO DATA';
  static const mockData = 'MOCK DATA';
  static const local = 'LOCAL';
  static const keepLocal = 'KEEP LOCAL';
  static const emptyDash = '—';
  static const journalHint = 'Log an activity, a meal, a workout…';
  static const journalEmpty =
      'Nothing logged yet. A run, a meal, a session, a night — write it as it happened.';
  static const patternsEmpty =
      'Nothing can be said yet. Insights need 21 paired days.';
  static const settings = 'SETTINGS';
  static const exportJson = 'EXPORT JSON';
  static const exportCsv = 'EXPORT CSV';
  static const deleteAll = 'DELETE ALL DATA';
  static const confirmDelete = 'CONFIRM DELETE';
  static const aiConsent = 'ALLOW INTERPRETATION';
  static const ageGate = 'I AM 16 OR OLDER';
  static const copied = 'Copied to the clipboard.';
  static const confirm = 'CONFIRM';
  static const confirmAll = 'CONFIRM ALL';
  static const drop = 'DROP';
  static const revert = 'REVERT';
  static const version = 'ILLUNIS 1.0';
  static const prev = 'PREV';
  static const next = 'NEXT';
  static const unitsKg = 'UNITS · KG';
  static const unitsLb = 'UNITS · LB';
  static const mass = 'MASS';
  static const journalEmptyDay = 'Nothing logged this day.';
  static const est = 'EST.';
  static const importJson = 'IMPORT JSON';
  static const importFailed = 'Nothing on the clipboard to import.';
  static const imported = 'Imported.';
  static const week = '7D';

  static String home(String place) => 'HOME · $place';

  static String insightsWait(String pair, int n) {
    final left = 21 - n;
    if (left <= 0) return patternsEmpty;
    return '$pair have $n paired days. $left remain before anything can be said.';
  }
}
