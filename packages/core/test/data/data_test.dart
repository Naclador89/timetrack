// spec: data-model.md, sync-format.md §6–§7
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

const dev = 'aaaaaaaaaaaaaaaa';

StoredRow row(String table, String id, Map<String, Object?> fields) =>
    StoredRow(table: table, id: id, fields: fields);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('DriftSyncStore', () {
    test(
      'rows, outbox, pending batch and clock survive closing the database',
      () async {
        final dir = await Directory.systemTemp.createTemp('timetrack_test');
        addTearDown(() => dir.delete(recursive: true));
        final file = File('${dir.path}/tt.sqlite');

        var db = TimeTrackDatabase(NativeDatabase(file));
        var repo = await SyncedRepository.open(DriftSyncStore(db), dev);
        await repo.write('projects', 'p', {
          'name': 'Werk Süd',
          'favorite': true,
        });
        final second = await repo.write('projects', 'p', {
          'project_number': 'P-1',
        });
        await DriftSyncStore(db).transaction(
          (tx) => tx.setPendingBatch(PendingBatch('x.jsonl.gz.enc', [second])),
        );
        await db.close();

        db = TimeTrackDatabase(NativeDatabase(file));
        addTearDown(db.close);
        final store = DriftSyncStore(db);
        repo = await SyncedRepository.open(store, dev);
        final p = await repo.get('projects', 'p');
        expect(p!.fields, {
          'name': 'Werk Süd',
          'favorite': true,
          'project_number': 'P-1',
        });
        expect(p.fieldClock['project_number'], second.hlc.toString());
        expect(await store.transaction((tx) => tx.outbox()), hasLength(2));
        expect(
          (await store.transaction((tx) => tx.pendingBatch()))!
              .changes
              .single
              .hlc,
          second.hlc,
        );
        expect(
          repo.clock.tick().isAfter(second.hlc),
          isTrue,
          reason: 'clock continues',
        );
      },
    );

    test('a failing transaction leaves nothing behind', () async {
      final db = TimeTrackDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final store = DriftSyncStore(db);
      await expectLater(
        store.transaction((tx) async {
          await tx.putRow(row('projects', 'p', {'name': 'X'}));
          await tx.markSeen('f', 'e1');
          throw StateError('boom');
        }),
        throwsStateError,
      );
      expect(await store.transaction((tx) => tx.rows('projects')), isEmpty);
      expect(await store.transaction((tx) => tx.seenEtag('f')), isNull);
    });

    test('watchRows emits after writes', () async {
      final db = TimeTrackDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final store = DriftSyncStore(db);
      final repo = await SyncedRepository.open(store, dev);
      final emitted = store.watchRows({'projects'}).map((rows) => rows.length);
      final emittedOne = expectLater(emitted, emitsThrough(1));
      await repo.write('projects', 'p', {'name': 'X'});
      await emittedOne;
    });
  });

  group('mapping (data-model.md)', () {
    test('complete rows become models, with defaults for optional fields', () {
      final data = ledgerDataFromRows([
        row('work_sessions', 's', {'start_utc': '2026-11-04T07:00:00Z'}),
        row('work_sessions', 'h', {
          'start_utc': '2026-11-04T07:00:00Z',
          'end_utc': '2026-11-04T15:00:00Z',
          'location': 'home',
        }),
        row('work_schedules', 'w', {
          'valid_from': '2026-01-01',
          'minutes_mon': 480,
          'minutes_fri': 360,
          'vacation_days': 30,
        }),
        row('absences', 'a', {
          'date': '2026-11-05',
          'kind': 'comp_time',
          'fraction': 0.5,
        }),
        row('trips', 't', {'depart_utc': '2026-11-10T05:00:00Z'}),
      ]);
      expect(data.sessions.map((s) => (s.id, s.location, s.isOpen)), [
        ('s', WorkLocation.office, true),
        ('h', WorkLocation.home, false),
      ]);
      expect(data.schedules.single.weekdayMinutes, [480, 0, 0, 0, 360, 0, 0]);
      expect(data.schedules.single.annualVacationDays, 30);
      expect(
        (data.absences.single.kind, data.absences.single.fraction),
        (AbsenceKind.compTime, 0.5),
      );
      expect(
        (
          data.trips.single.country,
          data.trips.single.overnight,
          data.trips.single.returnAt,
        ),
        ('DE', true, null),
      );
    });

    test('data-model.md §9: a trip keeps its order and notes', () {
      Trip trip(Map<String, Object?> fields) => ledgerDataFromRows([
        row('trips', 't', {'depart_utc': '2026-11-10T05:00:00Z', ...fields}),
      ]).trips.single;
      final t = trip({
        'order_kind': 'ga',
        'order_number': ' 4711 ',
        'note': 'Ersatzteil mitnehmen',
      });
      expect(
        (t.orderKind, t.orderNumber, t.orderLabel, t.note),
        (TripOrderKind.warranty, '4711', 'GA 4711', 'Ersatzteil mitnehmen'),
      );
      // A kind from a newer app keeps the number; no number, no label.
      expect(trip({'order_kind': 'xx', 'order_number': '12'}).orderLabel, '12');
      expect(trip({'order_kind': 'mo'}).orderLabel, '');
    });

    test(
      'deleted, incomplete and malformed rows are skipped (sync-format.md §6)',
      () {
        final data = ledgerDataFromRows([
          row('work_sessions', 'del', {
            'start_utc': '2026-11-04T07:00:00Z',
            'deleted': true,
          }),
          row('work_sessions', 'partial', {'end_utc': '2026-11-04T15:00:00Z'}),
          row('work_sessions', 'bad', {'start_utc': 'yesterday'}),
          row('work_sessions', 'badloc', {
            'start_utc': '2026-11-04T07:00:00Z',
            'location': 'moon',
          }),
          row('absences', 'nokind', {'date': '2026-11-05'}),
          row('unknown_table', 'x', {'a': 1}),
        ]);
        expect(data.sessions, isEmpty);
        expect(data.absences, isEmpty);
      },
    );

    test('projects, rules, meals and rates', () {
      final p = projectFromRow(
        row('projects', 'p', {
          'name': 'Werk',
          'order_number': 'A-1',
          'archived': true,
        }),
      )!;
      expect(
        (p.name, p.projectNumber, p.orderNumber, p.archived, p.favorite),
        ('Werk', '', 'A-1', true, false),
      );
      final rule = homeOfficeRuleFromRow(
        row('home_office_rules', 'r', {
          'valid_from': '2026-01-01',
          'period': 'month',
          'max_percent': 40,
        }),
      )!;
      expect(
        (rule.period, rule.unit, rule.basis, rule.maxPercent),
        (QuotaPeriod.month, QuotaUnit.days, QuotaBasis.worked, 40),
      );
      final meals = tripMealsFromRow(
        row('trip_meals', 'm', {
          'trip_id': 't',
          'date': '2026-11-10',
          'breakfast': true,
        }),
      )!;
      expect((meals.breakfast, meals.lunch), (true, false));
      final rate = perDiemRateFromRow(
        row('per_diem_rates', 'd', {
          'country': 'DE',
          'valid_from': '2020-01-01',
          'partial_cents': 1400,
          'full_cents': 2800,
        }),
      )!;
      expect(rate.fullCents, 2800);
      expect(
        projectFromRow(row('projects', 'x', {'client': 'no name'})),
        isNull,
      );
    });

    test('rows written through the repository feed the Ledger', () async {
      final store = InMemorySyncStore();
      final repo = await SyncedRepository.open(store, dev);
      await repo.write('work_schedules', 'w', {
        'valid_from': '2026-01-01',
        for (final d in ['mon', 'tue', 'wed', 'thu', 'fri']) 'minutes_$d': 480,
      });
      await repo.write('work_sessions', 's', {
        'start_utc': '2026-11-04T07:00:00Z',
        'end_utc': '2026-11-04T16:00:00Z',
        'location': 'home',
      });
      await repo.write('breaks', 'b', {
        'start_utc': '2026-11-04T11:00:00Z',
        'end_utc': '2026-11-04T11:30:00Z',
      });
      final rows = [
        for (final t in syncedTables)
          ...await store.transaction((tx) => tx.rows(t)),
      ];
      final ledger = Ledger(
        data: ledgerDataFromRows(rows),
        zone: HomeTimeZone(),
        holidays: HolidayCalendar(FederalState.nw),
        settings: LedgerSettings(balanceStart: LocalDate(2026, 11, 2)),
        nowMinute: epochMinute(DateTime.utc(2026, 11, 30)),
      );
      final day = ledger.day(LocalDate(2026, 11, 4));
      expect((day.work.worked, day.delta), (510, 30));
      expect(day.work.workedAt(WorkLocation.home), 510);
    });
  });
}
