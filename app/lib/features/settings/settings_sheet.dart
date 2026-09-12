import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/db/store.dart';
import '../../core/health/rollups.dart';
import '../../core/i18n/strings.dart';
import '../../core/place/homes.dart';
import '../../core/state/app_providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/units/mass.dart';
import 'quick_guide.dart';
import '../timeline/weather_sheet.dart';

Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF07090D),
    barrierColor: const Color(0x99000000),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(),
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends ConsumerStatefulWidget {
  const _SettingsSheet();

  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  var _confirmDelete = false;
  String? _note;

  AppStore get _store => ref.read(storeProvider);

  Future<void> _copy(String label, String payload) async {
    await Clipboard.setData(ClipboardData(text: payload));
    try {
      final dir = await getApplicationDocumentsDirectory();
      final name = label == S.exportCsv
          ? 'illunis-export.csv'
          : 'illunis-export.json';
      final file = File(p.join(dir.path, name));
      await file.writeAsString(payload);
      if (!mounted) return;
      setState(() => _note = file.path);
    } catch (_) {
      if (!mounted) return;
      setState(() => _note = S.copied);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(storeRevisionProvider);
    final profile = _store.profile;
    final maxH = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.margin,
              18,
              Space.margin,
              18,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(S.settings, style: Type.label),
                    const Spacer(),
                    Text(
                      S.version,
                      style: Type.micro.copyWith(color: Inks.faint),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(height: 1, color: Inks.hairline),
                const SizedBox(height: 14),
                _Line(
                  label: 'QUICK GUIDE',
                  sub:
                      'Swipe between surfaces. Long press a surface title for Settings.',
                  onTap: () => showQuickGuide(context),
                ),
                _Line(
                  label: 'WEATHER SOURCE / FORECAST',
                  onTap: () => showWeatherSheet(context),
                ),
                _Line(
                  label: S.exportJson,
                  onTap: () => _copy(S.exportJson, _store.exportJson()),
                ),
                _Line(
                  label: S.exportCsv,
                  onTap: () => _copy(S.exportCsv, _store.exportCsv()),
                ),
                _Line(
                  label: S.importJson,
                  onTap: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (!mounted) return;
                    final text = data?.text;
                    if (text == null || text.trim().isEmpty) {
                      setState(() => _note = S.importFailed);
                      return;
                    }
                    try {
                      await _store.importJson(text);
                      await recomputeSummaries(_store);
                      if (!mounted) return;
                      setState(() => _note = S.imported);
                    } catch (_) {
                      if (!mounted) return;
                      setState(() => _note = S.importFailed);
                    }
                  },
                ),
                _Line(
                  label: isImperial(profile.units) ? S.unitsLb : S.unitsKg,
                  onTap: () async {
                    await _store.putProfile(
                      profile.copyWith(
                        units: isImperial(profile.units)
                            ? 'metric'
                            : 'imperial',
                      ),
                    );
                  },
                ),
                _Line(
                  label: S.home(matchingHome(profile).label),
                  onTap: () async {
                    final next = nextHome(profile);
                    ref.read(weatherServiceProvider).setCachedObservation(null);
                    await _store.putProfile(
                      profile.copyWith(
                        homePlace: next.id,
                        latitudeDeg: next.latitudeDeg,
                        longitudeDeg: next.longitudeDeg,
                      ),
                    );
                  },
                ),
                _Line(
                  label:
                      'BURN SOURCE · ${profile.caloriesBurnedSource.toUpperCase()}',
                  sub:
                      'Prefer journal calculations when wearable calorie estimates are unreliable. Missing preferred data falls back to the other source.',
                  onTap: () => _store.putProfile(
                    profile.copyWith(
                      caloriesBurnedSource:
                          profile.caloriesBurnedSource == 'journal'
                          ? 'wearable'
                          : 'journal',
                    ),
                  ),
                ),
                _Line(
                  label: 'STEPS SOURCE · ${profile.stepsSource.toUpperCase()}',
                  sub:
                      'Choose journal or wearable priority. Manual steps remain in the journal.',
                  onTap: () => _store.putProfile(
                    profile.copyWith(
                      stepsSource: profile.stepsSource == 'wearable'
                          ? 'journal'
                          : 'wearable',
                    ),
                  ),
                ),
                _Line(
                  label:
                      'ACTIVE SOURCE · ${profile.activeMinutesSource.toUpperCase()}',
                  onTap: () => _store.putProfile(
                    profile.copyWith(
                      activeMinutesSource:
                          profile.activeMinutesSource == 'journal'
                          ? 'wearable'
                          : 'journal',
                    ),
                  ),
                ),
                Text(
                  'INTAKE · JOURNAL\nSLEEP · JOURNAL FIRST, WEARABLE FALLBACK\nRESTING HR · HEALTH CONNECT ONLY\nRESTEDNESS · RULE / AI, WHEN AVAILABLE',
                  style: Type.micro,
                ),
                _Line(
                  label: 'CONNECT / REFRESH WEARABLE',
                  sub: 'Android Health Connect. Desktop keeps journal figures.',
                  onTap: () async {
                    try {
                      final bridge = ref.read(healthBridgeProvider);
                      final available =
                          bridge.isSupported && await bridge.isAvailable();
                      final allowed =
                          available && await bridge.requestPermissions();
                      if (!mounted) return;
                      if (allowed) ref.invalidate(wearableDailyDataProvider);
                      setState(
                        () => _note = allowed
                            ? 'Wearable refresh requested.'
                            : 'Wearable access unavailable or denied. Journal figures remain available.',
                      );
                    } catch (_) {
                      if (mounted) {
                        setState(() => _note = 'Wearable access unavailable.');
                      }
                    }
                  },
                ),
                _Line(
                  label: profile.hasAiConsent
                      ? '${S.aiConsent} · ON'
                      : S.aiConsent,
                  sub: S.aiConsentNote,
                  onTap: () async {
                    await _store.putProfile(
                      profile.copyWith(
                        aiConsentAt: profile.hasAiConsent
                            ? null
                            : DateTime.now(),
                      ),
                    );
                  },
                ),
                _Line(
                  label: profile.ageAtLeast16
                      ? '${S.ageGate} · YES'
                      : S.ageGate,
                  onTap: () async {
                    await _store.putProfile(
                      profile.copyWith(ageAtLeast16: !profile.ageAtLeast16),
                    );
                  },
                ),
                _Line(
                  label: _confirmDelete ? S.confirmDelete : S.deleteAll,
                  onTap: () async {
                    if (!_confirmDelete) {
                      setState(() => _confirmDelete = true);
                      return;
                    }
                    final nav = Navigator.of(context);
                    await _store.deleteAll();
                    nav.pop();
                  },
                ),
                if (_note != null) ...[
                  const SizedBox(height: 12),
                  Text(_note!, style: Type.caption),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.onTap, this.sub});
  final String label;
  final VoidCallback onTap;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: sub != null ? '$label, $sub' : label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: Type.label.copyWith(color: Inks.strong)),
              if (sub != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    sub!,
                    style: Type.micro.copyWith(color: Inks.muted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
