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

  // spec: calculations.md §19
  group('§19 stamping at another time', () {
    DateTime u(String hhmm) => DateTime.parse(t(hhmm));

    test('every stamp can be dated back; a resumed project starts '
        'when the break ends', () async {
      final tr = tracker();
      at('09:00');
      await tr.clockIn(at: u('08:10'));
      await tr.startProject('A');
      at('12:30');
      await tr.startBreak(at: u('12:05'));
      at('13:00');
      await tr.endBreak(at: u('12:50'));
      at('17:00');
      await tr.clockOut(at: u('16:45'));
      final session = (await rows('work_sessions')).single.fields;
      expect(
        (session['start_utc'], session['end_utc']),
        (t('08:10'), t('16:45')),
      );
      final brk = (await rows('breaks')).single.fields;
      expect((brk['start_utc'], brk['end_utc']), (t('12:05'), t('12:50')));
      final entries = [
        for (final r in await rows('project_entries'))
          (r.fields['start_utc'], r.fields['end_utc']),
      ]..sort((a, b) => (a.$1! as String).compareTo(b.$1! as String));
      expect(entries, [(t('09:00'), t('12:05')), (t('12:50'), t('16:45'))]);
    });

    test('the location change can be dated back', () async {
      final tr = tracker();
      await tr.clockIn(location: WorkLocation.home);
      at('10:00');
      await tr.clockIn(location: WorkLocation.office, at: u('09:30'));
      final starts = [
        for (final r in await rows('work_sessions'))
          (r.fields['start_utc'], r.fields['end_utc']),
      ];
      expect(
        starts,
        containsAll([(t('07:00'), t('09:30')), (t('09:30'), null)]),
      );
    });

    test(
      'earliest instants: no overlap with what is already recorded',
      () async {
        final tr = tracker();
        expect(await tr.earliestAt(StampAction.clockIn), isNull);
        await tr.clockIn();
        at('08:00');
        await tr.clockOut();
        expect(await tr.earliestAt(StampAction.clockIn), u('08:00'));

        at('09:00');
        await tr.clockIn();
        expect(await tr.earliestAt(StampAction.clockOut), u('09:00'));
        at('10:00');
        await tr.startBreak();
        expect(await tr.earliestAt(StampAction.endBreak), u('10:00'));
        at('10:20');
        await tr.endBreak();
        // The finished break bounds the next break and the clock-out.
        expect(await tr.earliestAt(StampAction.clockOut), u('10:20'));
        at('11:00');
        await tr.startProject('A');
        expect(
          await tr.earliestAt(StampAction.startBreak),
          u('11:00'),
          reason: 'not before the running project started',
        );
        expect(await tr.earliestAt(StampAction.changeLocation), u('09:00'));
      },
    );

    test('times in the future or before the earliest instant throw', () async {
      final tr = tracker();
      await tr.clockIn();
      at('08:00');
      await tr.clockOut();
      at('09:00');
      await expectLater(tr.clockIn(at: u('07:50')), throwsArgumentError);
      await expectLater(tr.clockIn(at: u('09:01')), throwsArgumentError);
      await tr.clockIn(at: u('08:00'));
      await expectLater(tr.startBreak(at: u('07:59')), throwsArgumentError);
      expect((await tr.state()).onBreak, isFalse);
    });

    test('a trip can end at the dated-back clock-out', () async {
      final tr = tracker();
      await tr.startTrip();
      at('20:00');
      await tr.endTrip(at: u('19:40'));
      expect((await rows('trips')).single.fields['return_utc'], t('19:40'));
    });

    test('stampInstant: today, yesterday only across midnight', () {
      final zone = HomeTimeZone('Europe/Berlin');
      // 00:20 Berlin on 5 Nov.
      final now = DateTime.utc(2026, 11, 4, 23, 20);
      expect(stampInstant(zone, now, 0, 10), DateTime.utc(2026, 11, 4, 23, 10));
      expect(
        stampInstant(zone, now, 23, 50),
        DateTime.utc(2026, 11, 5, 22, 50),
        reason: 'no earliest before today: stays today (in the future)',
      );
      expect(
        stampInstant(
          zone,
          now,
          23,
          50,
          earliest: DateTime.utc(2026, 11, 4, 16),
        ),
        DateTime.utc(2026, 11, 4, 22, 50),
        reason: 'the session started yesterday',
      );
    });
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
