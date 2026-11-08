import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../widgets/app_bar_actions.dart';
import '../../widgets/charts.dart';
import '../../widgets/export.dart';
import '../../widgets/motion.dart';
import '../../widgets/sparkline.dart';
import '../calendar/week_screen.dart' show isoWeekNumber;
import 'report_documents.dart';
import 'report_preview.dart';

/// Monthly reports: timesheet, order report, travel expenses, statistics and
/// the JSON backup (concept §5, item 5).
class ReportsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _offset = 0; // months back from the current one

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final today = ref.watch(todayProvider);
    final ledger = ref.watch(ledgerProvider);
    final zone = ref.watch(zoneProvider);
    final month = _shiftMonth(today.startOfMonth, _offset);
    final last = month.addDays(31).startOfMonth.addDays(-1);
    final format = ReportFormat(
      l,
      Localizations.localeOf(context).toLanguageTag(),
      zone,
    );
    final sheet = buildTimesheet(ledger, month.year, month.month);
    final projects = ref.watch(projectByIdProvider);
    final bookings = buildOrderReport(
      ledger,
      projects,
      from: month,
      to: last.isAfter(today) ? today : last,
    );
    final trips = _tripReports(month, last);
    final stamp = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final now = ref.watch(clockProvider)();

    Future<void> csv(List<List<String>> table, String name) =>
        exportBytes(context, utf8.encode(toCsv(table)), name, 'text/csv');

    Widget actions(List<(String, Future<void> Function())> buttons) => Wrap(
      spacing: 8,
      children: [
        for (final (label, onPressed) in buttons)
          OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(
              label == 'PDF'
                  ? Icons.picture_as_pdf_outlined
                  : Icons.table_chart_outlined,
              size: 18,
            ),
            label: Text(label),
          ),
      ],
    );

    // Timesheet and travel report open a preview first; PDF and CSV are
    // downloaded from there (user request 2026-11-08).
    Widget preview(ReportPreviewScreen screen) => Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.tonalIcon(
        onPressed: () =>
            Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => screen)),
        icon: const Icon(Icons.preview_outlined),
        label: Text(l.preview),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.navReports), actions: commonActions()),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: l.previousMonth,
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _offset--),
              ),
              Text(
                format.month(month.year, month.month),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              IconButton(
                tooltip: l.nextMonth,
                icon: const Icon(Icons.chevron_right),
                onPressed: _offset >= 0
                    ? null
                    : () => setState(() => _offset++),
              ),
            ],
          ),
          _Dashboard(sheet: sheet, ledger: ledger, projects: projects),
          _section(context, l.timesheet, [
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _figure(context, l.worked, formatMinutes(sheet.worked)),
                _figure(context, l.credited, formatMinutes(sheet.credited)),
                _figure(context, l.target, formatMinutes(sheet.target)),
                _figure(context, l.difference, formatMinutes(sheet.delta)),
                if (sheet.sundayHours > 0)
                  _figure(
                    context,
                    l.sundayHours,
                    formatMinutes(sheet.sundayHours),
                  ),
                _figure(
                  context,
                  l.balanceAfter,
                  formatMinutes(sheet.balanceAfter),
                ),
                _figure(context, l.homeOfficeDays, '${sheet.homeOfficeDays}'),
                _figure(context, l.tripDays, '${sheet.tripDays}'),
                _figure(
                  context,
                  l.vacationDaysTaken,
                  format.days(sheet.vacationDays),
                ),
              ],
            ),
            const SizedBox(height: 12),
            preview(
              ReportPreviewScreen(
                title:
                    '${l.timesheet} ${format.month(month.year, month.month)}',
                table: timesheetTable(sheet, format),
                figures: timesheetFigures(sheet, format),
                legend: l.timesheetLegend,
                numericColumns: {
                  for (var i = 1; i <= (sheet.sundayHours > 0 ? 8 : 7); i++) i,
                },
                exports: [
                  (
                    'PDF',
                    () async {
                      final bytes = await timesheetPdf(sheet, format, now: now);
                      if (!context.mounted) return;
                      await exportBytes(
                        context,
                        bytes,
                        'Stundenzettel_$stamp.pdf',
                        'application/pdf',
                      );
                    },
                  ),
                  (
                    'CSV',
                    () => csv(
                      timesheetTable(sheet, format),
                      'Stundenzettel_$stamp.csv',
                    ),
                  ),
                ],
              ),
            ),
          ]),
          _section(context, l.orderReport, [
            if (bookings.isEmpty) Text(l.noBookings),
            for (final b in bookings.take(40))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${context.shortDate(b.date)} · ${b.orderNumber.isEmpty ? b.projectName : b.orderNumber}',
                ),
                subtitle: Text(
                  [
                    if (b.orderNumber.isNotEmpty) b.projectName,
                    ...b.notes,
                  ].join(' · '),
                ),

                trailing: Text(formatMinutes(b.minutes)),
              ),
            if (bookings.isNotEmpty)
              actions([
                (
                  'CSV',
                  () =>
                      csv(orderTable(bookings, format), 'Auftraege_$stamp.csv'),
                ),
              ]),
          ]),
          _section(context, l.travelReport, [
            if (trips.isEmpty) Text(l.noTrips),
            for (final t in trips)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.luggage_outlined),
                title: Text(
                  t.trip.destination.isEmpty ? l.tripDay : t.trip.destination,
                ),
                subtitle: Text('${t.days.length} × ${l.perDiem}'),
                trailing: Text(format.money(t.totalCents)),
              ),
            if (trips.isNotEmpty)
              preview(
                ReportPreviewScreen(
                  title:
                      '${l.travelReport} ${format.month(month.year, month.month)}',
                  table: travelTable(trips, format),
                  figures: travelFigures(trips, format),
                  numericColumns: travelNumericColumns,
                  exports: [
                    (
                      'PDF',
                      () async {
                        final bytes = await travelPdf(
                          trips,
                          month.year,
                          month.month,
                          format,
                          now: now,
                        );
                        if (!context.mounted) return;
                        await exportBytes(
                          context,
                          bytes,
                          'Reisebericht_$stamp.pdf',
                          'application/pdf',
                        );
                      },
                    ),
                    (
                      'CSV',
                      () => csv(
                        travelTable(trips, format),
                        'Reisebericht_$stamp.csv',
                      ),
                    ),
                  ],
                ),
              ),
          ]),
          Card(
            child: ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: Text(l.backupJson),
              trailing: const Icon(Icons.download),
              onTap: () async {
                final rows = await ref
                    .read(storeProvider)
                    .watchRows(syncedTables)
                    .first;
                if (!context.mounted) return;
                await exportBytes(
                  context,
                  utf8.encode(backupJson(rows, now)),
                  'TimeTrack_Sicherung_${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}.json',
                  'application/json',
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static LocalDate _shiftMonth(LocalDate firstOfMonth, int months) {
    final index = firstOfMonth.year * 12 + firstOfMonth.month - 1 + months;
    return LocalDate(index ~/ 12, index % 12 + 1, 1);
  }

  /// Trips touching the month, with only the per-diem days inside it.
  List<TripReport> _tripReports(LocalDate first, LocalDate last) {
    final zone = ref.watch(zoneProvider);
    final rates = ref.watch(perDiemRatesProvider);
    final meals = ref.watch(tripMealsProvider);
    final projects = ref.watch(projectByIdProvider);
    final ledger = ref.watch(ledgerProvider);
    ({int travel, int onSite}) times(LocalDate d) {
      final work = ledger.day(d).work;
      return (
        travel: work.workedAt(WorkLocation.travel),
        onSite: work.workedAt(WorkLocation.onSite),
      );
    }

    return [
      for (final trip in [
        ...ref.watch(ledgerDataProvider).trips,
      ]..sort((a, b) => a.depart.compareTo(b.depart)))
        if (perDiemForTrip(trip, zone: zone, rates: rates, meals: meals)
                .where((d) => !d.date.isBefore(first) && !d.date.isAfter(last))
                .toList()
            case final days when days.isNotEmpty)
          TripReport(
            trip,
            days,
            project: projects[trip.projectId],
            times: {for (final d in days) d.date: times(d.date)},
            legs: {for (final d in days) d.date: tripLegs(ledger, d.date)},
            credited: {
              for (final d in days) d.date: ledger.day(d.date).credited,
            },
          ),
    ];
  }

  static Widget _figure(BuildContext context, String label, String value) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      );

  static Widget _section(
    BuildContext context,
    String title,
    List<Widget> children,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );
}

/// The month at a glance: balance curve, hours per project and weeks
/// against the target, home-office share.
class _Dashboard extends ConsumerWidget {
  const _Dashboard({
    required this.sheet,
    required this.ledger,
    required this.projects,
  });

  final Timesheet sheet;
  final Ledger ledger;
  final Map<String, Project> projects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = ref.watch(todayProvider);

    final rows = sheet.rows.where((r) => !r.day.date.isAfter(today));
    final balances = <int>[];
    var b = sheet.balanceBefore;
    for (final r in rows) {
      b += r.day.delta;
      balances.add(b);
    }

    final perProject = <String, int>{};
    for (final r in sheet.rows) {
      r.day.bookedByProject.forEach(
        (id, m) => perProject[id] = (perProject[id] ?? 0) + m,
      );
    }
    final slices = [
      for (final e in perProject.entries)
        (
          label: projects[e.key]?.name ?? '?',
          value: e.value,
          color: scheme.projectColor(e.key),
        ),
    ]..sort((a, b) => b.value.compareTo(a.value));
    final booked = slices.fold(0, (a, s) => a + s.value);

    final weeks = <int, (int, int)>{};
    for (final r in sheet.rows) {
      final w = isoWeekNumber(r.day.date);
      final (credited, target) = weeks[w] ?? (0, 0);
      weeks[w] = (credited + r.day.credited, target + r.day.target);
    }

    final homeShare = sheet.workedDays == 0
        ? 0.0
        : sheet.homeOfficeDays / sheet.workedDays;
    final monthRule = ref
        .watch(homeOfficeRulesProvider)
        .where((r) => r.period == QuotaPeriod.month)
        .firstOrNull;

    Widget tile(String title, Widget child) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );

    final balanceTile = tile(
      l.balance,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedMinutes(
            sheet.balanceAfter,
            style: theme.textTheme.headlineSmall,
            signed: scheme.deltaColor,
          ),
          Text(
            '${l.difference} ${formatMinutes(sheet.delta)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Sparkline(
            values: balances,
            color: scheme.deltaColor(sheet.balanceAfter),
            height: 64,
          ),
        ],
      ),
    );
    final projectTile = tile(
      l.hoursByProject,
      slices.isEmpty
          ? Text(l.noBookings)
          : DonutChart(
              slices: slices,
              format: formatMinutes,
              center: Text(
                formatMinutes(booked),
                style: theme.textTheme.titleMedium,
              ),
            ),
    );
    final weekTile = tile(
      l.weeks,
      WeekBars(
        weeks: [
          for (final MapEntry(key: w, value: (c, t)) in weeks.entries)
            ('$w', c, t),
        ],
      ),
    );
    final homeTile = tile(
      l.homeOfficeDays,
      Row(
        children: [
          ProgressRing(
            value: (homeShare * 100).round(),
            total: 100,
            size: 88,
            color: monthRule != null && homeShare * 100 > monthRule.maxPercent
                ? scheme.error
                : scheme.dayTypeColor(DayType.home),
            child: Text(
              '${(homeShare * 100).round()} %',
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              [
                l.homeOfficeOfWorked(
                  '${sheet.homeOfficeDays}',
                  '${sheet.workedDays}',
                ),
                if (monthRule != null)
                  l.homeOfficeLimit('${monthRule.maxPercent}'),
              ].join('\n'),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 700) {
          return Column(
            children: [balanceTile, projectTile, weekTile, homeTile],
          );
        }
        Widget pair(Widget a, Widget b) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: a),
              const SizedBox(width: 12),
              Expanded(child: b),
            ],
          ),
        );
        return Column(
          children: [pair(balanceTile, projectTile), pair(weekTile, homeTile)],
        );
      },
    );
  }
}
