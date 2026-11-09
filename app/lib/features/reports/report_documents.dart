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
  if (r.day.breaks.deduction > 0)
    f.l.breakDeducted(formatMinutes(r.day.breaks.deduction)),
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
      l.credited,
      l.target,
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
        formatMinutes(r.day.credited),
        formatMinutes(r.day.target),
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
  const TripReport(
    this.trip,
    this.days, {
    this.project,
    this.times = const {},
    this.legs = const {},
    this.credited = const {},
  });

  /// Travel and on-site minutes per trip day (`W_loc`, calculations.md §2).
  final Map<LocalDate, ({int travel, int onSite})> times;

  /// Outbound, on-site and inbound legs with exact times per trip day
  /// (calculations.md §9.1).
  final Map<LocalDate, List<TripLeg>> legs;

  /// What the overtime account credits per trip day (`Cr`, §9): shown next
  /// to the actual times so the difference is visible.
  final Map<LocalDate, int> credited;

  /// The trip.
  final Trip trip;

  /// The trip's project, if it has one.
  final Project? project;

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

/// Columns of [travelTable] that hold numbers (right-aligned).
const travelNumericColumns = {5, 6, 7, 8, 10, 11};

/// The travel report as a table, one row per trip day (concept §5): the
/// exact times of the legs (calculations.md §9.1), their sums, what the
/// overtime account credits, and the per-diem.
List<List<String>> travelTable(List<TripReport> trips, ReportFormat f) {
  final l = f.l;
  String times(List<TripLeg>? legs, TripLegKind kind) => [
    for (final leg in legs ?? const <TripLeg>[])
      if (leg.kind == kind)
        '${f.clock(leg.span.start)}–${f.clock(leg.span.end)}',
  ].join(', ');
  return [
    [
      l.colDate,
      l.destination,
      l.legOutbound,
      l.legOnSite,
      l.legInbound,
      l.locationTravel,
      l.locationOnSite,
      l.creditedAccount,
      l.hoursAway,
      l.perDiem,
      l.mealsProvided,
      l.amount,
    ],
    for (final t in trips)
      for (final d in t.days)
        [
          f.date(d.date),
          [
            '${t.trip.destination} (${t.trip.country})',
            if (t.project != null) projectLabel(t.project),
          ].join(' · '),
          times(t.legs[d.date], TripLegKind.outbound),
          times(t.legs[d.date], TripLegKind.onSite),
          times(t.legs[d.date], TripLegKind.inbound),
          _minutesOrEmpty(t.times[d.date]?.travel),
          _minutesOrEmpty(t.times[d.date]?.onSite),
          _minutesOrEmpty(t.credited[d.date]),
          formatMinutes(d.absenceMinutes),
          d.rateMissing ? l.rateMissing(t.trip.country) : _category(f, d),
          d.reductionCents == 0 ? '' : '−${f.money(d.reductionCents)}',
          f.money(d.amountCents),
        ],
  ];
}

String _minutesOrEmpty(int? minutes) =>
    minutes == null || minutes == 0 ? '' : formatMinutes(minutes);

/// `Name · order number` (or project number) for reports; empty without a
/// project.
String projectLabel(Project? p) {
  if (p == null) return '';
  final number = p.orderNumber.isNotEmpty ? p.orderNumber : p.projectNumber;
  return number.isEmpty ? p.name : '${p.name} · $number';
}

/// The PDF standard fonts only cover Windows-1252; map the few characters
/// outside it that our texts use.
// The built-in PDF fonts lack these glyphs (€ showed as a box).
String _pdfSafe(String s) => s
    .replaceAll('−', '-')
    .replaceAll('…', '...')
    .replaceAll('½', '1/2')
    .replaceAll('\u00a0€', ' EUR')
    .replaceAll('€', 'EUR');

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

/// The month totals of the timesheet as (label, value), for the PDF and the
/// in-app preview.
List<(String, String)> timesheetFigures(Timesheet t, ReportFormat f) {
  final l = f.l;
  return [
    (l.worked, formatMinutes(t.worked)),
    (l.credited, formatMinutes(t.credited)),
    (l.target, formatMinutes(t.target)),
    (l.difference, formatMinutes(t.delta)),
    if (t.sundayHours > 0) (l.sundayHours, formatMinutes(t.sundayHours)),
    (l.balanceBefore, formatMinutes(t.balanceBefore)),
    (l.balanceAfter, formatMinutes(t.balanceAfter)),
    (l.workedDays, '${t.workedDays}'),
    (l.homeOfficeDays, '${t.homeOfficeDays}'),
    (l.tripDays, '${t.tripDays}'),
    if (t.servicePayDays > 0) (l.servicePayDays, '${t.servicePayDays}'),
    (l.vacationDaysTaken, f.days(t.vacationDays)),
  ];
}

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
            for (final (label, value) in timesheetFigures(t, f))
              figure(label, value),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          _pdfSafe(l.timesheetLegend),
          style: const pw.TextStyle(fontSize: 7),
        ),
        pw.SizedBox(height: 28),
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

/// Totals of the travel report as (label, value): travel and on-site time,
/// meal allowance. Shared by the PDF and the in-app preview.
List<(String, String)> travelFigures(List<TripReport> trips, ReportFormat f) {
  final l = f.l;
  int sum(int Function(({int travel, int onSite})) pick) => trips.fold(
    0,
    (a, t) => a + t.times.values.fold(0, (b, x) => b + pick(x)),
  );
  return [
    (l.locationTravel, formatMinutes(sum((x) => x.travel))),
    (l.locationOnSite, formatMinutes(sum((x) => x.onSite))),
    (
      l.creditedAccount,
      formatMinutes(
        trips.fold(0, (a, t) => a + t.credited.values.fold(0, (b, c) => b + c)),
      ),
    ),
    (l.total, f.money(trips.fold(0, (a, t) => a + t.totalCents))),
  ];
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
  doc.addPage(
    pw.MultiPage(
      // Landscape: nine columns.
      pageFormat: PdfPageFormat.a4.landscape,
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
            for (final c in travelNumericColumns) c: pw.Alignment.centerRight,
          },
        ),
        pw.SizedBox(height: 8),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            _pdfSafe(
              [
                for (final (label, value) in travelFigures(trips, f))
                  '$label: $value',
              ].join('   '),
            ),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    ),
  );
  return doc.save();
}
