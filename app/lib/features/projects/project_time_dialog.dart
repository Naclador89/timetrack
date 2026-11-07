import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../widgets/dialogs.dart';
import 'project_picker.dart';

/// Records or edits project time (data-model §4): usually a **duration**
/// (H:MM) on a date with a short summary; optionally a start time, which
/// makes it a time span. Pass [entry] or [duration] to edit an existing one.
Future<void> showProjectTimeDialog(
  BuildContext context, {
  required LocalDate date,
  ProjectEntry? entry,
  ProjectDuration? duration,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      _ProjectTimeDialog(date: date, entry: entry, duration: duration),
);

class _ProjectTimeDialog extends ConsumerStatefulWidget {
  const _ProjectTimeDialog({required this.date, this.entry, this.duration});

  final LocalDate date;
  final ProjectEntry? entry;
  final ProjectDuration? duration;

  @override
  ConsumerState<_ProjectTimeDialog> createState() => _ProjectTimeDialogState();
}

class _ProjectTimeDialogState extends ConsumerState<_ProjectTimeDialog> {
  late String? _projectId =
      widget.entry?.projectId ?? widget.duration?.projectId;
  late LocalDate _date = widget.duration?.date ?? widget.date;
  late final _minutes = TextEditingController();
  late final _note = TextEditingController(
    text: widget.entry?.note ?? widget.duration?.note ?? '',
  );
  late bool _withTime = widget.entry != null;
  int _start = 8 * 60;
  String? _error;

  /// A running timer: only project and summary can change here.
  bool get _running => widget.entry != null && widget.entry!.end == null;

  @override
  void initState() {
    super.initState();
    final zone = ref.read(zoneProvider);
    final e = widget.entry;
    if (e != null) {
      final local = zone.toLocal(e.start);
      _start = local.hour * 60 + local.minute;
      _date = zone.dateOf(e.start);
      if (e.end != null) {
        _minutes.text = formatMinutes(e.end!.difference(e.start).inMinutes);
      }
    } else if (widget.duration != null) {
      _minutes.text = formatMinutes(widget.duration!.minutes);
    }
  }

  @override
  void dispose() {
    _minutes.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    if (_projectId == null) {
      setState(() => _error = l.chooseProject);
      return;
    }
    final repo = ref.read(repositoryProvider);
    final id = widget.entry?.id ?? widget.duration?.id ?? repo.newId();
    final note = _note.text.trim();
    if (_running) {
      await repo.write('project_entries', id, {
        'project_id': _projectId,
        'note': note,
      });
    } else {
      final minutes = parseHours(_minutes.text);
      if (minutes == null || minutes <= 0 || minutes > 24 * 60) {
        setState(() => _error = l.invalidValue);
        return;
      }
      if (_withTime) {
        final start = ref
            .read(zoneProvider)
            .instantAt(_date, _start ~/ 60, _start % 60);
        await repo.write('project_entries', id, {
          'project_id': _projectId,
          'start_utc': isoMinute(start),
          'end_utc': isoMinute(start.add(Duration(minutes: minutes))),
          'date': null,
          'duration_min': null,
          'note': note,
          if (widget.entry == null && widget.duration == null)
            'source': 'manual',
        });
      } else {
        await repo.write('project_entries', id, {
          'project_id': _projectId,
          'date': '$_date',
          'duration_min': minutes,
          // Clearing the span fields turns a former time span into a duration.
          'start_utc': null,
          'end_utc': null,
          'note': note,
          if (widget.entry == null && widget.duration == null)
            'source': 'manual',
        });
      }
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final project = _projectId == null
        ? null
        : ref.watch(projectByIdProvider)[_projectId];
    final existing = widget.entry?.id ?? widget.duration?.id;
    return AlertDialog(
      title: Text(l.addProjectTime),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.work_outline),
                title: Text(project?.name ?? l.chooseProject),
                subtitle: project == null || project.orderNumber.isEmpty
                    ? null
                    : Text(project.orderNumber),
                trailing: const Icon(Icons.search),
                onTap: () async {
                  final id = await showProjectPicker(context);
                  if (id != null) setState(() => _projectId = id);
                },
              ),
              if (!_running) ...[
                DateTile(
                  label: l.colDate,
                  value: _date,
                  onChanged: (d) => setState(() => _date = d),
                ),
                TextField(
                  controller: _minutes,
                  autofocus: widget.entry == null && widget.duration == null,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l.durationHours,
                    hintText: '1:30',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.withClockTime),
                  value: _withTime,
                  onChanged: (v) => setState(() => _withTime = v),
                ),
                if (_withTime)
                  TimeTile(
                    label: l.start,
                    minutes: _start,
                    onChanged: (m) => setState(() => _start = m),
                  ),
              ],
              TextField(
                controller: _note,
                maxLines: 3,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l.summary,
                  hintText: l.summaryHint,
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (existing != null && !_running)
          TextButton(
            onPressed: () async {
              if (await confirmDelete(context)) {
                await ref
                    .read(repositoryProvider)
                    .delete('project_entries', existing);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: Text(l.delete),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}

/// Runs [action] (stop, switch, break, clock-out) and, if it ended the running
/// project timer, **always** asks for a short summary of the work
/// (user decision, docs/status.md). The user may skip it.
Future<void> withSummaryPrompt(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action,
) async {
  final before = ref.read(trackerStateProvider).entry;
  await action();
  if (before == null || !context.mounted) return;
  await askSummary(context, ref, before.id);
}

/// Asks for the summary of the project entry [entryId] if it has ended
/// (also for timers stopped from the notification, tile or widget, which
/// queue the entry in `PendingSummaries`). The user may skip it.
Future<void> askSummary(
  BuildContext context,
  WidgetRef ref,
  String entryId,
) async {
  final repo = ref.read(repositoryProvider);
  final after = await repo.get('project_entries', entryId);
  if (after == null ||
      after.isDeleted ||
      after.fields['end_utc'] == null ||
      !context.mounted) {
    return;
  }
  final project = ref.read(projectByIdProvider)[after.fields['project_id']];
  final l = context.l10n;
  final note = await showTextPrompt(
    context,
    title: l.summaryQuestion(project?.name ?? '?'),
    okLabel: l.save,
    cancelLabel: l.skip,
    initial: after.fields['note'] as String? ?? '',
    hint: l.summaryHint,
    maxLines: 3,
  );
  if (note != null) {
    await repo.write('project_entries', entryId, {'note': note});
  }
}
