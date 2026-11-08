import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../widgets/charts.dart';
import '../../widgets/export.dart';
import '../calendar/week_screen.dart' show isoWeekNumber;
import 'project_picker.dart';
import 'project_time_dialog.dart';

/// One project: its booked time this week, month, year and in total, the
/// budget, recent weeks and every day with what was done
/// (calculations §3.1).
class ProjectScreen extends ConsumerStatefulWidget {
  /// Creates the page of project [id].
  const ProjectScreen({super.key, required this.id});

  /// The project's row id.
  final String id;

  @override
  ConsumerState<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends ConsumerState<ProjectScreen> {
  bool _allDays = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final project = ref.watch(projectByIdProvider)[widget.id];
    if (project == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.noProjects)),
      );
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = ref.watch(todayProvider);
    final days = ref.watch(projectHistoryProvider(widget.id));
    final running = ref.watch(trackerStateProvider).projectId == widget.id;
    int sum(bool Function(LocalDate) where) =>
        days.where((d) => where(d.date)).fold(0, (a, d) => a + d.minutes);
    final total = sum((_) => true);
    final details = [
      project.projectNumber,
      project.orderNumber,
      project.client,
    ].where((s) => s.isNotEmpty).join(' · ');
    final repo = ref.read(repositoryProvider);

    Widget figure(String label, int minutes) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        Text(formatMinutes(minutes), style: theme.textTheme.titleLarge),
      ],
    );

    final newest = days.reversed.toList();
    final shown = _allDays ? newest : newest.take(20).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        actions: [
          IconButton(
            tooltip: l.favorite,
            isSelected: project.favorite,
            icon: const Icon(Icons.star_outline),
            selectedIcon: const Icon(Icons.star),
            onPressed: () => repo.write('projects', project.id, {
              'favorite': !project.favorite,
            }),
          ),
          IconButton(
            tooltip: l.editProject,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showProjectEditor(context, ref, project: project),
          ),
          PopupMenuButton<String>(
            tooltip: l.more,
            onSelected: (v) => switch (v) {
              'archive' => repo.write('projects', project.id, {
                'archived': !project.archived,
              }),
              _ => _exportCsv(project, days),
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'archive',
                child: Text(project.archived ? l.unarchive : l.archive),
              ),
              PopupMenuItem(
                value: 'csv',
                enabled: days.isNotEmpty,
                child: const Text('CSV'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            showProjectTimeDialog(context, date: today, projectId: project.id),
        icon: const Icon(Icons.more_time),
        label: Text(l.bookProjectTime),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 6,
                            backgroundColor: scheme.projectColor(project.id),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              details,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          if (running)
                            Chip(
                              avatar: const Icon(Icons.timer_outlined),
                              label: Text(l.projectRunning),
                            )
                          else if (!project.archived)
                            FilledButton.tonalIcon(
                              onPressed: () => withSummaryPrompt(
                                context,
                                ref,
                                () => ref
                                    .read(trackerProvider)
                                    .startProject(project.id),
                              ),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: Text(l.startTimer),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 32,
                        runSpacing: 12,
                        children: [
                          figure(
                            l.thisWeek,
                            sum((d) => !d.isBefore(today.startOfWeek)),
                          ),
                          figure(
                            l.thisMonth,
                            sum((d) => !d.isBefore(today.startOfMonth)),
                          ),
                          figure(l.thisYear, sum((d) => d.year == today.year)),
                          figure(l.total, total),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (project.budgetMinutes case final budget? when budget > 0)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: BudgetBar(used: total, budget: budget),
                  ),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.lastTwelveWeeks,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, box) {
                          final count = box.maxWidth < 560 ? 6 : 12;
                          return WeekBars(
                            weeks: [
                              for (var i = count - 1; i >= 0; i--)
                                if (today.startOfWeek.addDays(-7 * i)
                                    case final monday)
                                  (
                                    '${isoWeekNumber(monday)}',
                                    sum(
                                      (d) =>
                                          !d.isBefore(monday) &&
                                          d.isBefore(monday.addDays(7)),
                                    ),
                                    0,
                                  ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        l.projectHistory,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (days.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(l.noTimeBooked),
                      ),
                    for (final d in shown)
                      ListTile(
                        title: Text(
                          '${context.shortDate(d.date)} ${d.date.year}',
                        ),
                        subtitle: d.notes.isEmpty
                            ? null
                            : Text(d.notes.join(' · ')),
                        trailing: Text(
                          formatMinutes(d.minutes),
                          style: theme.textTheme.titleSmall,
                        ),
                        onTap: () => context.go('/calendar/day/${d.date}'),
                      ),
                    if (!_allDays && newest.length > shown.length)
                      TextButton(
                        onPressed: () => setState(() => _allDays = true),
                        child: Text(l.showAllDays(newest.length)),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportCsv(Project project, List<ProjectDay> days) {
    final l = context.l10n;
    final table = [
      [l.colDate, l.duration, l.activity],
      for (final d in days)
        ['${d.date}', formatMinutes(d.minutes), d.notes.join('; ')],
    ];
    final name = project.name.replaceAll(RegExp(r'[^\w-]+'), '_');
    return exportBytes(
      context,
      utf8.encode(toCsv(table)),
      'Projekt_$name.csv',
      'text/csv',
    );
  }
}

/// Booked time against the budget: a bar that turns amber at 80 % and red
/// above 100 % (calculations §3.1).
class BudgetBar extends StatelessWidget {
  /// Creates the bar.
  const BudgetBar({
    super.key,
    required this.used,
    required this.budget,
    this.compact = false,
  });

  /// Booked minutes.
  final int used;

  /// Budget minutes (> 0).
  final int budget;

  /// Only the bar and the figures, for list tiles.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final share = used / budget;
    final color = share > 1
        ? scheme.error
        : share >= 0.8
        ? scheme.tertiary
        : scheme.primary;
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: share.clamp(0, 1).toDouble(),
        minHeight: compact ? 4 : 8,
        color: color,
        backgroundColor: scheme.surfaceContainerHighest,
      ),
    );
    final figures = l.budgetUsed(
      formatMinutes(used),
      formatMinutes(budget),
      (share * 100).round(),
    );
    if (compact) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(figures, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          SizedBox(width: 120, child: bar),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l.budget, style: theme.textTheme.titleMedium),
            const Spacer(),
            Text(
              used > budget
                  ? l.budgetOverBy(formatMinutes(used - budget))
                  : l.budgetLeft(formatMinutes(budget - used)),
              style: theme.textTheme.labelLarge?.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        bar,
        const SizedBox(height: 6),
        Text(figures, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
