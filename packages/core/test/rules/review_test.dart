// spec: calculations.md §12
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

final berlin = HomeTimeZone();
LocalDate d(String iso) => LocalDate.parse(iso);

DateTime at(String date, String hhmm) {
  final p = hhmm.split(':');
  return instantOfEpochMinute(
    berlin.daySpan(d(date)).start + int.parse(p[0]) * 60 + int.parse(p[1]),
  );
}

void main() {
  test('§12 collects open sessions, overlaps, project time outside work and ArbZG warnings', () {
    final ledger = Ledger(
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
            location: WorkLocation.office,
          ),
          WorkSession(
            id: 'b',
            start: at('2026-11-02', '11:00'),
            end: at('2026-11-02', '13:00'),
            location: WorkLocation.home,
          ),
          WorkSession(
            id: 'open',
            start: at('2026-11-03', '08:00'),
            location: WorkLocation.office,
          ),
        ],
        entries: [
          ProjectEntry(
            id: 'p',
            projectId: 'x',
            start: at('2026-11-02', '12:30'),
            end: at('2026-11-02', '14:00'),
          ),
        ],
      ),
      zone: berlin,
      holidays: HolidayCalendar(FederalState.nw),
      settings: LedgerSettings(balanceStart: d('2026-11-01')),
      nowMinute: epochMinute(at('2026-11-03', '21:00')),
    );
    final items = reviewItems(
      ledger,
      from: d('2026-11-02'),
      to: d('2026-11-03'),
    );
    String key(ReviewItem i) =>
        '${i.date} ${i.kind.name}${i.arbzg == null ? '' : '/${i.arbzg!.name}'}';
    expect(items.map(key), [
      '2026-11-02 overlappingSessions',
      '2026-11-02 projectOutsideSession',
      '2026-11-03 openSessionTooLong',
      '2026-11-03 arbzg/breakMissing',
      '2026-11-03 arbzg/workOver6hWithoutBreak',
      '2026-11-03 arbzg/over10h',
    ]);
    expect(
      items.firstWhere((i) => i.kind == ReviewKind.openSessionTooLong).refId,
      'open',
    );
    expect(
      items
          .firstWhere((i) => i.kind == ReviewKind.projectOutsideSession)
          .minutes,
      60,
    );
  });
}
