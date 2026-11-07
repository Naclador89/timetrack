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
      body: ListView(
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
                  ),
              ],
            ),
          ),
          Card(
            child: ListTile(
              title: Text(l.weekTotal),
              subtitle: Text(
                '${l.worked} ${formatMinutes(sum((d) => d.work.worked))} · '
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
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.holiday,
    required this.isToday,
    required this.isFuture,
  });

  final DayResult day;
  final String? holiday;
  final bool isToday;
  final bool isFuture;

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
      if (day.isTripDay) l.tripDay,
    ];
    final delta = day.delta;
    return ListTile(
      selected: isToday,
      onTap: () => context.go('/calendar/day/${day.date}'),
      title: Row(
        children: [
          Text(context.shortDate(day.date)),
          const SizedBox(width: 8),
          for (final loc in day.work.byLocation.keys)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(locationIcon(loc), size: 16),
            ),
          if (day.warnings.isNotEmpty)
            Icon(Icons.info_outline, size: 16, color: scheme.tertiary),
        ],
      ),
      subtitle: labels.isEmpty ? null : Text(labels.join(' · ')),
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
