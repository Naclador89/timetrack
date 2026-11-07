// spec: concept.md §2 "How the two layers interact"; data-model.md §7
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

const dev = 'aaaaaaaaaaaaaaaa';

void main() {
  late InMemorySyncStore store;
  late SyncedRepository repo;
  late DateTime now;
  TimeTracker tracker({bool autoClockIn = true, bool resume = true}) =>
      TimeTracker(
        repo,
        now: () => now,
        autoClockIn: autoClockIn,
        resumeAfterBreak: resume,
      );
  void at(String hhmm) {
    final p = hhmm.split(':');
    now = DateTime.utc(2026, 11, 4, int.parse(p[0]), int.parse(p[1]), 42);
  }

  Future<List<StoredRow>> rows(String table) =>
      store.transaction((tx) => tx.rows(table));
  String t(String hhmm) => '2026-11-04T$hhmm:00Z';

  setUp(() async {
    store = InMemorySyncStore();
    repo = await SyncedRepository.open(store, dev);
    at('07:00');
  });

  test('isoMinute stores UTC at minute precision', () {
    expect(
      isoMinute(DateTime.utc(2026, 11, 4, 7, 5, 59)),
      '2026-11-04T07:05:00Z',
    );
    expect(
      isoMinute(DateTime.parse('2026-11-04T08:05:00+01:00')),
      '2026-11-04T07:05:00Z',
    );
  });

  test('clock in and out; clocking in twice does nothing', () async {
    final tr = tracker();
    await tr.clockIn(location: WorkLocation.home);
    await tr.clockIn(location: WorkLocation.home);
    expect((await tr.state()).location, WorkLocation.home);
    at('15:30');
    await tr.clockOut();
    final sessions = await rows('work_sessions');
    expect(sessions.single.fields, containsPair('end_utc', t('15:30')));
    expect((await tr.state()).clockedIn, isFalse);
  });

  test(
    'starting a project while clocked out clocks in (auto clock-in)',
    () async {
      final tr = tracker();
      await tr.startProject('A', location: WorkLocation.home);
      final s = await tr.state();
      expect(
        (s.clockedIn, s.location, s.projectId),
        (true, WorkLocation.home, 'A'),
      );
      await expectLater(
        tracker(autoClockIn: false).startProject('B'),
        completes,
        reason: 'already clocked in',
      );
    },
  );

  test(
    'without auto clock-in, starting a project while clocked out fails',
    () async {
      await expectLater(
        tracker(autoClockIn: false).startProject('A'),
        throwsStateError,
      );
    },
  );

  test(
    'switching projects stops the previous one at the same minute',
    () async {
      final tr = tracker();
      await tr.startProject('A');
      at('09:00');
      await tr.startProject('B');
      await tr.startProject('B'); // no-op
      final entries = await rows('project_entries');
      expect(entries, hasLength(2));
      final a = entries.firstWhere((e) => e.fields['project_id'] == 'A');
      final b = entries.firstWhere((e) => e.fields['project_id'] == 'B');
      expect(
        (a.fields['end_utc'], b.fields['start_utc'], b.fields['end_utc']),
        (t('09:00'), t('09:00'), null),
      );
    },
  );

  test('a break stops the project; ending it resumes the project', () async {
    final tr = tracker();
    await tr.startProject('A');
    at('12:00');
    await tr.startBreak();
    expect(
      ((await tr.state()).onBreak, (await tr.state()).projectId),
      (true, null),
    );
    at('12:30');
    await tr.endBreak();
    final s = await tr.state();
    expect((s.onBreak, s.projectId), (false, 'A'));
    expect(await rows('project_entries'), hasLength(2));
  });

  test('without resume, ending a break leaves no project running', () async {
    final tr = tracker(resume: false);
    await tr.startProject('A');
    at('12:00');
    await tr.startBreak();
    at('12:30');
    await tr.endBreak();
    expect((await tr.state()).projectId, isNull);
  });

  test('starting a project during a break ends the break', () async {
    final tr = tracker();
    await tr.clockIn();
    at('12:00');
    await tr.startBreak();
    at('12:20');
    await tr.startProject('B');
    final s = await tr.state();
    expect((s.onBreak, s.projectId), (false, 'B'));
    expect((await rows('breaks')).single.fields['end_utc'], t('12:20'));
  });

  test('clocking out ends break and project at the same minute', () async {
    final tr = tracker();
    await tr.startProject('A');
    at('12:00');
    await tr.startBreak();
    at('12:10');
    await tr.clockOut();
    expect((await rows('breaks')).single.fields['end_utc'], t('12:10'));
    expect((await rows('work_sessions')).single.fields['end_utc'], t('12:10'));
    expect(
      (await rows('project_entries')).single.fields['end_utc'],
      t('12:00'),
    );
  });

  test('changing location splits the session', () async {
    final tr = tracker();
    await tr.clockIn(location: WorkLocation.home);
    at('09:00');
    await tr.clockIn(location: WorkLocation.office); // same as changeLocation
    final sessions = await rows('work_sessions');
    expect(sessions, hasLength(2));
    expect((await tr.state()).location, WorkLocation.office);
  });

  test('trips start and end now', () async {
    final tr = tracker();
    await tr.startTrip(destination: 'Stuttgart');
    expect((await tr.state()).trip!.fields['destination'], 'Stuttgart');
    at('20:00');
    await tr.endTrip();
    expect((await tr.state()).trip, isNull);
    expect((await rows('trips')).single.fields['return_utc'], t('20:00'));
  });

  group('AppSettings (data-model.md §7)', () {
    test('defaults when nothing is stored', () {
      final s = AppSettings.fromRows(const []);
      expect(
        (
          s.federalState,
          s.breakMode,
          s.autoClockIn,
          s.travel.saturdayCapMinutes,
        ),
        (null, BreakRuleMode.warn, true, 660),
      );
    });

    test(
      'stored values are read; enums use snake_case; bad values fall back',
      () async {
        await saveSetting(repo, SettingKeys.federalState, 'BY');
        await saveSetting(
          repo,
          SettingKeys.breakRuleMode,
          BreakRuleMode.deduct,
        );
        await saveSetting(
          repo,
          SettingKeys.travelHoliday,
          TripDayRule.likeSaturday,
        );
        await saveSetting(repo, SettingKeys.startingBalance, 125);
        await saveSetting(repo, SettingKeys.balanceStartDate, '2026-11-01');
        await saveSetting(repo, SettingKeys.homeOfficeDayRule, 'nonsense');
        await saveSetting(repo, SettingKeys.vacationCarryOver(2026), 2.5);
        final s = AppSettings.fromRows(await rows('settings'));
        expect(
          (await rows('settings'))
              .firstWhere((r) => r.id == SettingKeys.travelHoliday)
              .fields['value'],
          'like_saturday',
        );
        expect(
          (s.federalState, s.breakMode, s.travel.holiday),
          (FederalState.by, BreakRuleMode.deduct, TripDayRule.likeSaturday),
        );
        expect(
          (s.startingBalance, s.balanceStart, s.homeOfficeDayRule),
          (125, LocalDate(2026, 11, 1), HomeOfficeDayRule.majority),
        );
        expect(s.number(SettingKeys.vacationCarryOver(2026)), 2.5);
      },
    );
  });
}
