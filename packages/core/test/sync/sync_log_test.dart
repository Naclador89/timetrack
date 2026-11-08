// spec: sync-log.md
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

DateTime t(int minute) => DateTime.utc(2026, 11, 8, 9, minute);

SyncLogEntry cycle(int minute, {SyncReport? report, Object? error}) =>
    SyncLogEntry.of(
      start: t(minute),
      end: t(minute).add(const Duration(milliseconds: 420)),
      trigger: SyncTrigger.app,
      report: report,
      error: error,
    );

const nothing = SyncReport(
  uploadedChanges: 0,
  downloadedFiles: 0,
  appliedChanges: 0,
  resolvedRows: 0,
);

void main() {
  test(
    'idle cycles in a row become one entry; work and errors stay single',
    () async {
      final log = SyncLog(InMemorySyncStore());
      await log.record(cycle(0, report: nothing));
      await log.record(cycle(1, report: nothing));
      await log.record(cycle(2, report: nothing));
      await log.record(
        cycle(
          3,
          report: const SyncReport(
            uploadedChanges: 2,
            downloadedFiles: 1,
            appliedChanges: 5,
            resolvedRows: 0,
          ),
        ),
      );
      await log.record(cycle(4, error: Exception('offline')));
      await log.record(cycle(5, report: nothing));

      final entries = await log.entries();
      expect(entries, hasLength(4));
      expect(entries[0].idle, isTrue);
      expect(entries[1].failed, isTrue);
      expect(entries[1].error, 'Exception: offline');
      expect(
        (
          entries[2].uploadedChanges,
          entries[2].downloadedFiles,
          entries[2].appliedChanges,
        ),
        (2, 1, 5),
      );
      expect(
        (entries[3].repeats, entries[3].start, entries[3].last),
        (3, t(0), t(2)),
      );
      expect(entries[3].durationMs, 420);

      await log.clear();
      expect(await log.entries(), isEmpty);
    },
  );

  test('keeps the newest ${SyncLog.capacity} entries', () async {
    final log = SyncLog(InMemorySyncStore());
    for (var i = 0; i < SyncLog.capacity + 5; i++) {
      await log.record(cycle(i % 60, error: 'e$i'));
    }
    final entries = await log.entries();
    expect(entries, hasLength(SyncLog.capacity));
    expect(entries.first.error, 'e${SyncLog.capacity + 4}');
  });

  test('errors lose credentials, line breaks and excess length', () {
    expect(
      sanitizeSyncError(
        'GET https://anna:geheim@cloud.example/x failed\n  404',
      ),
      'GET https://cloud.example/x failed 404',
    );
    expect(sanitizeSyncError('x' * 400), hasLength(300));
  });
}
