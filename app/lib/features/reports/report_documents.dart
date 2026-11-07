import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../l10n/app_localizations.dart';

/// Everything the report builders need to format values; no BuildContext, so
/// the documents can be built (and tested) anywhere.
final class ReportFormat {
  /// Creates the formatter.
  ReportFormat(this.l, this.locale, this.zone);

  /// Localized strings.
  final AppLocalizations l;

  /// Locale tag, e.g. `de`.
  final String locale;

  /// Home time zone for clock times.
  final HomeTimeZone zone;

  DateTime _dt(LocalDate d) => DateTime(d.year, d.month, d.day);

  /// `Di. 03.11.2026` (German: always two-digit day and month, which Excel
  /// reads as a date); other locales use their short date.
  String date(LocalDate d) {
    final dateText = locale.startsWith('de')
        ? DateFormat('dd.MM.yyyy', locale).format(_dt(d))
        : DateFormat.yMd(locale).format(_dt(d));
    return '${DateFormat.E(locale).format(_dt(d))} $dateText';
  }

  /// Local clock time of an epoch minute, `08:05`.
  String clock(int? epochMinute) => epochMinute == null
      ? ''
      : DateFormat.Hm(locale)
            .format(zone.toLocal(instantOfEpochMinute(epochMinute)));

  /// Month title, `November 2026`.
  String month(int year, int month) =>
      DateFormat.yMMMM(locale).format(DateTime(year, month));

  /// Money from cents, `14,00 €`.
  String money(int cents) =>
      NumberFormat.currency(locale: locale, symbol: '€').format(cents / 100);

  /// Days with up to one decimal.
  String days(num v) => NumberFormat('#0.#', locale).format(v);
}

String _notes(ReportFormat f, TimesheetRow r) => [
  ?r.holiday,
  for (final a in r.day.absences)
    a.fraction < 1
        ? '${absenceLabel(f.l, a.kind)} ½'
        : absenceLabel(f.l, a.kind),
  if (r.day.isTripDay) f.l.tripDay,
  ...r.locations.map((loc) => locationLabel(f.l, loc)),
].join(', ');

/// The monthly timesheet as a table: header row plus one row per day
/// (concept §5, "Monthly timesheet").
///
/// The column "Sunday hours" (trip Sundays for HR, calculations.md §9) is
/// only there in months that have some.
List<List<String>> timesheetTable(Timesheet t, ReportFormat f) {
  final l = f.l;
  final sunday = t.sundayHours > 0;
  return [
    [
      l.colDate,
      l.start,
      l.end,
      l.colBreak,
      l.worked,
      l.target,
      l.credited,
      l.difference,
      if (sunday) l.sundayHours,
      l.colNotes,
    ],
    for (final r in t.rows)
      [
        f.date(r.day.date),
        f.clock(r.firstStart),
        f.clock(r.lastEnd),
        r.breakMinutes == 0 ? '' : formatMinutes(r.breakMinutes),
        r.day.work.worked == 0 ? '' : formatMinutes(r.day.work.worked),
        formatMinutes(r.day.target),
        formatMinutes(r.day.credited),
        formatMinutes(r.day.delta),
        if (sunday)
          r.day.sundayHours == 0 ? '' : formatMinutes(r.day.sundayHours),
        _notes(f, r),
      ],
  ];
}

/// Project time per day and order number (concept §5, "Order report").
List<List<String>> orderTable(List<OrderBooking> bookings, ReportFormat f) {
  final l = f.l;
  return [
    [
      l.colDate,
      l.orderNumber,
      l.projectNumber,
      l.projectName,
      l.worked,
      l.activity,
    ],
    for (final b in bookings)
      [
        f.date(b.date),
        b.orderNumber,
        b.projectNumber,
        b.projectName,
        formatMinutes(b.minutes),
        b.notes.join('; '),
      ],
  ];
}

/// One trip with its per-diem days, for the travel report.
final class TripReport {
  /// Creates the entry.
  const TripReport(this.trip, this.days);

  /// The trip.
  final Trip trip;

  /// Per-diem per local date (calculations.md §13).
  final List<PerDiemDay> days;

  /// Sum of all amounts in cents.
  int get totalCents => days.fold(0, (a, d) => a + d.amountCents);
}

String _category(ReportFormat f, PerDiemDay d) => switch (d.category) {
  PerDiemCategory.none => f.l.perDiemNone,
  PerDiemCategory.partial => f.l.perDiemPartial,
  PerDiemCategory.full => f.l.perDiemFull,
};

/// The travel report as a table, one row per trip day (concept §5).
List<List<String>> travelTable(List<TripReport> trips, ReportFormat f) {
  final l = f.l;
  return [
    [
      l.colDate,
      l.destination,
      l.hoursAway,
      l.perDiem,
      l.mealsProvided,
      l.amount,
    ],
    for (final t in trips)
      for (final d in t.days)
        [
          f.date(d.date),
          '${t.trip.destination} (${t.trip.country})',
          formatMinutes(d.absenceMinutes),
          d.rateMissing ? l.rateMissing(t.trip.country) : _category(f, d),
          d.reductionCents == 0 ? '' : '−${f.money(d.reductionCents)}',
          f.money(d.amountCents),
        ],
  ];
}

/// All synced rows (including tombstones and field clocks) as JSON, so
/// nothing is lost even without Nextcloud.
String backupJson(List<StoredRow> rows, DateTime now) =>
    const JsonEncoder.withIndent(' ').convert({
      'app': 'TimeTrack',
      'format': syncFormatVersion,
      'exported': now.toUtc().toIso8601String(),
      'rows': [
        for (final r in rows)
          {
            'tbl': r.table,
            'id': r.id,
            'fields': r.fields,
            'fieldClock': r.fieldClock,
          },
      ],
    });

/// The PDF standard fonts only cover Windows-1252; map the few characters
/// outside it that our texts use.
String _pdfSafe(String s) =>
    s.replaceAll('−', '-').replaceAll('…', '...').replaceAll('½', '1/2');

pw.Widget _table(List<List<String>> table, {Map<int, pw.Alignment>? align}) =>
    pw.TableHelper.fromTextArray(
      headers: table.first.map(_pdfSafe).toList(),
      data: [for (final row in table.skip(1)) row.map(_pdfSafe).toList()],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignments: align ?? const {},
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
    );

pw.Widget _footer(ReportFormat f, pw.Context ctx, DateTime now) => pw.Row(
  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  children: [
    pw.Text(
      _pdfSafe(f.l.generatedBy(DateFormat.yMd(f.locale).format(now))),
      style: const pw.TextStyle(fontSize: 7),
    ),
    pw.Text(
      '${ctx.pageNumber}/${ctx.pagesCount}',
      style: const pw.TextStyle(fontSize: 7),
    ),
  ],
);

/// The monthly timesheet as a PDF (A4, with totals and a signature line).
Future<List<int>> timesheetPdf(
  Timesheet t,
  ReportFormat f, {
  required DateTime now,
}) {
  final l = f.l;
  final doc = pw.Document(title: '${l.timesheet} ${f.month(t.year, t.month)}');
  final lastNumber = t.sundayHours > 0 ? 8 : 7;
  final right = {
    for (var i = 1; i <= lastNumber; i++) i: pw.Alignment.centerRight,
  };
  pw.Widget figure(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(right: 18, bottom: 4),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(_pdfSafe(label), style: const pw.TextStyle(fontSize: 7)),
        pw.Text(
          _pdfSafe(value),
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      footer: (ctx) => _footer(f, ctx, now),
      build: (ctx) => [
        pw.Text(
          _pdfSafe('${l.timesheet} ${f.month(t.year, t.month)}'),
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        _table(timesheetTable(t, f), align: right),
        pw.SizedBox(height: 12),
        pw.Wrap(
          children: [
            figure(l.worked, formatMinutes(t.worked)),
            figure(l.target, formatMinutes(t.target)),
            figure(l.credited, formatMinutes(t.credited)),
            figure(l.difference, formatMinutes(t.delta)),
            if (t.sundayHours > 0)
              figure(l.sundayHours, formatMinutes(t.sundayHours)),
            figure(l.balanceBefore, formatMinutes(t.balanceBefore)),
            figure(l.balanceAfter, formatMinutes(t.balanceAfter)),
            figure(l.workedDays, '${t.workedDays}'),
            figure(l.homeOfficeDays, '${t.homeOfficeDays}'),
            figure(l.vacationDaysTaken, f.days(t.vacationDays)),
          ],
        ),
        pw.SizedBox(height: 36),
        pw.Container(
          width: 220,
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(width: 0.5)),
          ),
        ),
        pw.Text(_pdfSafe(l.signature), style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
  );
  return doc.save();
}

/// The travel report as a PDF: one table row per trip day, with the total.
Future<List<int>> travelPdf(
  List<TripReport> trips,
  int year,
  int month,
  ReportFormat f, {
  required DateTime now,
}) {
  final l = f.l;
  final doc = pw.Document(title: '${l.travelReport} ${f.month(year, month)}');
  final total = trips.fold(0, (a, t) => a + t.totalCents);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      footer: (ctx) => _footer(f, ctx, now),
      build: (ctx) => [
        pw.Text(
          _pdfSafe('${l.travelReport} ${f.month(year, month)}'),
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        _table(
          travelTable(trips, f),
          align: {
            2: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
          },
        ),
        pw.SizedBox(height: 8),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            _pdfSafe('${l.total}: ${f.money(total)}'),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    ),
  );
  return doc.save();
}
