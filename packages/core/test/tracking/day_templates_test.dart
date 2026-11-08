// spec: data-model.md §13; calculations.md §17
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

const dev = 'aaaaaaaaaaaaaaaa';
final zone = HomeTimeZone();

void main() {
  late InMemorySyncStore store;
  late SyncedRepository repo;
  final now = DateTime.utc(2026, 11, 6, 12);
  final wed = LocalDate(2026, 11, 4), thu = LocalDate(2026, 11, 5);

  setUp(() async {
    store = InMemorySyncStore();
    repo = await SyncedRepository.open(store, dev);
  });

  Ledger ledger() => appLedger(store.allRows.values, now);

  test('copy a day: sessions, breaks, entries and durations', () async {
    // 07:00–15:30 UTC = 08:00–16:30 Berlin.
    await repo.write('work_sessions', 's', {
      'start_utc': '2026-11-04T07:00:00Z',
      'end_utc': '2026-11-04T15:30:00Z',
      'location': 'home',
    });
    await repo.write('breaks', 'b', {
      'start_utc': '2026-11-04T11:00:00Z',
      'end_utc': '2026-11-04T11:30:00Z',
    });
    await repo.write('project_entries', 'e', {
      'project_id': 'p',
      'start_utc': '2026-11-04T07:00:00Z',
      'end_utc': '2026-11-04T09:00:00Z',
    });
    await repo.write('project_entries', 'd', {
      'project_id': 'q',
      'date': '2026-11-04',
      'duration_min': 60,
    });
    final template = captureDay(ledger().data, wed, zone);
    expect(template.items.length, 4);
    expect(template.items.first.start, 480);
    final created = await applyDayTemplate(repo, template, thu, zone: zone);
    expect(created.length, 4);
    final a = ledger().day(wed), b = ledger().day(thu);
    expect(b.work.worked, a.work.worked);
    expect(b.work.byProject, a.work.byProject);
    expect(b.type, DayType.home);
  });

  test('templates round-trip through their row', () async {
    const t = DayTemplate(
      id: 't',
      name: 'Büro',
      items: [
        TemplateItem(
          TemplateItemKind.session,
          start: 480,
          end: 990,
          location: WorkLocation.office,
        ),
        TemplateItem(TemplateItemKind.duration, minutes: 30, projectId: 'p'),
      ],
    );
    await saveDayTemplate(repo, t);
    final back = dayTemplateFromRow(store.rowsOf('day_templates')['t']!)!;
    expect(back.name, 'Büro');
    expect(
      [for (final i in back.items) i.toJson()],
      [for (final i in t.items) i.toJson()],
    );
  });

  test('§3 unassigned gaps: working time without timed entries', () async {
    await repo.write('work_sessions', 's', {
      'start_utc': '2026-11-04T07:00:00Z',
      'end_utc': '2026-11-04T11:00:00Z',
      'location': 'office',
    });
    await repo.write('project_entries', 'e', {
      'project_id': 'p',
      'start_utc': '2026-11-04T08:00:00Z',
      'end_utc': '2026-11-04T09:00:00Z',
    });
    final gaps = ledger().day(wed).work.unassignedSpans.spans;
    expect([for (final g in gaps) g.length], [60, 120]);
  });

  test('§12 unassigned review item only for finished days', () async {
    await repo.write('work_sessions', 's', {
      'start_utc': '2026-11-04T07:00:00Z',
      'end_utc': '2026-11-04T13:00:00Z',
      'location': 'office',
    });
    List<ReviewItem> items() => reviewItems(
      ledger(),
      from: wed,
      to: LocalDate(2026, 11, 6),
      includeUnassigned: true,
    ).where((i) => i.kind == ReviewKind.unassigned).toList();
    expect(items().single.minutes, 360);
    await repo.write('work_sessions', 'open', {
      'start_utc': '2026-11-06T07:00:00Z',
      'location': 'office',
    });
    expect(items().length, 1, reason: 'today is still running');
    await repo.write('trips', 't', {
      'depart_utc': '2026-11-04T05:00:00Z',
      'return_utc': '2026-11-04T18:00:00Z',
    });
    expect(items(), isEmpty, reason: 'trip days have no project time');
  });

  test(
    '§4 a missing break goes in the middle of the longest stretch',
    () async {
      await repo.write('work_sessions', 's', {
        'start_utc': '2026-11-04T07:00:00Z',
        'end_utc': '2026-11-04T14:00:00Z',
        'location': 'office',
      });
      final span = suggestBreak(ledger().day(wed), 30)!;
      expect(zone.toLocal(instantOfEpochMinute(span.start)).hour, 11);
      expect(span.length, 30);
    },
  );

  test('§4.1 a missing break goes to the usual slot if it is worked', () async {
    // spec: calculations.md §4.1
    await repo.write('work_sessions', 's', {
      'start_utc': '2026-11-04T07:00:00Z',
      'end_utc': '2026-11-04T14:00:00Z',
      'location': 'office',
    });
    final noon = epochMinute(zone.instantAt(wed, 12, 0));
    final usual = Span(noon, noon + 30);
    expect(suggestBreak(ledger().day(wed), 30, preferred: usual), usual);
    // 15:00 is after the session (08:00–15:00 local): the middle again.
    final late = Span(noon + 180, noon + 210);
    final span = suggestBreak(ledger().day(wed), 30, preferred: late)!;
    expect(zone.toLocal(instantOfEpochMinute(span.start)).hour, 11);
  });
}
