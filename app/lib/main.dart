import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/typography.dart';
import 'features/shell/illunis_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const ProviderScope(child: IllunisApp()));
}

class IllunisApp extends StatelessWidget {
  const IllunisApp({super.key});

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
      home: const IllunisShell(),
    );
  }
}
