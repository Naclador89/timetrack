import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
  /// Creates the screen; [month] opens the month view (`?view=month`).
  const WeekScreen({super.key, this.month = false});

  /// Start in the month view.
  final bool month;

  @override
  ConsumerState<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends ConsumerState<WeekScreen> {
  int _offset = 0; // weeks or months from the current one
  late bool _month = widget.month;

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
    // Days before the balance start count nothing (calculations §8).
    final past = days.where(
      (d) => !d.date.isAfter(today) && ledger.inBalance(d.date),
    );
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
                  inBalance: ledger.inBalance(d.date),
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
    this.inBalance = true,
    this.hasNotices = false,
  });

  /// On or after the balance start; before it, no target or difference.
  final bool inBalance;

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
          : !inBalance
          ? (day.work.worked == 0 ? null : Text(formatMinutes(day.work.worked)))
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
    var worked = 0, target = 0;
    // Only days in the balance count (calculations §8): a month before the
    // balance start has no figures, the start month only from that day.
    final from = ledger.inBalance(month) ? month : ledger.settings.balanceStart;
    if (!from.isAfter(counted)) {
      var b = ledger.balanceAtEndOf(from.addDays(-1));
      for (var d = from; !d.isAfter(counted); d = d.addDays(1)) {
        final day = ledger.day(d);
        b += day.delta;
        worked += day.credited;
        target += day.target;
        balances.add(b);
      }
    }
    final monthDelta = balances.isEmpty
        ? 0
        : balances.last - ledger.balanceAtEndOf(from.addDays(-1));
    final first = month.startOfWeek;
    final weeks = (first.daysUntil(last) ~/ 7) + 1;
    final marked = month.isAfter(today)
        ? const <LocalDate>{}
        : ref.watch(noticeDaysProvider((first, counted)));
    final locale = Localizations.localeOf(context).toLanguageTag();
    String signed(int m) => '${m > 0 ? '+' : ''}${formatMinutes(m)}';

    // Whether a day has figures worth showing (past or today, with a target
    // or work).
    bool counts(DayResult day) =>
        !day.date.isAfter(today) &&
        ledger.inBalance(day.date) &&
        (day.target > 0 || day.credited > 0);

    Widget cell(LocalDate d, {required bool wide, required double height}) {
      final inMonth = d.month == month.month;
      final day = ledger.day(d);
      final type = day.type;
      final isToday = d == today;
      final holiday = holidays.holidayOn(d)?.name;
      final shown = counts(day);
      final deltaColor = scheme.deltaColor(day.delta);
      final weekend = d.weekday >= DateTime.saturday;
      final number = Text(
        '${d.day}',
        style: theme.textTheme.labelLarge?.copyWith(
          color: holiday != null ? scheme.error : null,
          fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
        ),
      );
      final typeIcon = type == null
          ? null
          : Icon(dayTypeIcon(type), size: 14, color: scheme.dayTypeColor(type));
      final dot = marked.contains(d)
          ? Icon(Icons.circle, size: 7, color: scheme.tertiary)
          : null;
      final small = theme.textTheme.labelSmall;
      final Widget content;
      if (wide) {
        content = Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  number,
                  const SizedBox(width: 6),
                  ?typeIcon,
                  const Spacer(),
                  ?dot,
                ],
              ),
              if (holiday != null && height >= 72)
                Text(
                  holiday,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: small?.copyWith(color: scheme.error),
                ),
              const Spacer(),
              if (!shown && day.work.worked > 0)
                Text(
                  formatMinutes(day.work.worked),
                  style: theme.textTheme.bodySmall,
                ),
              if (shown)
                Row(
                  children: [
                    Text(
                      formatMinutes(day.credited),
                      style: theme.textTheme.bodySmall,
                    ),
                    const Spacer(),
                    if (day.delta != 0)
                      Text(
                        signed(day.delta),
                        style: small?.copyWith(
                          color: deltaColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        );
      } else {
        content = Stack(
          children: [
            if (dot != null) Positioned(top: 3, right: 3, child: dot),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  number,
                  SizedBox(
                    height: 14,
                    child: shown && day.delta != 0
                        ? FittedBox(
                            child: Text(
                              signed(day.delta),
                              style: small?.copyWith(color: deltaColor),
                            ),
                          )
                        : typeIcon,
                  ),
                ],
              ),
            ),
          ],
        );
      }
      return Opacity(
        opacity: inMonth ? 1 : 0.4,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Material(
            color: shown
                ? Color.alphaBlend(
                    deltaColor.withValues(alpha: day.delta == 0 ? 0 : 0.08),
                    scheme.surfaceContainerHigh,
                  )
                : weekend || holiday != null
                ? Colors.transparent
                : scheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: isToday
                  ? BorderSide(color: scheme.primary, width: 2)
                  : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: Tooltip(
              message: [
                context.longDate(d),
                ?holiday,
                if (type != null) dayTypeLabel(l, type),
                if (shown)
                  '${formatMinutes(day.credited)} / '
                      '${formatMinutes(day.target)} (${signed(day.delta)})',
              ].join('\n'),
              waitDuration: const Duration(milliseconds: 600),
              child: InkWell(
                onTap: () => context.go('/calendar/day/$d'),
                onLongPress: () => onOpenWeek(d),
                child: content,
              ),
            ),
          ),
        ),
      );
    }

    Widget figure(String label, String value, {Color? color}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        Text(value, style: theme.textTheme.titleMedium?.copyWith(color: color)),
      ],
    );

    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 600;
        // Six weeks must fit the window next to the summary, so the row
        // height follows the window instead of the cell width.
        final screen = MediaQuery.sizeOf(context).height;
        final weekColumn = wide ? 44.0 : 28.0;
        final cellWidth = (box.maxWidth - 16 - weekColumn) / 7;
        final height = wide
            ? ((screen - 330) / weeks).clamp(56.0, 110.0)
            : (cellWidth * 1.05).clamp(44.0, 64.0);
        final summary = [
          figure(l.worked, formatMinutes(worked)),
          figure(l.target, formatMinutes(target)),
          figure(
            l.difference,
            signed(monthDelta),
            color: scheme.deltaColor(monthDelta),
          ),
          if (balances.isNotEmpty)
            figure(
              l.balance,
              formatMinutes(balances.last),
              color: scheme.deltaColor(balances.last),
            ),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!ledger.inBalance(last))
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(
                    l.beforeBalanceStart(
                      context.date(ledger.settings.balanceStart),
                    ),
                  ),
                ),
              ),
            if (balances.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: wide
                      ? Row(
                          children: [
                            for (final f in summary) ...[
                              f,
                              const SizedBox(width: 28),
                            ],
                            if (balances.length > 1)
                              Expanded(
                                child: Sparkline(
                                  values: balances,
                                  color: scheme.deltaColor(balances.last),
                                  height: 36,
                                ),
                              ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(spacing: 20, runSpacing: 8, children: summary),
                            if (balances.length > 1) ...[
                              const SizedBox(height: 8),
                              Sparkline(
                                values: balances,
                                color: scheme.deltaColor(balances.last),
                                height: 32,
                              ),
                            ],
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
                        SizedBox(width: weekColumn),
                        for (var i = 0; i < 7; i++)
                          Expanded(
                            child: Center(
                              child: Text(
                                // 2026-11-02 is a Monday.
                                DateFormat.E(locale)
                                    .format(DateTime(2026, 11, 2 + i)),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    for (var w = 0; w < weeks; w++)
                      SizedBox(
                        height: height,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _WeekLabel(
                              width: weekColumn,
                              monday: first.addDays(w * 7),
                              delta: wide
                                  ? [
                                          for (var i = 0; i < 7; i++)
                                            ledger.day(
                                              first.addDays(w * 7 + i),
                                            ),
                                        ]
                                        .where(counts)
                                        .fold(0, (a, d) => a + d.delta)
                                  : 0,
                              onTap: () => onOpenWeek(first.addDays(w * 7)),
                            ),
                            for (var i = 0; i < 7; i++)
                              Expanded(
                                child: cell(
                                  first.addDays(w * 7 + i),
                                  wide: wide,
                                  height: height,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The calendar week beside a month row, with its ±; opens the week.
class _WeekLabel extends StatelessWidget {
  const _WeekLabel({
    required this.width,
    required this.monday,
    required this.delta,
    required this.onTap,
  });

  final double width;
  final LocalDate monday;
  final int delta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      width: width,
      child: Tooltip(
        message: context.l10n.weekNumber('${isoWeekNumber(monday)}'),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${isoWeekNumber(monday)}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (delta != 0)
                FittedBox(
                  child: Text(
                    '${delta > 0 ? '+' : ''}${formatMinutes(delta)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.deltaColor(delta),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
