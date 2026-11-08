import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/format.dart';
import '../sync/sync_controller.dart';

/// The sync state as a small icon; tap to sync now. Hidden while sync is not
/// set up.
class SyncIndicator extends ConsumerWidget {
  /// Creates the indicator.
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final status = ref.watch(syncControllerProvider);
    if (status.phase == SyncPhase.notConfigured) return const SizedBox();
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: switch (status.phase) {
        SyncPhase.error => l.syncError,
        SyncPhase.syncing => l.syncing,
        _ => l.syncNow,
      },
      onPressed: () => ref.read(syncControllerProvider.notifier).syncNow(),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: switch (status.phase) {
          SyncPhase.syncing => const SizedBox.square(
            key: ValueKey('busy'),
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SyncPhase.error => Icon(
            Icons.sync_problem,
            key: const ValueKey('error'),
            color: scheme.error,
          ),
          _ => const Icon(Icons.cloud_done_outlined, key: ValueKey('ok')),
        },
      ),
    );
  }
}

/// Opens the settings (they're no longer a tab).
class SettingsButton extends StatelessWidget {
  /// Creates the button.
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.l10n.navSettings,
    icon: const Icon(Icons.settings_outlined),
    onPressed: () => context.push('/settings'),
  );
}

/// The standard trailing app bar actions: sync state and settings.
List<Widget> commonActions() => const [
  SyncIndicator(),
  SettingsButton(),
  SizedBox(width: 4),
];
