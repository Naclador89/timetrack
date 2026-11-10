// spec: reminders.md
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

const dev = 'aaaaaaaaaaaaaaaa';

void main() {
  late InMemorySyncStore store;
  late SyncedRepository repo;
  DateTime t(String s) => DateTime.parse('${s}Z');

  setUp(() async {
    store = InMemorySyncStore();
    repo = await SyncedRepository.open(store, dev);
    await repo.write('work_schedules', 'w', {
      'valid_from': '2026-01-01',
      for (final d in ['mon', 'tue', 'wed', 'thu', 'fri']) 'minutes_$d': 480,
    });
  });

  Future<void> row(String table, String id, String start, String? end) =>
      repo.write(table, id, {
        if (table == 'work_sessions') ...{
          'start_utc': '${start}Z',
          'end_utc': end == null ? null : '${end}Z',
          'location': 'office',
        } else if (table == 'project_entries') ...{
          'project_id': 'p',
          'start_utc': '${start}Z',
          'end_utc': end == null ? null : '${end}Z',
        } else ...{
          'start_utc': '${start}Z',
          'end_utc': end == null ? null : '${end}Z',
        },
      });
  ForgottenSession? forgotten(String now) =>
      forgottenClockOut(store.allRows.values, t(now));

  group('§1 forgotten clock-out', () {
    test('a session from yesterday is forgotten, with suggestions', () async {
      // Earlier days ended at 16:00 local.
      for (final d in ['02', '03']) {
        await row(
          'work_sessions',
          'old$d',
          '2026-11-${d}T07:00:00',
          '2026-11-${d}T15:00:00',
        );
      }
      await row('work_sessions', 's', '2026-11-04T07:00:00', null);
      await row(
        'project_entries',
        'e',
        '2026-11-04T07:00:00',
        '2026-11-04T14:10:00',
      );
      final f = forgotten('2026-11-05T06:30:00')!;
      expect(f.id, 's');
      expect(f.suggestions, [
        (kind: EndSuggestionKind.lastActivity, at: t('2026-11-04T14:10:00')),
        (kind: EndSuggestionKind.usualEnd, at: t('2026-11-04T15:00:00')),
        // 08:00 local + 8 h + 30 min break.
        (kind: EndSuggestionKind.targetReached, at: t('2026-11-04T15:30:00')),
      ]);
    });

    test('equal suggestions are shown once', () async {
      await row(
        'work_sessions',
        'old',
        '2026-11-03T07:00:00',
        '2026-11-03T15:30:00',
      );
      await row('work_sessions', 's', '2026-11-04T07:00:00', null);
      final f = forgotten('2026-11-05T06:30:00')!;
      expect(f.suggestions, [
        (kind: EndSuggestionKind.targetReached, at: t('2026-11-04T15:30:00')),
      ]);
    });

    test('a session today within the limit is not forgotten', () async {
      await row('work_sessions', 's', '2026-11-04T07:00:00', null);
      expect(forgotten('2026-11-04T15:00:00'), isNull);
    });

    test('over the 12-hour limit on the same day it is', () async {
      await row('work_sessions', 's', '2026-11-04T05:00:00', null);
      final f = forgotten('2026-11-04T17:30:00')!;
      expect(f.suggestions.map((s) => s.kind), [
        EndSuggestionKind.targetReached,
      ], reason: '06:00 local + 8:30');
      expect(f.suggestions.single.at, t('2026-11-04T13:30:00'));
    });

    test('suggestions in the future are left out', () async {
      await row('work_sessions', 's', '2026-11-04T07:00:00', null);
      await repo.write('settings', SettingKeys.openSessionLimit, {'value': 60});
      final f = forgotten('2026-11-04T10:00:00')!;
      expect(f.suggestions, isEmpty, reason: 'target only at 15:30');
    });

    test(
      'clockOut(at:) ends at that time; later entries are deleted',
      () async {
        await row('work_sessions', 's', '2026-11-04T07:00:00', null);
        await row('project_entries', 'late', '2026-11-04T20:00:00', null);
        await row('breaks', 'b', '2026-11-04T15:00:00', null);
        final tracker = TimeTracker(repo, now: () => t('2026-11-05T06:00:00'));
        await tracker.clockOut(at: t('2026-11-04T16:00:00'));
        expect(
          (await repo.get('work_sessions', 's'))!.fields['end_utc'],
          '2026-11-04T16:00:00Z',
        );
        expect(
          (await repo.get('breaks', 'b'))!.fields['end_utc'],
          '2026-11-04T16:00:00Z',
        );
        expect((await repo.get('project_entries', 'late'))!.isDeleted, isTrue);
        expect((await tracker.state()).clockedIn, isFalse);
      },
    );
  });

  group('§2 reminders', () {
    List<Reminder> reminders(
      String now, {
      Map<String, Object?> set = const {},
    }) {
      final rows = store.allRows.values.toList();
      final ledger = appLedger(rows, t(now));
      final settings = AppSettings.fromRows(rows);
      return nextReminders(
        ledger,
        TrackerState.fromRows(rows),
        ledger.zone.dateOf(t(now)),
        settings,
      );
    }

    test('break due after 5:45 h, 10 hours near at 9:45 h', () async {
      await row('work_sessions', 's', '2026-11-04T07:00:00', null);
      final r = reminders('2026-11-04T09:00:00');
      expect(r.map((x) => (x.kind, x.at)), [
        (ReminderKind.breakDue, t('2026-11-04T12:45:00')),
        (ReminderKind.targetReached, t('2026-11-04T15:30:00')),
        (ReminderKind.longDay, t('2026-11-04T16:45:00')),
      ]);
    });

    test('a break of 15 min or more starts a new stretch and key', () async {
      await row('work_sessions', 's', '2026-11-04T07:00:00', null);
      final before = reminders('2026-11-04T09:00:00').first;
      await row('breaks', 'b', '2026-11-04T11:00:00', '2026-11-04T11:20:00');
      final after = reminders('2026-11-04T12:00:00').first;
      expect(after.at, t('2026-11-04T17:05:00'), reason: '40 min since 11:20');
      expect(after.key, isNot(before.key));
    });

    test('a short gap does not reset the stretch', () async {
      await row('work_sessions', 's', '2026-11-04T07:00:00', null);
      await row('breaks', 'b', '2026-11-04T09:00:00', '2026-11-04T09:10:00');
      final r = reminders('2026-11-04T10:00:00').first;
      expect(r.at, t('2026-11-04T12:55:00'), reason: '2:50 h worked');
    });

    test('nothing on a break, when clocked out or switched off', () async {
      await row('work_sessions', 's', '2026-11-04T07:00:00', null);
      await repo.write('settings', SettingKeys.remindBreak, {'value': false});
      expect(reminders('2026-11-04T09:00:00').map((r) => r.kind), [
        ReminderKind.targetReached,
        ReminderKind.longDay,
      ]);
      await row('breaks', 'b', '2026-11-04T09:00:00', null);
      expect(reminders('2026-11-04T09:30:00'), isEmpty);
    });

    test(
      '§2 target reached: due at the forecast target time; off by setting',
      () async {
        await repo.write('work_schedules', 'w', {
          'valid_from': '2026-01-01',
          for (final d in ['mon', 'tue', 'wed', 'thu', 'fri'])
            'minutes_$d': 480,
        });
        await row('work_sessions', 's', '2026-11-04T07:00:00', null);
        Reminder? target(String now) =>
            reminders(now)
                .where((r) => r.kind == ReminderKind.targetReached)
                .firstOrNull;
        // 8 h plus the 30 min break ArbZG requires.
        expect(target('2026-11-04T09:00:00')!.at, t('2026-11-04T15:30:00'));
        expect(target('2026-11-04T09:00:00')!.key, '2026-11-04/target_reached');
        // Reached already (e.g. when the task runs late): due now.
        expect(target('2026-11-04T16:00:00')!.at, t('2026-11-04T16:00:00'));
        await repo.write('settings', SettingKeys.remindTarget, {
          'value': false,
        });
        expect(target('2026-11-04T09:00:00'), isNull);
      },
    );

    test('overdue reminders are due now', () async {
      await row('work_sessions', 's', '2026-11-04T05:00:00', null);
      final r = reminders('2026-11-04T15:30:00');
      expect(r.every((x) => x.at == t('2026-11-04T15:30:00')), isTrue);
    });
  });
}
