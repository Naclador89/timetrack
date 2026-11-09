import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/appearance.dart';
import 'app/providers.dart';
import 'app/router.dart';
import 'app/services.dart';
import 'app/theme.dart';
import 'l10n/app_localizations.dart';
import 'quick/quick_access.dart';
import 'quick/quick_access_host.dart';
import 'reminders/forgotten_clock_out.dart';
import 'sync/sync_controller.dart';
import 'update/update_controller.dart';
import 'work_pc/start_prompt_host.dart';
import 'work_pc/tray.dart';
import 'work_pc/work_pc.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final localWrites = StreamController<void>.broadcast();
  final services = await AppServices.open(
    shareAcrossIsolates: true,
    onLocalWrite: () => localWrites.add(null),
  );
  await initQuickAccess();
  final appearance = await Appearance.load(services.store);
  runApp(
    ProviderScope(
      overrides: [
        storeProvider.overrideWithValue(services.store),
        repositoryProvider.overrideWithValue(services.repository),
        localWritesProvider.overrideWithValue(localWrites.stream),
        autostartedProvider.overrideWithValue(args.contains('--autostart')),
        initialAppearanceProvider.overrideWithValue(appearance),
      ],
      child: TimeTrackApp(router: buildRouter()),
    ),
  );
}

/// Root widget: theme, localization (German first) and routing.
class TimeTrackApp extends ConsumerWidget {
  /// Creates the app with its [router].
  const TimeTrackApp({super.key, required this.router});

  /// The app's routes.
  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    return DynamicColorBuilder(
      // Material You: the wallpaper colours on Android 12+, the accent
      // colour on Windows and Linux (unless switched off), the icon's cyan
      // elsewhere.
      builder: (light, dark) {
        if (!appearance.wallpaperColors) light = dark = null;
        return MaterialApp.router(
          onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
          debugShowCheckedModeBanner: false,
          themeMode: appearance.mode,
          theme: buildTheme(light ?? fallbackScheme(Brightness.light)),
          darkTheme: buildTheme(dark ?? fallbackScheme(Brightness.dark)),
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
              child: ForgottenClockOutHost(
                navigatorKey: router.routerDelegate.navigatorKey,
                child: StartPromptHost(
                  navigatorKey: router.routerDelegate.navigatorKey,
                  child: TrayHost(
                    navigatorKey: router.routerDelegate.navigatorKey,
                    child: child!,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
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
