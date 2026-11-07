import 'dart:async';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timetrack_core/timetrack_core.dart';

import 'app/providers.dart';
import 'app/router.dart';
import 'l10n/app_localizations.dart';
import 'sync/sync_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = TimeTrackDatabase(
    driftDatabase(
      name: 'timetrack',
      native: const DriftNativeOptions(
        // Per-app data folder (~/.local/share/<app id>, %APPDATA%\<app id>,
        // Android app storage), not the user's Documents folder.
        databaseDirectory: getApplicationSupportDirectory,
        // Background handlers (notification, tile, widget) will open it too (M5).
        shareAcrossIsolates: true,
      ),
    ),
  );
  final store = DriftSyncStore(db);
  final localWrites = StreamController<void>.broadcast();
  final repository = await SyncedRepository.open(
    store,
    await loadOrCreateDeviceId(db),
    onLocalWrite: () => localWrites.add(null),
  );
  runApp(
    ProviderScope(
      overrides: [
        storeProvider.overrideWithValue(store),
        repositoryProvider.overrideWithValue(repository),
        localWritesProvider.overrideWithValue(localWrites.stream),
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
    debugShowCheckedModeBanner: false,
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
    builder: (context, child) => _SyncLifecycle(child: child!),
  );
}

/// Starts the sync controller and syncs when the app returns to the foreground.
class _SyncLifecycle extends ConsumerStatefulWidget {
  const _SyncLifecycle({required this.child});

  final Widget child;

  @override
  ConsumerState<_SyncLifecycle> createState() => _SyncLifecycleState();
}

class _SyncLifecycleState extends ConsumerState<_SyncLifecycle> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(syncControllerProvider.notifier).onResume(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(syncControllerProvider); // keeps the controller alive
    return widget.child;
  }
}
