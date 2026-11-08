import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../app/format.dart';
import '../app/providers.dart';
import 'dialogs.dart';
import 'undo.dart';

/// Faster entry for [date] (calculations.md §17): one line like
/// `8-16:30 p30 bosch 014`, "copy the day before", saved templates, and
/// saving the day as a template.
Future<void> showQuickEntrySheet(BuildContext context, LocalDate date) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _QuickEntrySheet(date: date),
    );

class _QuickEntrySheet extends ConsumerStatefulWidget {
  const _QuickEntrySheet({required this.date});

  final LocalDate date;

  @override
  ConsumerState<_QuickEntrySheet> createState() => _QuickEntrySheetState();
}

class _QuickEntrySheetState extends ConsumerState<_QuickEntrySheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  QuickEntry? get _entry => parseQuickEntry(_text.text);

  Project? _project(QuickEntry? e) {
    if (e == null || e.projectQuery.isEmpty) return null;
    final results = searchProjects(
      e.projectQuery,
      ref.read(projectsProvider),
      usage: ref.read(projectUsageProvider),
    );
    return results.firstOrNull?.project;
  }

  /// Applies [template] to the day, closes the sheet and offers undo.
  Future<void> _apply(DayTemplate template, String message) async {
    final messengerContext = Navigator.of(context).context;
    final created = await applyDayTemplate(
      ref.read(repositoryProvider),
      template,
      widget.date,
      zone: ref.read(zoneProvider),
    );
    if (!mounted) return;
    Navigator.pop(context);
    if (messengerContext.mounted) {
      offerUndoCreate(messengerContext, ref, created, message);
    }
  }

  Future<void> _save() async {
    final e = _entry;
    if (e == null) return;
    final project = _project(e);
    final template = e.toTemplate(projectId: project?.id);
    if (template.isEmpty) return;
    await _apply(template, context.l10n.quickEntrySaved);
  }

  Future<void> _saveAsTemplate() async {
    final l = context.l10n;
    final template = captureDay(
      ref.read(ledgerDataProvider),
      widget.date,
      ref.read(zoneProvider),
    );
    if (template.isEmpty) return;
    final name = await showTextPrompt(
      context,
      title: l.saveAsTemplate,
      okLabel: l.save,
      cancelLabel: l.cancel,
      label: l.templateName,
    );
    if (name == null || name.isEmpty) return;
    final repo = ref.read(repositoryProvider);
    await saveDayTemplate(
      repo,
      DayTemplate(id: repo.newId(), name: name, items: template.items),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final e = _entry;
    final project = _project(e);
    final templates = ref.watch(dayTemplatesProvider);
    final data = ref.watch(ledgerDataProvider);
    final zone = ref.watch(zoneProvider);
    final previous = captureDay(data, widget.date.addDays(-1), zone);
    final thisDay = captureDay(data, widget.date, zone);
    String hm(int m) =>
        '${(m ~/ 60 % 24).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

    final preview = e == null
        ? (_text.text.isEmpty ? null : l.quickEntryInvalid)
        : [
            if (e.hasRange) '${hm(e.start!)}–${hm(e.end!)}',
            if (e.hasRange)
              context.locationName(e.location ?? WorkLocation.office),
            if (e.breakMinutes > 0)
              '${l.breaks} ${formatMinutes(e.breakMinutes)}',
            if (e.duration != null) formatMinutes(e.duration!),
            if (project != null)
              project.name
            else if (e.projectQuery.isNotEmpty)
              l.quickEntryNoProject(e.projectQuery),
            if (e.note.isNotEmpty) '„${e.note}“',
          ].join(' · ');

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${l.quickEntry} · ${context.shortDate(widget.date)}',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _text,
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.bolt),
                  hintText: '8-16:30 p30 Projekt: Notiz',
                  helperText: preview ?? l.quickEntryHelp,
                  helperMaxLines: 3,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  suffixIcon: IconButton(
                    tooltip: l.save,
                    icon: const Icon(Icons.check),
                    onPressed: e == null ? null : _save,
                  ),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!previous.isEmpty)
                    ActionChip(
                      avatar: const Icon(Icons.content_copy, size: 18),
                      label: Text(l.copyPreviousDay),
                      onPressed: () => _apply(previous, l.copiedPreviousDay),
                    ),
                  for (final t in templates)
                    InputChip(
                      avatar: const Icon(Icons.bookmark_outline, size: 18),
                      label: Text(t.name),
                      onPressed: () => _apply(t, l.templateApplied(t.name)),
                      onDeleted: () => deleteWithUndo(context, ref, [
                        ('day_templates', t.id),
                      ]),
                    ),
                  if (!thisDay.isEmpty)
                    ActionChip(
                      avatar: const Icon(Icons.bookmark_add_outlined, size: 18),
                      label: Text(l.saveAsTemplate),
                      onPressed: _saveAsTemplate,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
