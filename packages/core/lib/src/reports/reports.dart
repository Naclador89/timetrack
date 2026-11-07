import '../model/attendance.dart';
import '../model/planning.dart';
import '../model/project.dart';
import '../rules/home_office.dart';
import '../rules/ledger.dart';
import '../time/local_date.dart';

/// One day of the monthly timesheet (concept §5, "Monthly timesheet PDF").
final class TimesheetRow {
  /// Creates a row. Use [buildTimesheet] instead of calling this directly.
  const TimesheetRow({
    required this.day,
    required this.holiday,
    required this.firstStart,
    required this.lastEnd,
    required this.breakMinutes,
  });

  /// The full evaluation of the day.
  final DayResult day;

  /// Name of the public holiday, if any.
  final String? holiday;

  /// First start of work (minutes since the epoch), `null` if no work.
  final int? firstStart;

  /// Last end of work (minutes since the epoch), `null` if no work.
  final int? lastEnd;

  /// Time between first start and last end that wasn't worked, plus any
  /// automatic break deduction (calculations.md §4).
  final int breakMinutes;

  /// Locations worked at, in a stable order.
  List<WorkLocation> get locations => [
    for (final l in WorkLocation.values)
      if (day.work.workedAt(l) > 0) l,
  ];
}

/// A calendar month as a timesheet with totals (calculations.md §8, §11, §14).
final class Timesheet {
  /// Creates a timesheet. Use [buildTimesheet] instead of calling this directly.
  const Timesheet({
    required this.year,
    required this.month,
    required this.rows,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.homeOfficeDays,
    required this.workedDays,
  });

  /// The year.
  final int year;

  /// The month, 1–12.
  final int month;

  /// One row per day of the month, up to today if the month is still running.
  final List<TimesheetRow> rows;

  /// Overtime balance at the end of the previous month.
  final int balanceBefore;

  /// Overtime balance at the end of the last row.
  final int balanceAfter;

  /// Home-office days by the majority rule (§11.5).
  final int homeOfficeDays;

  /// Days with work.
  final int workedDays;

  int _sum(int Function(DayResult) f) => rows.fold(0, (a, r) => a + f(r.day));

  /// Total worked minutes.
  int get worked => _sum((d) => d.work.worked);

  /// Total target minutes.
  int get target => _sum((d) => d.target);

  /// Total credited minutes.
  int get credited => _sum((d) => d.credited);

  /// Total difference; equals `balanceAfter − balanceBefore`.
  int get delta => _sum((d) => d.delta);

  /// Vacation days taken in this month (workdays only, §10).
  double get vacationDays => rows
      .where((r) => r.day.target > 0)
      .expand((r) => r.day.absences)
      .where((a) => a.kind == AbsenceKind.vacation)
      .fold(0, (sum, a) => sum + a.fraction);
}

/// Builds the timesheet of [month]/[year] from [ledger]. Days after the
/// ledger's today are left out.
Timesheet buildTimesheet(Ledger ledger, int year, int month) {
  final first = LocalDate(year, month, 1);
  final next = first.addDays(31).startOfMonth;
  final today = ledger.today;
  final rows = <TimesheetRow>[];
  var homeOffice = 0, worked = 0;
  for (var d = first; d.isBefore(next) && !d.isAfter(today); d = d.addDays(1)) {
    final day = ledger.day(d);
    final spans = day.work.working.spans;
    final gaps = day.work.working.gaps.fold(0, (a, g) => a + g.length);
    rows.add(
      TimesheetRow(
        day: day,
        holiday: ledger.holidays.holidayOn(d)?.name,
        firstStart: spans.isEmpty ? null : spans.first.start,
        lastEnd: spans.isEmpty ? null : spans.last.end,
        breakMinutes: gaps + day.breaks.deduction,
      ),
    );
    homeOffice += homeOfficeValue(day, HomeOfficeDayRule.majority).toInt();
    if (day.work.worked > 0) worked++;
  }
  final lastDay = rows.isEmpty ? first.addDays(-1) : rows.last.day.date;
  return Timesheet(
    year: year,
    month: month,
    rows: rows,
    balanceBefore: ledger.balanceAtEndOf(first.addDays(-1)),
    balanceAfter: ledger.balanceAtEndOf(lastDay),
    homeOfficeDays: homeOffice,
    workedDays: worked,
  );
}

/// Minutes booked on one order number on one day (concept §5, "Order report").
final class OrderBooking {
  /// Creates a booking.
  const OrderBooking({
    required this.date,
    required this.orderNumber,
    required this.projectNumber,
    required this.projectName,
    required this.minutes,
    this.notes = const [],
  });

  /// The day.
  final LocalDate date;

  /// Order number (Auftragsnummer); empty if the project has none.
  final String orderNumber;

  /// Project number.
  final String projectNumber;

  /// Project name.
  final String projectName;

  /// Project time on this day (calculations.md §3).
  final int minutes;

  /// The summaries ("what did I do?") of the entries behind this booking.
  final List<String> notes;
}

/// Project time per day and order number for [from]–[to], ready to copy into
/// a company booking system. Sorted by date, then order number.
List<OrderBooking> buildOrderReport(
  Ledger ledger,
  Map<String, Project> projects, {
  required LocalDate from,
  required LocalDate to,
}) {
  final bookings = <OrderBooking>[];
  for (var d = from; !d.isAfter(to); d = d.addDays(1)) {
    final notes = _notesByProject(ledger, d);
    final perOrder = <String, (Project?, int, List<String>)>{};
    for (final MapEntry(key: id, value: minutes)
        in ledger.day(d).work.byProject.entries) {
      final p = projects[id];
      final key = p == null
          ? '?$id'
          : (p.orderNumber.isEmpty ? '#${p.id}' : p.orderNumber);
      final (_, before, previousNotes) =
          perOrder[key] ?? (p, 0, const <String>[]);
      perOrder[key] = (p, before + minutes, [...previousNotes, ...?notes[id]]);
    }
    final sorted = perOrder.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final MapEntry(value: (p, minutes, notes)) in sorted) {
      bookings.add(
        OrderBooking(
          date: d,
          orderNumber: p?.orderNumber ?? '',
          projectNumber: p?.projectNumber ?? '',
          projectName: p?.name ?? '?',
          minutes: minutes,
          notes: notes.toSet().toList(),
        ),
      );
    }
  }
  return bookings;
}

/// Non-empty summaries per project id of the entries starting on [day].
Map<String, List<String>> _notesByProject(Ledger ledger, LocalDate day) {
  final result = <String, List<String>>{};
  void add(String projectId, String note) {
    if (note.trim().isEmpty) return;
    (result[projectId] ??= []).add(note.trim());
  }

  for (final e in ledger.data.entries) {
    if (ledger.zone.dateOf(e.start) == day) add(e.projectId, e.note);
  }
  for (final d in ledger.data.durations) {
    if (d.date == day) add(d.projectId, d.note);
  }
  return result;
}

/// Formats [rows] as CSV (RFC 4180 quoting). With [excel], uses `;` and a
/// UTF-8 BOM so German Excel opens it correctly (concept §5, "CSV export").
String toCsv(List<List<String>> rows, {bool excel = true}) {
  final sep = excel ? ';' : ',';
  String cell(String v) =>
      v.contains(sep) || v.contains('"') || v.contains('\n') || v.contains('\r')
      ? '"${v.replaceAll('"', '""')}"'
      : v;
  final body = rows.map((r) => r.map(cell).join(sep)).join('\r\n');
  return '${excel ? '﻿' : ''}$body\r\n';
}
