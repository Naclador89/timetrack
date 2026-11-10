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

    final months = ref.watch(monthlyBalancesProvider);
    final balance =
        months.lastOrNull?.closing ?? ledger.settings.startingBalance;
    final monthDelta = months.lastOrNull?.change ?? 0;
    // The last six month ends; the current one is today's balance.
    final trend = [
      for (final m in months.reversed.take(6).toList().reversed) m.closing,
    ];

    final week = _week(ledger, today.startOfWeek);
    final credited = week.fold(0, (s, d) => s + d.credited);
    final target = week.fold(0, (s, d) => s + d.target);

    final vacation = ref.watch(vacationAccountProvider(today.year));
    final vacationTotal = vacation.entitlement + vacation.carryOver;
    final next = ref.watch(nextVacationProvider);

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
        value: formatMinutes(credited),
        subtitle: l.dashOfTarget(formatMinutes(target)),
        footer: TileProgress(value: target <= 0 ? 0 : credited / target),
        openBuilder: (_) => WeekDetailScreen(monday: today.startOfWeek),
      ),
      if (vacationTotal > 0 || next != null)
        DashboardTile(
          icon: dayTypeIcon(DayType.vacation),
          title: l.absenceVacation,
          value: context.days(vacation.remaining),
          subtitle: next == null
              ? l.dashDaysOf(context.days(vacationTotal))
              : l.nextVacationIn(
                  today.daysUntil(next.start),
                  next.days,
                  context.days(next.days),
                ),
          footer: TileProgress(
            value: vacationTotal <= 0
                ? 1
                : (vacation.taken + vacation.planned) / vacationTotal,
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

/// The counted days of the week from [monday] (calculations §8: days
/// before the balance start are left out of week totals).
List<DayResult> _week(Ledger ledger, LocalDate monday) => [
  for (var i = 0; i < 7; i++)
    if (ledger.inBalance(monday.addDays(i))) ledger.day(monday.addDays(i)),
];

/// The time account month by month, newest first (calculations §8).
class BalanceDetailScreen extends ConsumerWidget {
  /// Creates the screen.
  const BalanceDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ledger = ref.watch(ledgerProvider);
    final start = ledger.settings.balanceStart;
    final format = DateFormat.yMMMM(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final months = ref.watch(monthlyBalancesProvider);
    final balance =
        months.lastOrNull?.closing ?? ledger.settings.startingBalance;

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
                    for (final m in months.reversed)
                      ListTile(
                        title: Text(
                          format.format(DateTime(m.month.year, m.month.month)),
                        ),
                        subtitle: Text(
                          signedBalance(m.change),
                          style: TextStyle(color: scheme.deltaColor(m.change)),
                        ),
                        trailing: Text(
                          signedBalance(m.closing),
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

/// The days of the week from [monday]: credited time, target and
/// difference;
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
    final days = _week(ledger, monday);
    final credited = days.fold(0, (s, d) => s + d.credited);
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
                    formatMinutes(credited),
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
