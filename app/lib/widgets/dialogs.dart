import 'package:flutter/material.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../app/format.dart';

/// Picks a date; `null` if cancelled.
Future<LocalDate?> pickDate(BuildContext context, LocalDate initial) async {
  final d = await showDatePicker(
    context: context,
    initialDate: DateTime(initial.year, initial.month, initial.day),
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
  return d == null ? null : LocalDate(d.year, d.month, d.day);
}

/// Picks a local time of day; returns minutes since midnight, `null` if cancelled.
Future<int?> pickTime(BuildContext context, int initialMinutes) async {
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(
      hour: initialMinutes ~/ 60 % 24,
      minute: initialMinutes % 60,
    ),
  );
  return t == null ? null : t.hour * 60 + t.minute;
}

/// Asks before deleting; `true` if confirmed.
Future<bool> confirmDelete(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(c.l10n.deleteQuestion),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(c.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(c.l10n.delete),
          ),
        ],
      ),
    ) ??
    false;

/// A list tile that shows a date and opens a date picker.
class DateTile extends StatelessWidget {
  /// Creates the tile.
  const DateTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  /// Field label.
  final String label;

  /// Current date.
  final LocalDate value;

  /// Called with the picked date.
  final ValueChanged<LocalDate> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(context.date(value)),
    trailing: const Icon(Icons.calendar_today_outlined),
    onTap: () async {
      final d = await pickDate(context, value);
      if (d != null) onChanged(d);
    },
  );
}

/// A list tile that shows a local time and opens a time picker.
class TimeTile extends StatelessWidget {
  /// Creates the tile. [minutes] is minutes since local midnight, `null` = open.
  const TimeTile({
    super.key,
    required this.label,
    required this.minutes,
    required this.onChanged,
    this.onClear,
  });

  /// Field label.
  final String label;

  /// Minutes since midnight, or `null` for "still running".
  final int? minutes;

  /// Called with the picked time.
  final ValueChanged<int> onChanged;

  /// If given, offers to clear the time (= running).
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final m = minutes;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(
        m == null
            ? context.l10n.running
            : '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onClear != null && m != null)
            IconButton(icon: const Icon(Icons.clear), onPressed: onClear),
          const Icon(Icons.schedule),
        ],
      ),
      onTap: () async {
        final t = await pickTime(context, m ?? 8 * 60);
        if (t != null) onChanged(t);
      },
    );
  }
}
