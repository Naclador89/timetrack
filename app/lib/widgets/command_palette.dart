import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../app/format.dart';
import '../app/providers.dart';
import '../app/theme.dart';
import '../features/projects/project_time_dialog.dart';
import '../sync/sync_controller.dart';
import 'quick_entry_sheet.dart';

/// Opens the command palette with Ctrl+K (or ⌘K) anywhere below it.
class CommandPaletteShortcut extends StatelessWidget {
  /// Wraps [child].
  const CommandPaletteShortcut({super.key, required this.child});

  /// The app content.
  final Widget child;

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
          showCommandPalette(context),
      const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
          showCommandPalette(context),
    },
    child: Focus(autofocus: true, child: child),
  );
}

/// One search field for actions, screens and projects (desktop: Ctrl+K,
/// ↑↓, Enter). Choosing a project starts it.
Future<void> showCommandPalette(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => _Palette(router: GoRouter.of(context), host: context),
);

/// [run] is awaited while the palette is still open when [stay] is set
/// (it may ask something and needs the palette's providers), else it runs
/// after the palette closed (navigation).
typedef _Command = ({
  IconData icon,
  String label,
  Future<void> Function() run,
  Color? color,
  bool stay,
});

class _Palette extends ConsumerStatefulWidget {
  const _Palette({required this.router, required this.host});

  final GoRouter router;
  final BuildContext host;

  @override
  ConsumerState<_Palette> createState() => _PaletteState();
}

class _PaletteState extends ConsumerState<_Palette> {
  final _query = TextEditingController();
  int _selected = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<_Command> _commands() {
    final l = context.l10n;
    final state = ref.read(trackerStateProvider);
    final tracker = ref.read(trackerProvider);
    final today = ref.read(todayProvider);
    final host = widget.host;
    void go(String route) => widget.router.go(route);
    final scheme = Theme.of(context).colorScheme;
    final actions = <_Command>[
      if (!state.clockedIn)
        (
          icon: Icons.play_arrow_rounded,
          label: l.clockIn,
          run: () => tracker.clockIn(
            location: lastLocation(ref.read(rowsProvider).value ?? const []),
          ),
          color: null,
          stay: false,
        )
      else ...[
        (
          icon: Icons.stop_rounded,
          label: l.clockOut,
          run: () => withSummaryPrompt(host, ref, tracker.clockOut),
          color: null,
          stay: true,
        ),
        (
          icon: state.onBreak ? Icons.play_arrow : Icons.coffee_outlined,
          label: state.onBreak ? l.endBreak : l.startBreak,
          run: state.onBreak
              ? tracker.endBreak
              : () => withSummaryPrompt(host, ref, tracker.startBreak),
          color: null,
          stay: true,
        ),
      ],
      (
        icon: Icons.bolt,
        label: l.quickEntry,
        run: () async => showQuickEntrySheet(host, today),
        color: null,
        stay: false,
      ),
      (
        icon: Icons.today,
        label: l.navToday,
        run: () async => go('/today'),
        color: null,
        stay: false,
      ),
      (
        icon: Icons.edit_calendar_outlined,
        label: l.editDay,
        run: () async => go('/today/day/$today'),
        color: null,
        stay: false,
      ),
      (
        icon: Icons.calendar_month,
        label: l.navCalendar,
        run: () async => go('/calendar'),
        color: null,
        stay: false,
      ),
      (
        icon: Icons.beach_access_outlined,
        label: l.absences,
        run: () async => go('/calendar/absences'),
        color: null,
        stay: false,
      ),
      (
        icon: Icons.luggage_outlined,
        label: l.trips,
        run: () async => go('/calendar/trips'),
        color: null,
        stay: false,
      ),
      (
        icon: Icons.work,
        label: l.navProjects,
        run: () async => go('/projects'),
        color: null,
        stay: false,
      ),
      (
        icon: Icons.assessment,
        label: l.navReports,
        run: () async => go('/reports'),
        color: null,
        stay: false,
      ),
      (
        icon: Icons.settings_outlined,
        label: l.navSettings,
        run: () async => widget.router.push('/settings'),
        color: null,
        stay: false,
      ),
      if (ref.read(syncControllerProvider).phase != SyncPhase.notConfigured)
        (
          icon: Icons.sync,
          label: l.syncNow,
          run: ref.read(syncControllerProvider.notifier).syncNow,
          color: null,
          stay: false,
        ),
    ];
    final q = _query.text.trim().toLowerCase();
    final matching = q.isEmpty
        ? actions
        : actions.where((a) => a.label.toLowerCase().contains(q)).toList();
    final projects = q.isEmpty
        ? const <ProjectMatch>[]
        : searchProjects(
            _query.text,
            ref.read(projectsProvider),
            usage: ref.read(projectUsageProvider),
          ).take(6);
    return [
      ...matching,
      for (final m in projects)
        (
          icon: Icons.play_circle_outline,
          label: l.startProjectNamed(
            [
              m.project.name,
              if (m.project.projectNumber.isNotEmpty) m.project.projectNumber,
            ].join(' · '),
          ),
          run: () => withSummaryPrompt(
            host,
            ref,
            () => tracker.startProject(m.project.id, location: state.location),
          ),
          color: scheme.projectColor(m.project.id),
          stay: true,
        ),
    ];
  }

  Future<void> _run(_Command c) async {
    if (c.stay) {
      await c.run();
      if (mounted) Navigator.pop(context);
    } else {
      Navigator.pop(context);
      await c.run();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final commands = _commands();
    final selected = commands.isEmpty
        ? -1
        : _selected.clamp(0, commands.length - 1);
    return Dialog(
      alignment: const Alignment(0, -0.6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                      setState(() => _selected = selected + 1),
                  const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                      setState(
                        () => _selected = selected > 0 ? selected - 1 : 0,
                      ),
                },
                child: TextField(
                  controller: _query,
                  autofocus: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l.commandPaletteHint,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                  onChanged: (_) => setState(() => _selected = 0),
                  onSubmitted: (_) {
                    if (selected >= 0) _run(commands[selected]);
                  },
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  for (var i = 0; i < commands.length; i++)
                    ListTile(
                      selected: i == selected,
                      leading: Icon(commands[i].icon, color: commands[i].color),
                      title: Text(commands[i].label),
                      onTap: () => _run(commands[i]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
