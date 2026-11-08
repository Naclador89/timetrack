import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/back_navigation.dart';
import '../../app/format.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../sync/sync_controller.dart';
import '../../widgets/app_bar_actions.dart';
import '../../widgets/attention.dart';
import '../../widgets/explain_sheet.dart';
import '../../widgets/motion.dart';
import '../../widgets/shortcuts.dart';
import '../../widgets/sparkline.dart';

/// ISO 8601 week number of [d].
int isoWeekNumber(LocalDate d) {
  final thursday = d.startOfWeek.addDays(3);
  return LocalDate(thursday.year, 1, 1).daysUntil(thursday) ~/ 7 + 1;
}

/// The calendar: a week list (worked, target, difference and project hours
/// per day) or a month grid with the balance curve. Swipe to change the
/// week or month, pull down to sync.
class WeekScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const WeekScreen({super.key});

  @override
  ConsumerState<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends ConsumerState<WeekScreen> {
  int _offset = 0; // weeks or months from the current one
  bool _month = false;

  @override
  void initState() {
    super.initState();
    BackSteps.register(1, _back);
  }

  @override
  void dispose() {
    BackSteps.unregister(1, _back);
    super.dispose();
  }

  /// Back first returns to the current week (docs/specs/navigation.md).
  bool _back() {
    if (_offset == 0 && !_month) return false;
    setState(() => _offset != 0 ? _offset = 0 : _month = false);
    return true;
  }

  void _shift(int by) {
    tapFeedback();
    setState(() => _offset += by);
  }

  /// Opens the week of [date] (from the month grid).
  void _openWeek(LocalDate date) {
    final today = ref.read(todayProvider);
    setState(() {
      _month = false;
      _offset = today.startOfWeek.daysUntil(date.startOfWeek) ~/ 7;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final today = ref.watch(todayProvider);
    final monday = today.startOfWeek.addDays(7 * _offset);
    final month = _shiftMonth(today.startOfMonth, _offset);
    final title = _month
        ? MaterialLocalizations.of(context)
              .formatMonthYear(DateTime(month.year, month.month))
        : l.weekNumber('${isoWeekNumber(monday)}');
    final syncing = ref.watch(syncControllerProvider).phase;
    return PageKeys(
      onPrevious: () => _shift(-1),
      onNext: () => _shift(1),
      onToday: () => setState(() => _offset = 0),
      onToggleView: () => setState(() {
        _month = !_month;
        _offset = 0;
      }),
      child: Scaffold(
        appBar: AppBar(
          title: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(title, key: ValueKey(title)),
          ),
          actions: [
            IconButton(
              tooltip: l.goToToday,
              icon: const Icon(Icons.today),
              onPressed: _offset == 0
                  ? null
                  : () => setState(() => _offset = 0),
            ),
            PopupMenuButton<String>(
              tooltip: l.more,
              onSelected: (route) => context.go(route),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: '/calendar/absences',
                  child: ListTile(
                    leading: const Icon(Icons.beach_access_outlined),
                    title: Text(l.absences),
                  ),
                ),
                PopupMenuItem(
                  value: '/calendar/trips',
                  child: ListTile(
                    leading: const Icon(Icons.luggage_outlined),
                    title: Text(l.trips),
                  ),
                ),
              ],
            ),
            ...commonActions(),
          ],
        ),
        // Swipe left/right for the next/previous week (user request
        // 2026-11-08); works with touch and trackpads alike.
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0;
            if (v.abs() < 300) return;
            _shift(v < 0 ? 1 : -1);
          },
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(syncControllerProvider.notifier).syncNow(),
            notificationPredicate: (n) =>
                syncing != SyncPhase.notConfigured && n.depth == 0,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: _month ? l.previousMonth : l.previousWeek,
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _shift(-1),
                    ),
                    Expanded(
                      child: Center(
                        child: SegmentedButton<bool>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: false,
                              icon: const Icon(Icons.view_week_outlined),
                              label: Text(l.week),
                            ),
                            ButtonSegment(
                              value: true,
                              icon: const Icon(Icons.calendar_view_month),
                              label: Text(l.month),
                            ),
                          ],
                          selected: {_month},
                          onSelectionChanged: (v) => setState(() {
                            _month = v.single;
                            _offset = 0;
                          }),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _month ? l.nextMonth : l.nextWeek,
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _shift(1),
                    ),
                  ],
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _month
                      ? _MonthView(
                          key: ValueKey('m$_offset'),
                          month: month,
                          onOpenWeek: _openWeek,
                        )
                      : _WeekView(key: ValueKey('w$_offset'), monday: monday),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static LocalDate _shiftMonth(LocalDate first, int months) {
    final index = first.year * 12 + first.month - 1 + months;
    return LocalDate(index ~/ 12, index % 12 + 1, 1);
  }
}

class _WeekView extends ConsumerWidget {
  const _WeekView({super.key, required this.monday});

  final LocalDate monday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final today = ref.watch(todayProvider);
    final ledger = ref.watch(ledgerProvider);
    final holidays = ref.watch(holidaysProvider);
    final projects = ref.watch(projectByIdProvider);
    final scheme = Theme.of(context).colorScheme;
    final days = [for (var i = 0; i < 7; i++) ledger.day(monday.addDays(i))];
    final past = days.where((d) => !d.date.isAfter(today));
    int sum(int Function(DayResult) f) => past.fold(0, (a, d) => a + f(d));
    final lastCounted = monday.addDays(6).isAfter(today)
        ? today
        : monday.addDays(6);
    final last = monday.addDays(6).isAfter(today) ? today : monday.addDays(6);
    final balance = ledger.balanceAtEndOf(lastCounted);
    final marked = ref.watch(noticeDaysProvider((monday, last)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!monday.isAfter(today))
          AttentionCards(from: monday, to: last, grouped: true),
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
                  hasNotices: marked.contains(d.date),
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
                Text(l.balance, style: Theme.of(context).textTheme.labelSmall),
                Text(
                  formatMinutes(balance),
                  style: TextStyle(
                    color: scheme.deltaColor(balance),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DayRow extends ConsumerWidget {
  const _DayRow({
    required this.day,
    required this.holiday,
    required this.isToday,
    required this.projects,
    required this.isFuture,
    this.hasNotices = false,
  });

  /// Shows the small notice marker (cards may be off or dismissed).
  final bool hasNotices;

  final DayResult day;
  final String? holiday;
  final bool isToday;
  final bool isFuture;

  /// Project names for the bookings line.
  final Map<String, Project> projects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labels = [
      ?holiday,
      for (final a in day.absences)
        if (a.fraction < 1) '${context.absenceName(a.kind)} (½)',
      // The row shows worked / target; say so when the account counts
      // something else (§9).
      if (day.credited != day.work.worked)
        '${l.credited} ${formatMinutes(day.credited)}',
      if (day.sundayHours > 0)
        '${l.sundayHours} ${formatMinutes(day.sundayHours)}',
    ];
    final delta = day.delta;
    final booked = day.bookedByProject.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    // The day type's symbol in front (calculations §15).
    final type = day.type;
    return ListTile(
      selected: isToday,
      selectedTileColor: scheme.secondaryContainer.withValues(alpha: 0.4),
      onTap: () => context.go('/calendar/day/${day.date}'),
      leading: type == null
          ? const SizedBox(width: 36)
          : CircleAvatar(
              radius: 18,
              backgroundColor: scheme
                  .dayTypeColor(type)
                  .withValues(alpha: 0.16),
              child: Icon(
                dayTypeIcon(type),
                size: 20,
                color: scheme.dayTypeColor(type),
              ),
            ),
      title: Row(
        children: [
          Text(
            context.shortDate(day.date),
            style: TextStyle(fontWeight: isToday ? FontWeight.w700 : null),
          ),
          const SizedBox(width: 8),
          if (hasNotices)
            Icon(
              Icons.circle,
              size: 8,
              color: scheme.tertiary,
              semanticLabel: l.hasNotices,
            ),
        ],
      ),
      subtitle: labels.isEmpty && booked.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (labels.isNotEmpty) Text(labels.join(' · ')),
                // Hours per project, small (user request 2026-11-08); on
                // trip days the trip project (calculations §3).
                if (booked.isNotEmpty)
                  Wrap(
                    spacing: 10,
                    children: [
                      for (final MapEntry(key: id, value: minutes) in booked)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 8,
                              color: scheme.projectColor(id),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${projects[id]?.name ?? '?'} ${formatMinutes(minutes)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
              ],
            ),
      trailing: day.target == 0 && day.work.worked == 0 && day.credited == 0
          ? null
          : InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => showDayExplanation(context, ref, day.date),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
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
                          color: scheme.deltaColor(delta),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// A month as a grid: the day type as a coloured icon, the difference as a
/// tint, and the balance curve above. Tap a day to open its week.
class _MonthView extends ConsumerWidget {
  const _MonthView({super.key, required this.month, required this.onOpenWeek});

  final LocalDate month;
  final ValueChanged<LocalDate> onOpenWeek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = ref.watch(todayProvider);
    final ledger = ref.watch(ledgerProvider);
    final holidays = ref.watch(holidaysProvider);
    final last = month.addDays(31).startOfMonth.addDays(-1);
    final counted = last.isAfter(today) ? today : last;

    // Balance at the end of each day so far (one pass, not one per day).
    final balances = <int>[];
    if (!month.isAfter(today)) {
      var b = ledger.balanceAtEndOf(month.addDays(-1));
      for (var d = month; !d.isAfter(counted); d = d.addDays(1)) {
        b += ledger.day(d).delta;
        balances.add(b);
      }
    }
    final monthDelta = balances.isEmpty
        ? 0
        : balances.last - ledger.balanceAtEndOf(month.addDays(-1));
    final first = month.startOfWeek;
    final weeks = (first.daysUntil(last) ~/ 7) + 1;
    final marked = month.isAfter(today)
        ? const <LocalDate>{}
        : ref.watch(noticeDaysProvider((first, counted)));
    final labels = MaterialLocalizations.of(context).narrowWeekdays;

    Widget cell(LocalDate d) {
      final inMonth = d.month == month.month;
      final day = ledger.day(d);
      final future = d.isAfter(today);
      final type = day.type;
      final tint = future || day.target == 0 && day.work.worked == 0
          ? null
          : scheme.deltaColor(day.delta).withValues(alpha: 0.12);
      final isToday = d == today;
      return Opacity(
        opacity: inMonth ? 1 : 0.35,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onOpenWeek(d),
          onLongPress: () => context.go('/calendar/day/$d'),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(12),
              border: isToday
                  ? Border.all(color: scheme.primary, width: 2)
                  : null,
            ),
            child: Stack(
              children: [
                if (marked.contains(d))
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Icon(Icons.circle, size: 6, color: scheme.tertiary),
                  ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${d.day}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: holidays.isHoliday(d) ? scheme.error : null,
                          fontWeight: isToday ? FontWeight.w700 : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        height: 16,
                        child: type == null
                            ? null
                            : Icon(
                                dayTypeIcon(type),
                                size: 14,
                                color: scheme.dayTypeColor(type),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (balances.length > 1)
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.balance,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        '${monthDelta >= 0 ? '+' : ''}${formatMinutes(monthDelta)} · ',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        formatMinutes(balances.last),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.deltaColor(balances.last),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Sparkline(
                    values: balances,
                    color: scheme.deltaColor(balances.last),
                  ),
                ],
              ),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Row(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Center(
                          // narrowWeekdays starts on Sunday.
                          child: Text(
                            labels[(i + 1) % 7],
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                for (var w = 0; w < weeks; w++)
                  Row(
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 0.95,
                            child: cell(first.addDays(w * 7 + i)),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
