import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message ?? l.deleted),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: l.undo,
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
