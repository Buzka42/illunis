import 'package:flutter/material.dart';
import '../../core/theme/typography.dart';
import '../settings/settings_sheet.dart';

class SurfaceTitle extends StatelessWidget {
  const SurfaceTitle(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    hint: 'Long press for Settings',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => showSettingsSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(title, style: Type.label),
      ),
    ),
  );
}
