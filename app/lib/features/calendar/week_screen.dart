import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';

/// ISO 8601 week number of [d].
int isoWeekNumber(LocalDate d) {
  final thursday = d.startOfWeek.addDays(3);
  return LocalDate(thursday.year, 1, 1).daysUntil(thursday) ~/ 7 + 1;
}

/// One week: worked, target and difference per day; tap a day to edit it.
class WeekScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const WeekScreen({super.key});

  @override
  ConsumerState<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends ConsumerState<WeekScreen> {
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final today = ref.watch(todayProvider);
    final ledger = ref.watch(ledgerProvider);
    final holidays = ref.watch(holidaysProvider);
    final projects = ref.watch(projectByIdProvider);
    final monday = today.startOfWeek.addDays(7 * _offset);
    final days = [for (var i = 0; i < 7; i++) ledger.day(monday.addDays(i))];
    final past = days.where((d) => !d.date.isAfter(today));
    int sum(int Function(DayResult) f) => past.fold(0, (a, d) => a + f(d));
    final lastCounted = monday.addDays(6).isAfter(today)
        ? today
        : monday.addDays(6);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.weekNumber('${isoWeekNumber(monday)}')),
        actions: [
          IconButton(
            tooltip: l.goToToday,
            icon: const Icon(Icons.today),
            onPressed: _offset == 0 ? null : () => setState(() => _offset = 0),
          ),
          IconButton(
            tooltip: l.absences,
            icon: const Icon(Icons.beach_access_outlined),
            onPressed: () => context.go('/calendar/absences'),
          ),
          IconButton(
            tooltip: l.trips,
            icon: const Icon(Icons.luggage_outlined),
            onPressed: () => context.go('/calendar/trips'),
          ),
        ],
      ),
      // Swipe left/right for the next/previous week (user request
      // 2026-11-08); works with touch and trackpads alike.
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          if (v.abs() < 300) return;
          setState(() => v < 0 ? _offset++ : _offset--);
        },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: l.previousWeek,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _offset--),
                ),
                TextButton(
                  onPressed: _offset == 0
                      ? null
                      : () => setState(() => _offset = 0),
                  child: Text(l.thisWeek),
                ),
                IconButton(
                  tooltip: l.nextWeek,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() => _offset++),
                ),
              ],
            ),
            Card(
              child: Column(
                children: [
                  for (final d in days)
                    _DayRow(
                      day: d,
                      holiday: holidays.holidayOn(d.date)?.name,
                      isToday: d.date == today,
                      isFuture: d.date.isAfter(today),
                      projects: projects,
                    ),
                ],
              ),
            ),
            Card(
              child: ListTile(
                title: Text(l.weekTotal),
                subtitle: Text(
                  '${l.worked} ${formatMinutes(sum((d) => d.work.worked))} · '
                  '${l.credited} ${formatMinutes(sum((d) => d.credited))} · '
                  '${l.target} ${formatMinutes(sum((d) => d.target))} · '
                  '${l.difference} ${formatMinutes(sum((d) => d.delta))}',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      l.balance,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    Text(formatMinutes(ledger.balanceAtEndOf(lastCounted))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.holiday,
    required this.isToday,
    required this.projects,
    required this.isFuture,
  });

  final DayResult day;
  final String? holiday;
  final bool isToday;
  final bool isFuture;

  /// Project names for the bookings line.
  final Map<String, Project> projects;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final labels = [
      ?holiday,
      for (final a in day.absences)
        a.fraction < 1
            ? '${context.absenceName(a.kind)} (½)'
            : context.absenceName(a.kind),
      // The row shows worked / target; say so when the account counts
      // something else (§9).
      if (day.credited != day.work.worked)
        '${l.credited} ${formatMinutes(day.credited)}',
      if (day.sundayHours > 0)
        '${l.sundayHours} ${formatMinutes(day.sundayHours)}',
    ];
    final delta = day.delta;
    final bookings = [
      for (final MapEntry(key: id, value: minutes)
          in (day.bookedByProject.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value))))
        '${projects[id]?.name ?? '?'} ${formatMinutes(minutes)}',
    ];
    // The day type's symbol in front (calculations §15).
    final type = day.type;
    return ListTile(
      selected: isToday,
      onTap: () => context.go('/calendar/day/${day.date}'),
      leading: SizedBox(
        width: 24,
        child: type == null ? null : Icon(dayTypeIcon(type)),
      ),
      title: Row(
        children: [
          Text(context.shortDate(day.date)),
          const SizedBox(width: 8),
          if (day.warnings.isNotEmpty)
            Icon(Icons.info_outline, size: 16, color: scheme.tertiary),
        ],
      ),
      subtitle: labels.isEmpty && bookings.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (labels.isNotEmpty) Text(labels.join(' · ')),
                // Hours per project, small (user request 2026-11-08); on
                // trip days the trip project (calculations §3).
                if (bookings.isNotEmpty)
                  Text(
                    bookings.join(' · '),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
      trailing: day.target == 0 && day.work.worked == 0 && day.credited == 0
          ? null
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${formatMinutes(day.work.worked)} / ${formatMinutes(day.target)}',
                ),
                if (!isFuture)
                  Text(
                    formatMinutes(delta),
                    style: TextStyle(
                      color: delta < 0 ? scheme.error : scheme.primary,
                    ),
                  ),
              ],
            ),
    );
  }
}
