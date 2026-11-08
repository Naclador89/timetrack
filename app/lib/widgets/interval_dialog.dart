import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../app/format.dart';
import '../app/providers.dart';
import '../features/projects/project_picker.dart';
import 'dialogs.dart';
import 'undo.dart';

/// Opens the editor for one session, break or project entry on [date].
/// [id] `null` creates a row; [initialStart]/[initialEnd] (local minutes)
/// prefill a new one, e.g. a suggested break.
Future<void> showIntervalDialog(
  BuildContext context, {
  required LocalDate date,
  required String table,
  String? id,
  DateTime? start,
  DateTime? end,
  WorkLocation? location,
  String? projectId,
  int? initialStart,
  int? initialEnd,
}) => showDialog<void>(
  context: context,
  builder: (_) => _IntervalDialog(
    date: date,
    table: table,
    id: id,
    start: start,
    end: end,
    location: location,
    projectId: projectId,
    initialStart: initialStart,
    initialEnd: initialEnd,
  ),
);

/// Edits one session, break or project entry on [date].
class _IntervalDialog extends ConsumerStatefulWidget {
  const _IntervalDialog({
    required this.date,
    required this.table,
    this.id,
    this.start,
    this.end,
    this.location,
    this.projectId,
    this.initialStart,
    this.initialEnd,
  });

  final int? initialStart;
  final int? initialEnd;
  final LocalDate date;
  final String table;
  final String? id;
  final DateTime? start;
  final DateTime? end;
  final WorkLocation? location;
  final String? projectId;

  @override
  ConsumerState<_IntervalDialog> createState() => _IntervalDialogState();
}

class _IntervalDialogState extends ConsumerState<_IntervalDialog> {
  late int _start;
  int? _end;
  late WorkLocation _location = widget.location ?? WorkLocation.office;
  late String? _projectId = widget.projectId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final zone = ref.read(zoneProvider);
    int local(DateTime t) {
      final l = zone.toLocal(t);
      return l.hour * 60 + l.minute;
    }

    final isBreak = widget.table == 'breaks';
    _start = widget.start == null
        ? (widget.initialStart ?? (isBreak ? 12 * 60 : 8 * 60))
        : local(widget.start!);
    _end = widget.id == null
        ? (widget.initialEnd ?? (isBreak ? 12 * 60 + 30 : 16 * 60))
        : widget.end == null
        ? null
        : local(widget.end!);
  }

  Future<void> _save() async {
    final l = context.l10n;
    if (widget.table == 'project_entries' && _projectId == null) {
      setState(() => _error = l.required);
      return;
    }
    final zone = ref.read(zoneProvider);
    final startAt = zone.instantAt(widget.date, _start ~/ 60, _start % 60);
    DateTime? endAt;
    if (_end != null) {
      // An end at or before the start means the next day (night work).
      final endDate = _end! <= _start ? widget.date.addDays(1) : widget.date;
      endAt = zone.instantAt(endDate, _end! ~/ 60, _end! % 60);
      if (!endAt.isAfter(startAt)) {
        setState(() => _error = l.endBeforeStart);
        return;
      }
    }
    final repo = ref.read(repositoryProvider);
    await repo.write(widget.table, widget.id ?? repo.newId(), {
      'start_utc': isoMinute(startAt),
      'end_utc': endAt == null ? null : isoMinute(endAt),
      if (widget.table == 'work_sessions')
        'location': _effectiveLocation.wireName,
      if (widget.table == 'project_entries') 'project_id': _projectId,
      if (widget.id == null) 'source': 'manual',
    });
    if (mounted) Navigator.pop(context);
  }

  /// The locations the day type allows (calculations §15): travel and
  /// on-site on business trips, office or home office otherwise.
  List<WorkLocation> get _locations {
    final type = ref.watch(ledgerProvider).day(widget.date).type;
    final allowed = type?.locations ?? const <WorkLocation>[];
    return allowed.isEmpty
        ? const [WorkLocation.office, WorkLocation.home]
        : allowed;
  }

  WorkLocation get _effectiveLocation {
    final allowed = _locations;
    if (allowed.contains(_location)) return _location;
    return allowed.contains(WorkLocation.onSite)
        ? WorkLocation.onSite
        : allowed.first;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final title = switch (widget.table) {
      'work_sessions' => l.sessions,
      'breaks' => l.breaks,
      _ => l.projectEntries,
    };
    final project = _projectId == null
        ? null
        : ref.watch(projectByIdProvider)[_projectId];
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TimeTile(
              label: l.start,
              minutes: _start,
              onChanged: (v) => setState(() => _start = v),
            ),
            TimeTile(
              label: l.end,
              minutes: _end,
              onChanged: (v) => setState(() => _end = v),
              onClear: () => setState(() => _end = null),
            ),
            if (widget.table == 'work_sessions' && _locations.length > 1) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final loc in _locations)
                      ChoiceChip(
                        showCheckmark: false,
                        avatar: Icon(locationIcon(loc), size: 18),
                        label: Text(context.locationName(loc)),
                        selected: _effectiveLocation == loc,
                        onSelected: (_) => setState(() => _location = loc),
                      ),
                  ],
                ),
              ),
            ],
            if (widget.table == 'project_entries')
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(project?.name ?? l.chooseProject),
                trailing: const Icon(Icons.search),
                onTap: () async {
                  final id = await showProjectPicker(context);
                  if (id != null) setState(() => _projectId = id);
                },
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (widget.id != null)
          TextButton(
            onPressed: () async {
              // Starts the delete (it reads the messenger right away),
              // then closes the dialog.
              final done = deleteWithUndo(context, ref, [
                (widget.table, widget.id!),
              ]);
              Navigator.pop(context);
              await done;
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
