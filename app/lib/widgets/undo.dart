import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../app/format.dart';
import '../app/providers.dart';

/// Deletes rows right away and offers to bring them back for a few seconds
/// (instead of asking first; a tombstone is undone by writing
/// `deleted: false`, sync-format.md §5).
Future<void> deleteWithUndo(
  BuildContext context,
  WidgetRef ref,
  List<(String, String)> rows, {
  String? message,
}) async {
  final repo = ref.read(repositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  final l = context.l10n;
  for (final (table, id) in rows) {
    await repo.delete(table, id);
  }
  _offerRestore(messenger, repo, rows, message ?? l.deleted, l.undo);
}

/// Shows [message] with an undo that brings back the rows just [deleted]
/// elsewhere (e.g. by `clearDayType`).
void offerUndoDelete(
  BuildContext context,
  WidgetRef ref,
  List<(String, String)> deleted,
  String message,
) => _offerRestore(
  ScaffoldMessenger.of(context),
  ref.read(repositoryProvider),
  deleted,
  message,
  context.l10n.undo,
);

void _offerRestore(
  ScaffoldMessengerState messenger,
  SyncedRepository repo,
  List<(String, String)> rows,
  String message,
  String undo,
) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        // With an action Flutter would keep it until tapped.
        persist: false,
        action: SnackBarAction(
          label: undo,
          onPressed: () async {
            for (final (table, id) in rows) {
              await repo.write(table, id, const {'deleted': false});
            }
          },
        ),
      ),
    );
}

/// Shows [message] with an undo that deletes the rows just [created].
void offerUndoCreate(
  BuildContext context,
  WidgetRef ref,
  List<(String, String)> created,
  String message,
) {
  final repo = ref.read(repositoryProvider);
  final l = context.l10n;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
        // With an action Flutter would keep it until tapped.
        persist: false,
        action: SnackBarAction(
          label: l.undo,
          onPressed: () async {
            for (final (table, id) in created) {
              await repo.delete(table, id);
            }
          },
        ),
      ),
    );
}
