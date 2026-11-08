import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../sync/sync_controller.dart';

/// Picks a JSON backup and loads it the way the user chooses
/// (spec: backup.md §2).
Future<void> restoreBackupFlow(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'JSON',
        extensions: ['json'],
        mimeTypes: ['application/json'],
      ),
    ],
  );
  if (file == null) return;
  final Backup backup;
  try {
    backup = decodeBackup(await file.readAsString());
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l.notABackup)));
    return;
  }
  if (context.mounted) await showRestoreDialog(context, ref, backup);
}

/// Syncs first, so the previews see the other devices' latest rows, then
/// lets the user pick merge or replace with what each would change.
Future<void> showRestoreDialog(
  BuildContext context,
  WidgetRef ref,
  Backup backup,
) async {
  final sync = ref.read(syncControllerProvider.notifier);
  await sync.syncNow();
  if (!context.mounted) return;
  final repo = ref.read(repositoryProvider);
  final previews = {
    for (final mode in RestoreMode.values)
      mode: await restoreBackup(repo, backup, mode, dryRun: true),
  };
  if (!context.mounted) return;
  final mode = await showDialog<RestoreMode>(
    context: context,
    builder: (_) => _RestoreDialog(
      backup: backup,
      previews: previews,
      syncFailed: ref.read(syncControllerProvider).phase == SyncPhase.error,
    ),
  );
  if (mode == null || !context.mounted) return;
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final done = await restoreBackup(repo, backup, mode);
  messenger.showSnackBar(
    SnackBar(content: Text(l.restoreDone(_counts(l, done)))),
  );
}

String _counts(AppLocalizations l, RestoreSummary s) => s.isEmpty
    ? l.restoreNoChange
    : l.restoreCounts('${s.added}', '${s.changed}', '${s.deleted}');

class _RestoreDialog extends StatefulWidget {
  const _RestoreDialog({
    required this.backup,
    required this.previews,
    required this.syncFailed,
  });

  final Backup backup;
  final Map<RestoreMode, RestoreSummary> previews;
  final bool syncFailed;

  @override
  State<_RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends State<_RestoreDialog> {
  RestoreMode? _mode;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final exported = DateFormat.yMd(Localizations.localeOf(context).toString())
        .add_Hm()
        .format(widget.backup.exported.toLocal());
    Widget option(RestoreMode mode, String title, String hint) {
      final preview = widget.previews[mode]!;
      final danger = mode == RestoreMode.replace && preview.deleted > 0;
      return RadioListTile<RestoreMode>(
        value: mode,
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(hint),
            const SizedBox(height: 4),
            Text(
              _counts(l, preview),
              style: theme.textTheme.labelLarge?.copyWith(
                color: danger ? theme.colorScheme.error : null,
              ),
            ),
          ],
        ),
      );
    }

    return AlertDialog(
      title: Text(l.restoreBackup),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: RadioGroup<RestoreMode>(
            groupValue: _mode,
            onChanged: (m) => setState(() => _mode = m),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.restoreFrom(exported, '${widget.backup.rows.length}'),
                  style: theme.textTheme.bodySmall,
                ),
                if (widget.syncFailed) ...[
                  const SizedBox(height: 8),
                  Text(
                    l.restoreSyncFailed,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 12),
                Text(l.restoreChoose),
                option(RestoreMode.merge, l.restoreMerge, l.restoreMergeHint),
                option(
                  RestoreMode.replace,
                  l.restoreReplace,
                  l.restoreReplaceHint,
                ),
                const SizedBox(height: 8),
                Text(l.restoreTip, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          style: _mode == RestoreMode.replace
              ? FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                )
              : null,
          onPressed: _mode == null || widget.previews[_mode]!.isEmpty
              ? null
              : () => Navigator.pop(context, _mode),
          child: Text(switch (_mode) {
            RestoreMode.replace => l.restoreReplace,
            RestoreMode.merge => l.restoreMerge,
            null => l.restoreBackup,
          }),
        ),
      ],
    );
  }
}
