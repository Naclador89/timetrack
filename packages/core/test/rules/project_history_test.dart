// spec: calculations.md §3.1
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

const dev = 'aaaaaaaaaaaaaaaa';

void main() {
  late InMemorySyncStore store;
  late SyncedRepository repo;
  final now = DateTime.utc(2026, 11, 20, 12);

  setUp(() async {
    store = InMemorySyncStore();
    repo = await SyncedRepository.open(store, dev);
  });

  Ledger ledger() => appLedger(store.allRows.values, now);
  Future<void> work(String date, String from, String to) =>
      repo.write('work_sessions', repo.newId(), {
        'start_utc': '${date}T${from}Z',
        'end_utc': '${date}T${to}Z',
        'location': 'office',
      });
  Future<void> entry(String date, String from, String to, String note) =>
      repo.write('project_entries', repo.newId(), {
        'project_id': 'p',
        'start_utc': '${date}T${from}Z',
        'end_utc': '${date}T${to}Z',
        'note': note,
      });
  Future<void> duration(String date, int minutes, String note) => repo.write(
    'project_entries',
    repo.newId(),
    {'project_id': 'p', 'date': date, 'duration_min': minutes, 'note': note},
  );

  test('§3.1 booked minutes per day with the notes, oldest first', () async {
    await work('2026-11-02', '07:00:00', '15:00:00');
    await entry('2026-11-02', '07:00:00', '09:00:00', 'Planung');
    await duration('2026-11-02', 60, 'Planung');
    await duration('2026-11-03', 90, 'Abnahme');
    await work('2026-11-03', '07:00:00', '12:00:00');
    final days = projectHistory(ledger(), 'p');
    expect(days.map((d) => (d.date, d.minutes, d.notes.join('|'))), [
      (LocalDate(2026, 11, 2), 180, 'Planung'),
      (LocalDate(2026, 11, 3), 90, 'Abnahme'),
    ]);
  });

  test('§3.1 a trip project gets the trip days\' time', () async {
    await repo.write('trips', 't', {
      'depart_utc': '2026-11-04T06:00:00Z',
      'return_utc': '2026-11-04T18:00:00Z',
      'project_id': 'p',
    });
    await work('2026-11-04', '06:00:00', '16:00:00');
    expect(projectHistory(ledger(), 'p').single.minutes, 600);
  });

  group('§3.1 budget', () {
    Project project(int budget) =>
        Project(id: 'p', name: 'Werk Süd', budgetMinutes: budget);
    List<ReviewItem> items(int budget) => budgetItems(
      ledger(),
      [project(budget)],
      from: LocalDate(2026, 11, 1),
      to: LocalDate(2026, 11, 30),
    );

    setUp(() async {
      for (final d in ['02', '03', '04']) {
        await duration('2026-11-$d', 240, '');
      }
    });

    test('80 % and over 100 % on the days they are reached', () async {
      // 4 h, 8 h, 12 h of a 10 h budget.
      expect(items(600).map((i) => (i.date, i.kind)), [
        (LocalDate(2026, 11, 3), ReviewKind.projectBudgetNear),
        (LocalDate(2026, 11, 4), ReviewKind.projectBudgetOver),
      ]);
    });

    test('both on one day → only "over"', () async {
      expect(items(420).map((i) => (i.date, i.kind)), [
        (LocalDate(2026, 11, 3), ReviewKind.projectBudgetOver),
      ]);
    });

    test('exactly 100 % is not over', () async {
      expect(items(720).map((i) => i.kind), [ReviewKind.projectBudgetNear]);
    });

    test('no budget → no notices; they are review items', () async {
      expect(
        budgetItems(
          ledger(),
          [const Project(id: 'p', name: 'x')],
          from: LocalDate(2026, 11, 1),
          to: LocalDate(2026, 11, 30),
        ),
        isEmpty,
      );
      final review = reviewItems(
        ledger(),
        from: LocalDate(2026, 11, 4),
        to: LocalDate(2026, 11, 4),
        projects: [project(600)],
      ).where((i) => i.refId == 'p').toList();
      expect(review.single.kind, ReviewKind.projectBudgetOver);
      expect(NoticeCategory.of(review.single), NoticeCategory.projectBudget);
    });
  });
}
