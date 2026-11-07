import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timetrack_core/timetrack_core.dart';

import 'app/providers.dart';
import 'app/router.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = TimeTrackDatabase(
    driftDatabase(
      name: 'timetrack',
      // Background handlers (notification, tile, widget) will open it too (M5).
      native: const DriftNativeOptions(shareAcrossIsolates: true),
    ),
  );
  final store = DriftSyncStore(db);
  final repository = await SyncedRepository.open(
    store,
    await loadOrCreateDeviceId(db),
  );
  runApp(
    ProviderScope(
      overrides: [
        storeProvider.overrideWithValue(store),
        repositoryProvider.overrideWithValue(repository),
      ],
      child: TimeTrackApp(router: buildRouter()),
    ),
  );
}

/// Root widget: theme, localization (German first) and routing.
class TimeTrackApp extends StatelessWidget {
  /// Creates the app with its [router].
  const TimeTrackApp({super.key, required this.router});

  /// The app's routes.
  final GoRouter router;

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
    theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
    darkTheme: ThemeData(
      colorSchemeSeed: Colors.teal,
      brightness: Brightness.dark,
      useMaterial3: true,
    ),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('de'), Locale('en')],
    routerConfig: router,
  );
}
