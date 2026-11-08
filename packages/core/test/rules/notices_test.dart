// spec: calculations.md §12; data-model.md §14
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

const dev = 'aaaaaaaaaaaaaaaa';

void main() {
  late InMemorySyncStore store;
  late SyncedRepository repo;
  final now = DateTime.utc(2026, 11, 6, 12);
  final wed = LocalDate(2026, 11, 4);

  setUp(() async {
    store = InMemorySyncStore();
    repo = await SyncedRepository.open(store, dev);
    // 08:00–16:00 Berlin, no break, no project.
    await repo.write('work_sessions', 's', {
      'start_utc': '2026-11-04T07:00:00Z',
      'end_utc': '2026-11-04T15:00:00Z',
      'location': 'office',
    });
  });

  List<ReviewItem> items({int min = 1}) => reviewItems(
    appLedger(store.allRows.values, now),
    from: wed,
    to: wed,
    includeUnassigned: true,
    unassignedMinMinutes: min,
  );

  test('§12 unassigned time below the threshold is no notice', () {
    expect(items().any((i) => i.kind == ReviewKind.unassigned), isTrue);
    expect(
      items(min: 481).any((i) => i.kind == ReviewKind.unassigned),
      isFalse,
    );
  });

  test('§12 categories switched off and dismissed keys are hidden', () async {
    final all = items();
    final both = splitNotices(all, shows: (_) => true, dismissed: const {});
    expect(both.shown.map(NoticeCategory.of).toSet(), {
      NoticeCategory.unassigned,
      NoticeCategory.breaks,
    });
    expect(
      both.shown.where((i) => NoticeCategory.of(i) == NoticeCategory.breaks),
      hasLength(1),
      reason: 'one card for both break warnings',
    );

    final noBreaks = splitNotices(
      all,
      shows: (c) => c != NoticeCategory.breaks,
      dismissed: const {},
    );
    expect(noBreaks.shown.map(NoticeCategory.of), [NoticeCategory.unassigned]);
    expect(noBreaks.hidden.map(NoticeCategory.of), [NoticeCategory.breaks]);

    final unassigned = all.firstWhere((i) => i.kind == ReviewKind.unassigned);
    await repo.write('dismissed_notices', noticeKey(unassigned), {
      'date': '$wed',
    });
    final dismissed = splitNotices(
      all,
      shows: (_) => true,
      dismissed: dismissedNoticeKeys(store.allRows.values),
    );
    expect(dismissed.shown.map(NoticeCategory.of), [NoticeCategory.breaks]);
    expect(noticeKey(unassigned), '2026-11-04/unassigned');
  });

  test('settings: threshold and switches with defaults', () async {
    expect(AppSettings.fromRows(const []).noticeUnassignedMinMinutes, 30);
    await saveSetting(repo, SettingKeys.noticeUnassignedMin, 120);
    await saveSetting(repo, SettingKeys.noticeShow('long_day'), false);
    final s = AppSettings.fromRows(store.allRows.values);
    expect(s.noticeUnassignedMinMinutes, 120);
    expect(s.showsNotice(NoticeCategory.longDay.wireName), isFalse);
    expect(s.showsNotice(NoticeCategory.breaks.wireName), isTrue);
  });
}
