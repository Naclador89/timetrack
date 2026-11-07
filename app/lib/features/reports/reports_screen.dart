import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../widgets/export.dart';
import '../calendar/week_screen.dart' show isoWeekNumber;
import 'report_documents.dart';

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

    return Scaffold(
      appBar: AppBar(title: Text(l.navReports)),
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
          _section(context, l.timesheet, [
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _figure(context, l.worked, formatMinutes(sheet.worked)),
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
                _figure(
                  context,
                  l.vacationDaysTaken,
                  format.days(sheet.vacationDays),
                ),
              ],
            ),
            const SizedBox(height: 12),
            actions([
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
            ]),
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
              actions([
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
                      'Reisekosten_$stamp.pdf',
                      'application/pdf',
                    );
                  },
                ),
                (
                  'CSV',
                  () =>
                      csv(travelTable(trips, format), 'Reisekosten_$stamp.csv'),
                ),
              ]),
          ]),
          _section(
            context,
            l.statistics,
            _statistics(context, sheet, projects),
          ),
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
    return [
      for (final trip in [
        ...ref.watch(ledgerDataProvider).trips,
      ]..sort((a, b) => a.depart.compareTo(b.depart)))
        if (perDiemForTrip(trip, zone: zone, rates: rates, meals: meals)
                .where((d) => !d.date.isBefore(first) && !d.date.isAfter(last))
                .toList()
            case final days when days.isNotEmpty)
          TripReport(trip, days),
    ];
  }

  List<Widget> _statistics(
    BuildContext context,
    Timesheet sheet,
    Map<String, Project> projects,
  ) {
    final l = context.l10n;
    final perProject = <String, int>{};
    for (final r in sheet.rows) {
      r.day.work.byProject.forEach(
        (id, m) => perProject[id] = (perProject[id] ?? 0) + m,
      );
    }
    final ranked = perProject.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxProject = ranked.isEmpty ? 1 : ranked.first.value;
    final weeks = <int, (int, int)>{};
    for (final r in sheet.rows) {
      final w = isoWeekNumber(r.day.date);
      final (worked, target) = weeks[w] ?? (0, 0);
      weeks[w] = (worked + r.day.credited, target + r.day.target);
    }
    final maxWeek = weeks.values.fold(
      1,
      (a, w) => [a, w.$1, w.$2].reduce((x, y) => x > y ? x : y),
    );
    Widget bar(String label, int value, int max, String text, {int? target}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
                  Text(text),
                ],
              ),
              const SizedBox(height: 2),
              LinearProgressIndicator(
                value: max == 0 ? 0 : value / max,
                minHeight: 6,
              ),
            ],
          ),
        );
    return [
      if (ranked.isNotEmpty)
        Text(l.hoursByProject, style: Theme.of(context).textTheme.labelLarge),
      for (final e in ranked)
        bar(
          projects[e.key]?.name ?? '?',
          e.value,
          maxProject,
          formatMinutes(e.value),
        ),
      const SizedBox(height: 12),
      Text(l.weeks, style: Theme.of(context).textTheme.labelLarge),
      for (final MapEntry(key: week, value: (credited, target))
          in weeks.entries)
        bar(
          l.weekNumber('$week'),
          credited,
          maxWeek,
          '${formatMinutes(credited)} / ${formatMinutes(target)}',
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
