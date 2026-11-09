import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timetrack/features/reports/report_documents.dart';
import 'package:timetrack/l10n/app_localizations.dart';
import 'package:timetrack_core/timetrack_core.dart';

final zone = HomeTimeZone();
LocalDate d(String iso) => LocalDate.parse(iso);
DateTime at(String date, String hm) {
  final p = hm.split(':');
  return zone.instantAt(d(date), int.parse(p[0]), int.parse(p[1]));
}

Ledger sampleLedger() => Ledger(
  data: LedgerData(
    schedules: [
      WorkSchedule(
        id: 'w',
        validFrom: d('2026-01-01'),
        weekdayMinutes: [480, 480, 480, 480, 480, 0, 0],
      ),
    ],
    sessions: [
      WorkSession(
        id: 'a',
        start: at('2026-11-02', '08:00'),
        end: at('2026-11-02', '12:00'),
        location: WorkLocation.home,
      ),
      WorkSession(
        id: 'b',
        start: at('2026-11-02', '12:30'),
        end: at('2026-11-02', '17:00'),
        location: WorkLocation.home,
      ),
    ],
    absences: [
      Absence(
        id: 'v',
        date: d('2026-11-03'),
        kind: AbsenceKind.vacation,
        fraction: 0.5,
      ),
    ],
  ),
  zone: zone,
  holidays: HolidayCalendar(FederalState.nw),
  settings: LedgerSettings(balanceStart: d('2026-11-01')),
  nowMinute: epochMinute(at('2026-11-03', '20:00')),
);

void main() {
  setUpAll(() => initializeDateFormatting('de'));
  final f = ReportFormat(
    lookupAppLocalizations(const Locale('de')),
    'de',
    zone,
  );
  final now = DateTime.utc(2026, 11, 7, 12);

  test('timesheet table: German headers, times, breaks and notes', () {
    final table = timesheetTable(buildTimesheet(sampleLedger(), 2026, 11), f);
    expect(table.first.take(4), ['Datum', 'Beginn', 'Ende', 'Pause']);
    final monday = table.firstWhere((r) => r.first.contains('02.11.2026'));
    expect(monday.sublist(1, 5), ['08:00', '17:00', '0:30', '8:30']);
    expect(monday.last, contains('Homeoffice'));
    expect(
      table.firstWhere((r) => r.first.contains('01.11.2026')).last,
      contains('Allerheiligen'),
    );
    expect(
      table.firstWhere((r) => r.first.contains('03.11.2026')).last,
      contains('Urlaub ½'),
    );
    final csv = toCsv(table);
    expect(csv, startsWith('﻿Datum;Beginn'));
  });

  test(
    '§9 trip Sundays: Sunday hours column and total, not in the balance',
    () {
      final base = sampleLedger();
      final ledger = Ledger(
        data: LedgerData(
          schedules: base.data.schedules,
          trips: [
            Trip(
              id: 't',
              depart: at('2026-11-01', '06:00'),
              returnAt: at('2026-11-01', '22:00'),
            ),
          ],
          sessions: [
            WorkSession(
              id: 's',
              start: at('2026-11-01', '06:00'),
              end: at('2026-11-01', '10:00'),
              location: WorkLocation.travel,
            ),
            WorkSession(
              id: 'o',
              start: at('2026-11-01', '10:00'),
              end: at('2026-11-01', '19:00'),
              location: WorkLocation.onSite,
            ),
          ],
        ),
        zone: zone,
        holidays: HolidayCalendar(FederalState.nw),
        settings: LedgerSettings(balanceStart: d('2026-11-01')),
        nowMinute: epochMinute(at('2026-11-03', '20:00')),
      );
      final sheet = buildTimesheet(ledger, 2026, 11);
      expect(
        sheet.sundayHours,
        720,
        reason: '4 h travel + 9 h on site, max 12 h',
      );
      expect(sheet.rows.first.day.credited, 0);
      final table = timesheetTable(sheet, f);
      final column = table.first.indexOf('Sonn-/Feiertagsstunden');
      expect(column, greaterThan(0));
      expect(table[1][column], '12:00');
      expect(sheet.servicePayDays, 0, reason: 'no supplement on a Sunday');
      expect(
        timesheetTable(buildTimesheet(sampleLedger(), 2026, 11), f).first,
        isNot(contains('Sonn-/Feiertagsstunden')),
      );
    },
  );

  test('§9 days of a service trip are counted for the supplement', () {
    final base = sampleLedger();
    Timesheet sheet({required bool service}) => buildTimesheet(
      Ledger(
        data: LedgerData(
          schedules: base.data.schedules,
          trips: [
            Trip(
              id: 't',
              depart: at('2026-11-02', '06:00'),
              returnAt: at('2026-11-03', '20:00'),
              service: service,
            ),
          ],
        ),
        zone: zone,
        holidays: HolidayCalendar(FederalState.nw),
        settings: LedgerSettings(balanceStart: d('2026-11-01')),
        nowMinute: epochMinute(at('2026-11-04', '20:00')),
      ),
      2026,
      11,
    );
    expect(sheet(service: true).servicePayDays, 2);
    expect(
      timesheetFigures(sheet(service: true), f),
      contains(('Tage mit Reisezuschlag', '2')),
    );
    expect(
      timesheetFigures(sheet(service: false), f).map((x) => x.$1),
      isNot(contains('Tage mit Reisezuschlag')),
    );
  });

  test('timesheet and travel PDFs are valid PDF documents', () async {
    final pdf = await timesheetPdf(
      buildTimesheet(sampleLedger(), 2026, 11),
      f,
      now: now,
    );
    expect(utf8.decode(pdf.sublist(0, 5)), '%PDF-');
    final trip = Trip(
      id: 't',
      depart: at('2026-11-02', '06:00'),
      returnAt: at('2026-11-03', '20:00'),
      destination: 'München',
    );
    final days = perDiemForTrip(
      trip,
      zone: zone,
      rates: defaultPerDiemRates(),
      meals: [
        TripMeals(id: 'm', tripId: 't', date: d('2026-11-03'), breakfast: true),
      ],
    );
    final reports = [
      TripReport(
        trip,
        days,
        project: const Project(
          id: 'p',
          name: 'Werk Süd',
          orderNumber: 'A-4711',
        ),
        times: {d('2026-11-02'): (travel: 150, onSite: 0)},
        credited: {d('2026-11-02'): 480},
        legs: {
          d('2026-11-02'): [
            TripLeg(
              TripLegKind.outbound,
              Span.fromInstants(
                at('2026-11-02', '07:00'),
                at('2026-11-02', '09:30'),
              ),
              sessionId: 'a',
            ),
            TripLeg(
              TripLegKind.onSite,
              Span.fromInstants(
                at('2026-11-02', '09:45'),
                at('2026-11-02', '17:00'),
              ),
              sessionId: 'b',
            ),
          ],
        },
      ),
    ];
    expect(reports.single.totalCents, 1400 + 1400 - 560);
    final table = travelTable(reports, f);
    expect(table[2].last, '8,40\u00a0€');
    expect(table.first.sublist(2, 8), [
      'Anfahrt',
      'Beim Kunden',
      'Rückfahrt',
      'Unterwegs',
      'Vor Ort',
      'Angerechnet (Konto)',
    ]);
    // Exact times of the legs, then the sums and the account credit.
    expect(table[1].sublist(2, 8), [
      '07:00–09:30',
      '09:45–17:00',
      '',
      '2:30',
      '',
      '8:00',
    ]);
    expect(table[2][10], '−5,60\u00a0€');
    expect(table[1][1], 'München (Deutschland) · Werk Süd · A-4711');
    final travel = await travelPdf(reports, 2026, 11, f, now: now);
    expect(utf8.decode(travel.sublist(0, 5)), '%PDF-');
  });

  test('backup contains every row with its field clocks', () {
    final json = jsonDecode(
      encodeBackup([
        StoredRow(
          table: 'projects',
          id: 'p',
          fields: const {'name': 'Werk Süd', 'deleted': true},
          fieldClock: const {'name': 'x'},
        ),
      ], now),
    ) as Map<String, Object?>;
    expect(json['format'], 1);
    final row = (json['rows']! as List).single as Map;
    expect(
      (
        row['tbl'],
        (row['fields'] as Map)['name'],
        (row['fieldClock'] as Map)['name'],
      ),
      ('projects', 'Werk Süd', 'x'),
    );
  });
}
