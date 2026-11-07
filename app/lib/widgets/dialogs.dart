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
    this.leading,
  });

  /// Optional leading icon; with it, the tile uses normal list padding
  /// (for settings lists) instead of none (for dialogs).
  final Widget? leading;

  /// Field label.
  final String label;

  /// Current date.
  final LocalDate value;

  /// Called with the picked date.
  final ValueChanged<LocalDate> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: leading == null ? EdgeInsets.zero : null,
    leading: leading,
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

/// Asks for one line (or a few lines) of text; returns it trimmed, or `null`
/// if the user chose [cancelLabel]. The dialog owns its controller, so it
/// stays valid during the closing animation.
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  required String okLabel,
  required String cancelLabel,
  String initial = '',
  String? label,
  String? hint,
  int maxLines = 1,
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextPrompt(
    title: title,
    okLabel: okLabel,
    cancelLabel: cancelLabel,
    initial: initial,
    label: label,
    hint: hint,
    maxLines: maxLines,
  ),
);

class _TextPrompt extends StatefulWidget {
  const _TextPrompt({
    required this.title,
    required this.okLabel,
    required this.cancelLabel,
    required this.initial,
    required this.label,
    required this.hint,
    required this.maxLines,
  });

  final String title;
  final String okLabel;
  final String cancelLabel;
  final String initial;
  final String? label;
  final String? hint;
  final int maxLines;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _ok() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLines: widget.maxLines,
      minLines: 1,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
      ),
      onSubmitted: widget.maxLines == 1 ? (_) => _ok() : null,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(widget.cancelLabel),
      ),
      FilledButton(onPressed: _ok, child: Text(widget.okLabel)),
    ],
  );
}
