import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';

/// Opens the project search (spec: project-search.md) and returns the chosen
/// project id, or `null` if cancelled. Enter picks the first result.
Future<String?> showProjectPicker(BuildContext context) => showDialog<String>(
  context: context,
  builder: (_) => const _ProjectPickerDialog(),
);

class _ProjectPickerDialog extends ConsumerStatefulWidget {
  const _ProjectPickerDialog();

  @override
  ConsumerState<_ProjectPickerDialog> createState() => _PickerState();
}

class _PickerState extends ConsumerState<_ProjectPickerDialog> {
  final _query = TextEditingController();
  bool _archived = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final results = searchProjects(
      _query.text,
      ref.watch(projectsProvider),
      usage: ref.watch(projectUsageProvider),
      includeArchived: _archived,
    );
    return AlertDialog(
      title: Text(l.chooseProject),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 480,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l.searchProjects,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (results.isNotEmpty) {
                  Navigator.pop(context, results.first.project.id);
                }
              },
            ),
            CheckboxListTile(
              dense: true,
              value: _archived,
              title: Text(l.showArchived),
              onChanged: (v) => setState(() => _archived = v ?? false),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final m in results)
                    ProjectTile(
                      match: m,
                      onTap: () => Navigator.pop(context, m.project.id),
                    ),
                  if (_query.text.trim().isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.add),
                      title: Text(l.createProjectNamed(_query.text.trim())),
                      onTap: () async {
                        final id = await showProjectEditor(
                          context,
                          ref,
                          initialName: _query.text.trim(),
                        );
                        if (id != null && context.mounted) {
                          Navigator.pop(context, id);
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
      ],
    );
  }
}

/// A project in a list, with the matched parts of a search highlighted.
class ProjectTile extends StatelessWidget {
  /// Creates the tile.
  const ProjectTile({
    super.key,
    required this.match,
    this.onTap,
    this.trailing,
    this.leading,
    this.selected = false,
  });

  /// Replaces the favourite/work icon.
  final Widget? leading;

  /// Highlighted (keyboard selection).
  final bool selected;

  /// The search result (use `ProjectMatch(project, 0, {})` without a search).
  final ProjectMatch match;

  /// Tap handler.
  final VoidCallback? onTap;

  /// Optional trailing widget.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = match.project;
    final style = DefaultTextStyle.of(context).style;
    final strong = TextStyle(
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.primary,
    );
    final details = [
      (p.projectNumber, ProjectField.projectNumber),
      (p.orderNumber, ProjectField.orderNumber),
      (p.client, ProjectField.client),
    ].where((d) => d.$1.isNotEmpty).toList();
    return ListTile(
      onTap: onTap,
      selected: selected,
      leading: leading ?? Icon(p.favorite ? Icons.star : Icons.work_outline),
      title: Text.rich(
        _highlight(p.name, match.highlights[ProjectField.name], strong),
        style: p.archived
            ? style.copyWith(color: Theme.of(context).disabledColor)
            : null,
      ),
      subtitle: details.isEmpty
          ? null
          : Text.rich(
              TextSpan(
                children: [
                  for (var i = 0; i < details.length; i++) ...[
                    if (i > 0) const TextSpan(text: ' · '),
                    _highlight(
                      details[i].$1,
                      match.highlights[details[i].$2],
                      strong,
                    ),
                  ],
                ],
              ),
            ),
      trailing: trailing,
    );
  }

  static TextSpan _highlight(
    String text,
    List<(int, int)>? ranges,
    TextStyle strong,
  ) {
    if (ranges == null || ranges.isEmpty) return TextSpan(text: text);
    final spans = <TextSpan>[];
    var at = 0;
    for (final (s, e) in ranges) {
      if (s > at) spans.add(TextSpan(text: text.substring(at, s)));
      spans.add(TextSpan(text: text.substring(s, e), style: strong));
      at = e;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return TextSpan(children: spans);
  }
}

/// Opens the project editor; creates a project if [project] is `null`.
/// Returns the project id after saving, `null` if cancelled.
Future<String?> showProjectEditor(
  BuildContext context,
  WidgetRef ref, {
  Project? project,
  String initialName = '',
}) => showDialog<String>(
  context: context,
  builder: (_) => _ProjectEditor(project: project, initialName: initialName),
);

class _ProjectEditor extends ConsumerStatefulWidget {
  const _ProjectEditor({this.project, this.initialName = ''});

  final Project? project;
  final String initialName;

  @override
  ConsumerState<_ProjectEditor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_ProjectEditor> {
  late final _name = TextEditingController(
    text: widget.project?.name ?? widget.initialName,
  );
  late final _number = TextEditingController(
    text: widget.project?.projectNumber,
  );
  late final _order = TextEditingController(text: widget.project?.orderNumber);
  late final _client = TextEditingController(text: widget.project?.client);
  late bool _favorite = widget.project?.favorite ?? false;
  late bool _archived = widget.project?.archived ?? false;
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    for (final c in [_name, _number, _order, _client]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = ref.read(repositoryProvider);
    final id = widget.project?.id ?? repo.newId();
    await repo.write('projects', id, {
      'name': _name.text.trim(),
      'project_number': _number.text.trim(),
      'order_number': _order.text.trim(),
      'client': _client.text.trim(),
      'favorite': _favorite,
      'archived': _archived,
    });
    if (mounted) Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.project == null ? l.newProject : l.editProject),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  decoration: InputDecoration(labelText: l.projectName),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? l.required : null,
                ),
                TextFormField(
                  controller: _number,
                  decoration: InputDecoration(labelText: l.projectNumber),
                ),
                TextFormField(
                  controller: _order,
                  decoration: InputDecoration(labelText: l.orderNumber),
                ),
                TextFormField(
                  controller: _client,
                  decoration: InputDecoration(labelText: l.client),
                  onFieldSubmitted: (_) => _save(),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.favorite),
                  value: _favorite,
                  onChanged: (v) => setState(() => _favorite = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.archived),
                  value: _archived,
                  onChanged: (v) => setState(() => _archived = v),
                ),
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
        CallbackShortcuts(
          bindings: {const SingleActivator(LogicalKeyboardKey.enter): _save},
          child: FilledButton(onPressed: _save, child: Text(l.save)),
        ),
      ],
    );
  }
}
