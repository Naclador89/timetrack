import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/undo.dart';
import 'project_picker.dart';

/// Books or edits project time (data-model §4) in a bottom sheet (user
/// request 2026-11-08): search the project as you type (name, project and
/// order number, client), the duration in hours on a 15-minute grid, an
/// optional start time, and a comment on what was done.
///
/// Pass [entry] or [duration] to edit one. [startMinutes] (local minutes)
/// and [durationMinutes] prefill a new booking, e.g. a gap in the timeline.
Future<void> showProjectTimeDialog(
  BuildContext context, {
  required LocalDate date,
  ProjectEntry? entry,
  ProjectDuration? duration,
  int? startMinutes,
  int? durationMinutes,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (_) => _BookingSheet(
    date: date,
    entry: entry,
    duration: duration,
    startMinutes: startMinutes,
    durationMinutes: durationMinutes,
  ),
);

class _BookingSheet extends ConsumerStatefulWidget {
  const _BookingSheet({
    required this.date,
    this.entry,
    this.duration,
    this.startMinutes,
    this.durationMinutes,
  });

  final LocalDate date;
  final ProjectEntry? entry;
  final ProjectDuration? duration;
  final int? startMinutes;
  final int? durationMinutes;

  @override
  ConsumerState<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends ConsumerState<_BookingSheet> {
  late String? _projectId =
      widget.entry?.projectId ?? widget.duration?.projectId;
  late LocalDate _date = widget.duration?.date ?? widget.date;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  late final _note = TextEditingController(
    text: widget.entry?.note ?? widget.duration?.note ?? '',
  );
  int _minutes = 60;
  late bool _withTime = widget.entry != null || widget.startMinutes != null;
  int _start = 8 * 60;
  int _highlighted = 0;
  String? _error;

  /// A running timer: only project and comment can change here.
  bool get _running => widget.entry != null && widget.entry!.end == null;

  bool get _isNew => widget.entry == null && widget.duration == null;

  @override
  void initState() {
    super.initState();
    final zone = ref.read(zoneProvider);
    final e = widget.entry;
    if (e != null) {
      final local = zone.toLocal(e.start);
      _start = local.hour * 60 + local.minute;
      _date = zone.dateOf(e.start);
      if (e.end != null) _minutes = e.end!.difference(e.start).inMinutes;
    } else if (widget.duration != null) {
      _minutes = widget.duration!.minutes;
    } else {
      // Existing values stay exact; new ones start on the grid.
      _minutes = widget.durationMinutes ?? 60;
      _start = widget.startMinutes ?? _start;
    }
    _search.addListener(() => setState(() => _highlighted = 0));
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _note.dispose();
    super.dispose();
  }

  List<ProjectMatch> _results() {
    final all = searchProjects(
      _search.text,
      ref.watch(projectsProvider),
      usage: ref.watch(projectUsageProvider),
    );
    return all.take(_search.text.trim().isEmpty ? 5 : 6).toList();
  }

  void _pick(String id) {
    setState(() {
      _projectId = id;
      _search.clear();
      _error = null;
    });
    _searchFocus.unfocus();
  }

  Future<void> _create() async {
    final id = await showProjectEditor(
      context,
      ref,
      initialName: _search.text.trim(),
    );
    if (id != null) _pick(id);
  }

  void _setMinutes(int m) => setState(() => _minutes = m.clamp(15, 24 * 60));

  Future<void> _typeDuration() async {
    final l = context.l10n;
    final text = await showTextPrompt(
      context,
      title: l.duration,
      okLabel: l.save,
      cancelLabel: l.cancel,
      initial: formatMinutes(_minutes),
      hint: '1,5 · 1:30',
    );
    final v = text == null ? null : parseHours(text);
    if (v != null && v > 0) _setMinutes(snapToQuarter(v));
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
    } else if (_withTime) {
      final start = ref
          .read(zoneProvider)
          .instantAt(_date, _start ~/ 60, _start % 60);
      await repo.write('project_entries', id, {
        'project_id': _projectId,
        'start_utc': isoMinute(start),
        'end_utc': isoMinute(start.add(Duration(minutes: _minutes))),
        'date': null,
        'duration_min': null,
        'note': note,
        if (_isNew) 'source': 'manual',
      });
    } else {
      await repo.write('project_entries', id, {
        'project_id': _projectId,
        'date': '$_date',
        'duration_min': _minutes,
        // Clearing the span fields turns a former time span into a duration.
        'start_utc': null,
        'end_utc': null,
        'note': note,
        if (_isNew) 'source': 'manual',
      });
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final project = _projectId == null
        ? null
        : ref.watch(projectByIdProvider)[_projectId];
    final day = ref.watch(ledgerProvider).day(_date);
    final rest = day.isTripDay || day.unassigned < 15
        ? null
        : snapToQuarter(day.unassigned);
    final notes = _projectId == null
        ? const <String>[]
        : recentNotes(
            ref.watch(ledgerDataProvider),
            _projectId!,
          ).where((n) => n != _note.text.trim()).toList();
    final existing = widget.entry?.id ?? widget.duration?.id;
    String hm(int m) =>
        '${(m ~/ 60 % 24).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

    // Project: chosen one as a tile, else the search with its dropdown.
    final Widget projectField;
    if (project != null) {
      projectField = Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: Icon(Icons.circle, color: scheme.projectColor(project.id)),
          title: Text(project.name),
          subtitle: Text(
            [
              project.projectNumber,
              project.orderNumber,
              project.client,
            ].where((t) => t.isNotEmpty).join(' · '),
          ),
          trailing: IconButton(
            tooltip: l.changeProject,
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() => _projectId = null);
              _searchFocus.requestFocus();
            },
          ),
        ),
      );
    } else {
      final results = _results();
      final query = _search.text.trim();
      final selected = results.isEmpty
          ? -1
          : _highlighted.clamp(0, results.length - 1);
      projectField = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                  setState(() => _highlighted = selected + 1),
              const SingleActivator(LogicalKeyboardKey.arrowUp): () => setState(
                () => _highlighted = selected > 0 ? selected - 1 : 0,
              ),
            },
            child: TextField(
              controller: _search,
              focusNode: _searchFocus,
              autofocus: _isNew && project == null,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l.projectSearchHint,
                errorText: _error,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
              onSubmitted: (_) {
                if (selected >= 0) _pick(results[selected].project.id);
              },
            ),
          ),
          Card(
            margin: const EdgeInsets.only(top: 4),
            color: scheme.surfaceContainerHigh,
            child: Column(
              children: [
                if (query.isEmpty && results.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l.recentlyUsed,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                  ),
                for (var i = 0; i < results.length; i++)
                  ProjectTile(
                    match: results[i],
                    selected: i == selected && query.isNotEmpty,
                    leading: Icon(
                      Icons.circle,
                      size: 14,
                      color: scheme.projectColor(results[i].project.id),
                    ),
                    onTap: () => _pick(results[i].project.id),
                  ),
                if (query.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: Text(l.createProjectNamed(query)),
                    onTap: _create,
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isNew ? l.bookProjectTime : l.editProjectTime,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                if (!_running)
                  ActionChip(
                    avatar: const Icon(Icons.event_outlined, size: 18),
                    label: Text(context.shortDate(_date)),
                    onPressed: () async {
                      final d = await pickDate(context, _date);
                      if (d != null) setState(() => _date = d);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            projectField,
            if (!_running) ...[
              const SizedBox(height: 20),
              Text(l.duration, style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: '− 0:15',
                    onPressed: _minutes <= 15
                        ? null
                        : () => _setMinutes(snapToQuarter(_minutes) - 15),
                    icon: const Icon(Icons.remove),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _typeDuration,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '${formatMinutes(_minutes)} h',
                          key: const ValueKey('duration'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: '+ 0:15',
                    onPressed: () => _setMinutes(snapToQuarter(_minutes) + 15),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in const [15, 30, 60, 120, 240, 480])
                    ChoiceChip(
                      label: Text(formatMinutes(m)),
                      selected: _minutes == m,
                      onSelected: (_) => _setMinutes(m),
                    ),
                  if (rest != null && _isNew)
                    ActionChip(
                      avatar: const Icon(Icons.hourglass_bottom, size: 18),
                      label: Text(l.restOfDay(formatMinutes(rest))),
                      onPressed: () => _setMinutes(rest),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.withClockTime),
                value: _withTime,
                onChanged: (v) => setState(() => _withTime = v),
              ),
              if (_withTime)
                Row(
                  children: [
                    Text(l.start),
                    const SizedBox(width: 16),
                    DropdownButton<int>(
                      value: _start,
                      menuMaxHeight: 320,
                      items: [
                        // Quarter hours, plus the current value if it is off
                        // the grid (an existing entry).
                        for (final m in {
                          for (var q = 0; q < 24 * 60; q += 15) q,
                          _start,
                        }.toList()..sort())
                          DropdownMenuItem(value: m, child: Text(hm(m))),
                      ],
                      onChanged: (m) => setState(() => _start = m ?? _start),
                    ),
                    const Spacer(),
                    Text(
                      '${l.end} ${hm(_start + _minutes)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              maxLines: 4,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l.whatWasDone,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in notes)
                    ActionChip(
                      avatar: const Icon(Icons.history, size: 18),
                      label: Text(n.length > 40 ? '${n.substring(0, 40)}…' : n),
                      onPressed: () => setState(() => _note.text = n),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                if (existing != null)
                  TextButton.icon(
                    onPressed: () {
                      final done = deleteWithUndo(context, ref, [
                        ('project_entries', existing),
                      ]);
                      Navigator.pop(context);
                      done.ignore();
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l.delete),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: Text(_isNew ? l.book : l.save),
                ),
              ],
            ),
          ],
        ),
      ),
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
