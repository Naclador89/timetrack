import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:timetrack_core/timetrack_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/providers.dart';
import '../sync/sync_controller.dart';
import 'installer.dart';

/// All releases (Settings → App).
final releasesPage = Uri.parse(
  'https://github.com/Naclador89/timetrack/releases',
);

/// The running version (`pubspec.yaml`, spec: updates.md §2); `null` if the
/// platform can't tell.
final installedVersionProvider = FutureProvider<AppVersion?>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return AppVersion.tryParse(info.version);
});

/// This device's release build, or `null` (no updates offered).
final updatePlatformProvider = Provider<UpdatePlatform?>(
  (ref) => UpdatePlatform.of(Platform.operatingSystem),
);

/// An HTTP client for GitHub: through the device's sync proxy setting, if
/// one is saved (spec: updates.md §1).
Future<http.Client> updateHttpClient(Ref ref) async {
  String proxy = '';
  try {
    proxy = (await ref.read(syncConfigStoreProvider).load())?.proxy ?? '';
  } on Object {
    // No secure storage: go direct.
  }
  return ref.read(httpClientFactoryProvider)(proxy);
}

/// Installs a downloaded release; replaced in tests.
final updateInstallerProvider = Provider<UpdateInstaller>(
  (ref) => UpdateInstaller.forPlatform(),
);

/// What the updater is doing.
enum UpdatePhase {
  /// Nothing to offer.
  none,

  /// [UpdateStatus.release] can be installed.
  available,

  /// Downloading; [UpdateStatus.progress] runs from 0 to 1.
  downloading,

  /// Installed on desktop, waiting for the restart.
  ready,

  /// Download or install failed; [UpdateStatus.error] says why.
  failed,
}

/// The update state shown in the UI.
final class UpdateStatus {
  /// Creates a status.
  const UpdateStatus(
    this.phase, {
    this.release,
    this.progress = 0,
    this.error,
    this.hidden = false,
  });

  /// Current phase.
  final UpdatePhase phase;

  /// The release on offer.
  final Release? release;

  /// Download progress (0–1; 0 while the size is unknown).
  final double progress;

  /// Why it failed.
  final Object? error;

  /// The banner was put away with *Später* (until the next start).
  final bool hidden;

  /// Whether the banner shows.
  bool get showsBanner => phase != UpdatePhase.none && !hidden;
}

/// Checks for releases and installs them (spec: updates.md).
class UpdateController extends Notifier<UpdateStatus> {
  @override
  UpdateStatus build() {
    Future.microtask(() async {
      try {
        await ref.read(updateInstallerProvider).cleanUp();
      } on Object {
        // Leftovers are harmless; the next start tries again.
      }
      if (!syncDisabled) await check();
    });
    return const UpdateStatus(UpdatePhase.none);
  }

  /// The checker for this device, or `null` where there are no builds.
  Future<UpdateChecker?> _checker() async {
    final platform = ref.read(updatePlatformProvider);
    final installed = await ref.read(installedVersionProvider.future);
    if (platform == null || installed == null) return null;
    return UpdateChecker(
      store: ref.read(storeProvider),
      installed: installed,
      platform: platform,
      now: ref.read(clockProvider),
      fetch: () async {
        final client = await updateHttpClient(ref);
        try {
          return await fetchLatestRelease(client);
        } finally {
          client.close();
        }
      },
    );
  }

  /// The automatic check (start, resume; at most once per 24 h). Never
  /// throws.
  Future<void> check() async {
    if (syncDisabled || state.phase != UpdatePhase.none) return;
    try {
      final checker = await _checker();
      final release = await checker?.check();
      if (release != null && state.phase == UpdatePhase.none) {
        state = UpdateStatus(UpdatePhase.available, release: release);
        // Seen in the banner: no system notification for it later (§4).
        await checker!.takeNotification(release);
      }
    } on Object {
      // No version info, no storage: nothing to offer.
    }
  }

  /// Call when the app returns to the foreground.
  void onResume() => unawaited(check());

  /// Checks now, ignoring the pause, the switch and a skipped version;
  /// returns the release on offer (`null`: up to date). Throws when GitHub
  /// can't be reached.
  Future<Release?> checkNow() async {
    final checker = await _checker();
    if (checker == null) return null;
    final release = await checker.check(manual: true);
    if (state.phase case UpdatePhase.none || UpdatePhase.available) {
      state = release == null
          ? const UpdateStatus(UpdatePhase.none)
          : UpdateStatus(UpdatePhase.available, release: release);
    }
    return release;
  }

  /// *Später*: hide the banner until the next start.
  void later() => state = UpdateStatus(
    state.phase,
    release: state.release,
    progress: state.progress,
    error: state.error,
    hidden: true,
  );

  /// *Überspringen*: don't offer this version again by itself.
  Future<void> skip() async {
    final release = state.release;
    if (release == null) return;
    await (await _checker())?.skip(release.version);
    state = const UpdateStatus(UpdatePhase.none);
  }

  /// Turns the automatic check on or off.
  Future<void> setAuto(bool on) async {
    await (await _checker())?.setAuto(on);
    ref.invalidate(updateStateProvider);
  }

  /// Downloads, verifies and installs the release on offer
  /// (spec: updates.md §5).
  Future<void> install() async {
    final release = state.release;
    final platform = ref.read(updatePlatformProvider);
    if (release == null || platform == null) return;
    if (state.phase case UpdatePhase.downloading || UpdatePhase.ready) return;
    final installer = ref.read(updateInstallerProvider);
    if (!await installer.canSelfInstall()) {
      // Installed somewhere the app can't write (e.g. Program Files).
      await launchUrl(release.page, mode: LaunchMode.externalApplication);
      return;
    }
    state = UpdateStatus(UpdatePhase.downloading, release: release);
    try {
      // Nothing unsent stays behind (the data itself survives anyway).
      await ref.read(syncControllerProvider.notifier).syncNow();
      final client = await updateHttpClient(ref);
      final File file;
      try {
        file = await downloadVerified(
          client,
          release,
          platform,
          await installer.downloadFolder(),
          onProgress: (p) => state = UpdateStatus(
            UpdatePhase.downloading,
            release: release,
            progress: p,
          ),
        );
      } finally {
        client.close();
      }
      final restart = await installer.install(file);
      state = UpdateStatus(
        restart ? UpdatePhase.ready : UpdatePhase.available,
        release: release,
      );
    } on Object catch (e) {
      state = UpdateStatus(UpdatePhase.failed, release: release, error: e);
    }
  }

  /// Desktop: starts the new version and quits.
  Future<void> restart() => ref.read(updateInstallerProvider).restart();
}

/// The updater and its status.
final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateStatus>(UpdateController.new);

/// The stored update state (settings screen).
final updateStateProvider = FutureProvider<UpdateState>((ref) async {
  final raw = await ref
      .watch(storeProvider)
      .transaction((tx) => tx.localValue(UpdateChecker.stateKey));
  return UpdateState.decode(raw);
});
