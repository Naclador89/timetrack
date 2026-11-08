import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/providers.dart';
import 'app/router.dart';
import 'app/services.dart';
import 'app/theme.dart';
import 'l10n/app_localizations.dart';
import 'quick/quick_access.dart';
import 'quick/quick_access_host.dart';
import 'sync/sync_controller.dart';
import 'update/update_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localWrites = StreamController<void>.broadcast();
  final services = await AppServices.open(
    shareAcrossIsolates: true,
    onLocalWrite: () => localWrites.add(null),
  );
  await initQuickAccess();
  runApp(
    ProviderScope(
      overrides: [
        storeProvider.overrideWithValue(services.store),
        repositoryProvider.overrideWithValue(services.repository),
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
  Widget build(BuildContext context) => DynamicColorBuilder(
    // Material You: the wallpaper colours on Android 12+, teal elsewhere.
    builder: (light, dark) => MaterialApp.router(
      onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(light ?? ColorScheme.fromSeed(seedColor: seedColor)),
      darkTheme: buildTheme(
        dark ??
            ColorScheme.fromSeed(
              seedColor: seedColor,
              brightness: Brightness.dark,
            ),
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('en')],
      routerConfig: router,
      builder: (context, child) => _SyncLifecycle(
        child: QuickAccessHost(
          navigatorKey: router.routerDelegate.navigatorKey,
          child: child!,
        ),
      ),
    ),
  );
}

/// Starts the sync and update controllers; both act when the app returns to
/// the foreground.
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
      onResume: () {
        ref.read(syncControllerProvider.notifier).onResume();
        ref.read(updateControllerProvider.notifier).onResume();
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the controllers alive.
    ref
      ..watch(syncControllerProvider)
      ..watch(updateControllerProvider);
    return widget.child;
  }
}
