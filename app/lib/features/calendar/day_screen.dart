import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/notices.dart';
import '../projects/project_picker.dart';
import '../projects/project_time_dialog.dart';
import 'absences_screen.dart';

/// Everything recorded on one day, editable: sessions, breaks, project
/// entries and absences.
class DayScreen extends ConsumerWidget {
  /// Creates the screen for [date].
  const DayScreen({super.key, required this.date});

  /// The day being edited.
  final LocalDate date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final zone = ref.watch(zoneProvider);
    final ledger = ref.watch(ledgerProvider);
    final data = ref.watch(ledgerDataProvider);
    final projects = ref.watch(projectByIdProvider);
    final holiday = ref.watch(holidaysProvider).holidayOn(date);
    final day = ledger.day(date);
    final window = zone.daySpan(date);
    final now = ledger.nowMinute;
    bool onDay(Span s) => s.start < window.end && s.end > window.start;
    List<T> sorted<T>(Iterable<T> items, DateTime Function(T) start) =>
        items.toList()..sort((a, b) => start(a).compareTo(start(b)));
    final sessions = sorted(
      data.sessions.where((s) => onDay(s.spanAt(now))),
      (s) => s.start,
    );
    final breaks = sorted(
      data.breaks.where((b) => onDay(b.spanAt(now))),
      (b) => b.start,
    );
    final entries = sorted(
      data.entries.where((e) => onDay(e.spanAt(now))),
      (e) => e.start,
    );
    final notices = reviewItems(ledger, from: date, to: date);

    String range(DateTime s, DateTime? e) =>
        '${context.time(s, zone)} – ${e == null ? l.running : context.time(e, zone)}';

    Widget section(String title, VoidCallback onAdd, List<Widget> tiles) =>
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                title: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                trailing: IconButton(
                  tooltip: l.add,
                  icon: const Icon(Icons.add),
                  onPressed: onAdd,
                ),
              ),
              ...tiles,
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.longDate(date)),
        actions: [
          IconButton(
            tooltip: l.addAbsence,
            icon: const Icon(Icons.beach_access_outlined),
            onPressed: () =>
                showAbsenceDialog(context, ref, initial: date, singleDay: true),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              title: Text(
                '${l.worked} ${formatMinutes(day.work.worked)} · ${l.target} ${formatMinutes(day.target)}',
              ),
              subtitle: Text(
                [
                  if (holiday != null) holiday.name,
                  if (day.isTripDay) l.tripDay,
                  if (day.credited != day.breaks.effectiveWorked)
                    '${l.credited} ${formatMinutes(day.credited)}',
                  '${l.difference} ${formatMinutes(day.delta)}',
                  '${l.unassigned} ${formatMinutes(day.work.unassigned)}',
                ].join(' · '),
              ),
            ),
          ),
          NoticesCard(items: notices),
          section(
            l.sessions,
            () => _editInterval(context, ref, 'work_sessions', null),
            [
              for (final s in sessions)
                ListTile(
                  leading: Icon(locationIcon(s.location)),
                  title: Text(range(s.start, s.end)),
                  subtitle: Text(context.locationName(s.location)),
                  onTap: () => _editInterval(
                    context,
                    ref,
                    'work_sessions',
                    s.id,
                    start: s.start,
                    end: s.end,
                    location: s.location,
                  ),
                ),
            ],
          ),
          section(l.breaks, () => _editInterval(context, ref, 'breaks', null), [
            for (final b in breaks)
              ListTile(
                leading: const Icon(Icons.coffee_outlined),
                title: Text(range(b.start, b.end)),
                onTap: () => _editInterval(
                  context,
                  ref,
                  'breaks',
                  b.id,
                  start: b.start,
                  end: b.end,
                ),
              ),
          ]),
          section(
            l.projectEntries,
            () => showProjectTimeDialog(context, date: date),
            [
              for (final p in data.durations.where((x) => x.date == date))
                ListTile(
                  leading: const Icon(Icons.timelapse),
                  title: Text(
                    '${formatMinutes(p.minutes)} · ${projects[p.projectId]?.name ?? '?'}',
                  ),
                  subtitle: p.note.isEmpty ? null : Text(p.note),
                  onTap: () =>
                      showProjectTimeDialog(context, date: date, duration: p),
                ),
              for (final e in entries)
                ListTile(
                  leading: const Icon(Icons.work_outline),
                  title: Text(
                    '${range(e.start, e.end)} · ${projects[e.projectId]?.name ?? '?'}',
                  ),
                  subtitle: e.note.isEmpty ? null : Text(e.note),
                  onTap: () =>
                      showProjectTimeDialog(context, date: date, entry: e),
                ),
            ],
          ),
          if (day.absences.isNotEmpty)
            Card(
              child: Column(
                children: [
                  for (final a in day.absences)
                    ListTile(
                      leading: const Icon(Icons.beach_access_outlined),
                      title: Text(context.absenceName(a.kind)),
                      subtitle: a.fraction < 1 ? Text(l.halfDay) : null,
                      trailing: IconButton(
                        tooltip: l.delete,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          if (await confirmDelete(context)) {
                            await ref
                                .read(repositoryProvider)
                                .delete('absences', a.id);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _editInterval(
    BuildContext context,
    WidgetRef ref,
    String table,
    String? id, {
    DateTime? start,
    DateTime? end,
    WorkLocation? location,
    String? projectId,
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
    ),
  );
}

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
  });

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
        ? (isBreak ? 12 * 60 : 8 * 60)
        : local(widget.start!);
    _end = widget.id == null
        ? (isBreak ? 12 * 60 + 30 : 16 * 60)
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
      if (widget.table == 'work_sessions') 'location': _location.wireName,
      if (widget.table == 'project_entries') 'project_id': _projectId,
      if (widget.id == null) 'source': 'manual',
    });
    if (mounted) Navigator.pop(context);
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
            if (widget.table == 'work_sessions')
              DropdownButtonFormField<WorkLocation>(
                initialValue: _location,
                decoration: InputDecoration(labelText: l.location),
                items: [
                  for (final loc in WorkLocation.values)
                    DropdownMenuItem(
                      value: loc,
                      child: Text(context.locationName(loc)),
                    ),
                ],
                onChanged: (v) => setState(() => _location = v ?? _location),
              ),
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
              if (await confirmDelete(context)) {
                await ref
                    .read(repositoryProvider)
                    .delete(widget.table, widget.id!);
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
