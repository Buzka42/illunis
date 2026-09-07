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

Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xF20B0E14),
    barrierColor: Colors.transparent,
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
      setState(() => _note = file.path);
    } catch (_) {
      setState(() => _note = S.copied);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(storeRevisionProvider);
    final profile = _store.profile;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.margin,
        18,
        Space.margin,
        MediaQuery.paddingOf(context).bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(S.settings, style: Type.label),
              const Spacer(),
              Text(S.version, style: Type.micro.copyWith(color: Inks.faint)),
            ],
          ),
          const SizedBox(height: 6),
          Container(height: 1, color: Inks.hairline),
          const SizedBox(height: 14),
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
              final text = data?.text;
              if (text == null || text.trim().isEmpty) {
                setState(() => _note = S.importFailed);
                return;
              }
              try {
                await _store.importJson(text);
                await recomputeSummaries(_store);
                setState(() => _note = S.imported);
              } catch (_) {
                setState(() => _note = S.importFailed);
              }
            },
          ),
          _Line(
            label: isImperial(profile.units) ? S.unitsLb : S.unitsKg,
            onTap: () async {
              await _store.putProfile(
                profile.copyWith(
                  units: isImperial(profile.units) ? 'metric' : 'imperial',
                ),
              );
            },
          ),
          _Line(
            label: S.home(matchingHome(profile).label),
            onTap: () async {
              final next = nextHome(profile);
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
            label: profile.hasAiConsent ? '${S.aiConsent} · ON' : S.aiConsent,
            onTap: () async {
              await _store.putProfile(
                profile.copyWith(
                  aiConsentAt: profile.hasAiConsent ? null : DateTime.now(),
                ),
              );
            },
          ),
          _Line(
            label: profile.ageAtLeast16 ? '${S.ageGate} · YES' : S.ageGate,
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
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(label, style: Type.label.copyWith(color: Inks.strong)),
      ),
    );
  }
}
