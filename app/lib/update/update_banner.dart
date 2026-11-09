import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app/format.dart';
import 'installer.dart';
import 'update_controller.dart';

/// Shows the update banner above [child] while an update is on offer
/// (spec: updates.md §4).
class UpdateBannerHost extends ConsumerWidget {
  /// Wraps [child].
  const UpdateBannerHost({super.key, required this.child});

  /// The app's tabs.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(updateControllerProvider);
    final banner = status.showsBanner;
    // Always the same tree around child: if the banner swapped it in and out
    // of a Column, child would be rebuilt from scratch and lose its state
    // (e.g. Settings in the middle of the manual check).
    return Column(
      children: [
        if (banner)
          SafeArea(bottom: false, child: UpdateBanner(status: status)),
        Expanded(
          key: const ValueKey('content'),
          // The banner already keeps clear of the status bar.
          child: MediaQuery.removePadding(
            context: context,
            removeTop: banner,
            child: child,
          ),
        ),
      ],
    );
  }
}

/// The banner for [status].
class UpdateBanner extends ConsumerWidget {
  /// Creates the banner.
  const UpdateBanner({super.key, required this.status});

  /// What to show.
  final UpdateStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final updater = ref.read(updateControllerProvider.notifier);
    final version = '${status.release?.version}';
    final later = TextButton(
      onPressed: updater.later,
      child: Text(l.updateLater),
    );
    final (icon, text, actions) = switch (status.phase) {
      UpdatePhase.downloading => (
        Icons.downloading,
        l.updateDownloading(
          version,
          NumberFormat.percentPattern(
            Localizations.localeOf(context).toString(),
          ).format(status.progress),
        ),
        <Widget>[later],
      ),
      UpdatePhase.ready => (
        Icons.restart_alt,
        l.updateReady(version),
        <Widget>[
          later,
          FilledButton(
            onPressed: updater.restart,
            child: Text(l.updateRestart),
          ),
        ],
      ),
      UpdatePhase.failed => (
        Icons.error_outline,
        status.error is InstallPermissionNeeded
            ? l.updateNeedsPermission
            : l.updateFailed('${status.error}'),
        <Widget>[
          later,
          FilledButton(onPressed: updater.install, child: Text(l.updateRetry)),
        ],
      ),
      _ => (
        Icons.system_update,
        l.updateAvailable(version),
        <Widget>[
          TextButton(
            onPressed: () => showUpdateDialog(context, ref),
            child: Text(l.updateWhatsNew),
          ),
          later,
          FilledButton(onPressed: updater.install, child: Text(l.updateNow)),
        ],
      ),
    };
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Icon(icon),
                const SizedBox(width: 16),
                Expanded(child: Text(text)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(spacing: 8, children: actions),
            ),
          ),
          if (status.phase == UpdatePhase.downloading)
            LinearProgressIndicator(
              value: status.progress > 0 ? status.progress : null,
            ),
        ],
      ),
    );
  }
}

/// The release notes with *Aktualisieren*, *Überspringen* and *Später*.
Future<void> showUpdateDialog(BuildContext context, WidgetRef ref) async {
  final release = ref.read(updateControllerProvider).release;
  if (release == null) return;
  final l = context.l10n;
  final action = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.updateAvailable('${release.version}')),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: SelectableText(
            release.notes.trim().isEmpty ? l.updateNoNotes : release.notes,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'skip'),
          child: Text(l.updateSkip),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.updateLater),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, 'install'),
          child: Text(l.updateNow),
        ),
      ],
    ),
  );
  final updater = ref.read(updateControllerProvider.notifier);
  switch (action) {
    case 'install':
      unawaited(updater.install());
    case 'skip':
      await updater.skip();
  }
}

/// Settings → App: manual check (spec: updates.md §3).
Future<void> checkForUpdatesByHand(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final release = await ref
        .read(updateControllerProvider.notifier)
        .checkNow();
    ref.invalidate(updateStateProvider);
    if (release == null) {
      messenger.showSnackBar(SnackBar(content: Text(l.upToDate)));
    } else if (context.mounted) {
      await showUpdateDialog(context, ref);
    }
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l.updateCheckFailed)));
  }
}
