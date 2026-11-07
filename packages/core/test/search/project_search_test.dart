// spec: project-search.md
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

const werk = Project(
  id: 'werk',
  name: 'Werk Süd Umbau',
  projectNumber: 'P-2026/014',
  orderNumber: 'A-778812',
  client: 'Bosch',
);
const mueller = Project(
  id: 'mueller',
  name: 'Müller Logistik',
  projectNumber: 'P-2025/140',
  orderNumber: 'A-120014',
  client: 'Müller GmbH',
);
const intern = Project(id: 'intern', name: 'Interne Schulung', favorite: true);
const old = Project(id: 'old', name: 'Altprojekt 014', archived: true);
const all = [werk, mueller, intern, old];

List<String> ids(
  String query, {
  Map<String, ProjectUsage> usage = const {},
  bool archived = false,
}) => [
  for (final m in searchProjects(
    query,
    all,
    usage: usage,
    includeArchived: archived,
  ))
    m.project.id,
];

ProjectMatch only(String query) => searchProjects(query, all).single;

void main() {
  test('§1 separators in numbers are ignored', () {
    for (final q in [
      'P-2026/014',
      'p2026014',
      '2026014',
      '2026/014',
      '2026-014',
    ]) {
      expect(ids(q), ['werk'], reason: q);
    }
  });

  test('§1 umlauts match both ways: ü = u = ue', () {
    for (final q in ['müller', 'muller', 'mueller', 'MUELLER']) {
      expect(ids(q), ['mueller'], reason: q);
    }
    expect(ids('sud'), ['werk']);
    expect(ids('sued'), ['werk']);
  });

  test('§2 every word must match some field', () {
    expect(ids('bosch 014'), ['werk']);
    expect(ids('bosch logistik'), isEmpty);
    expect(ids('umbau 7788'), ['werk']);
  });

  test('§3 exact number before prefix before contains', () {
    expect(only('2026014').tier, 0);
    expect(only('A-778812').tier, 0);
    expect(only('77881').tier, 1);
    // "014": werk's project number contains it (tier 2), so does mueller's
    // order number. Same tier, no usage → alphabetical (§4).
    final m = searchProjects('014', all);
    expect(
      [for (final x in m) (x.project.id, x.tier)],
      [('mueller', 2), ('werk', 2)],
    );
  });

  test('§3 word start before contains in text fields; fuzzy last', () {
    expect(only('log').tier, 1);
    expect(only('gistik').tier, 2);
    final fuzzy = searchProjects('wrkumb', all);
    expect([for (final x in fuzzy) (x.project.id, x.tier)], [('werk', 3)]);
    expect(
      ids('wu'),
      isEmpty,
      reason: 'no fuzzy matching for tokens under 3 characters',
    );
  });

  test('§4 equally good matches: most used, then most recent, then name', () {
    final usage = {
      'mueller': const ProjectUsage(count: 5, lastUsedMinute: 100),
      'werk': const ProjectUsage(count: 5, lastUsedMinute: 200),
    };
    expect(ids('014', usage: usage), ['werk', 'mueller']);
    expect(ids('014', usage: {'mueller': const ProjectUsage(count: 9)}), [
      'mueller',
      'werk',
    ]);
  });

  test('§4 empty query: favorites first, archived hidden', () {
    expect(ids(''), ['intern', 'mueller', 'werk']);
    expect(ids('   ', archived: true), ['intern', 'old', 'mueller', 'werk']);
  });

  test('§5 archived projects only when asked', () {
    expect(ids('altprojekt'), isEmpty);
    expect(ids('altprojekt', archived: true), ['old']);
  });

  test('§5 highlights point into the original strings', () {
    final m = only('2026/014');
    expect(m.highlights[ProjectField.projectNumber], [(2, 10)]);
    expect(werk.projectNumber.substring(2, 10), '2026/014');

    final u = searchProjects('mueller', all).single;
    final (s, e) = u.highlights[ProjectField.name]!.single;
    expect(mueller.name.substring(s, e), 'Müller');

    final both = searchProjects('bosch umbau', all).single;
    expect(
      both.highlights.keys,
      containsAll([ProjectField.client, ProjectField.name]),
    );
  });
}
