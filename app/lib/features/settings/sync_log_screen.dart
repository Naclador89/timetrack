import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../sync/sync_controller.dart';

/// The last sync cycles of this device (spec: sync-log.md).
class SyncLogScreen extends ConsumerWidget {
  /// Creates the screen.
  const SyncLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final status = ref.watch(syncControllerProvider);
    final entries = ref.watch(syncLogProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: Text(l.syncLog),
        actions: [
          IconButton(
            tooltip: l.syncNow,
            icon: const Icon(Icons.refresh),
            onPressed:
                status.phase == SyncPhase.syncing ||
                    status.phase == SyncPhase.notConfigured
                ? null
                : ref.read(syncControllerProvider.notifier).syncNow,
          ),
          IconButton(
            tooltip: l.syncLogClear,
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: entries.isEmpty
                ? null
                : () async {
                    await SyncLog(ref.read(storeProvider)).clear();
                    ref.invalidate(syncLogProvider);
                  },
          ),
        ],
      ),
      body: entries.isEmpty
          ? Center(child: Text(l.syncLogEmpty))
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: entries.length + 1,
              separatorBuilder: (_, i) =>
                  i == 0 ? const SizedBox.shrink() : const Divider(height: 1),
              itemBuilder: (context, i) => i == 0
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        l.syncLogHint,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  : SyncLogTile(entry: entries[i - 1]),
            ),
    );
  }
}

/// One log entry: what moved or why it failed, when, how long.
class SyncLogTile extends StatelessWidget {
  /// Creates the tile.
  const SyncLogTile({super.key, required this.entry});

  /// The entry shown.
  final SyncLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final e = entry;
    return ListTile(
      leading: Icon(
        e.failed
            ? Icons.error_outline
            : (e.idle ? Icons.check : Icons.sync_alt),
        color: e.failed
            ? scheme.error
            : (e.idle ? scheme.onSurfaceVariant : scheme.primary),
      ),
      title: Text(syncLogTitle(l, e)),
      subtitle: Text(
        [_when(context, e), if (e.error != null) e.error!].join('\n'),
      ),
      isThreeLine: e.error != null,
    );
  }

  static String _when(BuildContext context, SyncLogEntry e) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final day = DateFormat.yMd(locale);
    final time = DateFormat.Hm(locale);
    final start = e.start.toLocal();
    final last = e.last.toLocal();
    final seconds = NumberFormat('0.0', locale).format(e.durationMs / 1000);
    return [
      e.repeats > 1
          ? '${day.format(start)} ${time.format(start)}–${time.format(last)}'
          : '${day.format(start)} ${time.format(start)}',
      '$seconds s',
      if (e.trigger == SyncTrigger.background) l.syncLogBackground,
      if (e.trigger == SyncTrigger.network) l.syncLogNetwork,
    ].join(' · ');
  }
}

/// "↑ 2 changes sent · ↓ 5 changes received", "Nothing to sync · 42×" or
/// "Failed".
String syncLogTitle(AppLocalizations l, SyncLogEntry e) {
  if (e.failed) return l.syncLogFailed;
  if (e.idle) {
    return [
      l.syncLogIdle,
      if (e.repeats > 1) l.syncLogTimes('${e.repeats}'),
    ].join(' · ');
  }
  return [
    if (e.uploadedChanges > 0) l.syncLogUp('${e.uploadedChanges}'),
    if (e.downloadedFiles > 0) l.syncLogDown('${e.appliedChanges}'),
    if (e.resolvedRows > 0) l.syncLogResolved('${e.resolvedRows}'),
  ].join(' · ');
}
