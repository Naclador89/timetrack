// calculations.md §3, §12; data-model.md §4
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

final zone = HomeTimeZone();
LocalDate d(String iso) => LocalDate.parse(iso);
DateTime at(String date, String hm) {
  final p = hm.split(':');
  return zone.instantAt(d(date), int.parse(p[0]), int.parse(p[1]));
}

StoredRow row(String id, Map<String, Object?> fields) =>
    StoredRow(table: 'project_entries', id: id, fields: fields);

Ledger ledger(LedgerData data) => Ledger(
  data: data,
  zone: zone,
  holidays: HolidayCalendar(FederalState.nw),
  settings: LedgerSettings(balanceStart: d('2026-11-01')),
  nowMinute: epochMinute(at('2026-11-30', '12:00')),
);

void main() {
  test('data-model §4: rows become a time span or a duration, never both', () {
    final data = ledgerDataFromRows([
      row('span', {
        'project_id': 'a',
        'start_utc': '2026-11-03T07:00:00Z',
        'end_utc': '2026-11-03T09:00:00Z',
        'note': 'Review',
      }),
      row('dur', {
        'project_id': 'b',
        'date': '2026-11-03',
        'duration_min': 150,
        'note': 'Angebot geschrieben',
      }),
      row('both', {
        'project_id': 'c',
        'start_utc': '2026-11-03T10:00:00Z',
        'date': '2026-11-03',
        'duration_min': 30,
      }),
      row('incomplete', {'project_id': 'd', 'date': '2026-11-03'}),
    ]);
    expect(data.entries.map((e) => (e.id, e.note)), [
      ('span', 'Review'),
      ('both', ''),
    ]);
    expect(data.durations.map((x) => (x.id, x.minutes, x.note)), [
      ('dur', 150, 'Angebot geschrieben'),
    ]);
  });

  test('§3 durations count fully on their date; unassigned never below 0', () {
    final l = ledger(
      LedgerData(
        sessions: [
          WorkSession(
            id: 's',
            start: at('2026-11-03', '08:00'),
            end: at('2026-11-03', '16:00'),
            location: WorkLocation.office,
          ),
        ],
        durations: const [],
        entries: [
          ProjectEntry(
            id: 'e',
            projectId: 'a',
            start: at('2026-11-03', '08:00'),
            end: at('2026-11-03', '10:00'),
          ),
        ],
      ),
    );
    expect(l.day(d('2026-11-03')).work.unassigned, 360);

    final withDurations = ledger(
      LedgerData(
        sessions: [
          WorkSession(
            id: 's',
            start: at('2026-11-03', '08:00'),
            end: at('2026-11-03', '16:00'),
            location: WorkLocation.office,
          ),
        ],
        entries: [
          ProjectEntry(
            id: 'e',
            projectId: 'a',
            start: at('2026-11-03', '08:00'),
            end: at('2026-11-03', '10:00'),
          ),
        ],
        durations: [
          ProjectDuration(
            id: 'x',
            projectId: 'b',
            date: d('2026-11-03'),
            minutes: 150,
          ),
          ProjectDuration(
            id: 'y',
            projectId: 'a',
            date: d('2026-11-03'),
            minutes: 30,
          ),
          ProjectDuration(
            id: 'z',
            projectId: 'b',
            date: d('2026-11-04'),
            minutes: 60,
          ),
        ],
      ),
    );
    final work = withDurations.day(d('2026-11-03')).work;
    expect((work.projectTime, work.unassigned), (300, 180));
    expect(work.byProject, {'a': 150, 'b': 150});
    expect(withDurations.day(d('2026-11-04')).work.byProject, {
      'b': 60,
    }, reason: 'counts without attendance');
    expect(withDurations.day(d('2026-11-04')).work.unassigned, 0);
  });

  test('§12 more project time than worked time is flagged', () {
    final l = ledger(
      LedgerData(
        sessions: [
          WorkSession(
            id: 's',
            start: at('2026-11-03', '08:00'),
            end: at('2026-11-03', '10:00'),
            location: WorkLocation.office,
          ),
        ],
        durations: [
          ProjectDuration(
            id: 'x',
            projectId: 'b',
            date: d('2026-11-03'),
            minutes: 180,
          ),
        ],
      ),
    );
    final items = reviewItems(l, from: d('2026-11-03'), to: d('2026-11-03'));
    expect(
      items.where((i) => i.kind == ReviewKind.projectOverWork).single.minutes,
      60,
    );
  });

  test('order report lists the summaries of the day per order', () {
    final projects = {
      'a': const Project(id: 'a', name: 'Werk', orderNumber: 'A-1'),
      'b': const Project(id: 'b', name: 'Werk Nachtrag', orderNumber: 'A-1'),
    };
    final l = ledger(
      LedgerData(
        sessions: [
          WorkSession(
            id: 's',
            start: at('2026-11-03', '08:00'),
            end: at('2026-11-03', '16:00'),
            location: WorkLocation.office,
          ),
        ],
        entries: [
          ProjectEntry(
            id: 'e',
            projectId: 'a',
            start: at('2026-11-03', '08:00'),
            end: at('2026-11-03', '09:00'),
            note: 'Abstimmung',
          ),
        ],
        durations: [
          ProjectDuration(
            id: 'x',
            projectId: 'b',
            date: d('2026-11-03'),
            minutes: 90,
            note: 'Zeichnung geprüft',
          ),
          ProjectDuration(
            id: 'y',
            projectId: 'a',
            date: d('2026-11-03'),
            minutes: 30,
            note: 'Abstimmung',
          ),
        ],
      ),
    );
    final booking = buildOrderReport(
      l,
      projects,
      from: d('2026-11-03'),
      to: d('2026-11-03'),
    ).single;
    expect((booking.orderNumber, booking.minutes), ('A-1', 180));
    expect(booking.notes, ['Abstimmung', 'Zeichnung geprüft']);
  });
}
