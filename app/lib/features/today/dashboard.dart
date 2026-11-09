import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../widgets/balance_zone.dart';
import '../../widgets/dashboard_tile.dart';
import '../../widgets/sparkline.dart';
import '../calendar/absences_screen.dart';
import '../settings/home_office_rules_screen.dart';

/// This year's vacation account (calculations §10).
final vacationAccountProvider = Provider<VacationAccount>((ref) {
  final today = ref.watch(todayProvider);
  final ledger = ref.watch(ledgerProvider);
  final data = ref.watch(ledgerDataProvider);
  final settings = ref.watch(settingsProvider);
  return vacationAccount(
    year: today.year,
    targets: ledger.targets,
    schedules: data.schedules,
    absences: data.absences,
    today: today,
    entitlementOverride: settings.number(
      SettingKeys.vacationEntitlement(today.year),
    ),
    carryOver: settings.number(SettingKeys.vacationCarryOver(today.year)) ?? 0,
  );
});

/// Today's overview tiles: time account, this week, vacation and the
/// home-office quotas; two columns where there is room.
class DashboardGrid extends ConsumerWidget {
  /// Creates the grid.
  const DashboardGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final today = ref.watch(todayProvider);
    final ledger = ref.watch(ledgerProvider);

    final balance = ledger.balanceAtEndOf(today);
    final monthStart = LocalDate(today.year, today.month, 1);
    final monthDelta = ledger.inBalance(monthStart)
        ? balance - ledger.balanceAtEndOf(monthStart.addDays(-1))
        : balance - ledger.settings.startingBalance;
    final trend = [
      for (var i = 5; i >= 1; i--)
        if (ledger.inBalance(_monthEnd(today, -i)))
          ledger.balanceAtEndOf(_monthEnd(today, -i)),
      balance,
    ];

    final monday = today.startOfWeek;
    final week = [for (var i = 0; i < 7; i++) ledger.day(monday.addDays(i))];
    final worked = week.fold(0, (s, d) => s + d.work.worked);
    final target = week.fold(0, (s, d) => s + d.target);

    final vacation = ref.watch(vacationAccountProvider);
    final vacationTotal = vacation.entitlement + vacation.carryOver;

    final quotas = ref
        .watch(homeOfficeQuotasProvider)
        .where((q) => q.rule.unit == QuotaUnit.days);

    final tiles = <Widget>[
      DashboardTile(
        icon: Icons.account_balance_wallet_outlined,
        title: l.dashAccount,
        value: signedBalance(balance),
        valueColor: scheme.deltaColor(balance),
        badge: BalanceZoneDot(balance),
        subtitle: l.dashMonthDelta(signedBalance(monthDelta)),
        footer: trend.length > 1
            ? Sparkline(values: trend, color: scheme.primary, height: 28)
            : null,
        openBuilder: (_) => const BalanceDetailScreen(),
      ),
      DashboardTile(
        icon: Icons.date_range_outlined,
        title: l.thisWeek,
        value: formatMinutes(worked),
        subtitle: l.dashOfTarget(formatMinutes(target)),
        footer: TileProgress(value: target <= 0 ? 0 : worked / target),
        openBuilder: (_) => WeekDetailScreen(monday: monday),
      ),
      if (vacationTotal > 0)
        DashboardTile(
          icon: dayTypeIcon(DayType.vacation),
          title: l.absenceVacation,
          value: context.days(vacation.remaining),
          subtitle: l.dashDaysOf(context.days(vacationTotal)),
          footer: TileProgress(
            value: (vacation.taken + vacation.planned) / vacationTotal,
            color: scheme.dayTypeColor(DayType.vacation),
          ),
          openBuilder: (_) => const AbsencesScreen(),
        ),
      for (final q in quotas)
        DashboardTile(
          icon: dayTypeIcon(DayType.home),
          title: l.locationHome,
          value: l.dashDaysLeft(context.days(q.left)),
          subtitle: (q.rule.period == QuotaPeriod.week
              ? l.dashQuotaWeek
              : l.dashQuotaMonth)(context.days(q.used), '${q.allowedTotal}'),
          footer: TileProgress(
            value: q.allowedTotal <= 0 ? 0 : q.used / q.allowedTotal,
            color: q.left <= 0
                ? scheme.error
                : scheme.dayTypeColor(DayType.home),
          ),
          openBuilder: (_) => const HomeOfficeRulesScreen(),
        ),
    ];

    return LayoutBuilder(
      builder: (context, box) {
        final columns = box.maxWidth >= 300 ? 2 : 1;
        return Column(
          children: [
            for (var i = 0; i < tiles.length; i += columns)
              // Tiles side by side are as tall as the taller one.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = i; j < i + columns; j++) ...[
                      if (j > i) const SizedBox(width: 12),
                      Expanded(
                        child: j < tiles.length
                            ? tiles[j]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The last day of the month [offset] months from [today]'s.
LocalDate _monthEnd(LocalDate today, int offset) {
  final first = DateTime.utc(today.year, today.month + offset + 1);
  return LocalDate(first.year, first.month, 1).addDays(-1);
}

/// The time account month by month, newest first (calculations §8).
class BalanceDetailScreen extends ConsumerWidget {
  /// Creates the screen.
  const BalanceDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = ref.watch(todayProvider);
    final ledger = ref.watch(ledgerProvider);
    final start = ledger.settings.balanceStart;
    final months = DateFormat.yMMMM(
      Localizations.localeOf(context).toLanguageTag(),
    );

    // One pass from the start: each month's change and closing balance.
    final rows = <(LocalDate, int, int)>[];
    var balance = ledger.settings.startingBalance;
    var month = LocalDate(start.year, start.month, 1);
    var opening = balance;
    for (var d = start; !d.isAfter(today); d = d.addDays(1)) {
      if (d.month != month.month || d.year != month.year) {
        rows.add((month, balance - opening, balance));
        month = LocalDate(d.year, d.month, 1);
        opening = balance;
      }
      balance += ledger.day(d).delta;
    }
    if (!start.isAfter(today)) rows.add((month, balance - opening, balance));

    return Scaffold(
      appBar: AppBar(title: Text(l.dashAccount)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.balance, style: theme.textTheme.labelLarge),
                      Row(
                        children: [
                          Text(
                            signedBalance(balance),
                            style: theme.textTheme.displayMedium?.copyWith(
                              color: scheme.deltaColor(balance),
                            ),
                          ),
                          const SizedBox(width: 12),
                          BalanceZoneDot(balance, size: 14),
                        ],
                      ),
                      Text(
                        l.balanceCountedSince(
                          context.date(start),
                          signedBalance(ledger.settings.startingBalance),
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
                child: Text(
                  l.balanceHistory,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Card(
                child: Column(
                  children: [
                    for (final (m, delta, end) in rows.reversed)
                      ListTile(
                        title: Text(months.format(DateTime(m.year, m.month))),
                        subtitle: Text(
                          signedBalance(delta),
                          style: TextStyle(color: scheme.deltaColor(delta)),
                        ),
                        trailing: Text(
                          signedBalance(end),
                          style: theme.textTheme.titleMedium,
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
}

/// The days of the week from [monday]: worked, target and difference;
/// a day opens its day view.
class WeekDetailScreen extends ConsumerWidget {
  /// Creates the screen.
  const WeekDetailScreen({super.key, required this.monday});

  /// The week's first day.
  final LocalDate monday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ledger = ref.watch(ledgerProvider);
    final days = [for (var i = 0; i < 7; i++) ledger.day(monday.addDays(i))];
    final worked = days.fold(0, (s, d) => s + d.work.worked);
    final target = days.fold(0, (s, d) => s + d.target);
    final delta = days.fold(0, (s, d) => s + d.delta);
    return Scaffold(
      appBar: AppBar(title: Text(l.thisWeek)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            children: [
              Card(
                child: ListTile(
                  title: Text(
                    formatMinutes(worked),
                    style: theme.textTheme.headlineSmall,
                  ),
                  subtitle: Text(l.dashOfTarget(formatMinutes(target))),
                  trailing: Text(
                    signedBalance(delta),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.deltaColor(delta),
                    ),
                  ),
                ),
              ),
              Card(
                child: Column(
                  children: [
                    for (final d in days)
                      ListTile(
                        leading: d.type == null
                            ? const Icon(Icons.circle_outlined)
                            : Icon(
                                dayTypeIcon(d.type!),
                                color: scheme.dayTypeColor(d.type!),
                              ),
                        title: Text(context.longDate(d.date)),
                        subtitle: Text(
                          '${formatMinutes(d.credited)} · '
                          '${l.dashOfTarget(formatMinutes(d.target))}',
                        ),
                        trailing: d.delta == 0
                            ? null
                            : Text(
                                signedBalance(d.delta),
                                style: TextStyle(
                                  color: scheme.deltaColor(d.delta),
                                ),
                              ),
                        onTap: () => context.push('/today/day/${d.date}'),
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
}
