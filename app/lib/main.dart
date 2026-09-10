import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/db/store.dart';
import 'core/health/rollups.dart';
import 'core/state/app_providers.dart';
import 'core/theme/typography.dart';
import 'features/debug/frame_budget.dart';
import 'features/shell/dream_shell.dart';
import 'features/shell/illunis_shell.dart';

Future<void> main() async {
  final store = await _openStore();
  _boot(const IllunisShell(), store: store);
}

/// Screensaver entrypoint. Bound by `IllunisDreamService`; also reachable
/// with `--dart-define=ILLUNIS_DREAM=true` for desktop review.
@pragma('vm:entry-point')
Future<void> dreamMain() async {
  final store = await _openStore();
  _boot(const DreamShell(), store: store);
}

Future<AppStore> _openStore() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore.memory();
  await store.load();
  await recomputeSummaries(store);
  return store;
}

void _boot(Widget home, {AppStore? store}) {
  if (!kReleaseMode) FrameBudget.instance.start();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final root = const bool.fromEnvironment('ILLUNIS_DREAM')
      ? const DreamShell()
      : home;
  runApp(
    ProviderScope(
      overrides: [if (store != null) ...illunisOverrides(store)],
      child: IllunisApp(home: root),
    ),
  );
}

class IllunisApp extends StatelessWidget {
  const IllunisApp({super.key, this.home = const IllunisShell()});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Illunis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF07090D),
        colorScheme: const ColorScheme.dark(
          primary: Inks.full,
          surface: Color(0xFF0B0E14),
        ),
        fontFamily: Type.text,
        textTheme: Type.theme,
        splashFactory: NoSplash.splashFactory,
      ),
      home: home,
    );
  }
}
